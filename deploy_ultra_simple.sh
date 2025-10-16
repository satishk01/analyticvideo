#!/bin/bash

# Ultra Simple Deployment - Minimal Video Understanding Solution
# No complex configurations, just basic functionality

set -e

echo "🚀 Starting Ultra Simple Deployment..."

# Check basic requirements
echo "📋 Checking requirements..."
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Please install Python 3."
    exit 1
fi

if ! command -v cdk &> /dev/null; then
    echo "❌ CDK not found. Installing CDK..."
    npm install -g aws-cdk@latest
fi

# Check AWS credentials
echo "🔑 Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Get AWS info
export CDK_DEPLOY_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export CDK_DEPLOY_REGION=$(aws configure get region)

if [ -z "$CDK_DEPLOY_REGION" ]; then
    export CDK_DEPLOY_REGION="us-east-1"
    echo "⚠️  No region configured. Using us-east-1"
fi

echo "📍 Account: $CDK_DEPLOY_ACCOUNT"
echo "📍 Region: $CDK_DEPLOY_REGION"

# Check region
if [[ "$CDK_DEPLOY_REGION" != "us-east-1" && "$CDK_DEPLOY_REGION" != "us-west-2" ]]; then
    echo "❌ Region must be us-east-1 or us-west-2 for Bedrock support."
    exit 1
fi

# Setup Python environment
echo "🐍 Setting up Python environment..."
if [ -d "venv" ]; then
    source venv/bin/activate
else
    python3 -m venv venv
    source venv/bin/activate
fi

# Install minimal packages
pip install --upgrade pip --quiet
pip install --upgrade aws-cdk-lib boto3 constructs --quiet

echo "✅ Environment ready!"

# Test the CDK app first
echo "🧪 Testing CDK app..."
if ! python3 lib/app_minimal.py > /dev/null 2>&1; then
    echo "❌ CDK app test failed. Check lib/app_minimal.py"
    exit 1
fi

echo "✅ CDK app test passed!"

# Bootstrap CDK
echo "🏗️  Bootstrapping CDK..."
cdk bootstrap --app "python3 lib/app_minimal.py" aws://$CDK_DEPLOY_ACCOUNT/$CDK_DEPLOY_REGION --quiet

# Deploy
echo "🚀 Deploying stack..."
cdk deploy --app "python3 lib/app_minimal.py" --require-approval never --outputs-file deployment-output.json

# Show results
echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo ""

if [ -f "deployment-output.json" ]; then
    echo "📋 Deployment Details:"
    
    AUTH_API=$(jq -r '.VideoUnderstandingStack.AuthAPIUrl // "Not available"' deployment-output.json)
    VIDEO_API=$(jq -r '.VideoUnderstandingStack.VideoAPIUrl // "Not available"' deployment-output.json)
    BUCKET=$(jq -r '.VideoUnderstandingStack.S3BucketName // "Not available"' deployment-output.json)
    DB_ENDPOINT=$(jq -r '.VideoUnderstandingStack.DatabaseEndpoint // "Not available"' deployment-output.json)
    
    echo "  • Auth API: $AUTH_API"
    echo "  • Video API: $VIDEO_API"
    echo "  • S3 Bucket: $BUCKET"
    echo "  • Database: $DB_ENDPOINT"
    echo ""
    echo "🔑 Login Credentials:"
    echo "  • Username: admin"
    echo "  • Password: admin"
    echo ""
    echo "🧹 To clean up: ./cleanup_ultra_simple.sh"
else
    echo "⚠️  Could not read deployment output."
fi

echo ""
echo "✅ Ultra simple deployment completed!"