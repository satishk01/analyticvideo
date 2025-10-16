#!/bin/bash

# Simple Deployment Script - No CDK NAG checks
# For Video Understanding Solution with Hardcoded Authentication

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
DEPLOYMENT_OUTPUT_FILE="deployment-output.json"

# Function to check basic prerequisites
check_prerequisites() {
    log_info "Checking basic prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed."
        exit 1
    fi
    
    # Check CDK
    if ! command -v cdk &> /dev/null; then
        log_error "AWS CDK is not installed."
        exit 1
    fi
    
    log_success "Basic prerequisites satisfied."
}

# Function to setup environment
setup_environment() {
    log_info "Setting up deployment environment..."
    
    # Get AWS info
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local current_region=$(aws configure get region)
    
    if [ -z "$current_region" ]; then
        current_region=$DEFAULT_REGION
        log_warning "No default region configured. Using $DEFAULT_REGION"
    fi
    
    # Check if region supports Bedrock
    if [[ "$current_region" != "us-east-1" && "$current_region" != "us-west-2" ]]; then
        log_error "This solution requires us-east-1 or us-west-2 for Bedrock support."
        exit 1
    fi
    
    export CDK_DEPLOY_ACCOUNT=$account_id
    export CDK_DEPLOY_REGION=$current_region
    
    log_info "AWS Account ID: $account_id"
    log_info "AWS Region: $current_region"
    
    # Setup Python environment
    if [ -d "venv" ]; then
        source venv/bin/activate
    else
        python3 -m venv venv
        source venv/bin/activate
    fi
    
    # Install minimal required packages
    pip install --upgrade pip
    pip install --upgrade "aws-cdk-lib>=2.122.0"
    pip install --upgrade boto3
    pip install --upgrade constructs
    
    log_success "Environment setup complete."
}

# Function to deploy
deploy_solution() {
    log_info "Deploying Video Understanding Solution..."
    
    # Bootstrap CDK if needed
    log_info "Bootstrapping CDK..."
    cdk bootstrap --app "python3 lib/app_minimal.py" aws://$CDK_DEPLOY_ACCOUNT/$CDK_DEPLOY_REGION
    
    # Deploy the stack
    log_info "Deploying CDK stack..."
    cdk deploy --app "python3 lib/app_minimal.py" --require-approval never --outputs-file $DEPLOYMENT_OUTPUT_FILE
    
    log_success "Deployment complete!"
}

# Function to display results
display_results() {
    log_success "=== DEPLOYMENT COMPLETE ==="
    echo
    
    if [ -f "$DEPLOYMENT_OUTPUT_FILE" ]; then
        local auth_api_url=$(jq -r '.VideoUnderstandingStack.AuthAPIUrl // "Not available"' $DEPLOYMENT_OUTPUT_FILE)
        local video_api_url=$(jq -r '.VideoUnderstandingStack.VideoAPIUrl // "Not available"' $DEPLOYMENT_OUTPUT_FILE)
        local bucket_name=$(jq -r '.VideoUnderstandingStack.S3BucketName // "Not available"' $DEPLOYMENT_OUTPUT_FILE)
        local db_endpoint=$(jq -r '.VideoUnderstandingStack.DatabaseEndpoint // "Not available"' $DEPLOYMENT_OUTPUT_FILE)
        
        log_info "Deployment Details:"
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
        echo "  1. Access the web application using the provided URLs"
        echo "  2. Login with admin/admin credentials"
        echo "  3. Upload videos to test the solution"
        echo "  4. Clean up when done: ./cleanup_simple.sh"
        echo
        log_warning "Security Notice:"
        echo "  This deployment uses hardcoded credentials for demo purposes only."
    else
        log_error "Could not read deployment output file."
    fi
}

# Main function
main() {
    log_info "Starting simple deployment of Video Understanding Solution..."
    echo
    
    check_prerequisites
    setup_environment
    deploy_solution
    display_results
    
    log_success "Simple deployment completed successfully!"
}

# Run main function
main "$@"