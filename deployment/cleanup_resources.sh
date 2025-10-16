#!/bin/bash

# Cleanup Script for Video Understanding Solution - Hardcoded Authentication
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
STACK_NAME="VideoUnderstandingStack"
DEPLOYMENT_OUTPUT_FILE="deployment-output.json"

# Function to get AWS account and region info
get_aws_info() {
    log_info "Getting AWS account information..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid."
        exit 1
    fi
    
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export AWS_REGION=$(aws configure get region)
    
    if [ -z "$AWS_REGION" ]; then
        log_warning "No default region configured."
        read -p "Please enter the AWS region where the stack was deployed: " AWS_REGION
        export AWS_REGION
    fi
    
    log_info "AWS Account ID: $AWS_ACCOUNT_ID"
    log_info "AWS Region: $AWS_REGION"
}

# Function to confirm cleanup
confirm_cleanup() {
    echo
    log_warning "=== CLEANUP CONFIRMATION ==="
    echo
    log_warning "This will DELETE ALL RESOURCES created by the Video Understanding Solution."
    echo "This includes:"
    echo "  • S3 buckets and all stored videos/data"
    echo "  • Aurora PostgreSQL database and all data"
    echo "  • Lambda functions"
    echo "  • API Gateway endpoints"
    echo "  • VPC and networking components"
    echo "  • IAM roles and policies"
    echo "  • All other AWS resources created by the stack"
    echo
    log_error "THIS ACTION CANNOT BE UNDONE!"
    echo
    read -p "Are you sure you want to proceed? Type 'DELETE' to confirm: " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        log_info "Cleanup cancelled."
        exit 0
    fi
    
    echo
    read -p "Final confirmation - type 'YES' to proceed with deletion: " final_confirmation
    
    if [ "$final_confirmation" != "YES" ]; then
        log_info "Cleanup cancelled."
        exit 0
    fi
    
    log_warning "Proceeding with cleanup in 5 seconds... Press Ctrl+C to cancel."
    sleep 5
}

# Function to empty S3 buckets
empty_s3_buckets() {
    log_info "Emptying S3 buckets..."
    
    # Get bucket name from deployment output or find it
    local bucket_name=""
    
    if [ -f "$DEPLOYMENT_OUTPUT_FILE" ]; then
        bucket_name=$(jq -r '.VideoUnderstandingStack.S3BucketName // empty' $DEPLOYMENT_OUTPUT_FILE 2>/dev/null || echo "")
    fi
    
    if [ -z "$bucket_name" ]; then
        # Try to find bucket by prefix
        bucket_name=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'videounderstandingstack')].Name" --output text 2>/dev/null | head -n1)
    fi
    
    if [ -n "$bucket_name" ]; then
        log_info "Found S3 bucket: $bucket_name"
        log_info "Emptying bucket contents..."
        
        # Empty the bucket
        aws s3 rm s3://$bucket_name --recursive 2>/dev/null || true
        
        # Remove any versioned objects
        aws s3api delete-objects --bucket $bucket_name --delete "$(aws s3api list-object-versions --bucket $bucket_name --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}' --output json)" 2>/dev/null || true
        
        # Remove any delete markers
        aws s3api delete-objects --bucket $bucket_name --delete "$(aws s3api list-object-versions --bucket $bucket_name --query '{Objects: DeleteMarkers[].{Key: Key, VersionId: VersionId}}' --output json)" 2>/dev/null || true
        
        log_success "S3 bucket emptied."
    else
        log_warning "Could not find S3 bucket to empty."
    fi
}

# Function to disable RDS deletion protection
disable_rds_protection() {
    log_info "Disabling RDS deletion protection..."
    
    # Find Aurora clusters with our stack prefix
    local clusters=$(aws rds describe-db-clusters --query "DBClusters[?starts_with(DBClusterIdentifier, 'videounderstandingstack')].DBClusterIdentifier" --output text 2>/dev/null || echo "")
    
    if [ -n "$clusters" ]; then
        for cluster in $clusters; do
            log_info "Disabling deletion protection for cluster: $cluster"
            aws rds modify-db-cluster --db-cluster-identifier $cluster --no-deletion-protection --apply-immediately 2>/dev/null || true
        done
        
        log_info "Waiting for cluster modifications to complete..."
        sleep 30
        
        log_success "RDS deletion protection disabled."
    else
        log_warning "No Aurora clusters found to modify."
    fi
}

# Function to destroy CDK stack
destroy_cdk_stack() {
    log_info "Destroying CDK stack..."
    
    # Set up environment variables
    export CDK_DEPLOY_ACCOUNT=$AWS_ACCOUNT_ID
    export CDK_DEPLOY_REGION=$AWS_REGION
    
    # Activate Python virtual environment if it exists
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    # Destroy the stack
    if cdk destroy --app "python3 lib/app_simple.py" --force; then
        log_success "CDK stack destroyed successfully."
    else
        log_error "CDK stack destruction failed."
        log_info "You may need to manually delete remaining resources in the AWS console."
        return 1
    fi
}

# Function to clean up any remaining resources
cleanup_remaining_resources() {
    log_info "Checking for remaining resources..."
    
    # Check for any remaining S3 buckets
    local remaining_buckets=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'videounderstandingstack')].Name" --output text 2>/dev/null || echo "")
    
    if [ -n "$remaining_buckets" ]; then
        log_warning "Found remaining S3 buckets:"
        for bucket in $remaining_buckets; do
            echo "  • $bucket"
        done
        log_info "These may need to be deleted manually from the AWS console."
    fi
    
    # Check for any remaining Aurora clusters
    local remaining_clusters=$(aws rds describe-db-clusters --query "DBClusters[?starts_with(DBClusterIdentifier, 'videounderstandingstack')].DBClusterIdentifier" --output text 2>/dev/null || echo "")
    
    if [ -n "$remaining_clusters" ]; then
        log_warning "Found remaining Aurora clusters:"
        for cluster in $remaining_clusters; do
            echo "  • $cluster"
        done
        log_info "These may need to be deleted manually from the AWS console."
    fi
    
    # Check for CloudFormation stacks
    local remaining_stacks=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?starts_with(StackName, 'VideoUnderstandingStack')].StackName" --output text 2>/dev/null || echo "")
    
    if [ -n "$remaining_stacks" ]; then
        log_warning "Found remaining CloudFormation stacks:"
        for stack in $remaining_stacks; do
            echo "  • $stack"
        done
        log_info "These may need to be deleted manually from the AWS console."
    fi
}

# Function to clean up local files
cleanup_local_files() {
    log_info "Cleaning up local deployment files..."
    
    # Remove deployment output file
    if [ -f "$DEPLOYMENT_OUTPUT_FILE" ]; then
        rm -f $DEPLOYMENT_OUTPUT_FILE
        log_info "Removed deployment output file."
    fi
    
    # Reset aws-exports.js to placeholder values
    if [ -f "webui/src/aws-exports.js" ]; then
        log_info "Resetting web UI configuration..."
        cat > webui/src/aws-exports.js << 'EOF'
/* eslint-disable */

export default {
    "aws_project_region": "PLACEHOLDER_REGION",
    "bucket_name": "PLACEHOLDER_BUCKET_NAME",
    "balanced_model_id": "PLACEHOLDER_BALANCED_MODEL_ID",
    "fast_model_id": "PLACEHOLDER_FAST_MODEL_ID",
    "raw_folder": "PLACEHOLDER_RAW_FOLDER",
    "video_script_folder": "PLACEHOLDER_VIDEO_SCRIPT_FOLDER",
    "video_caption_folder": "PLACEHOLDER_VIDEO_CAPTION_FOLDER",
    "transcription_folder": "PLACEHOLDER_TRANSCRIPTION_FOLDER",
    "entity_sentiment_folder": "PLACEHOLDER_ENTITY_SENTIMENT_FOLDER",
    "summary_folder": "PLACEHOLDER_SUMMARY_FOLDER",
    "rest_api_url": "PLACEHOLDER_REST_API_URL",
    "videos_api_resource": "PLACEHOLDER_VIDEOS_API_RESOURCE",
    "auth_api_url": "PLACEHOLDER_AUTH_API_URL"
}
EOF
        log_info "Web UI configuration reset."
    fi
    
    # Remove backup files
    find . -name "*.bak" -delete 2>/dev/null || true
    
    # Remove web UI build artifacts
    if [ -d "webui/build" ]; then
        rm -rf webui/build
    fi
    
    # Remove CDK output
    if [ -d "cdk.out" ]; then
        rm -rf cdk.out
    fi
    
    log_success "Local cleanup complete."
}

# Function to display cleanup summary
display_cleanup_summary() {
    log_success "=== CLEANUP COMPLETE ==="
    echo
    log_info "Cleanup Summary:"
    echo "  • CDK stack destroyed"
    echo "  • S3 buckets emptied and deleted"
    echo "  • Aurora database deleted"
    echo "  • All Lambda functions deleted"
    echo "  • API Gateway endpoints deleted"
    echo "  • VPC and networking components deleted"
    echo "  • IAM roles and policies deleted"
    echo "  • Local deployment files cleaned up"
    echo
    log_info "What was NOT cleaned up:"
    echo "  • AWS CLI configuration"
    echo "  • Python virtual environment (venv/)"
    echo "  • Node.js dependencies (node_modules/)"
    echo "  • Source code files"
    echo
    log_warning "Please check the AWS console to verify all resources have been deleted."
    echo "If any resources remain, you may need to delete them manually."
    echo
    log_info "To redeploy the solution, run: ./deployment/deploy_hardcoded_auth.sh"
}

# Function to handle errors during cleanup
handle_cleanup_error() {
    log_error "Cleanup encountered an error."
    log_info "Some resources may still exist in your AWS account."
    log_info "Please check the AWS console and delete any remaining resources manually."
    echo
    log_info "Common resources to check:"
    echo "  • CloudFormation stacks starting with 'VideoUnderstandingStack'"
    echo "  • S3 buckets starting with 'videounderstandingstack'"
    echo "  • Aurora clusters starting with 'videounderstandingstack'"
    echo "  • Lambda functions with 'VideoUnderstandingStack' in the name"
    echo "  • API Gateway APIs with 'VideoUnderstandingStack' in the name"
    exit 1
}

# Main cleanup function
main() {
    log_info "Starting cleanup of Video Understanding Solution resources..."
    echo
    
    # Set up error handling
    trap handle_cleanup_error ERR
    
    # Run cleanup steps
    get_aws_info
    confirm_cleanup
    empty_s3_buckets
    disable_rds_protection
    destroy_cdk_stack
    cleanup_remaining_resources
    cleanup_local_files
    display_cleanup_summary
    
    log_success "Cleanup completed successfully!"
}

# Run main function
main "$@"