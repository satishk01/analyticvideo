#!/bin/bash

# Project Setup Script for Video Understanding Solution - Hardcoded Authentication
# This script ensures all necessary files and directories are in place

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

# Function to create missing directories
create_directories() {
    log_info "Creating project directories..."
    
    # Create main directories
    mkdir -p lib/auth_lambda
    mkdir -p lib/main_analyzer
    mkdir -p webui/src/components/Login
    mkdir -p webui/src/components/ProtectedRoute
    mkdir -p webui/src/contexts
    mkdir -p webui/public
    mkdir -p deployment
    
    log_success "Directories created."
}

# Function to check and create missing webui files
setup_webui_structure() {
    log_info "Setting up webui structure..."
    
    # Create public/index.html if missing
    if [ ! -f "webui/public/index.html" ]; then
        log_info "Creating webui/public/index.html..."
        cat > webui/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Video Understanding Solution" />
    <title>Video Understanding Solution</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF
    fi
    
    # Create public/manifest.json if missing
    if [ ! -f "webui/public/manifest.json" ]; then
        log_info "Creating webui/public/manifest.json..."
        cat > webui/public/manifest.json << 'EOF'
{
  "short_name": "Video Understanding",
  "name": "Video Understanding Solution",
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
EOF
    fi
    
    # Create src/index.js if missing
    if [ ! -f "webui/src/index.js" ]; then
        log_info "Creating webui/src/index.js..."
        cat > webui/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import 'bootstrap/dist/css/bootstrap.min.css';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF
    fi
    
    # Create src/index.css if missing
    if [ ! -f "webui/src/index.css" ]; then
        log_info "Creating webui/src/index.css..."
        cat > webui/src/index.css << 'EOF'
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
EOF
    fi
    
    # Create src/App.css if missing
    if [ ! -f "webui/src/App.css" ]; then
        log_info "Creating webui/src/App.css..."
        cat > webui/src/App.css << 'EOF'
.App {
  text-align: center;
}

.App-header {
  background-color: #282c34;
  padding: 20px;
  color: white;
}
EOF
    fi
    
    log_success "WebUI structure setup complete."
}

# Function to create placeholder VideoTable and VideoUpload components
create_placeholder_components() {
    log_info "Creating placeholder components..."
    
    # Create VideoTable directory and component
    mkdir -p webui/src/VideoTable
    if [ ! -f "webui/src/VideoTable/VideoTable.js" ]; then
        log_info "Creating placeholder VideoTable component..."
        cat > webui/src/VideoTable/VideoTable.js << 'EOF'
import React from 'react';

export const VideoTable = (props) => {
  return (
    <div>
      <h3>Video Table</h3>
      <p>Video processing and display functionality will be implemented here.</p>
      <p>Bucket: {props.bucketName}</p>
    </div>
  );
};
EOF
    fi
    
    # Create VideoUpload directory and component
    mkdir -p webui/src/VideoUpload
    if [ ! -f "webui/src/VideoUpload/VideoUpload.js" ]; then
        log_info "Creating placeholder VideoUpload component..."
        cat > webui/src/VideoUpload/VideoUpload.js << 'EOF'
import React from 'react';
import { Button } from 'react-bootstrap';

export const VideoUpload = (props) => {
  return (
    <div>
      <h3>Video Upload</h3>
      <p>Upload videos to bucket: {props.bucketName}</p>
      <Button variant="primary">Upload Video (Coming Soon)</Button>
    </div>
  );
};
EOF
    fi
    
    log_success "Placeholder components created."
}

# Function to verify all required files exist
verify_project_structure() {
    log_info "Verifying project structure..."
    
    local missing_files=()
    
    # Check critical files
    [ ! -f "lib/app_hardcoded_auth.py" ] && missing_files+=("lib/app_hardcoded_auth.py")
    [ ! -f "lib/video_understanding_solution_stack_hardcoded_auth.py" ] && missing_files+=("lib/video_understanding_solution_stack_hardcoded_auth.py")
    [ ! -f "lib/auth_lambda/index.py" ] && missing_files+=("lib/auth_lambda/index.py")
    [ ! -f "webui/package.json" ] && missing_files+=("webui/package.json")
    [ ! -f "webui/src/App.js" ] && missing_files+=("webui/src/App.js")
    [ ! -f "webui/src/aws-exports.js" ] && missing_files+=("webui/src/aws-exports.js")
    [ ! -f "deployment/deploy_hardcoded_auth.sh" ] && missing_files+=("deployment/deploy_hardcoded_auth.sh")
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Missing critical files:"
        for file in "${missing_files[@]}"; do
            echo "  • $file"
        done
        log_error "Please ensure all files from the solution are present."
        return 1
    fi
    
    log_success "All critical files are present."
    return 0
}

# Function to make scripts executable
make_scripts_executable() {
    log_info "Making scripts executable..."
    
    chmod +x deployment/*.sh 2>/dev/null || true
    chmod +x install_prerequisites.sh 2>/dev/null || true
    chmod +x setup_project.sh 2>/dev/null || true
    
    log_success "Scripts made executable."
}

# Function to display project status
display_project_status() {
    log_success "=== PROJECT SETUP COMPLETE ==="
    echo
    log_info "Project Structure:"
    echo "  ✓ lib/ - CDK infrastructure code"
    echo "  ✓ webui/ - React web application"
    echo "  ✓ deployment/ - Deployment scripts"
    echo
    log_info "Next Steps:"
    echo "  1. Install prerequisites: ./install_prerequisites.sh"
    echo "  2. Configure AWS: aws configure"
    echo "  3. Deploy solution: ./deployment/deploy_hardcoded_auth.sh"
    echo
    log_info "Current Directory: $(pwd)"
    log_info "Ready for deployment!"
}

# Main setup function
main() {
    log_info "Setting up Video Understanding Solution project structure..."
    echo
    
    create_directories
    setup_webui_structure
    create_placeholder_components
    make_scripts_executable
    
    if verify_project_structure; then
        display_project_status
        log_success "Project setup completed successfully!"
    else
        log_error "Project setup completed with missing files."
        log_info "Please ensure all solution files are present before deployment."
        exit 1
    fi
}

# Run main function
main "$@"