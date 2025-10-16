#!/bin/bash

# Simple Cleanup Script for Video Understanding Solution

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

# Function to confirm cleanup
confirm_cleanup() {
    echo
    log_warning "=== CLEANUP CONFIRMATION ==="
    echo
    log_warning "This will DELETE ALL RESOURCES created by the Video Understanding Solution."
    log_error "THIS ACTION CANNOT BE UNDONE!"
    echo
    read -p "Are you sure you want to proceed? Type 'DELETE' to confirm: " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        log_info "Cleanup cancelled."
        exit 0
    fi
}

# Function to setup environment
setup_environment() {
    log_info "Setting up cleanup environment..."
    
    # Get AWS info
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export AWS_REGION=$(aws configure get region)
    
    if [ -z "$AWS_REGION" ]; then
        read -p "Please enter the AWS region where the stack was deployed: " AWS_REGION
        export AWS_REGION
    fi
    
    export CDK_DEPLOY_ACCOUNT=$AWS_ACCOUNT_ID
    export CDK_DEPLOY_REGION=$AWS_REGION
    
    log_info "AWS Account ID: $AWS_ACCOUNT_ID"
    log_info "AWS Region: $AWS_REGION"
    
    # Activate Python environment if it exists
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
}

# Function to empty S3 buckets
empty_s3_buckets() {
    log_info "Emptying S3 buckets..."
    
    # Find buckets with our stack prefix
    local buckets=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'videounderstandingstack')].Name" --output text 2>/dev/null || echo "")
    
    if [ -n "$buckets" ]; then
        for bucket in $buckets; do
            log_info "Emptying bucket: $bucket"
            aws s3 rm s3://$bucket --recursive 2>/dev/null || true
        done
        log_success "S3 buckets emptied."
    else
        log_info "No S3 buckets found to empty."
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
        log_info "No Aurora clusters found."
    fi
}

# Function to destroy CDK stack
destroy_stack() {
    log_info "Destroying CDK stack..."
    
    if cdk destroy --app "python3 lib/app_minimal.py" --force; then
        log_success "CDK stack destroyed successfully."
    else
        log_error "CDK stack destruction failed."
        log_info "You may need to manually delete remaining resources in the AWS console."
        return 1
    fi
}

# Function to clean up local files
cleanup_local_files() {
    log_info "Cleaning up local files..."
    
    # Remove deployment output file
    rm -f deployment-output.json
    
    # Remove CDK output
    rm -rf cdk.out
    
    log_success "Local cleanup complete."
}

# Main function
main() {
    log_info "Starting cleanup of Video Understanding Solution..."
    echo
    
    confirm_cleanup
    setup_environment
    empty_s3_buckets
    disable_rds_protection
    destroy_stack
    cleanup_local_files
    
    log_success "=== CLEANUP COMPLETE ==="
    echo
    log_info "All resources have been removed."
    log_info "To redeploy, run: ./deploy_simple.sh"
}

# Run main function
main "$@"