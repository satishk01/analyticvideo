#!/bin/bash

# Ultra Simple Cleanup Script

set -e

echo "🧹 Starting Ultra Simple Cleanup..."

# Confirm cleanup
echo ""
echo "⚠️  WARNING: This will DELETE ALL RESOURCES!"
echo "This action CANNOT be undone!"
echo ""
read -p "Type 'DELETE' to confirm: " confirmation

if [ "$confirmation" != "DELETE" ]; then
    echo "❌ Cleanup cancelled."
    exit 0
fi

# Setup environment
export CDK_DEPLOY_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export CDK_DEPLOY_REGION=$(aws configure get region)

if [ -z "$CDK_DEPLOY_REGION" ]; then
    read -p "Enter AWS region where stack was deployed: " CDK_DEPLOY_REGION
    export CDK_DEPLOY_REGION
fi

echo "📍 Account: $CDK_DEPLOY_ACCOUNT"
echo "📍 Region: $CDK_DEPLOY_REGION"

# Activate Python environment
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Empty S3 buckets first
echo "🗑️  Emptying S3 buckets..."
BUCKETS=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'videounderstandingstack')].Name" --output text 2>/dev/null || echo "")

if [ -n "$BUCKETS" ]; then
    for bucket in $BUCKETS; do
        echo "  Emptying: $bucket"
        aws s3 rm s3://$bucket --recursive --quiet 2>/dev/null || true
    done
fi

# Disable RDS deletion protection
echo "🛡️  Disabling RDS deletion protection..."
CLUSTERS=$(aws rds describe-db-clusters --query "DBClusters[?starts_with(DBClusterIdentifier, 'videounderstandingstack')].DBClusterIdentifier" --output text 2>/dev/null || echo "")

if [ -n "$CLUSTERS" ]; then
    for cluster in $CLUSTERS; do
        echo "  Modifying: $cluster"
        aws rds modify-db-cluster --db-cluster-identifier $cluster --no-deletion-protection --apply-immediately --quiet 2>/dev/null || true
    done
    echo "  Waiting 30 seconds for changes..."
    sleep 30
fi

# Destroy CDK stack
echo "💥 Destroying CDK stack..."
cdk destroy --app "python3 lib/app_minimal.py" --force

# Clean up local files
echo "🧹 Cleaning up local files..."
rm -f deployment-output.json
rm -rf cdk.out

echo ""
echo "✅ Ultra simple cleanup completed!"
echo "💰 All AWS resources have been removed to prevent charges."
echo ""
echo "🚀 To redeploy: ./deploy_ultra_simple.sh"