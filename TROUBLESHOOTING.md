# 🔧 Troubleshooting Guide - Video Understanding Solution

## 🚨 Common Deployment Issues

### Issue 1: "webui: No such file or directory"

**Error Message:**
```
./deploy_hardcoded_auth.sh: line 155: cd: webui: No such file or directory
```

**Cause:** Script is not running from the correct directory or webui directory is missing.

**Solutions:**

#### Option A: Run from correct directory
```bash
# Make sure you're in the project root directory
ls -la
# You should see: deployment/ lib/ webui/ and other files

# If not in correct directory, navigate to project root
cd /path/to/video-understanding-solution

# Then run deployment
./deployment/deploy_hardcoded_auth.sh
```

#### Option B: Set up project structure
```bash
# Run project setup script to create missing directories
chmod +x setup_project.sh
./setup_project.sh

# Then run deployment
./deployment/deploy_hardcoded_auth.sh
```

#### Option C: Manual directory creation
```bash
# Create webui directory structure manually
mkdir -p webui/src webui/public
touch webui/package.json

# Copy the webui files from the solution
# Then run deployment
```

---

### Issue 2: "AWS CDK is not installed"

**Error Message:**
```
[ERROR] AWS CDK is not installed. Please install CDK 2.122.0 or higher.
```

**Solutions:**

#### Option A: Install CDK globally
```bash
# Install Node.js first if not installed
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20.10.0
nvm use 20.10.0

# Install CDK
npm install -g aws-cdk@latest

# Verify installation
cdk --version
```

#### Option B: Run prerequisites script
```bash
chmod +x install_prerequisites.sh
./install_prerequisites.sh
```

---

### Issue 3: "Python 3 is not installed"

**Error Message:**
```
[ERROR] Python 3 is not installed. Please install Python 3.8 or higher.
```

**Solutions:**

#### For Amazon Linux 2023:
```bash
# Install Python 3.9
sudo yum groupinstall -y "Development Tools"
sudo yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel

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

# Verify
python3 --version
```

---

### Issue 4: "Docker is not running"

**Error Message:**
```
[ERROR] Docker is not running. Please start Docker service.
```

**Solutions:**

```bash
# Install Docker
sudo yum install -y docker

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -a -G docker $USER

# Log out and back in, then verify
docker --version
docker info
```

---

### Issue 5: "Cannot access Amazon Bedrock"

**Error Message:**
```
[ERROR] Cannot access Amazon Bedrock. Please ensure you have enabled model access.
```

**Solutions:**

#### Enable Bedrock Model Access:
1. Go to [Amazon Bedrock Console](https://console.aws.amazon.com/bedrock/home#/modelaccess)
2. Click "Enable specific models"
3. Enable these models:
   - **Anthropic Claude 3 Sonnet**
   - **Anthropic Claude 3 Haiku**
   - **Cohere Embed Multilingual v3**
4. Submit request (usually approved immediately)

#### Verify Access:
```bash
aws bedrock list-foundation-models --region us-east-1
```

---

### Issue 6: "CDK bootstrap failed"

**Error Message:**
```
[ERROR] CDK bootstrap failed.
```

**Solutions:**

#### Manual Bootstrap:
```bash
# Set environment variables
export CDK_DEPLOY_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export CDK_DEPLOY_REGION=$(aws configure get region)

# Bootstrap manually
cdk bootstrap aws://$CDK_DEPLOY_ACCOUNT/$CDK_DEPLOY_REGION
```

#### Check Permissions:
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check region
aws configure get region
```

---

### Issue 7: "AWS credentials not configured"

**Error Message:**
```
[ERROR] AWS credentials not configured. Please run 'aws configure' first.
```

**Solutions:**

```bash
# Configure AWS credentials
aws configure

# Enter when prompted:
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-east-1 or us-west-2
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

---

### Issue 8: "Region not supported"

**Error Message:**
```
[ERROR] This solution requires a region with Amazon Bedrock support (us-east-1 or us-west-2).
```

**Solutions:**

```bash
# Change region to supported region
aws configure set region us-east-1
# or
aws configure set region us-west-2

# Verify change
aws configure get region
```

---

### Issue 9: "Permission denied" errors

**Error Message:**
```
Permission denied (various contexts)
```

**Solutions:**

#### For Docker:
```bash
sudo usermod -a -G docker $USER
# Log out and back in
```

#### For Scripts:
```bash
chmod +x deployment/*.sh
chmod +x install_prerequisites.sh
chmod +x setup_project.sh
```

#### For AWS:
- Ensure your AWS user has sufficient permissions
- Check IAM policies include CDK deployment permissions

---

### Issue 10: "CDK deployment failed"

**Error Message:**
```
[ERROR] CDK deployment failed.
```

**Solutions:**

#### Check CloudFormation Console:
1. Go to [CloudFormation Console](https://console.aws.amazon.com/cloudformation/)
2. Look for "VideoUnderstandingStack" stack
3. Check "Events" tab for detailed error messages

#### Common Fixes:
```bash
# Check account limits
aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE

# Verify Bedrock access
aws bedrock list-foundation-models --region us-east-1

# Check IAM permissions
aws iam get-user
```

---

## 🔍 Diagnostic Commands

### Check Prerequisites:
```bash
# Check all prerequisites
python3 --version
node --version
aws --version
docker --version
cdk --version
jq --version
```

### Check AWS Setup:
```bash
# Check credentials
aws sts get-caller-identity

# Check region
aws configure get region

# Test Bedrock access
aws bedrock list-foundation-models --region us-east-1
```

### Check Project Structure:
```bash
# Verify project files
ls -la lib/
ls -la webui/
ls -la deployment/

# Check critical files
[ -f "lib/app_hardcoded_auth.py" ] && echo "✓ CDK app found" || echo "✗ CDK app missing"
[ -f "webui/package.json" ] && echo "✓ WebUI found" || echo "✗ WebUI missing"
[ -f "deployment/deploy_hardcoded_auth.sh" ] && echo "✓ Deploy script found" || echo "✗ Deploy script missing"
```

---

## 🆘 Getting Help

### AWS Console Links:
- [CloudFormation Stacks](https://console.aws.amazon.com/cloudformation/)
- [Bedrock Model Access](https://console.aws.amazon.com/bedrock/home#/modelaccess)
- [IAM Users](https://console.aws.amazon.com/iam/home#/users)
- [S3 Buckets](https://console.aws.amazon.com/s3/)

### Log Locations:
- **CDK Logs**: Check CloudFormation events
- **Lambda Logs**: CloudWatch Logs
- **Deployment Logs**: Terminal output

### Support Resources:
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)

---

## 🔄 Clean Start Process

If you're having multiple issues, try a clean start:

### 1. Clean Up Existing Resources:
```bash
./deployment/cleanup_resources.sh
```

### 2. Reset Environment:
```bash
# Remove virtual environment
rm -rf venv/

# Reset webui
rm -rf webui/node_modules/
```

### 3. Fresh Installation:
```bash
# Run prerequisites installation
./install_prerequisites.sh

# Log out and back in
exit
# SSH back in

# Configure AWS
aws configure

# Run deployment
./deployment/deploy_hardcoded_auth.sh
```

---

## 📞 Still Need Help?

If you're still experiencing issues:

1. **Check the error message** against this troubleshooting guide
2. **Review the deployment logs** for specific error details
3. **Verify all prerequisites** are properly installed
4. **Check AWS console** for resource status and error messages
5. **Try the clean start process** if multiple issues persist

Remember: This solution is for demonstration purposes with hardcoded authentication. For production use, implement proper security measures.