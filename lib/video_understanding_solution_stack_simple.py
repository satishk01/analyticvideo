import os, json, time, base64
from aws_cdk import (
    Stack,
    CfnOutput,
    aws_iam as _iam,
    aws_s3 as _s3,
    aws_ec2 as _ec2,
    aws_rds as _rds,
    aws_lambda as _lambda,
    aws_apigateway as _apigw,
    aws_logs as _logs,
    aws_ssm as _ssm,
    aws_secretsmanager as _secretsmanager,
    Duration, CfnOutput, BundlingOptions, RemovalPolicy
)
from constructs import Construct

# Configuration constants
model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
fast_model_id = "anthropic.claude-3-haiku-20240307-v1:0"
balanced_model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
raw_folder = "source"
summary_folder = "summary"
video_script_folder = "video_timeline"
video_caption_folder = "captions"
transcription_folder = "audio_transcript/source"
entity_sentiment_folder = "entities"
database_name = "videos"
videos_api_resource = "videos"

CONFIG_LABEL_DETECTION_ENABLED = "label_detection_enabled"
CONFIG_TRANSCRIPTION_ENABLED = "transcription_enabled"

class VideoUnderstandingSolutionStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        
        aws_region = Stack.of(self).region
        aws_account_id = Stack.of(self).account

        # Simple VPC without flow logs for demo
        vpc = _ec2.Vpc(self, f"Vpc",
            ip_addresses=_ec2.IpAddresses.cidr("10.120.0.0/16"),
            max_azs=2,  # Reduced for simplicity
            enable_dns_support=True,
            enable_dns_hostnames=True,
            nat_gateways=1,
            vpc_name=f"{construct_id}-VPC",
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
        default_configuration_parameters = {
            CONFIG_LABEL_DETECTION_ENABLED: "1",
            CONFIG_TRANSCRIPTION_ENABLED: "1"
        }
        configuration_parameters_ssm = _ssm.StringParameter(self, f"{construct_id}-configuration-parameters",
            parameter_name=f"{construct_id}-configuration",
            string_value=json.dumps(default_configuration_parameters)
        )

        # Simple S3 Video bucket
        video_bucket_s3 = _s3.Bucket(
            self, 
            "video-understanding", 
            block_public_access=_s3.BlockPublicAccess.BLOCK_ALL,
            removal_policy=RemovalPolicy.DESTROY,
            auto_delete_objects=True,  # For easy cleanup
            cors=[_s3.CorsRule(
                allowed_headers=["*"],
                allowed_methods=[_s3.HttpMethods.PUT, _s3.HttpMethods.GET, _s3.HttpMethods.HEAD, _s3.HttpMethods.POST, _s3.HttpMethods.DELETE],
                allowed_origins=["*"],
                max_age=3000
            )],
            enforce_ssl=True     
        )

        # CloudWatch Log Group for API Gateway
        api_log_group = _logs.LogGroup(
            self, "APILogGroup",
            log_group_name=f"/aws/apigateway/{construct_id}",
            removal_policy=RemovalPolicy.DESTROY
        )

        # Authentication Lambda with proper logging
        auth_lambda_role = _iam.Role(
            self, "AuthLambdaRole",
            role_name=f"{construct_id}-{aws_region}-auth-lambda",
            assumed_by=_iam.ServicePrincipal("lambda.amazonaws.com"),
            managed_policies=[
                _iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AWSLambdaBasicExecutionRole")
            ]
        )

        auth_lambda = _lambda.Function(
            self, "AuthLambda",
            function_name=f"{construct_id}-auth",
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
            timeout=Duration.minutes(1),
            memory_size=256
        )

        # API Gateway for authentication with proper logging and validation
        auth_api = _apigw.RestApi(
            self, "AuthAPI",
            rest_api_name=f"{construct_id}-auth-api",
            description="Authentication API for Video Understanding Solution",
            cloud_watch_role=True,
            deploy_options=_apigw.StageOptions(
                stage_name="prod",
                logging_level=_apigw.MethodLoggingLevel.INFO,
                access_log_destination=_apigw.LogGroupLogDestination(api_log_group),
                access_log_format=_apigw.AccessLogFormat.json_with_standard_fields()
            ),
            default_cors_preflight_options=_apigw.CorsOptions(
                allow_origins=_apigw.Cors.ALL_ORIGINS,
                allow_methods=_apigw.Cors.ALL_METHODS,
                allow_headers=["Content-Type", "Authorization"]
            )
        )

        # Request validator for API Gateway
        request_validator = _apigw.RequestValidator(
            self, "AuthAPIRequestValidator",
            rest_api=auth_api,
            validate_request_body=True,
            validate_request_parameters=True
        )

        # Auth API resources
        auth_resource = auth_api.root.add_resource("auth")
        login_resource = auth_resource.add_resource("login")
        logout_resource = auth_resource.add_resource("logout")
        validate_resource = auth_resource.add_resource("validate")

        # Lambda integration
        auth_integration = _apigw.LambdaIntegration(auth_lambda)

        # API methods with request validation
        login_resource.add_method("POST", auth_integration,
            request_validator=request_validator
        )
        logout_resource.add_method("POST", auth_integration,
            request_validator=request_validator
        )
        validate_resource.add_method("GET", auth_integration,
            request_validator=request_validator
        )

        # Database security group
        db_security_group = _ec2.SecurityGroup(self, "VectorDBSecurityGroup",
            security_group_name=f"{construct_id}-vectorDB",
            vpc=vpc,
            allow_all_outbound=False,  # More restrictive
            description="Security group for Aurora Serverless PostgreSQL",
        )

        # Only allow PostgreSQL from within VPC
        db_security_group.add_ingress_rule(
            peer=_ec2.Peer.ipv4(vpc.vpc_cidr_block),
            connection=_ec2.Port.tcp(5432),
            description="PostgreSQL port from within VPC"
        )

        # Aurora cluster secret with rotation
        aurora_cluster_username = "clusteradmin"
        aurora_cluster_secret = _secretsmanager.Secret(self, "AuroraClusterCredentials",
            secret_name=f"{construct_id}-vectorDB-creds",
            description="Aurora Cluster Credentials",
            generate_secret_string=_secretsmanager.SecretStringGenerator(
                exclude_characters="\"@/\\ '",
                generate_string_key="password",
                password_length=30,
                secret_string_template=json.dumps({
                    "username": aurora_cluster_username,
                    "engine": "postgres"
                })
            )
        )

        # Add automatic rotation for the secret
        aurora_cluster_secret.add_rotation_schedule(
            "SecretRotation",
            automatically_after=Duration.days(30)
        )

        # Aurora database with proper settings
        db_subnet_group = _rds.SubnetGroup(self, "DBSubnetGroup",
            vpc=vpc,
            description="Aurora subnet group",
            vpc_subnets=private_with_egress_subnets,
            subnet_group_name="Aurora subnet group"
        )

        aurora_cluster = _rds.DatabaseCluster(self, f"{construct_id}AuroraDatabase",
            credentials=_rds.Credentials.from_secret(aurora_cluster_secret, aurora_cluster_username),
            engine=_rds.DatabaseClusterEngine.aurora_postgres(version=_rds.AuroraPostgresEngineVersion.VER_15_5),
            writer=_rds.ClusterInstance.serverless_v2("writer"),
            serverless_v2_min_capacity=0.5,
            serverless_v2_max_capacity=1,
            default_database_name=database_name,
            security_groups=[db_security_group],
            vpc=vpc,
            subnet_group=db_subnet_group,
            storage_encrypted=True,
            deletion_protection=True,  # Enable for production-like setup
            iam_authentication=True,  # Enable IAM authentication
        )

        # Video processing API with proper logging
        video_api = _apigw.RestApi(
            self, "VideoAPI",
            rest_api_name=f"{construct_id}-video-api",
            description="Video processing API",
            cloud_watch_role=True,
            deploy_options=_apigw.StageOptions(
                stage_name="prod",
                logging_level=_apigw.MethodLoggingLevel.INFO,
                access_log_destination=_apigw.LogGroupLogDestination(api_log_group),
                access_log_format=_apigw.AccessLogFormat.json_with_standard_fields()
            ),
            default_cors_preflight_options=_apigw.CorsOptions(
                allow_origins=_apigw.Cors.ALL_ORIGINS,
                allow_methods=_apigw.Cors.ALL_METHODS,
                allow_headers=["Content-Type", "Authorization"]
            )
        )

        # Output important values
        CfnOutput(self, "AuthAPIUrl", 
            value=auth_api.url,
            description="Authentication API URL"
        )
        
        CfnOutput(self, "VideoAPIUrl",
            value=video_api.url, 
            description="Video API URL"
        )
        
        CfnOutput(self, "S3BucketName",
            value=video_bucket_s3.bucket_name,
            description="S3 bucket for videos"
        )
        
        CfnOutput(self, "DatabaseEndpoint",
            value=aurora_cluster.cluster_endpoint.hostname,
            description="Aurora database endpoint"
        )

        CfnOutput(self, "WebAppCredentials",
            value="Username: admin, Password: admin",
            description="Hardcoded login credentials"
        )