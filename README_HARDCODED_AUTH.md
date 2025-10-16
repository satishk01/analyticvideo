# Video Understanding Solution - Hardcoded Authentication Version

## Overview

This is a modified version of the Video Understanding Solution that removes AWS Cognito authentication and implements hardcoded credentials for demonstration purposes.

**Login Credentials:**
- Username: `admin`
- Password: `admin`

⚠️ **Security Warning:** This version is for demonstration and testing purposes only. Do not use in production environments.

## Quick Start

### Prerequisites
- Amazon Linux 2023 EC2 instance
- AWS CLI configured with appropriate permissions
- Amazon Bedrock model access enabled

### 1. Environment Setup
```bash
# Run the environment setup script
./deployment/setup_ec2_environment.sh
```

### 2. Deploy the Solution
```bash
# Deploy with hardcoded authentication
./deployment/deploy_hardcoded_auth.sh
```

### 3. Access the Application
After deployment, use the provided URL with:
- Username: `admin`
- Password: `admin`

### 4. Clean Up Resources
```bash
# Remove all AWS resources
./deployment/cleanup_resources.sh
```

## What's Different from the Original

### Removed Components
- ❌ AWS Cognito User Pools
- ❌ AWS Cognito Identity Pools
- ❌ Amplify UI authentication
- ❌ Complex credential management

### Added Components
- ✅ Simple authentication Lambda function
- ✅ Hardcoded admin/admin credentials
- ✅ Session-based authentication
- ✅ Custom login interface
- ✅ Simplified deployment scripts

## Architecture Changes

```
Original: User → Cognito → Identity Pool → AWS Services
Modified: User → Custom Auth → Session Token → AWS Services
```

### Authentication Flow
1. User enters admin/admin credentials
2. Authentication Lambda validates credentials
3. Session token is generated and stored
4. Token is used for subsequent API calls
5. Session expires after 8 hours

## File Structure

```
├── deployment/
│   ├── deploy_hardcoded_auth.sh      # Main deployment script
│   ├── setup_ec2_environment.sh      # EC2 environment setup
│   └── cleanup_resources.sh          # Resource cleanup script
├── lib/
│   ├── auth_lambda/                   # Authentication Lambda function
│   ├── app_hardcoded_auth.py         # Modified CDK app
│   └── video_understanding_solution_stack_hardcoded_auth.py
├── webui/
│   ├── src/
│   │   ├── components/
│   │   │   ├── Login/               # Custom login component
│   │   │   └── ProtectedRoute/      # Route protection
│   │   ├── contexts/
│   │   │   └── AuthContext.js       # Authentication context
│   │   └── aws-exports.js           # Updated configuration
│   └── package.json                 # Updated dependencies
├── DEPLOYMENT_GUIDE.md              # Comprehensive deployment guide
└── README_HARDCODED_AUTH.md         # This file
```

## Deployment Scripts

### 1. Environment Setup (`setup_ec2_environment.sh`)
- Installs Python 3.9+
- Installs Node.js 20
- Installs AWS CLI v2
- Installs Docker
- Installs AWS CDK
- Configures user permissions

### 2. Main Deployment (`deploy_hardcoded_auth.sh`)
- Validates prerequisites
- Checks AWS setup and Bedrock access
- Sets up Python virtual environment
- Installs dependencies
- Deploys CDK stack
- Configures web application

### 3. Cleanup (`cleanup_resources.sh`)
- Empties S3 buckets
- Disables RDS deletion protection
- Destroys CDK stack
- Cleans up local files
- Verifies resource deletion

## Security Considerations

### Demo Environment
- **Hardcoded credentials** for simplicity
- **No password hashing** (credentials stored in plain text)
- **Simple session management** (in-memory storage)
- **Broad IAM permissions** for ease of use

### Not Suitable for Production
- No user management
- No password policies
- No multi-factor authentication
- No audit logging
- No rate limiting
- No encryption at rest for sessions

## Cost Optimization

### Reduced Costs
- ❌ No Cognito charges
- ❌ No Amplify hosting charges
- ❌ Simplified Lambda functions

### Remaining Costs
- Aurora Serverless PostgreSQL
- S3 storage
- Lambda execution
- Bedrock model usage
- Transcribe usage
- Rekognition usage

## Troubleshooting

### Common Issues

#### Authentication Not Working
```bash
# Check authentication Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/VideoUnderstandingStack-auth"
```

#### Deployment Fails
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name VideoUnderstandingStack
```

#### Web UI Not Loading
1. Check if aws-exports.js is properly configured
2. Verify API Gateway endpoints are accessible
3. Check browser console for errors

### Getting Help
1. Review deployment logs
2. Check AWS CloudFormation console
3. Verify all prerequisites are met
4. Ensure AWS credentials have sufficient permissions

## Development

### Local Development
```bash
# Install dependencies
cd webui
npm install

# Start development server (after deployment)
npm start
```

### Modifying Authentication
The authentication logic is in `lib/auth_lambda/index.py`. To change credentials:

```python
# Update these constants
ADMIN_USERNAME = "your_username"
ADMIN_PASSWORD = "your_password"
```

### Adding Features
1. Modify the CDK stack in `lib/video_understanding_solution_stack_hardcoded_auth.py`
2. Update web UI components in `webui/src/`
3. Redeploy with `./deployment/deploy_hardcoded_auth.sh`

## Migration

### From Original Version
1. Back up any existing data
2. Run cleanup on original deployment
3. Deploy hardcoded auth version
4. Restore data if needed

### To Production Version
1. Implement proper authentication (Cognito, SAML, etc.)
2. Add user management
3. Implement proper session security
4. Add monitoring and logging
5. Apply security best practices

## Support

### Documentation
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Detailed deployment instructions
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)

### Resources
- AWS Support Center
- AWS Forums
- GitHub Issues (if applicable)

---

**Remember:** This is a demonstration version with hardcoded authentication. Always implement proper security measures for production deployments.