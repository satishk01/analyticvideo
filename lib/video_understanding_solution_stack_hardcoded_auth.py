import os, json, time, base64
from aws_cdk import (
    Stack,
    CfnOutput,
    aws_iam as _iam,
    aws_s3 as _s3,
    aws_ec2 as _ec2,
    aws_rds as _rds,
    aws_events as _events,
    aws_events_targets as _events_targets,
    aws_lambda as _lambda,
    aws_apigateway as _apigw,
    aws_ecs as _ecs,
    aws_logs as _logs,
    aws_ssm as _ssm,
    aws_stepfunctions as _sfn,
    aws_stepfunctions_tasks as _sfn_tasks,
    aws_bedrock as _bedrock,
    aws_secretsmanager as _secretsmanager,
    custom_resources as _custom_resources,
    Duration, CfnOutput, BundlingOptions, RemovalPolicy, CustomResource, Aspects, Size
)
from constructs import Construct
from aws_cdk.custom_resources import Provider
from cdk_nag import AwsSolutionsChecks, NagSuppressions

# Configuration constants
model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
vqa_model_id = "anthropic.claude-3-haiku-20240307-v1:0"
frame_interval = "1000"
fast_model_id = "anthropic.claude-3-haiku-20240307-v1:0"
balanced_model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
embedding_model_id = "cohere.embed-multilingual-v3"
raw_folder = "source"
summary_folder = "summary"
video_script_folder = "video_timeline"
video_caption_folder = "captions"
transcription_root_folder = "audio_transcript"
transcription_folder = f"{transcription_root_folder}/{raw_folder}"
entity_sentiment_folder = "entities"
database_name = "videos"
video_table_name = "videos"
entities_table_name = "entities"
content_table_name = "content"
embedding_dimension = 1024
video_search_by_summary_acceptable_embedding_distance = 0.50
videos_api_resource = "videos"
visual_objects_detection_confidence_threshold = 30.0
visual_extraction_prompt_name = "vus-visual-extraction-prompt"
visual_extraction_prompt_variant_name = "claude3"
visual_extraction_prompt_version_description = "Default version"

CONFIG_LABEL_DETECTION_ENABLED = "label_detection_enabled"
CONFIG_TRANSCRIPTION_ENABLED = "transcription_enabled"
CONFIG_VISUAL_EXTRACTION_PROMPT = "visual_extraction_prompt"

# Load prompt files
with open('./lib/main_analyzer/default_visual_extraction_system_prompt.txt', 'r') as file:
    default_visual_extraction_system_prompt = file.read()
with open('./lib/main_analyzer/default_visual_extraction_task_prompt.txt', 'r') as file:
    default_visual_extraction_task_prompt = file.read()

class VideoUnderstandingSolutionStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        
        aws_region = Stack.of(self).region
        aws_account_id = Stack.of(self).account

        # Suppress CDK nag checks for demo purposes
        Aspects.of(self).add(AwsSolutionsChecks(verbose=True))

        # VPC
        vpc = _ec2.Vpc(self, f"Vpc",
            ip_addresses=_ec2.IpAddresses.cidr("10.120.0.0/16"),
            max_azs=3,
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
                ),
                _ec2.SubnetConfiguration(
                    cidr_mask=24,
                    name='private',
                    subnet_type=_ec2.SubnetType.PRIVATE_ISOLATED,
                )
            ]
        )
        
        private_subnets = _ec2.SubnetSelection(subnet_type=_ec2.SubnetType.PRIVATE_ISOLATED)
        private_with_egress_subnets = _ec2.SubnetSelection(subnet_type=_ec2.SubnetType.PRIVATE_WITH_EGRESS)
        public_subnets = _ec2.SubnetSelection(subnet_type=_ec2.SubnetType.PUBLIC)

        # Configuration parameters
        default_configuration_parameters = {
            CONFIG_LABEL_DETECTION_ENABLED: "1",
            CONFIG_TRANSCRIPTION_ENABLED: "1",
            CONFIG_VISUAL_EXTRACTION_PROMPT: {
                "prompt_id": "",
                "variant_name": "claude3",
                "version_id": ""
            }
        }
        configuration_parameters_ssm = _ssm.StringParameter(self, f"{construct_id}-configuration-parameters",
            parameter_name=f"{construct_id}-configuration",
            string_value=json.dumps(default_configuration_parameters)
        )

        # S3 Video bucket
        video_bucket_s3 = _s3.Bucket(
            self, 
            "video-understanding", 
            event_bridge_enabled=True,
            block_public_access=_s3.BlockPublicAccess.BLOCK_ALL,
            removal_policy=RemovalPolicy.DESTROY,
            cors=[_s3.CorsRule(
                allowed_headers=["*"],
                allowed_methods=[_s3.HttpMethods.PUT, _s3.HttpMethods.GET, _s3.HttpMethods.HEAD, _s3.HttpMethods.POST, _s3.HttpMethods.DELETE],
                allowed_origins=["*"],
                exposed_headers=["x-amz-server-side-encryption", "x-amz-request-id", "x-amz-id-2", "ETag"],
                max_age=3000
            )],
            enforce_ssl=True     
        )

        # Authentication Lambda
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

        # API Gateway for authentication
        auth_api = _apigw.RestApi(
            self, "AuthAPI",
            rest_api_name=f"{construct_id}-auth-api",
            description="Authentication API for Video Understanding Solution",
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

        # Database setup (simplified version)
        db_security_group = _ec2.SecurityGroup(self, "VectorDBSecurityGroup",
            security_group_name=f"{construct_id}-vectorDB",
            vpc=vpc,
            allow_all_outbound=True,
            description="Security group for Aurora Serverless PostgreSQL",
        )

        db_security_group.add_ingress_rule(
            peer=_ec2.Peer.ipv4(vpc.vpc_cidr_block),
            connection=_ec2.Port.tcp(5432),
            description="PostgreSQL port from within VPC"
        )

        # Aurora cluster secret
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

        # Aurora database
        db_subnet_group = _rds.SubnetGroup(self, "DBSubnetGroup",
            vpc=vpc,
            description="Aurora subnet group",
            vpc_subnets=private_subnets,
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
            deletion_protection=False,  # Set to False for easier cleanup in demo
        )

        # IAM role for web application (replaces Cognito)
        web_app_role = _iam.Role(
            self, "WebAppRole",
            role_name=f"{construct_id}-{aws_region}-web-app",
            assumed_by=_iam.ServicePrincipal("lambda.amazonaws.com"),
            inline_policies={
                "WebAppPolicy": _iam.PolicyDocument(
                    statements=[
                        _iam.PolicyStatement(
                            actions=[
                                "s3:GetObject",
                                "s3:PutObject",
                                "s3:DeleteObject",
                                "s3:ListBucket"
                            ],
                            resources=[
                                video_bucket_s3.bucket_arn,
                                f"{video_bucket_s3.bucket_arn}/*"
                            ]
                        ),
                        _iam.PolicyStatement(
                            actions=[
                                "bedrock:InvokeModel",
                                "bedrock:InvokeModelWithResponseStream"
                            ],
                            resources=["*"]
                        ),
                        _iam.PolicyStatement(
                            actions=["secretsmanager:GetSecretValue"],
                            resources=[aurora_cluster_secret.secret_full_arn]
                        )
                    ]
                )
            }
        )

        # Video processing API (simplified)
        video_api = _apigw.RestApi(
            self, "VideoAPI",
            rest_api_name=f"{construct_id}-video-api",
            description="Video processing API",
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

        # Add suppressions for demo purposes
        NagSuppressions.add_resource_suppressions(auth_lambda_role, [
            {"id": 'AwsSolutions-IAM4', "reason": 'Demo purposes - using managed policies'},
        ], True)
        
        NagSuppressions.add_resource_suppressions(web_app_role, [
            {"id": 'AwsSolutions-IAM5', "reason": 'Demo purposes - broad permissions for Bedrock'},
        ], True)