#!/bin/bash

# EC2 Environment Setup Script for Amazon Linux 2023
# Video Understanding Solution - Hardcoded Authentication

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

# Function to update system packages
update_system() {
    log_info "Updating system packages..."
    sudo yum update -y
    log_success "System packages updated."
}

# Function to install Python 3.9+
install_python() {
    log_info "Installing Python 3.9..."
    
    # Check if Python 3.9+ is already installed
    if python3 --version 2>/dev/null | grep -q "Python 3\.[9-9]\|Python 3\.1[0-9]"; then
        log_info "Python 3.9+ is already installed."
        return 0
    fi
    
    # Install development tools
    sudo yum groupinstall -y "Development Tools"
    sudo yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel
    
    # Download and compile Python 3.9
    cd /tmp
    wget https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tgz
    tar xzf Python-3.9.18.tgz
    cd Python-3.9.18
    ./configure --enable-optimizations
    make -j $(nproc)
    sudo make altinstall
    
    # Clean up
    cd /
    rm -rf /tmp/Python-3.9.18*
    
    # Create symlinks
    sudo ln -sf /usr/local/bin/python3.9 /usr/local/bin/python3
    sudo ln -sf /usr/local/bin/pip3.9 /usr/local/bin/pip3
    
    log_success "Python 3.9 installed successfully."
}

# Function to install pip and virtualenv
install_pip_virtualenv() {
    log_info "Installing pip and virtualenv..."
    
    # Ensure pip is installed
    python3 -m ensurepip --upgrade
    
    # Install virtualenv
    python3 -m pip install --user virtualenv
    
    log_success "pip and virtualenv installed."
}

# Function to install Node.js 20
install_nodejs() {
    log_info "Installing Node.js 20..."
    
    # Install NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    
    # Source NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    # Install Node.js 20
    nvm install 20.10.0
    nvm use 20.10.0
    nvm alias default 20.10.0
    
    # Add to bashrc for persistence
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc
    
    log_success "Node.js 20 installed successfully."
}

# Function to install AWS CLI v2
install_aws_cli() {
    log_info "Installing AWS CLI v2..."
    
    # Check if AWS CLI v2 is already installed
    if aws --version 2>/dev/null | grep -q "aws-cli/2"; then
        log_info "AWS CLI v2 is already installed."
        return 0
    fi
    
    # Download and install AWS CLI v2
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    
    # Clean up
    rm -rf /tmp/aws*
    
    log_success "AWS CLI v2 installed successfully."
}

# Function to install Docker
install_docker() {
    log_info "Installing Docker..."
    
    # Install Docker
    sudo yum install -y docker
    
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    sudo usermod -a -G docker $USER
    sudo usermod -a -G docker ec2-user 2>/dev/null || true
    sudo usermod -a -G docker ssm-user 2>/dev/null || true
    
    log_success "Docker installed successfully."
    log_warning "You may need to log out and back in for Docker group permissions to take effect."
}

# Function to install additional tools
install_additional_tools() {
    log_info "Installing additional tools..."
    
    # Install jq, zip, unzip, git
    sudo yum install -y jq zip unzip git
    
    log_success "Additional tools installed."
}

# Function to install AWS CDK
install_aws_cdk() {
    log_info "Installing AWS CDK..."
    
    # Source NVM to ensure npm is available
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install CDK globally
    npm install -g aws-cdk@latest
    
    log_success "AWS CDK installed successfully."
}

# Function to install Python CDK libraries
install_python_cdk_libs() {
    log_info "Installing Python CDK libraries..."
    
    # Create a temporary virtual environment for global CDK libraries
    python3 -m pip install --user --upgrade pip
    python3 -m pip install --user "aws-cdk-lib>=2.122.0"
    python3 -m pip install --user "cdk-nag>=2.28.16"
    python3 -m pip install --user boto3
    
    log_success "Python CDK libraries installed."
}

# Function to configure AWS credentials prompt
configure_aws_credentials() {
    log_info "AWS credentials configuration..."
    echo
    log_warning "Please configure your AWS credentials before proceeding with deployment."
    echo "You can do this by running: aws configure"
    echo
    echo "You will need:"
    echo "  • AWS Access Key ID"
    echo "  • AWS Secret Access Key"
    echo "  • Default region (us-east-1 or us-west-2 recommended for Bedrock support)"
    echo "  • Default output format (json recommended)"
    echo
    read -p "Would you like to configure AWS credentials now? (y/n): " configure_now
    
    if [[ $configure_now =~ ^[Yy]$ ]]; then
        aws configure
        log_success "AWS credentials configured."
    else
        log_warning "Remember to configure AWS credentials before deployment."
    fi
}

# Function to verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check Python
    if python3 --version; then
        log_success "Python: OK"
    else
        log_error "Python: FAILED"
        return 1
    fi
    
    # Check Node.js
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if node --version; then
        log_success "Node.js: OK"
    else
        log_error "Node.js: FAILED"
        return 1
    fi
    
    # Check AWS CLI
    if aws --version; then
        log_success "AWS CLI: OK"
    else
        log_error "AWS CLI: FAILED"
        return 1
    fi
    
    # Check Docker
    if docker --version; then
        log_success "Docker: OK"
    else
        log_error "Docker: FAILED"
        return 1
    fi
    
    # Check CDK
    if cdk --version; then
        log_success "AWS CDK: OK"
    else
        log_error "AWS CDK: FAILED"
        return 1
    fi
    
    # Check additional tools
    if jq --version && zip --version && unzip -v && git --version; then
        log_success "Additional tools: OK"
    else
        log_error "Additional tools: FAILED"
        return 1
    fi
    
    log_success "All components verified successfully!"
}

# Function to display next steps
display_next_steps() {
    log_success "=== EC2 ENVIRONMENT SETUP COMPLETE ==="
    echo
    log_info "Next Steps:"
    echo "  1. Log out and log back in to ensure Docker group permissions are active"
    echo "  2. Configure AWS credentials if not done already: aws configure"
    echo "  3. Clone or download the Video Understanding Solution code"
    echo "  4. Run the deployment script: ./deployment/deploy_hardcoded_auth.sh"
    echo
    log_info "Important Notes:"
    echo "  • Ensure you have enabled Amazon Bedrock model access in your AWS account"
    echo "  • Use us-east-1 or us-west-2 regions for Bedrock support"
    echo "  • This setup is for demo purposes with hardcoded authentication"
    echo
    log_warning "Security Reminder:"
    echo "  This environment is configured for demonstration purposes."
    echo "  Do not use hardcoded authentication in production environments."
}

# Main setup function
main() {
    log_info "Starting EC2 environment setup for Amazon Linux 2023..."
    echo
    
    # Check if running on Amazon Linux 2023
    if ! grep -q "Amazon Linux release 2023" /etc/system-release 2>/dev/null; then
        log_warning "This script is designed for Amazon Linux 2023. Proceeding anyway..."
    fi
    
    # Run setup steps
    update_system
    install_python
    install_pip_virtualenv
    install_nodejs
    install_aws_cli
    install_docker
    install_additional_tools
    install_aws_cdk
    install_python_cdk_libs
    configure_aws_credentials
    verify_installation
    display_next_steps
    
    log_success "EC2 environment setup completed successfully!"
}

# Run main function
main "$@"