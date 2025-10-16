# Complete Deployment Guide - Video Understanding Solution with Hardcoded Authentication

## 🎯 Overview

This guide provides complete step-by-step instructions to deploy the Video Understanding Solution with hardcoded authentication (admin/admin) on Amazon Linux 2023.

⚠️ **Security Warning**: This version uses hardcoded credentials for demonstration purposes only. Do not use in production.

## 📋 Prerequisites

### AWS Account Requirements
- AWS Account with administrative permissions
- Amazon Bedrock model access enabled
- Supported regions: **us-east-1** or **us-west-2** only

### System Requirements
- Amazon Linux 2023 EC2 instance (minimum t3.medium)
- 10GB+ free disk space
- Internet connectivity

## 🚀 Step-by-Step Deployment

### Step 1: Launch and Configure EC2 Instance

#### 1.1 Launch EC2 Instance
```bash
# Launch Amazon Linux 2023 instance
# Instance type: t3.medium or larger
# Security group: Allow SSH (port 22)
# Storage: 20GB+ EBS volume
```

#### 1.2 Connect to Instance
```bash
# Connect via SSH
ssh -i your-key.pem ec2-user@your-instance-ip
```

### Step 2: Install Prerequisites

#### 2.1 Update System
```bash
sudo yum update -y
```

#### 2.2 Install Development Tools
```bash
sudo yum groupinstall -y "Development Tools"
sudo yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel
```

#### 2.3 Install Python 3.9+
```bash
# Download and compile Python 3.9
cd /tmp
wget https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tgz
tar xzf Python-3.9.18.tgz
cd Python-3.9.18
./configure --enable-optimizations
make -j $(nproc)
sudo make altinstall

# Create symlinks
sudo ln -sf /usr/local/bin/python3.9 /usr/local/bin/python3
sudo ln -sf /usr/local/bin/pip3.9 /usr/local/bin/pip3

# Clean up
cd /
rm -rf /tmp/Python-3.9.18*
```

#### 2.4 Install Node.js 20
```bash
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js 20
nvm install 20.10.0
nvm use 20.10.0
nvm alias default 20.10.0

# Add to bashrc
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
```

#### 2.5 Install AWS CLI v2
```bash
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf /tmp/aws*
```

#### 2.6 Install Docker
```bash
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker $USER
sudo usermod -a -G docker ec2-user

# Note: You'll need to log out and back in for Docker group permissions
```

#### 2.7 Install Additional Tools
```bash
sudo yum install -y jq zip unzip git
```

#### 2.8 Install AWS CDK
```bash
# Source NVM to ensure npm is available
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install CDK globally
npm install -g aws-cdk@latest

# Verify installation
cdk --version
```

#### 2.9 Install Python CDK Libraries
```bash
# Install pip and virtualenv
python3 -m ensurepip --upgrade
python3 -m pip install --user virtualenv

# Install CDK libraries
python3 -m pip install --user --upgrade pip
python3 -m pip install --user "aws-cdk-lib>=2.122.0"
python3 -m pip install --user "cdk-nag>=2.28.16"
python3 -m pip install --user boto3
```

### Step 3: Configure AWS Credentials

#### 3.1 Configure AWS CLI
```bash
aws configure
```
Enter:
- **AWS Access Key ID**: Your access key
- **AWS Secret Access Key**: Your secret key
- **Default region**: `us-east-1` or `us-west-2`
- **Default output format**: `json`

#### 3.2 Verify AWS Access
```bash
# Test AWS access
aws sts get-caller-identity

# Should return your account ID and user info
```

### Step 4: Enable Amazon Bedrock Access

#### 4.1 Enable Model Access
1. Go to [Amazon Bedrock Console](https://console.aws.amazon.com/bedrock/)
2. Navigate to "Model access" in the left sidebar
3. Click "Enable specific models"
4. Enable these models:
   - **Anthropic Claude 3 Sonnet**
   - **Anthropic Claude 3 Haiku** 
   - **Cohere Embed Multilingual v3**
5. Submit request (usually approved immediately)

#### 4.2 Verify Bedrock Access
```bash
# Test Bedrock access
aws bedrock list-foundation-models --region us-east-1
# Should return a list of available models
```

### Step 5: Download Solution Code

#### 5.1 Create Working Directory
```bash
mkdir -p ~/video-understanding-solution
cd ~/video-understanding-solution
```

#### 5.2 Download/Copy Solution Files
```bash
# If using git (replace with actual repository URL)
git clone https://github.com/your-repo/video-understanding-solution.git .

# Or manually copy all the files we created to this directory
# Make sure you have all the files from our implementation
```

### Step 6: Deploy the Solution

#### 6.1 Make Scripts Executable
```bash
chmod +x deployment/*.sh
```

#### 6.2 Log Out and Back In
```bash
# Log out and back in to activate Docker group permissions
exit
# SSH back in
ssh -i your-key.pem ec2-user@your-instance-ip
cd ~/video-understanding-solution
```

#### 6.3 Run Deployment Script
```bash
# Run the deployment
./deployment/deploy_hardcoded_auth.sh
```

The deployment will:
1. ✅ Check all prerequisites
2. ✅ Validate AWS setup and Bedrock access
3. ✅ Set up Python virtual environment
4. ✅ Install Node.js dependencies
5. ✅ Bootstrap CDK
6. ✅ Deploy AWS infrastructure
7. ✅ Configure web application

**Deployment time**: 15-20 minutes

### Step 7: Access the Application

#### 7.1 Get Application URL
After successful deployment, you'll see:
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

#### 7.2 Access Web Application
1. Open the provided web application URL
2. Login with:
   - **Username**: `admin`
   - **Password**: `admin`

### Step 8: Test the Solution

#### 8.1 Upload a Video
1. Use the web interface to upload an MP4 video
2. Or upload directly to S3 bucket under "source" folder

#### 8.2 Verify Processing
The system will automatically:
- Extract video frames
- Perform transcription
- Analyze with Amazon Rekognition
- Generate AI summaries
- Extract entities and sentiment

#### 8.3 Test Features
- ✅ Video upload and processing
- ✅ AI-generated summaries
- ✅ Entity extraction
- ✅ Video search
- ✅ Q&A chatbot

## 🧹 Cleanup After Testing

### When You're Done
```bash
# Run cleanup script to remove all AWS resources
./deployment/cleanup_resources.sh
```

The cleanup will:
1. Empty S3 buckets
2. Disable RDS deletion protection
3. Destroy CDK stack
4. Clean up local files
5. Verify resource deletion

## 🔧 Troubleshooting

### Common Issues and Solutions

#### Issue: CDK Not Found
```bash
# Error: AWS CDK is not installed
# Solution: Install CDK globally
npm install -g aws-cdk@latest
```

#### Issue: Python Version
```bash
# Error: Python version issues
# Solution: Verify Python 3.9+
python3 --version
# Should show Python 3.9.x or higher
```

#### Issue: Docker Permission Denied
```bash
# Error: Docker permission denied
# Solution: Add user to docker group and restart session
sudo usermod -a -G docker $USER
# Log out and back in
```

#### Issue: Bedrock Access Denied
```bash
# Error: Cannot access Amazon Bedrock
# Solution: Enable model access in Bedrock console
# Visit: https://console.aws.amazon.com/bedrock/home#/modelaccess
```

#### Issue: CDK Bootstrap Failed
```bash
# Error: CDK bootstrap fails
# Solution: Manual bootstrap
export CDK_DEPLOY_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export CDK_DEPLOY_REGION=$(aws configure get region)
cdk bootstrap aws://$CDK_DEPLOY_ACCOUNT/$CDK_DEPLOY_REGION
```

#### Issue: Deployment Fails
```bash
# Check CloudFormation console for detailed error messages
# Common fixes:
# 1. Ensure sufficient IAM permissions
# 2. Check region supports all services
# 3. Verify Bedrock model access
# 4. Check account limits/quotas
```

### Getting Help
1. Check AWS CloudFormation console for stack events
2. Review CloudWatch logs for Lambda errors
3. Verify all prerequisites are correctly installed
4. Ensure AWS credentials have sufficient permissions

## 💰 Cost Estimation

### Variable Costs (usage-based)
- **Amazon Bedrock**: ~$0.01-0.10 per video
- **Amazon Transcribe**: ~$0.02-0.05 per video minute
- **Amazon Rekognition**: ~$0.10-0.50 per video
- **S3 Storage**: ~$0.023 per GB/month

### Fixed Costs (always running)
- **Aurora Serverless**: ~$0.50-1.00 per hour
- **NAT Gateway**: ~$0.045 per hour

### Cost Management Tips
- Use smaller videos for initial testing
- Clean up resources when done
- Monitor usage with AWS Cost Explorer
- Set up billing alerts

## 🔒 Security Considerations

### Demo Environment Limitations
- **Hardcoded credentials** (admin/admin)
- **No password encryption**
- **Basic session management**
- **Broad IAM permissions**

### Production Recommendations
- Implement proper authentication (Cognito, SAML)
- Use encrypted sessions
- Apply principle of least privilege
- Add monitoring and logging
- Implement rate limiting

## 📞 Support Resources

### Documentation
- [Amazon Bedrock User Guide](https://docs.aws.amazon.com/bedrock/)
- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/)
- [Amazon Transcribe Developer Guide](https://docs.aws.amazon.com/transcribe/)

### AWS Support
- [AWS Support Center](https://console.aws.amazon.com/support/)
- [AWS Forums](https://forums.aws.amazon.com/)

---

## 📝 Quick Reference Commands

### Essential Commands
```bash
# Check prerequisites
aws --version
python3 --version
node --version
cdk --version
docker --version

# Deploy solution
./deployment/deploy_hardcoded_auth.sh

# Clean up resources
./deployment/cleanup_resources.sh

# Check AWS credentials
aws sts get-caller-identity

# Test Bedrock access
aws bedrock list-foundation-models --region us-east-1
```

### File Structure
```
video-understanding-solution/
├── deployment/
│   ├── deploy_hardcoded_auth.sh
│   ├── setup_ec2_environment.sh
│   └── cleanup_resources.sh
├── lib/
│   ├── auth_lambda/
│   ├── app_hardcoded_auth.py
│   └── video_understanding_solution_stack_hardcoded_auth.py
├── webui/
│   └── src/
├── DEPLOYMENT_GUIDE.md
└── README_HARDCODED_AUTH.md
```

This complete guide should get you from a fresh Amazon Linux 2023 instance to a fully deployed Video Understanding Solution with hardcoded authentication!