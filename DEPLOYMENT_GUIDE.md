# Video Understanding Solution - Hardcoded Authentication Deployment Guide

This guide provides step-by-step instructions for deploying the Video Understanding Solution with hardcoded authentication on Amazon Linux 2023.

## Overview

This modified version of the Video Understanding Solution removes AWS Cognito authentication and implements a simple hardcoded authentication system using:
- **Username:** admin
- **Password:** admin

⚠️ **Security Warning:** This configuration is for demonstration purposes only. Do not use hardcoded credentials in production environments.

## Prerequisites

### AWS Account Requirements
1. **AWS Account** with appropriate permissions
2. **Amazon Bedrock Access** enabled for:
   - Anthropic Claude models
   - Cohere Embed Multilingual model
3. **Supported Regions:** us-east-1 (N. Virginia) or us-west-2 (Oregon)
4. **IAM Permissions** for deploying CDK stacks

### System Requirements
- **Amazon Linux 2023** EC2 instance (recommended: t3.medium or larger)
- **Internet connectivity** for downloading dependencies
- **At least 10GB free disk space**

## Step 1: EC2 Instance Setup

### Launch EC2 Instance
1. Launch an Amazon Linux 2023 EC2 instance
2. Choose instance type: t3.medium or larger
3. Configure security group to allow SSH (port 22)
4. Create or use existing key pair
5. Launch instance and connect via SSH

### Run Environment Setup Script
```bash
# Download the setup script
curl -O https://raw.githubusercontent.com/your-repo/video-understanding-solution/main/deployment/setup_ec2_environment.sh

# Make it executable
chmod +x setup_ec2_environment.sh

# Run the setup script
./setup_ec2_environment.sh
```

The setup script will install:
- Python 3.9+
- Node.js 20
- AWS CLI v2
- Docker
- AWS CDK
- Additional required tools

### Post-Setup Steps
1. **Log out and log back in** to activate Docker group permissions
2. **Configure AWS credentials:**
   ```bash
   aws configure
   ```
   Enter your:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (us-east-1 or us-west-2)
   - Default output format (json)

## Step 2: Enable Amazon Bedrock Access

1. Go to the [Amazon Bedrock Console](https://console.aws.amazon.com/bedrock/)
2. Navigate to "Model access" in the left sidebar
3. Click "Enable specific models"
4. Enable the following models:
   - **Anthropic Claude 3 Sonnet**
   - **Anthropic Claude 3 Haiku**
   - **Cohere Embed Multilingual v3**
5. Submit the request and wait for approval (usually immediate)

## Step 3: Download Solution Code

```bash
# Clone the repository (replace with actual repository URL)
git clone https://github.com/your-repo/video-understanding-solution.git
cd video-understanding-solution

# Or download and extract the ZIP file
wget https://github.com/your-repo/video-understanding-solution/archive/main.zip
unzip main.zip
cd video-understanding-solution-main
```

## Step 4: Deploy the Solution

### Run Deployment Script
```bash
# Make the deployment script executable
chmod +x deployment/deploy_hardcoded_auth.sh

# Run the deployment
./deployment/deploy_hardcoded_auth.sh
```

The deployment script will:
1. Check all prerequisites
2. Validate AWS setup and Bedrock access
3. Set up Python virtual environment
4. Install Node.js dependencies
5. Bootstrap CDK (if needed)
6. Deploy the AWS infrastructure
7. Configure the web application

### Deployment Process
The deployment typically takes 15-20 minutes and includes:
- **VPC and networking components**
- **Aurora PostgreSQL database**
- **S3 bucket for video storage**
- **Lambda functions for authentication and processing**
- **API Gateway endpoints**
- **Step Functions for video processing workflow**

## Step 5: Access the Application

### After Successful Deployment
The deployment script will display:
- **Authentication API URL**
- **Video API URL**
- **S3 Bucket Name**
- **Database Endpoint**
- **Login Credentials** (admin/admin)

### Web Application Access
1. The web application will be available at the provided URL
2. Use the login credentials:
   - **Username:** admin
   - **Password:** admin

## Step 6: Test the Solution

### Upload a Video
1. Log in to the web application
2. Use the upload interface to upload an MP4 video file
3. Or upload directly to S3 bucket under the "source" folder

### Video Processing
1. After upload, the system will automatically:
   - Extract video frames
   - Perform transcription (if enabled)
   - Analyze visual content with Amazon Rekognition
   - Generate summaries using Amazon Bedrock
   - Extract entities and sentiment

### Features to Test
- **Video upload and processing**
- **AI-generated summaries**
- **Entity extraction**
- **Video search functionality**
- **Q&A chatbot about videos**

## Troubleshooting

### Common Issues

#### 1. Bedrock Access Denied
**Error:** Cannot access Amazon Bedrock models
**Solution:** 
- Ensure model access is enabled in Bedrock console
- Check you're in a supported region (us-east-1 or us-west-2)

#### 2. CDK Bootstrap Failed
**Error:** CDK bootstrap fails
**Solution:**
```bash
# Manually bootstrap CDK
cdk bootstrap aws://ACCOUNT-ID/REGION
```

#### 3. Docker Permission Denied
**Error:** Docker commands fail with permission denied
**Solution:**
```bash
# Add user to docker group and restart session
sudo usermod -a -G docker $USER
# Log out and log back in
```

#### 4. Python Version Issues
**Error:** Python version compatibility issues
**Solution:**
```bash
# Verify Python version
python3 --version
# Should be 3.9 or higher

# If needed, recreate virtual environment
rm -rf venv
python3 -m venv venv
source venv/bin/activate
```

### Getting Help
1. Check CloudFormation console for stack deployment status
2. Review CloudWatch logs for Lambda function errors
3. Verify all prerequisites are installed correctly
4. Ensure AWS credentials have sufficient permissions

## Cleanup

### When You're Done Testing
To remove all AWS resources and avoid charges:

```bash
# Make cleanup script executable
chmod +x deployment/cleanup_resources.sh

# Run cleanup
./deployment/cleanup_resources.sh
```

The cleanup script will:
1. Empty S3 buckets
2. Disable RDS deletion protection
3. Destroy the CDK stack
4. Clean up local files
5. Verify resource deletion

### Manual Cleanup (if needed)
If automatic cleanup fails, manually delete:
1. CloudFormation stack: "VideoUnderstandingStack"
2. S3 buckets starting with "videounderstandingstack"
3. Aurora clusters starting with "videounderstandingstack"

## Security Considerations

### Demo Environment Only
- **Hardcoded credentials** (admin/admin) are for demo only
- **No encryption** for authentication tokens
- **Broad IAM permissions** for simplicity
- **No rate limiting** or abuse protection

### Production Recommendations
For production use, implement:
- **Proper authentication** (Cognito, SAML, etc.)
- **Encrypted sessions** and secure token storage
- **Principle of least privilege** for IAM roles
- **Network security** with private subnets
- **Monitoring and logging** for security events

## Cost Estimation

### Variable Costs (usage-based)
- **Amazon Bedrock:** ~$0.01-0.10 per video (depending on length)
- **Amazon Transcribe:** ~$0.02-0.05 per video minute
- **Amazon Rekognition:** ~$0.10-0.50 per video (depending on faces detected)
- **S3 Storage:** ~$0.023 per GB per month

### Fixed Costs (always running)
- **Aurora Serverless:** ~$0.50-1.00 per hour (0.5-1 ACU)
- **NAT Gateway:** ~$0.045 per hour
- **Lambda:** Usually within free tier for demo usage

### Cost Management
- **Monitor usage** with AWS Cost Explorer
- **Set up billing alerts** for unexpected charges
- **Clean up resources** when done testing
- **Use smaller videos** for initial testing

## Support and Resources

### Documentation
- [Amazon Bedrock User Guide](https://docs.aws.amazon.com/bedrock/)
- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/)
- [Amazon Transcribe Developer Guide](https://docs.aws.amazon.com/transcribe/)

### AWS Support
- [AWS Support Center](https://console.aws.amazon.com/support/)
- [AWS Forums](https://forums.aws.amazon.com/)
- [AWS Documentation](https://docs.aws.amazon.com/)

---

**Note:** This deployment guide is for the hardcoded authentication version of the Video Understanding Solution, intended for demonstration and testing purposes only.