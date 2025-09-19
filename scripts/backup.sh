#!/bin/bash

# ==============================================
# n8n Backup Script
# ==============================================
# Creates backup of n8n data, workflows, and configuration
# ==============================================

set -e

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

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

# Check if Docker Compose is available
check_docker_compose() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available"
        exit 1
    fi
}

# Create backup directory
create_backup_dir() {
    log_info "Creating backup directory..."
    mkdir -p "$BACKUP_PATH"
    log_success "Backup directory created: $BACKUP_PATH"
}

# Backup n8n data
backup_n8n_data() {
    log_info "Backing up n8n data..."
    
    if [[ -d "./n8n_data" ]]; then
        # Create tar archive of n8n data
        tar -czf "$BACKUP_PATH/n8n_data.tar.gz" -C . n8n_data/
        log_success "n8n data backed up"
    else
        log_warning "n8n data directory not found"
    fi
}

# Backup configuration files
backup_config() {
    log_info "Backing up configuration files..."
    
    # Copy configuration files
    [[ -f ".env" ]] && cp .env "$BACKUP_PATH/" && log_success ".env backed up"
    [[ -f "docker-compose.yml" ]] && cp docker-compose.yml "$BACKUP_PATH/" && log_success "docker-compose.yml backed up"
    
    # Backup Let's Encrypt certificates
    if [[ -d "./letsencrypt" ]]; then
        tar -czf "$BACKUP_PATH/letsencrypt.tar.gz" -C . letsencrypt/
        log_success "Let's Encrypt certificates backed up"
    fi
}

# Export workflows
export_workflows() {
    log_info "Exporting workflows..."
    
    # Check if n8n container is running
    if docker compose ps -q n8n | grep -q .; then
        # Create workflows export directory
        mkdir -p "$BACKUP_PATH/workflows"
        
        # Export all workflows (if n8n CLI is available in container)
        if docker compose exec -T n8n n8n export:workflow --all --output=/tmp/workflows_export.json 2>/dev/null; then
            docker compose exec -T n8n cat /tmp/workflows_export.json > "$BACKUP_PATH/workflows/all_workflows.json"
            log_success "Workflows exported"
        else
            log_warning "Could not export workflows via n8n CLI - data backup includes workflows"
        fi
    else
        log_warning "n8n container is not running - skipping workflow export"
    fi
}

# Export credentials (encrypted)
export_credentials() {
    log_info "Exporting credentials..."
    
    if docker compose ps -q n8n | grep -q .; then
        mkdir -p "$BACKUP_PATH/credentials"
        
        if docker compose exec -T n8n n8n export:credentials --all --output=/tmp/credentials_export.json 2>/dev/null; then
            docker compose exec -T n8n cat /tmp/credentials_export.json > "$BACKUP_PATH/credentials/all_credentials.json"
            log_success "Credentials exported (encrypted)"
        else
            log_warning "Could not export credentials via n8n CLI - data backup includes credentials"
        fi
    else
        log_warning "n8n container is not running - skipping credentials export"
    fi
}

# Create backup info file
create_backup_info() {
    log_info "Creating backup information file..."
    
    cat > "$BACKUP_PATH/backup_info.txt" << EOF
n8n Backup Information
======================
Backup Date: $(date)
Backup Name: $BACKUP_NAME
Server: $(hostname)
User: $(whoami)

Docker Compose Status:
$(docker compose ps 2>/dev/null || echo "Docker Compose not available")

n8n Version:
$(docker compose exec -T n8n n8n --version 2>/dev/null || echo "n8n container not running")

Backup Contents:
- n8n data directory (n8n_data.tar.gz)
- Configuration files (.env, docker-compose.yml)
- Let's Encrypt certificates (letsencrypt.tar.gz)
- Workflows export (workflows/)
- Credentials export (credentials/)

Restore Instructions:
1. Stop n8n services: docker compose down
2. Extract data: tar -xzf n8n_data.tar.gz
3. Restore config files
4. Start services: docker compose up -d

Note: Make sure to use the same N8N_ENCRYPTION_KEY when restoring!
EOF
    
    log_success "Backup information file created"
}

# Compress final backup
compress_backup() {
    log_info "Compressing backup..."
    
    # Create final compressed archive
    tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"
    
    # Remove uncompressed directory
    rm -rf "$BACKUP_PATH"
    
    log_success "Backup compressed: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
}

# Clean old backups
clean_old_backups() {
    log_info "Cleaning old backups..."
    
    # Keep only last 7 backups
    KEEP_BACKUPS=7
    
    cd "$BACKUP_DIR"
    ls -t n8n_backup_*.tar.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs rm -f
    
    REMAINING=$(ls -1 n8n_backup_*.tar.gz 2>/dev/null | wc -l)
    log_success "Keeping $REMAINING backup(s)"
}

# Calculate backup size
show_backup_size() {
    if [[ -f "$BACKUP_DIR/$BACKUP_NAME.tar.gz" ]]; then
        SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)
        log_success "Backup size: $SIZE"
    fi
}

# Main backup function
main() {
    log_info "Starting n8n backup process..."
    echo
    
    check_docker_compose
    create_backup_dir
    backup_n8n_data
    backup_config
    export_workflows
    export_credentials
    create_backup_info
    compress_backup
    clean_old_backups
    show_backup_size
    
    echo
    log_success "Backup completed successfully!"
    log_info "Backup location: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
    echo
    log_info "To restore this backup:"
    log_info "  ./scripts/restore.sh $BACKUP_NAME.tar.gz"
    echo
}

# Run main function
main "$@"
