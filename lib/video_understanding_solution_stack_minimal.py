import os, json
from aws_cdk import (
    Stack,
    CfnOutput,
    aws_iam as _iam,
    aws_s3 as _s3,
    aws_ec2 as _ec2,
    aws_rds as _rds,
    aws_lambda as _lambda,
    aws_apigateway as _apigw,
    aws_ssm as _ssm,
    aws_secretsmanager as _secretsmanager,
    Duration, BundlingOptions, RemovalPolicy
)
from constructs import Construct

# Configuration constants
raw_folder = "source"
summary_folder = "summary"
video_script_folder = "video_timeline"
video_caption_folder = "captions"
transcription_folder = "audio_transcript/source"
entity_sentiment_folder = "entities"
database_name = "videos"
videos_api_resource = "videos"

class VideoUnderstandingSolutionStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        
        aws_region = Stack.of(self).region
        aws_account_id = Stack.of(self).account

        # Minimal VPC
        vpc = _ec2.Vpc(self, f"Vpc",
            ip_addresses=_ec2.IpAddresses.cidr("10.120.0.0/16"),
            max_azs=2,
            nat_gateways=1,
            subnet_configuration=[
                _ec2.SubnetConfiguration(
                    cidr_mask=24,
                    name='public',
                    subnet_type=_ec2.SubnetType.PUBLIC,
                ),
                _ec2.SubnetConfiguration(
                    cidr_mask=24,
                    name='private_with_egress',
                    subnet_type=_ec2.SubnetType.PRIVATE_WITH_EGRESS,
                )
            ]
        )
        
        private_with_egress_subnets = _ec2.SubnetSelection(subnet_type=_ec2.SubnetType.PRIVATE_WITH_EGRESS)

        # Configuration parameters
        configuration_parameters_ssm = _ssm.StringParameter(self, f"{construct_id}-configuration-parameters",
            parameter_name=f"{construct_id}-configuration",
            string_value=json.dumps({"label_detection_enabled": "1", "transcription_enabled": "1"})
        )

        # Simple S3 bucket
        video_bucket_s3 = _s3.Bucket(
            self, 
            "video-understanding", 
            removal_policy=RemovalPolicy.DESTROY,
            auto_delete_objects=True,
            cors=[_s3.CorsRule(
                allowed_headers=["*"],
                allowed_methods=[_s3.HttpMethods.PUT, _s3.HttpMethods.GET, _s3.HttpMethods.HEAD, _s3.HttpMethods.POST, _s3.HttpMethods.DELETE],
                allowed_origins=["*"],
                max_age=3000
            )]
        )

        # Authentication Lambda
        auth_lambda_role = _iam.Role(
            self, "AuthLambdaRole",
            assumed_by=_iam.ServicePrincipal("lambda.amazonaws.com"),
            managed_policies=[
                _iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AWSLambdaBasicExecutionRole")
            ]
        )

        auth_lambda = _lambda.Function(
            self, "AuthLambda",
            runtime=_lambda.Runtime.PYTHON_3_13,
            code=_lambda.Code.from_asset('./lib/auth_lambda',
                bundling=BundlingOptions(
                    image=_lambda.Runtime.PYTHON_3_13.bundling_image,
                    command=[
                        'bash', '-c',
                        'pip install --platform manylinux2014_x86_64 --only-binary=:all: -r requirements.txt -t /asset-output && cp -au . /asset-output',
                    ],
                )
            ),
            handler="index.lambda_handler",
            role=auth_lambda_role,
            timeout=Duration.minutes(1)
        )

        # Simple API Gateway
        auth_api = _apigw.RestApi(
            self, "AuthAPI",
            rest_api_name=f"{construct_id}-auth-api",
            default_cors_preflight_options=_apigw.CorsOptions(
                allow_origins=_apigw.Cors.ALL_ORIGINS,
                allow_methods=_apigw.Cors.ALL_METHODS,
                allow_headers=["Content-Type", "Authorization"]
            )
        )

        # Auth API resources
        auth_resource = auth_api.root.add_resource("auth")
        login_resource = auth_resource.add_resource("login")
        logout_resource = auth_resource.add_resource("logout")
        validate_resource = auth_resource.add_resource("validate")

        # Lambda integration
        auth_integration = _apigw.LambdaIntegration(auth_lambda)

        # API methods
        login_resource.add_method("POST", auth_integration)
        logout_resource.add_method("POST", auth_integration)
        validate_resource.add_method("GET", auth_integration)

        # Database security group
        db_security_group = _ec2.SecurityGroup(self, "VectorDBSecurityGroup",
            vpc=vpc,
            allow_all_outbound=False
        )

        db_security_group.add_ingress_rule(
            peer=_ec2.Peer.ipv4(vpc.vpc_cidr_block),
            connection=_ec2.Port.tcp(5432)
        )

        # Aurora cluster secret
        aurora_cluster_secret = _secretsmanager.Secret(self, "AuroraClusterCredentials",
            generate_secret_string=_secretsmanager.SecretStringGenerator(
                exclude_characters="\"@/\\ '",
                generate_string_key="password",
                password_length=30,
                secret_string_template=json.dumps({
                    "username": "clusteradmin",
                    "engine": "postgres"
                })
            )
        )

        # Aurora database
        db_subnet_group = _rds.SubnetGroup(self, "DBSubnetGroup",
            vpc=vpc,
            vpc_subnets=private_with_egress_subnets
        )

        aurora_cluster = _rds.DatabaseCluster(self, f"{construct_id}AuroraDatabase",
            credentials=_rds.Credentials.from_secret(aurora_cluster_secret, "clusteradmin"),
            engine=_rds.DatabaseClusterEngine.aurora_postgres(version=_rds.AuroraPostgresEngineVersion.VER_15_5),
            writer=_rds.ClusterInstance.serverless_v2("writer"),
            serverless_v2_min_capacity=0.5,
            serverless_v2_max_capacity=1,
            default_database_name=database_name,
            security_groups=[db_security_group],
            vpc=vpc,
            subnet_group=db_subnet_group,
            deletion_protection=False
        )

        # Video processing API
        video_api = _apigw.RestApi(
            self, "VideoAPI",
            rest_api_name=f"{construct_id}-video-api",
            default_cors_preflight_options=_apigw.CorsOptions(
                allow_origins=_apigw.Cors.ALL_ORIGINS,
                allow_methods=_apigw.Cors.ALL_METHODS,
                allow_headers=["Content-Type", "Authorization"]
            )
        )

        # Outputs
        CfnOutput(self, "AuthAPIUrl", value=auth_api.url)
        CfnOutput(self, "VideoAPIUrl", value=video_api.url)
        CfnOutput(self, "S3BucketName", value=video_bucket_s3.bucket_name)
        CfnOutput(self, "DatabaseEndpoint", value=aurora_cluster.cluster_endpoint.hostname)
        CfnOutput(self, "WebAppCredentials", value="Username: admin, Password: admin")