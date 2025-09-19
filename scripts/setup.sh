#!/bin/bash

# ==============================================
# n8n Production Setup Script
# ==============================================
# This script automates the initial setup process
# for n8n with Traefik reverse proxy on Ubuntu VPS
# ==============================================

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root!"
        log_info "Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Check if running on Ubuntu
check_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_warning "This script is designed for Ubuntu. Proceeding anyway..."
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    log_success "System updated successfully"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker is already installed"
        return
    fi

    log_info "Installing Docker..."
    
    # Remove old versions
    sudo apt remove docker docker-engine docker.io containerd runc -y 2>/dev/null || true
    
    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    log_success "Docker installed successfully"
    log_warning "You need to log out and back in for Docker group changes to take effect"
}

# Test Docker installation
test_docker() {
    log_info "Testing Docker installation..."
    if docker run --rm hello-world &> /dev/null; then
        log_success "Docker is working correctly"
    else
        log_error "Docker test failed. Please check your installation."
        exit 1
    fi
}

# Create Docker network
create_network() {
    log_info "Creating Docker network..."
    if docker network ls | grep -q "web"; then
        log_info "Network 'web' already exists"
    else
        docker network create web
        log_success "Network 'web' created"
    fi
}

# Setup directory structure
setup_directories() {
    log_info "Setting up directory structure..."
    
    # Create necessary directories
    mkdir -p letsencrypt
    mkdir -p n8n_data
    mkdir -p backups
    
    # Set proper permissions
    chmod 600 letsencrypt 2>/dev/null || true
    
    log_success "Directories created"
}

# Generate encryption key
generate_encryption_key() {
    if command -v openssl &> /dev/null; then
        ENCRYPTION_KEY=$(openssl rand -base64 32)
        log_success "Generated encryption key: $ENCRYPTION_KEY"
        echo "Please save this key securely and add it to your .env file:"
        echo "N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY"
    else
        log_warning "OpenSSL not found. Please generate an encryption key manually."
    fi
}

# Create environment file
create_env_file() {
    if [[ ! -f .env ]]; then
        log_info "Creating .env file from template..."
        cp .env.example .env
        log_success ".env file created"
        log_warning "Please edit the .env file with your configuration before starting the services"
    else
        log_info ".env file already exists"
    fi
}

# Setup firewall
setup_firewall() {
    log_info "Setting up firewall..."
    
    # Check if ufw is available
    if command -v ufw &> /dev/null; then
        # Enable firewall
        sudo ufw --force enable
        
        # Allow SSH
        sudo ufw allow ssh
        
        # Allow HTTP and HTTPS
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        
        log_success "Firewall configured"
    else
        log_warning "UFW not available. Please configure firewall manually."
    fi
}

# Make scripts executable
setup_scripts() {
    log_info "Making scripts executable..."
    chmod +x scripts/*.sh 2>/dev/null || true
    log_success "Scripts are now executable"
}

# Final instructions
show_final_instructions() {
    echo
    echo "=================================="
    echo "🎉 Setup Complete!"
    echo "=================================="
    echo
    echo "Next steps:"
    echo "1. Edit the .env file with your configuration:"
    echo "   nano .env"
    echo
    echo "2. Update these variables:"
    echo "   - N8N_HOST (your domain)"
    echo "   - ACME_EMAIL (your email)"
    echo "   - N8N_ENCRYPTION_KEY (generated above)"
    echo
    echo "3. Start the services:"
    echo "   docker compose up -d"
    echo
    echo "4. Check the logs:"
    echo "   docker compose logs -f"
    echo
    echo "5. Access n8n at: https://your-domain.com"
    echo
    echo "Useful commands:"
    echo "  - View logs: docker compose logs -f [service]"
    echo "  - Restart: docker compose restart"
    echo "  - Stop: docker compose down"
    echo "  - Backup: ./scripts/backup.sh"
    echo "  - Update: ./scripts/update.sh"
    echo
}

# Main execution
main() {
    log_info "Starting n8n production setup..."
    echo
    
    check_root
    check_ubuntu
    update_system
    install_docker
    
    # Test Docker (skip if not in docker group yet)
    if groups | grep -q docker; then
        test_docker
        create_network
    else
        log_warning "Skipping Docker test - please log out and back in, then run 'docker network create web'"
    fi
    
    setup_directories
    create_env_file
    setup_scripts
    setup_firewall
    generate_encryption_key
    
    show_final_instructions
}

# Run main function
main "$@"
