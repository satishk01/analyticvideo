#!/bin/bash

# Prerequisites Installation Script for Video Understanding Solution
# Amazon Linux 2023 - Hardcoded Authentication Version

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

# Function to check if running on Amazon Linux 2023
check_os() {
    log_info "Checking operating system..."
    
    if ! grep -q "Amazon Linux release 2023" /etc/system-release 2>/dev/null; then
        log_warning "This script is designed for Amazon Linux 2023."
        log_warning "Proceeding anyway, but some steps may fail on other systems."
    else
        log_success "Running on Amazon Linux 2023."
    fi
}

# Function to update system packages
update_system() {
    log_info "Updating system packages..."
    sudo yum update -y
    log_success "System packages updated."
}

# Function to install development tools
install_dev_tools() {
    log_info "Installing development tools..."
    sudo yum groupinstall -y "Development Tools"
    sudo yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel
    log_success "Development tools installed."
}

# Function to install Python 3.9+
install_python() {
    log_info "Checking Python installation..."
    
    # Check if Python 3.9+ is already installed
    if python3 --version 2>/dev/null | grep -q "Python 3\.[9-9]\|Python 3\.1[0-9]"; then
        log_success "Python 3.9+ is already installed: $(python3 --version)"
        return 0
    fi
    
    log_info "Installing Python 3.9..."
    
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
    
    log_success "Python 3.9 installed: $(python3 --version)"
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
    
    # Check if Node.js 20 is already installed
    if node --version 2>/dev/null | grep -q "v20"; then
        log_success "Node.js 20 is already installed: $(node --version)"
        return 0
    fi
    
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
    
    log_success "Node.js 20 installed: $(node --version)"
}

# Function to install AWS CLI v2
install_aws_cli() {
    log_info "Installing AWS CLI v2..."
    
    # Check if AWS CLI v2 is already installed
    if aws --version 2>/dev/null | grep -q "aws-cli/2"; then
        log_success "AWS CLI v2 is already installed: $(aws --version)"
        return 0
    fi
    
    # Download and install AWS CLI v2
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    
    # Clean up
    rm -rf /tmp/aws*
    
    log_success "AWS CLI v2 installed: $(aws --version)"
}

# Function to install Docker
install_docker() {
    log_info "Installing Docker..."
    
    # Check if Docker is already installed
    if docker --version 2>/dev/null; then
        log_success "Docker is already installed: $(docker --version)"
    else
        # Install Docker
        sudo yum install -y docker
        log_success "Docker installed: $(docker --version)"
    fi
    
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    sudo usermod -a -G docker $USER
    sudo usermod -a -G docker ec2-user 2>/dev/null || true
    sudo usermod -a -G docker ssm-user 2>/dev/null || true
    
    log_success "Docker service configured."
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
    
    # Check if CDK is already installed
    if cdk --version 2>/dev/null; then
        log_success "AWS CDK is already installed: $(cdk --version)"
    else
        # Install CDK globally
        npm install -g aws-cdk@latest
        log_success "AWS CDK installed: $(cdk --version)"
    fi
}

# Function to install Python CDK libraries
install_python_cdk_libs() {
    log_info "Installing Python CDK libraries..."
    
    # Install CDK libraries
    python3 -m pip install --user --upgrade pip
    python3 -m pip install --user "aws-cdk-lib>=2.122.0"
    python3 -m pip install --user "cdk-nag>=2.28.16"
    python3 -m pip install --user boto3
    
    log_success "Python CDK libraries installed."
}

# Function to verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    local all_good=true
    
    # Check Python
    if python3 --version 2>/dev/null | grep -q "Python 3\.[8-9]\|Python 3\.1[0-9]"; then
        log_success "✓ Python: $(python3 --version)"
    else
        log_error "✗ Python: Not found or version too old"
        all_good=false
    fi
    
    # Check Node.js
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if node --version 2>/dev/null; then
        log_success "✓ Node.js: $(node --version)"
    else
        log_error "✗ Node.js: Not found"
        all_good=false
    fi
    
    # Check AWS CLI
    if aws --version 2>/dev/null; then
        log_success "✓ AWS CLI: $(aws --version)"
    else
        log_error "✗ AWS CLI: Not found"
        all_good=false
    fi
    
    # Check Docker
    if docker --version 2>/dev/null; then
        log_success "✓ Docker: $(docker --version)"
    else
        log_error "✗ Docker: Not found"
        all_good=false
    fi
    
    # Check CDK
    if cdk --version 2>/dev/null; then
        log_success "✓ AWS CDK: $(cdk --version)"
    else
        log_error "✗ AWS CDK: Not found"
        all_good=false
    fi
    
    # Check additional tools
    if jq --version 2>/dev/null && zip --version 2>/dev/null && git --version 2>/dev/null; then
        log_success "✓ Additional tools: jq, zip, git installed"
    else
        log_error "✗ Additional tools: Some tools missing"
        all_good=false
    fi
    
    if [ "$all_good" = true ]; then
        log_success "All prerequisites verified successfully!"
        return 0
    else
        log_error "Some prerequisites failed verification."
        return 1
    fi
}

# Function to display next steps
display_next_steps() {
    log_success "=== PREREQUISITES INSTALLATION COMPLETE ==="
    echo
    log_info "Next Steps:"
    echo "  1. Log out and log back in to ensure Docker group permissions are active"
    echo "  2. Configure AWS credentials: aws configure"
    echo "  3. Enable Amazon Bedrock model access in AWS console"
    echo "  4. Run the deployment script: ./deployment/deploy_hardcoded_auth.sh"
    echo
    log_info "AWS Configuration:"
    echo "  • Run: aws configure"
    echo "  • Enter your AWS Access Key ID"
    echo "  • Enter your AWS Secret Access Key"
    echo "  • Set region to: us-east-1 or us-west-2"
    echo "  • Set output format to: json"
    echo
    log_info "Bedrock Model Access:"
    echo "  • Go to: https://console.aws.amazon.com/bedrock/home#/modelaccess"
    echo "  • Enable: Anthropic Claude 3 Sonnet"
    echo "  • Enable: Anthropic Claude 3 Haiku"
    echo "  • Enable: Cohere Embed Multilingual v3"
    echo
    log_warning "Important Notes:"
    echo "  • Log out and back in for Docker permissions"
    echo "  • Use us-east-1 or us-west-2 for Bedrock support"
    echo "  • This setup is for demo purposes only"
}

# Main installation function
main() {
    log_info "Starting prerequisites installation for Video Understanding Solution..."
    echo
    
    # Run installation steps
    check_os
    update_system
    install_dev_tools
    install_python
    install_pip_virtualenv
    install_nodejs
    install_aws_cli
    install_docker
    install_additional_tools
    install_aws_cdk
    install_python_cdk_libs
    
    if verify_installation; then
        display_next_steps
        log_success "Prerequisites installation completed successfully!"
    else
        log_error "Prerequisites installation completed with errors."
        log_info "Please review the error messages above and fix any issues."
        exit 1
    fi
}

# Run main function
main "$@"