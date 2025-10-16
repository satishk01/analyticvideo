# 🚀 Quick Start - Video Understanding Solution (Simple Deployment)

## Overview

This is a simplified deployment that bypasses all CDK NAG security checks for quick demo deployment on public EC2 instances.

**Login Credentials:** admin/admin

## 🎯 One-Command Deployment

### Prerequisites
- Amazon Linux 2023 EC2 instance
- AWS CLI configured
- Basic tools installed

### Step 1: Install Prerequisites (if needed)
```bash
# Install basic tools
sudo yum update -y
sudo yum install -y python3 python3-pip nodejs npm jq git

# Install CDK
npm install -g aws-cdk@latest

# Install Python packages
python3 -m pip install --user aws-cdk-lib boto3 constructs
```

### Step 2: Configure AWS
```bash
aws configure
# Enter your AWS Access Key, Secret Key, Region (us-east-1 or us-west-2), Format (json)
```

### Step 3: Deploy Solution
```bash
# Make script executable and run
chmod +x deploy_simple.sh
./deploy_simple.sh
```

### Step 4: Access Application
After deployment (5-10 minutes), you'll get:
- Authentication API URL
- Video API URL
- S3 Bucket Name
- Login: admin/admin

### Step 5: Clean Up
```bash
# When done testing
chmod +x cleanup_simple.sh
./cleanup_simple.sh
```

## 🔧 What's Different in Simple Version

### Removed for Simplicity:
- ❌ CDK NAG security checks
- ❌ VPC Flow Logs
- ❌ Complex security configurations
- ❌ S3 server access logs
- ❌ Advanced API Gateway features

### Kept for Functionality:
- ✅ Hardcoded admin/admin authentication
- ✅ S3 bucket for video storage
- ✅ Aurora PostgreSQL database
- ✅ Lambda functions
- ✅ API Gateway endpoints
- ✅ Basic security (VPC, encryption)

## 📁 File Structure

```
video-understanding-solution/
├── deploy_simple.sh              # Simple deployment script
├── cleanup_simple.sh             # Simple cleanup script
├── lib/
│   ├── app_simple.py            # Simple CDK app
│   ├── video_understanding_solution_stack_simple.py
│   └── auth_lambda/             # Authentication Lambda
├── webui/                       # Web application
└── QUICK_START.md              # This file
```

## 🚨 Troubleshooting

### Issue: CDK Not Found
```bash
npm install -g aws-cdk@latest
```

### Issue: Python Packages Missing
```bash
python3 -m pip install --user aws-cdk-lib boto3 constructs
```

### Issue: AWS Credentials
```bash
aws configure
aws sts get-caller-identity  # Test credentials
```

### Issue: Region Not Supported
```bash
# Use us-east-1 or us-west-2 only
aws configure set region us-east-1
```

## 💰 Cost Estimate

### Daily Costs (approximate):
- **Aurora Serverless**: $12-24/day
- **NAT Gateway**: $1/day
- **Lambda**: Usually free tier
- **S3**: $0.01-0.10/day
- **API Gateway**: Usually free tier

**Total**: ~$13-25/day

### Cost Management:
- Clean up resources when done testing
- Use smaller videos for testing
- Monitor with AWS Cost Explorer

## ⚠️ Important Notes

### Security Warnings:
- **Demo only**: Hardcoded admin/admin credentials
- **Public EC2**: Not recommended for production
- **Simplified security**: Basic protections only
- **No monitoring**: Limited logging and alerts

### Limitations:
- **Regions**: us-east-1 or us-west-2 only (Bedrock requirement)
- **Video format**: MP4 files only
- **Video length**: Best for videos under 15 minutes
- **Concurrent users**: Single user demo system

## 🎉 Success Indicators

### Deployment Success:
```
=== DEPLOYMENT COMPLETE ===
Deployment Details:
• Authentication API URL: https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/
• Video API URL: https://yyyyyyyyyy.execute-api.us-east-1.amazonaws.com/prod/
• S3 Bucket Name: videounderstandingstack-xxxxxxxxxx
• Database Endpoint: xxxxxxxxxx.cluster-xxxxxxxxxx.us-east-1.rds.amazonaws.com

Login Credentials:
• Username: admin
• Password: admin
```

### Application Success:
- ✅ Can login with admin/admin
- ✅ Can upload MP4 videos
- ✅ Videos process automatically
- ✅ AI summaries appear
- ✅ Q&A chatbot works

## 📞 Need Help?

### Quick Fixes:
1. **Check AWS credentials**: `aws sts get-caller-identity`
2. **Check region**: `aws configure get region`
3. **Check CDK**: `cdk --version`
4. **Check Python**: `python3 --version`

### AWS Console Links:
- [CloudFormation](https://console.aws.amazon.com/cloudformation/)
- [S3 Buckets](https://console.aws.amazon.com/s3/)
- [RDS Databases](https://console.aws.amazon.com/rds/)
- [Bedrock Model Access](https://console.aws.amazon.com/bedrock/home#/modelaccess)

---

**Remember**: This is a simplified demo version. Always implement proper security for production use!