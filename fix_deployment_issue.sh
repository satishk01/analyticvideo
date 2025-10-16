#!/bin/bash

# Fix Deployment Issues Script
# This script resolves common deployment issues for the hardcoded auth version

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check and fix Python dependencies
fix_python_dependencies() {
    log_info "Fixing Python dependencies..."
    
    # Activate virtual environment if it exists
    if [ -d "venv" ]; then
        source venv/bin/activate
        log_info "Activated virtual environment."
    else
        log_info "Creating new virtual environment..."
        python3 -m venv venv
        source venv/bin/activate
    fi
    
    # Install only the dependencies we need (without amplify)
    log_info "Installing required Python packages..."
    pip install --upgrade pip
    pip install --upgrade "aws-cdk-lib>=2.122.0"
    pip install --upgrade "cdk-nag>=2.28.16"
    pip install --upgrade boto3
    pip install --upgrade constructs
    
    # Remove any problematic packages
    pip uninstall -y aws-cdk.aws-amplify-alpha 2>/dev/null || true
    
    log_success "Python dependencies fixed."
}

# Function to create a temporary CDK config for our hardcoded auth version
create_temp_cdk_config() {
    log_info "Creating temporary CDK configuration..."
    
    # Backup original cdk.json if it exists
    if [ -f "cdk.json" ]; then
        cp cdk.json cdk.json.backup
        log_info "Backed up original cdk.json"
    fi
    
    # Create temporary cdk.json for hardcoded auth
    cat > cdk.json << 'EOF'
{
  "app": "python3 lib/app_hardcoded_auth.py",
  "watch": {
    "include": [
      "**"
    ],
    "exclude": [
      "README.md",
      "cdk*.json",
      "requirements*.txt",
      "source.bat",
      "**/__pycache__",
      "**/.venv",
      "**/.env"
    ]
  },
  "context": {
    "@aws-cdk/aws-lambda:recognizeLayerVersion": true,
    "@aws-cdk/core:checkSecretUsage": true,
    "@aws-cdk/core:target-partitions": [
      "aws",
      "aws-cn"
    ],
    "@aws-cdk-containers/ecs-service-extensions:enableDefaultLogDriver": true,
    "@aws-cdk/aws-ec2:uniqueImdsv2TemplateName": true,
    "@aws-cdk/aws-ecs:arnFormatIncludesClusterName": true,
    "@aws-cdk/aws-iam:minimizePolicies": true,
    "@aws-cdk/core:validateSnapshotRemovalPolicy": true,
    "@aws-cdk/aws-codepipeline:crossAccountKeyAliasStackSafeResourceName": true,
    "@aws-cdk/aws-s3:createDefaultLoggingPolicy": true,
    "@aws-cdk/aws-sns-subscriptions:restrictSqsDescryption": true,
    "@aws-cdk/aws-apigateway:disableCloudWatchRole": true,
    "@aws-cdk/core:enablePartitionLiterals": true,
    "@aws-cdk/aws-events:eventsTargetQueueSameAccount": true,
    "@aws-cdk/aws-iam:standardizedServicePrincipals": true,
    "@aws-cdk/aws-ecs:disableExplicitDeploymentControllerForCircuitBreaker": true,
    "@aws-cdk/aws-iam:importedRoleStackSafeDefaultPolicyName": true,
    "@aws-cdk/aws-s3:serverAccessLogsUseBucketPolicy": true,
    "@aws-cdk/aws-route53-patters:useCertificate": true,
    "@aws-cdk/customresources:installLatestAwsSdkDefault": false,
    "@aws-cdk/aws-rds:databaseProxyUniqueResourceName": true,
    "@aws-cdk/aws-codedeploy:removeAlarmsFromDeploymentGroup": true,
    "@aws-cdk/aws-apigateway:authorizerChangeDeploymentLogicalId": true,
    "@aws-cdk/aws-ec2:launchTemplateDefaultUserData": true,
    "@aws-cdk/aws-secretsmanager:useAttachedSecretResourcePolicyForSecretTargetAttachments": true,
    "@aws-cdk/aws-redshift:columnId": true,
    "@aws-cdk/aws-stepfunctions-tasks:enableLogging": true,
    "@aws-cdk/aws-ec2:restrictDefaultSecurityGroup": true,
    "@aws-cdk/aws-apigateway:requestValidatorUniqueId": true,
    "@aws-cdk/aws-kms:aliasNameRef": true,
    "@aws-cdk/aws-autoscaling:generateLaunchTemplateInsteadOfLaunchConfig": true,
    "@aws-cdk/core:includePrefixInUniqueNameGeneration": true,
    "@aws-cdk/aws-efs:denyAnonymousAccess": true,
    "@aws-cdk/aws-opensearchservice:enableLogging": true,
    "@aws-cdk/aws-nordicapis-apigateway:authorizerChangeDeploymentLogicalId": true,
    "@aws-cdk/aws-lambda:automaticAsyncInvocation": true,
    "@aws-cdk/aws-ecs:reduceEc2FargateCloudWatchPermissions": true,
    "@aws-cdk/aws-lambda-nodejs:useLatestRuntimeVersion": true
  }
}
EOF
    
    log_success "Temporary CDK configuration created."
}

# Function to restore original CDK config
restore_cdk_config() {
    log_info "Restoring original CDK configuration..."
    
    if [ -f "cdk.json.backup" ]; then
        mv cdk.json.backup cdk.json
        log_success "Original cdk.json restored."
    fi
}

# Function to test CDK app
test_cdk_app() {
    log_info "Testing CDK app..."
    
    # Set environment variables
    export CDK_DEPLOY_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    export CDK_DEPLOY_REGION=$(aws configure get region)
    
    # Test the app
    if python3 lib/app_hardcoded_auth.py; then
        log_success "CDK app test passed."
        return 0
    else
        log_error "CDK app test failed."
        return 1
    fi
}

# Function to clean up CDK cache
clean_cdk_cache() {
    log_info "Cleaning CDK cache..."
    
    # Remove CDK output directory
    if [ -d "cdk.out" ]; then
        rm -rf cdk.out
        log_info "Removed cdk.out directory."
    fi
    
    # Remove Python cache
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    
    log_success "CDK cache cleaned."
}

# Function to verify project structure
verify_project_structure() {
    log_info "Verifying project structure..."
    
    local missing_files=()
    
    # Check critical files for hardcoded auth version
    [ ! -f "lib/app_hardcoded_auth.py" ] && missing_files+=("lib/app_hardcoded_auth.py")
    [ ! -f "lib/video_understanding_solution_stack_hardcoded_auth.py" ] && missing_files+=("lib/video_understanding_solution_stack_hardcoded_auth.py")
    [ ! -f "lib/auth_lambda/index.py" ] && missing_files+=("lib/auth_lambda/index.py")
    [ ! -f "lib/auth_lambda/requirements.txt" ] && missing_files+=("lib/auth_lambda/requirements.txt")
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Missing critical files for hardcoded auth version:"
        for file in "${missing_files[@]}"; do
            echo "  • $file"
        done
        return 1
    fi
    
    log_success "Project structure verified."
    return 0
}

# Function to display next steps
display_next_steps() {
    log_success "=== DEPLOYMENT ISSUE FIX COMPLETE ==="
    echo
    log_info "What was fixed:"
    echo "  ✓ Python dependencies updated"
    echo "  ✓ CDK configuration set for hardcoded auth version"
    echo "  ✓ CDK cache cleaned"
    echo "  ✓ Project structure verified"
    echo
    log_info "Next Steps:"
    echo "  1. Try running the deployment again:"
    echo "     ./deployment/deploy_hardcoded_auth.sh"
    echo
    echo "  2. If you still encounter issues, try manual bootstrap:"
    echo "     export CDK_DEPLOY_ACCOUNT=\$(aws sts get-caller-identity --query Account --output text)"
    echo "     export CDK_DEPLOY_REGION=\$(aws configure get region)"
    echo "     cdk bootstrap aws://\$CDK_DEPLOY_ACCOUNT/\$CDK_DEPLOY_REGION"
    echo
    echo "  3. Then run deployment:"
    echo "     cdk deploy --require-approval never"
    echo
    log_warning "Note: This script temporarily modifies cdk.json for the hardcoded auth version."
}

# Main fix function
main() {
    log_info "Starting deployment issue fix for Video Understanding Solution..."
    echo
    
    # Run fix steps
    verify_project_structure || exit 1
    clean_cdk_cache
    fix_python_dependencies
    create_temp_cdk_config
    
    if test_cdk_app; then
        display_next_steps
        log_success "Deployment issues fixed successfully!"
    else
        log_error "CDK app test failed. Please check the error messages above."
        restore_cdk_config
        exit 1
    fi
}

# Cleanup function for script exit
cleanup() {
    if [ -f "cdk.json.backup" ]; then
        log_info "Restoring original CDK configuration on exit..."
        restore_cdk_config
    fi
}

# Set up cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"