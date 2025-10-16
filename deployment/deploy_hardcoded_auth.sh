#!/bin/bash

# Video Understanding Solution - Hardcoded Authentication Deployment Script
# For Amazon Linux 2023

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

# Configuration
DEFAULT_REGION="us-east-1"
STACK_NAME="VideoUnderstandingStack"
DEPLOYMENT_OUTPUT_FILE="deployment-output.json"

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install AWS CLI v2.15.5 or higher."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed. Please install Python 3.8 or higher."
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed. Please install Node.js 20.10.0 or higher."
        exit 1
    fi
    
    # Check CDK
    if ! command -v cdk &> /dev/null; then
        log_error "AWS CDK is not installed. Please install CDK 2.122.0 or higher."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker 20.10.25 or higher."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker service."
        exit 1
    fi
    
    log_success "All prerequisites are satisfied."
}

# Function to validate AWS region and Bedrock access
validate_aws_setup() {
    log_info "Validating AWS setup..."
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local current_region=$(aws configure get region)
    
    if [ -z "$current_region" ]; then
        current_region=$DEFAULT_REGION
        log_warning "No default region configured. Using $DEFAULT_REGION"
    fi
    
    log_info "AWS Account ID: $account_id"
    log_info "AWS Region: $current_region"
    
    # Check if region supports Bedrock
    if [[ "$current_region" != "us-east-1" && "$current_region" != "us-west-2" ]]; then
        log_error "This solution requires a region with Amazon Bedrock support (us-east-1 or us-west-2)."
        exit 1
    fi
    
    # Test Bedrock access
    log_info "Testing Amazon Bedrock access..."
    if ! aws bedrock list-foundation-models --region $current_region &> /dev/null; then
        log_error "Cannot access Amazon Bedrock. Please ensure you have enabled model access in the Bedrock console."
        log_error "Visit: https://console.aws.amazon.com/bedrock/home?region=$current_region#/modelaccess"
        exit 1
    fi
    
    export CDK_DEPLOY_ACCOUNT=$account_id
    export CDK_DEPLOY_REGION=$current_region
    
    log_success "AWS setup validated successfully."
}

# Function to setup Python virtual environment
setup_python_env() {
    log_info "Setting up Python virtual environment..."
    
    if [ -d "venv" ]; then
        log_info "Virtual environment already exists. Activating..."
        source venv/bin/activate
    else
        log_info "Creating new virtual environment..."
        python3 -m venv venv
        source venv/bin/activate
    fi
    
    log_info "Installing Python dependencies..."
    pip install --upgrade pip
    pip install --upgrade "aws-cdk-lib>=2.122.0"
    pip install --upgrade "cdk-nag>=2.28.16"
    pip install --upgrade boto3
    
    log_success "Python environment setup complete."
}

# Function to setup Node.js environment
setup_nodejs_env() {
    log_info "Setting up Node.js environment..."
    
    # Install CDK globally if not present
    if ! npm list -g aws-cdk &> /dev/null; then
        log_info "Installing AWS CDK globally..."
        npm install -g aws-cdk@latest
    fi
    
    # Install web UI dependencies
    log_info "Installing web UI dependencies..."
    cd webui
    npm install
    cd ..
    
    log_success "Node.js environment setup complete."
}

# Function to bootstrap CDK
bootstrap_cdk() {
    log_info "Bootstrapping CDK..."
    
    if ! cdk bootstrap --app "python3 lib/app_simple.py" aws://$CDK_DEPLOY_ACCOUNT/$CDK_DEPLOY_REGION; then
        log_error "CDK bootstrap failed."
        exit 1
    fi
    
    log_success "CDK bootstrap complete."
}

# Function to build and deploy
deploy_stack() {
    log_info "Building and deploying the Video Understanding Solution..."
    
    # Check if webui directory exists
    if [ ! -d "webui" ]; then
        log_error "webui directory not found. Please ensure you're running this script from the project root directory."
        exit 1
    fi
    
    # Prepare web UI
    log_info "Preparing web UI..."
    cd webui
    find . -name 'ui_repo*.zip' -exec rm {} \; 2>/dev/null || true
    zip -r "ui_repo$(date +%s).zip" src package.json package-lock.json public
    cd ..
    
    # Deploy CDK stack
    log_info "Deploying CDK stack..."
    if ! cdk deploy --app "python3 lib/app_simple.py" --require-approval never --outputs-file $DEPLOYMENT_OUTPUT_FILE; then
        log_error "CDK deployment failed."
        exit 1
    fi
    
    log_success "Deployment complete!"
}

# Function to update web UI configuration
update_web_config() {
    log_info "Updating web UI configuration..."
    
    if [ ! -f "$DEPLOYMENT_OUTPUT_FILE" ]; then
        log_error "Deployment output file not found. Cannot update web configuration."
        return 1
    fi
    
    # Extract values from deployment output
    local bucket_name=$(jq -r '.VideoUnderstandingStack.S3BucketName // empty' $DEPLOYMENT_OUTPUT_FILE)
    local auth_api_url=$(jq -r '.VideoUnderstandingStack.AuthAPIUrl // empty' $DEPLOYMENT_OUTPUT_FILE)
    local video_api_url=$(jq -r '.VideoUnderstandingStack.VideoAPIUrl // empty' $DEPLOYMENT_OUTPUT_FILE)
    
    if [ -z "$bucket_name" ] || [ -z "$auth_api_url" ]; then
        log_error "Could not extract required values from deployment output."
        return 1
    fi
    
    # Update aws-exports.js
    log_info "Updating aws-exports.js..."
    sed -i.bak \
        -e "s|PLACEHOLDER_REGION|$CDK_DEPLOY_REGION|g" \
        -e "s|PLACEHOLDER_BUCKET_NAME|$bucket_name|g" \
        -e "s|PLACEHOLDER_AUTH_API_URL|$auth_api_url|g" \
        -e "s|PLACEHOLDER_REST_API_URL|$video_api_url|g" \
        -e "s|PLACEHOLDER_BALANCED_MODEL_ID|anthropic.claude-3-sonnet-20240229-v1:0|g" \
        -e "s|PLACEHOLDER_FAST_MODEL_ID|anthropic.claude-3-haiku-20240307-v1:0|g" \
        -e "s|PLACEHOLDER_RAW_FOLDER|source|g" \
        -e "s|PLACEHOLDER_VIDEO_SCRIPT_FOLDER|video_timeline|g" \
        -e "s|PLACEHOLDER_VIDEO_CAPTION_FOLDER|captions|g" \
        -e "s|PLACEHOLDER_TRANSCRIPTION_FOLDER|audio_transcript/source|g" \
        -e "s|PLACEHOLDER_ENTITY_SENTIMENT_FOLDER|entities|g" \
        -e "s|PLACEHOLDER_SUMMARY_FOLDER|summary|g" \
        -e "s|PLACEHOLDER_VIDEOS_API_RESOURCE|videos|g" \
        webui/src/aws-exports.js
    
    log_success "Web UI configuration updated."
}

# Function to display deployment information
display_deployment_info() {
    log_success "=== DEPLOYMENT COMPLETE ==="
    echo
    log_info "Deployment Details:"
    
    if [ -f "$DEPLOYMENT_OUTPUT_FILE" ]; then
        local auth_api_url=$(jq -r '.VideoUnderstandingStack.AuthAPIUrl // "Not available"' $DEPLOYMENT_OUTPUT_FILE)
        local video_api_url=$(jq -r '.VideoUnderstandingStack.VideoAPIUrl // "Not available"' $DEPLOYMENT_OUTPUT_FILE)
        local bucket_name=$(jq -r '.VideoUnderstandingStack.S3BucketName // "Not available"' $DEPLOYMENT_OUTPUT_FILE)
        local db_endpoint=$(jq -r '.VideoUnderstandingStack.DatabaseEndpoint // "Not available"' $DEPLOYMENT_OUTPUT_FILE)
        
        echo "  • Authentication API URL: $auth_api_url"
        echo "  • Video API URL: $video_api_url"
        echo "  • S3 Bucket Name: $bucket_name"
        echo "  • Database Endpoint: $db_endpoint"
        echo
        log_info "Login Credentials:"
        echo "  • Username: admin"
        echo "  • Password: admin"
        echo
        log_info "Next Steps:"
        echo "  1. The web application will be available once the frontend is deployed"
        echo "  2. You can upload videos to the S3 bucket under the 'source' folder"
        echo "  3. Use the cleanup script when you're done: ./deployment/cleanup_resources.sh"
        echo
        log_warning "Security Notice:"
        echo "  This deployment uses hardcoded credentials for demo purposes only."
        echo "  Do not use this configuration in production environments."
    else
        log_error "Could not read deployment output file."
    fi
}

# Function to handle cleanup on error
cleanup_on_error() {
    log_error "Deployment failed. You may need to clean up resources manually."
    log_info "To clean up, run: ./deployment/cleanup_resources.sh"
    exit 1
}

# Function to check project structure
check_project_structure() {
    log_info "Checking project structure..."
    
    # Check if we're in the right directory
    if [ ! -f "lib/app_simple.py" ]; then
        log_error "Cannot find lib/app_simple.py. Please ensure you're running this script from the project root directory."
        log_info "Expected directory structure:"
        log_info "  project-root/"
        log_info "  ├── deployment/"
        log_info "  ├── lib/"
        log_info "  ├── webui/"
        log_info "  └── ..."
        exit 1
    fi
    
    if [ ! -d "webui" ]; then
        log_error "webui directory not found. Please ensure the webui directory exists in the project root."
        exit 1
    fi
    
    if [ ! -f "webui/package.json" ]; then
        log_error "webui/package.json not found. Please ensure the webui directory is properly set up."
        exit 1
    fi
    
    log_success "Project structure verified."
}

# Main deployment function
main() {
    log_info "Starting Video Understanding Solution deployment with hardcoded authentication..."
    echo
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Run deployment steps
    check_project_structure
    check_prerequisites
    validate_aws_setup
    setup_python_env
    setup_nodejs_env
    bootstrap_cdk
    deploy_stack
    update_web_config
    display_deployment_info
    
    log_success "Deployment completed successfully!"
}

# Run main function
main "$@"