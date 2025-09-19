#!/bin/bash

# ==============================================
# n8n Update Script
# ==============================================
# Updates n8n and Traefik containers safely
# ==============================================

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if auto-backup is requested
AUTO_BACKUP=false
if [[ "$1" == "--backup" ]] || [[ "$1" == "-b" ]]; then
    AUTO_BACKUP=true
fi

# Show help
show_help() {
    echo "n8n Update Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -b, --backup    Create backup before updating"
    echo "  -h, --help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0              Update without backup"
    echo "  $0 --backup     Create backup then update"
}

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Check Docker Compose
check_docker_compose() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available"
        exit 1
    fi
}

# Create backup before update
create_backup() {
    if [[ "$AUTO_BACKUP" == "true" ]]; then
        log_info "Creating backup before update..."
        if [[ -f "./scripts/backup.sh" ]]; then
            ./scripts/backup.sh
            log_success "Backup completed"
        else
            log_error "Backup script not found"
            exit 1
        fi
    else
        log_warning "Updating without backup. Use --backup flag to create backup first."
        read -p "Continue without backup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Update cancelled"
            exit 0
        fi
    fi
}

# Show current versions
show_current_versions() {
    log_info "Current container versions:"
    echo
    
    if docker compose ps -q n8n | grep -q .; then
        N8N_VERSION=$(docker compose exec -T n8n n8n --version 2>/dev/null || echo "Unable to get version")
        echo "  n8n: $N8N_VERSION"
    else
        echo "  n8n: Container not running"
    fi
    
    if docker compose ps -q traefik | grep -q .; then
        TRAEFIK_VERSION=$(docker compose exec -T traefik traefik version 2>/dev/null | head -1 || echo "Unable to get version")
        echo "  traefik: $TRAEFIK_VERSION"
    else
        echo "  traefik: Container not running"
    fi
    
    echo
}

# Pull latest images
pull_images() {
    log_info "Pulling latest container images..."
    
    docker compose pull
    
    log_success "Images pulled successfully"
}

# Stop services
stop_services() {
    log_info "Stopping services..."
    
    docker compose down
    
    log_success "Services stopped"
}

# Start services
start_services() {
    log_info "Starting updated services..."
    
    docker compose up -d
    
    log_success "Services started"
}

# Wait for services to be healthy
wait_for_health() {
    log_info "Waiting for services to become healthy..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker compose ps | grep -q "healthy\|Up"; then
            log_success "Services are healthy"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting for services..."
        sleep 10
        ((attempt++))
    done
    
    log_warning "Services may not be fully healthy yet"
    return 1
}

# Show new versions
show_new_versions() {
    log_info "Updated container versions:"
    echo
    
    sleep 5  # Wait a bit for containers to fully start
    
    if docker compose ps -q n8n | grep -q .; then
        N8N_VERSION=$(docker compose exec -T n8n n8n --version 2>/dev/null || echo "Unable to get version")
        echo "  n8n: $N8N_VERSION"
    fi
    
    if docker compose ps -q traefik | grep -q .; then
        TRAEFIK_VERSION=$(docker compose exec -T traefik traefik version 2>/dev/null | head -1 || echo "Unable to get version")
        echo "  traefik: $TRAEFIK_VERSION"
    fi
    
    echo
}

# Clean up old images
cleanup_images() {
    log_info "Cleaning up old Docker images..."
    
    # Remove dangling images
    docker image prune -f &> /dev/null || true
    
    log_success "Cleanup completed"
}

# Show service status
show_service_status() {
    log_info "Service Status:"
    echo
    docker compose ps
    echo
}

# Check for configuration changes
check_config_changes() {
    log_info "Checking for configuration updates..."
    
    # Check if docker-compose.yml has been updated
    if git status --porcelain docker-compose.yml 2>/dev/null | grep -q "M"; then
        log_warning "docker-compose.yml has local changes"
    fi
    
    # Check if .env needs updates
    if [[ -f ".env.example" ]] && [[ -f ".env" ]]; then
        if ! diff -q .env.example .env &>/dev/null; then
            log_info "Environment template may have updates. Compare .env with .env.example"
        fi
    fi
}

# Test services after update
test_services() {
    log_info "Testing services..."
    
    # Test n8n health endpoint
    if docker compose ps -q n8n | grep -q .; then
        if docker compose exec -T n8n wget -q --spider http://localhost:5678/healthz 2>/dev/null; then
            log_success "n8n health check passed"
        else
            log_warning "n8n health check failed"
        fi
    fi
    
    # Test Traefik API
    if docker compose ps -q traefik | grep -q .; then
        if docker compose exec -T traefik wget -q --spider http://localhost:8080/ping 2>/dev/null; then
            log_success "Traefik health check passed"
        else
            log_warning "Traefik health check failed"
        fi
    fi
}

# Show final instructions
show_final_instructions() {
    echo
    echo "=================================="
    echo "🎉 Update Complete!"
    echo "=================================="
    echo
    echo "Next steps:"
    echo "1. Check that your n8n instance is accessible"
    echo "2. Verify your workflows are working correctly"
    echo "3. Check the logs if you encounter any issues:"
    echo "   docker compose logs -f"
    echo
    echo "If you encounter problems:"
    echo "1. Check service logs: docker compose logs [service]"
    echo "2. Restart services: docker compose restart"
    echo "3. Restore from backup if needed: ./scripts/restore.sh [backup-file]"
    echo
}

# Main update function
main() {
    log_info "Starting n8n update process..."
    echo
    
    check_docker_compose
    show_current_versions
    create_backup
    check_config_changes
    pull_images
    stop_services
    start_services
    wait_for_health
    show_new_versions
    show_service_status
    test_services
    cleanup_images
    
    show_final_instructions
}

# Run main function
main "$@"
