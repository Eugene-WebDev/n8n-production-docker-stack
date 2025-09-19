# 💾 n8n Backup & Restore Guide

Comprehensive guide for backing up and restoring your n8n production deployment.

## 📋 Overview

This guide covers:
- Automated backup strategies
- Manual backup procedures
- Full system restoration
- Disaster recovery planning
- Data migration techniques

## 🎯 Backup Strategy

### What Gets Backed Up

1. **n8n Application Data** (`n8n_data/`)
   - Workflows and their versions
   - Execution history
   - Credentials (encrypted)
   - Settings and configurations
   - User data and permissions

2. **Configuration Files**
   - `.env` environment variables
   - `docker-compose.yml` deployment configuration
   - Custom Traefik configurations

3. **SSL Certificates** (`letsencrypt/`)
   - Let's Encrypt certificates
   - ACME account information
   - Certificate renewal data

4. **Database** (if using external database)
   - PostgreSQL/MySQL dumps
   - Database configurations

### Backup Types

- **Full Backup**: Complete system backup including all data and configurations
- **Incremental Backup**: Only changes since last backup
- **Configuration Backup**: Only settings and configurations
- **Data-Only Backup**: Only n8n data without system configurations

## 🔄 Automated Backup

### Using the Backup Script

The included backup script provides comprehensive automated backups.

#### 1. Basic Usage

```bash
# Run manual backup
./scripts/backup.sh

# Check backup was created
ls -la backups/
```

#### 2. Schedule Automated Backups

```bash
# Edit crontab
crontab -e

# Add backup schedules
# Daily backup at 2 AM
0 2 * * * /home/n8n_user/n8n-production-docker-stack/scripts/backup.sh

# Weekly full backup on Sundays at 1 AM
0 1 * * 0 /home/n8n_user/n8n-production-docker-stack/scripts/backup.sh

# Monthly backup on 1st of each month
0 0 1 * * /home/n8n_user/n8n-production-docker-stack/scripts/backup.sh
```

#### 3. Backup with Email Notifications

Create an enhanced backup script with notifications:

```bash
# Create enhanced backup script
cat > scripts/backup-with-notification.sh << 'EOF'
#!/bin/bash

BACKUP_SCRIPT="./scripts/backup.sh"
EMAIL="admin@yourdomain.com"
LOG_FILE="/tmp/n8n_backup.log"

# Run backup and capture output
$BACKUP_SCRIPT > $LOG_FILE 2>&1
BACKUP_STATUS=$?

# Check if backup was successful
if [ $BACKUP_STATUS -eq 0 ]; then
    SUBJECT="n8n Backup Successful - $(date '+%Y-%m-%d')"
    echo "Backup completed successfully at $(date)" | mail -s "$SUBJECT" "$EMAIL"
else
    SUBJECT="n8n Backup FAILED - $(date '+%Y-%m-%d')"
    cat $LOG_FILE | mail -s "$SUBJECT" "$EMAIL"
fi

# Clean up log file
rm -f $LOG_FILE
EOF

chmod +x scripts/backup-with-notification.sh
```

### Backup Retention Policy

#### 1. Default Retention

The backup script keeps:
- **Daily backups**: Last 7 days
- **Weekly backups**: Last 4 weeks
- **Monthly backups**: Last 12 months

#### 2. Custom Retention

Modify the cleanup function in `backup.sh`:

```bash
# Custom retention policy
clean_old_backups() {
    log_info "Cleaning old backups..."
    
    cd "$BACKUP_DIR"
    
    # Keep daily backups for 14 days
    find . -name "n8n_backup_*.tar.gz" -mtime +14 -delete
    
    # Keep weekly backups (every Sunday) for 8 weeks
    # Implementation depends on your naming convention
    
    REMAINING=$(ls -1 n8n_backup_*.tar.gz 2>/dev/null | wc -l)
    log_success "Keeping $REMAINING backup(s)"
}
```

## 📤 Remote Backup Storage

### Cloud Storage Integration

#### 1. AWS S3 Backup

```bash
# Install AWS CLI
sudo apt install awscli -y

# Configure AWS credentials
aws configure

# Create S3 backup script
cat > scripts/backup-to-s3.sh << 'EOF'
#!/bin/bash

# Run local backup first
./scripts/backup.sh

# Upload to S3
LATEST_BACKUP=$(ls -t backups/n8n_backup_*.tar.gz | head -1)
if [ -f "$LATEST_BACKUP" ]; then
    aws s3 cp "$LATEST_BACKUP" s3://your-backup-bucket/n8n/
    echo "Backup uploaded to S3: $LATEST_BACKUP"
else
    echo "No backup file found to upload"
    exit 1
fi

# Clean old S3 backups (keep last 30 days)
aws s3 ls s3://your-backup-bucket/n8n/ --output text | \
    awk '{print $4}' | \
    sort | \
    head -n -30 | \
    xargs -I {} aws s3 rm s3://your-backup-bucket/n8n/{}
EOF

chmod +x scripts/backup-to-s3.sh
```

#### 2. Google Drive Backup

```bash
# Install rclone
sudo apt install rclone -y

# Configure Google Drive
rclone config

# Create Google Drive backup script
cat > scripts/backup-to-gdrive.sh << 'EOF'
#!/bin/bash

# Run local backup
./scripts/backup.sh

# Upload to Google Drive
LATEST_BACKUP=$(ls -t backups/n8n_backup_*.tar.gz | head -1)
if [ -f "$LATEST_BACKUP" ]; then
    rclone copy "$LATEST_BACKUP" gdrive:n8n-backups/
    echo "Backup uploaded to Google Drive: $LATEST_BACKUP"
fi

# Clean old remote backups
rclone delete gdrive:n8n-backups/ --min-age 30d
EOF

chmod +x scripts/backup-to-gdrive.sh
```

#### 3. Encrypted Remote Backup

```bash
# Create encrypted remote backup script
cat > scripts/backup-encrypted-remote.sh << 'EOF'
#!/bin/bash

GPG_RECIPIENT="your-email@example.com"
BACKUP_SERVER="backup-server.com"
BACKUP_USER="backup_user"

# Run local backup
./scripts/backup.sh

# Get latest backup
LATEST_BACKUP=$(ls -t backups/n8n_backup_*.tar.gz | head -1)

if [ -f "$LATEST_BACKUP" ]; then
    # Encrypt backup
    ENCRYPTED_FILE="${LATEST_BACKUP}.gpg"
    gpg --trust-model always --encrypt --recipient "$GPG_RECIPIENT" --output "$ENCRYPTED_FILE" "$LATEST_BACKUP"
    
    # Upload encrypted backup
    scp "$ENCRYPTED_FILE" "${BACKUP_USER}@${BACKUP_SERVER}:/backups/n8n/"
    
    # Clean up local encrypted file
    rm "$ENCRYPTED_FILE"
    
    echo "Encrypted backup uploaded: $(basename $ENCRYPTED_FILE)"
else
    echo "No backup file found"
    exit 1
fi
EOF

chmod +x scripts/backup-encrypted-remote.sh
```

## 📥 Restore Procedures

### Create Restore Script

```bash
# Create comprehensive restore script
cat > scripts/restore.sh << 'EOF'
#!/bin/bash

# ==============================================
# n8n Restore Script
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

# Show usage
show_usage() {
    echo "n8n Restore Script"
    echo
    echo "Usage: $0 [OPTIONS] BACKUP_FILE"
    echo
    echo "Options:"
    echo "  --dry-run       Show what would be restored without making changes"
    echo "  --config-only   Restore only configuration files"
    echo "  --data-only     Restore only n8n data"
    echo "  --force         Skip confirmation prompts"
    echo "  -h, --help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 backups/n8n_backup_20231201_120000.tar.gz"
    echo "  $0 --config-only backups/n8n_backup_20231201_120000.tar.gz"
    echo "  $0 --dry-run backups/n8n_backup_20231201_120000.tar.gz"
}

# Parse command line arguments
DRY_RUN=false
CONFIG_ONLY=false
DATA_ONLY=false
FORCE=false
BACKUP_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --config-only)
            CONFIG_ONLY=true
            shift
            ;;
        --data-only)
            DATA_ONLY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option $1"
            show_usage
            exit 1
            ;;
        *)
            BACKUP_FILE="$1"
            shift
            ;;
    esac
done

# Check if backup file is provided
if [[ -z "$BACKUP_FILE" ]]; then
    log_error "Backup file is required"
    show_usage
    exit 1
fi

# Check if backup file exists
if [[ ! -f "$BACKUP_FILE" ]]; then
    log_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Extract backup to temporary directory
TEMP_DIR="/tmp/n8n_restore_$$"
mkdir -p "$TEMP_DIR"

log_info "Extracting backup file..."
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Find the backup directory
BACKUP_DIR=$(find "$TEMP_DIR" -name "n8n_backup_*" -type d | head -1)
if [[ -z "$BACKUP_DIR" ]]; then
    log_error "Invalid backup file structure"
    rm -rf "$TEMP_DIR"
    exit 1
fi

log_success "Backup extracted to temporary directory"

# Show backup information
if [[ -f "$BACKUP_DIR/backup_info.txt" ]]; then
    log_info "Backup Information:"
    cat "$BACKUP_DIR/backup_info.txt"
    echo
fi

# Confirmation prompt
if [[ "$FORCE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
    log_warning "This will restore your n8n installation from backup."
    log_warning "Current data will be replaced!"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Restore cancelled"
        rm -rf "$TEMP_DIR"
        exit 0
    fi
fi

# Stop services
stop_services() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would stop Docker services"
        return
    fi
    
    log_info "Stopping Docker services..."
    docker compose down
    log_success "Services stopped"
}

# Restore configuration files
restore_config() {
    if [[ "$DATA_ONLY" == "true" ]]; then
        return
    fi
    
    log_info "Restoring configuration files..."
    
    if [[ -f "$BACKUP_DIR/.env" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would restore .env file"
        else
            cp "$BACKUP_DIR/.env" .
            log_success ".env restored"
        fi
    fi
    
    if [[ -f "$BACKUP_DIR/docker-compose.yml" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would restore docker-compose.yml"
        else
            cp "$BACKUP_DIR/docker-compose.yml" .
            log_success "docker-compose.yml restored"
        fi
    fi
}

# Restore n8n data
restore_data() {
    if [[ "$CONFIG_ONLY" == "true" ]]; then
        return
    fi
    
    log_info "Restoring n8n data..."
    
    if [[ -f "$BACKUP_DIR/n8n_data.tar.gz" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would restore n8n data directory"
        else
            # Backup current data if it exists
            if [[ -d "./n8n_data" ]]; then
                mv ./n8n_data ./n8n_data.backup.$(date +%Y%m%d_%H%M%S)
                log_info "Current n8n_data backed up"
            fi
            
            # Extract n8n data
            tar -xzf "$BACKUP_DIR/n8n_data.tar.gz" -C .
            log_success "n8n data restored"
        fi
    else
        log_warning "n8n data not found in backup"
    fi
}

# Restore SSL certificates
restore_ssl() {
    if [[ "$CONFIG_ONLY" == "true" ]] || [[ "$DATA_ONLY" == "true" ]]; then
        return
    fi
    
    log_info "Restoring SSL certificates..."
    
    if [[ -f "$BACKUP_DIR/letsencrypt.tar.gz" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would restore Let's Encrypt certificates"
        else
            # Backup current certificates if they exist
            if [[ -d "./letsencrypt" ]]; then
                mv ./letsencrypt ./letsencrypt.backup.$(date +%Y%m%d_%H%M%S)
                log_info "Current certificates backed up"
            fi
            
            # Extract certificates
            tar -xzf "$BACKUP_DIR/letsencrypt.tar.gz" -C .
            chmod 600 letsencrypt/acme.json
            log_success "SSL certificates restored"
        fi
    else
        log_warning "SSL certificates not found in backup"
    fi
}

# Import workflows (if available)
import_workflows() {
    if [[ "$CONFIG_ONLY" == "true" ]]; then
        return
    fi
    
    if [[ -f "$BACKUP_DIR/workflows/all_workflows.json" ]]; then
        log_info "Workflow export found - will import after services start"
        IMPORT_WORKFLOWS=true
    fi
}

# Start services
start_services() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would start Docker services"
        return
    fi
    
    log_info "Starting Docker services..."
    docker compose up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to become healthy..."
    sleep 30
    
    # Check if services are running
    if docker compose ps | grep -q "Up"; then
        log_success "Services started successfully"
    else
        log_warning "Some services may not have started correctly"
        log_info "Check logs with: docker compose logs"
    fi
}

# Import workflows after services are running
import_workflows_post_start() {
    if [[ "$DRY_RUN" == "true" ]] || [[ "$IMPORT_WORKFLOWS" != "true" ]]; then
        return
    fi
    
    log_info "Importing workflows..."
    
    # Wait a bit more for n8n to be fully ready
    sleep 10
    
    # Import workflows
    if docker compose exec -T n8n n8n import:workflow --input=/tmp/workflows_import.json 2>/dev/null; then
        log_success "Workflows imported"
    else
        log_warning "Could not import workflows via CLI - they should be available in the restored data"
    fi
}

# Cleanup
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    log_success "Cleanup completed"
}

# Set trap for cleanup
trap cleanup EXIT

# Main restore process
main() {
    log_info "Starting n8n restore process..."
    echo
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "=== DRY RUN MODE - NO CHANGES WILL BE MADE ==="
        echo
    fi
    
    stop_services
    restore_config
    restore_data
    restore_ssl
    import_workflows
    
    if [[ "$DRY_RUN" != "true" ]]; then
        start_services
        import_workflows_post_start
        
        echo
        log_success "Restore completed successfully!"
        echo
        log_info "Next steps:"
        log_info "1. Verify your n8n instance is accessible"
        log_info "2. Check that your workflows are working correctly"
        log_info "3. Test your credentials and connections"
        log_info "4. Monitor logs: docker compose logs -f"
        echo
    else
        echo
        log_info "Dry run completed - no changes were made"
        echo
    fi
}

# Run main function
main "$@"
EOF

chmod +x scripts/restore.sh
```

### Basic Restore Usage

```bash
# List available backups
ls -la backups/

# Dry run to see what would be restored
./scripts/restore.sh --dry-run backups/n8n_backup_20231201_120000.tar.gz

# Full restore
./scripts/restore.sh backups/n8n_backup_20231201_120000.tar.gz

# Restore only configuration
./scripts/restore.sh --config-only backups/n8n_backup_20231201_120000.tar.gz

# Restore only data
./scripts/restore.sh --data-only backups/n8n_backup_20231201_120000.tar.gz
```

## 🔧 Manual Backup Procedures

### Manual Data Backup

```bash
# Stop services
docker compose down

# Create backup directory
mkdir -p manual_backups/$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="manual_backups/$(date +%Y%m%d_%H%M%S)"

# Copy n8n data
cp -r n8n_data/ "$BACKUP_DIR/"

# Copy configuration
cp .env "$BACKUP_DIR/"
cp docker-compose.yml "$BACKUP_DIR/"

# Copy SSL certificates
cp -r letsencrypt/ "$BACKUP_DIR/"

# Create archive
tar -czf "$BACKUP_DIR.tar.gz" -C manual_backups/ $(basename $BACKUP_DIR)

# Start services
docker compose up -d

echo "Manual backup created: $BACKUP_DIR.tar.gz"
```

### Export Workflows Only

```bash
# Export all workflows to JSON
docker compose exec n8n n8n export:workflow --all --output=/tmp/workflows_export.json

# Copy from container to host
docker compose cp n8n:/tmp/workflows_export.json ./workflows_backup_$(date +%Y%m%d).json

echo "Workflows exported to: ./workflows_backup_$(date +%Y%m%d).json"
```

### Export Credentials Only

```bash
# Export all credentials (encrypted)
docker compose exec n8n n8n export:credentials --all --output=/tmp/credentials_export.json

# Copy from container to host
docker compose cp n8n:/tmp/credentials_export.json ./credentials_backup_$(date +%Y%m%d).json

echo "Credentials exported to: ./credentials_backup_$(date +%Y%m%d).json"
```

## 🚨 Disaster Recovery

### Complete System Recovery

#### 1. Emergency Recovery Plan

```bash
# Create emergency recovery script
cat > scripts/emergency-recovery.sh << 'EOF'
#!/bin/bash

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Emergency recovery procedure
BACKUP_FILE="$1"

if [[ -z "$BACKUP_FILE" ]]; then
    log_error "Usage: $0 <backup_file.tar.gz>"
    exit 1
fi

log_info "Starting emergency recovery procedure..."

# 1. Stop all services
log_info "Stopping all Docker services..."
docker compose down || true
docker stop $(docker ps -aq) 2>/dev/null || true

# 2. Remove corrupted data
log_info "Removing corrupted data..."
rm -rf n8n_data/ letsencrypt/

# 3. Restore from backup
log_info "Restoring from backup: $BACKUP_FILE"
./scripts/restore.sh --force "$BACKUP_FILE"

# 4. Verify restoration
log_info "Verifying restoration..."
if [[ -d "n8n_data" ]] && [[ -f ".env" ]]; then
    log_info "Emergency recovery completed successfully"
    exit 0
else
    log_error "Emergency recovery failed - manual intervention required"
    exit 1
fi
EOF

chmod +x scripts/emergency-recovery.sh
```

#### 2. Recovery from Remote Backup

```bash
# Create remote recovery script
cat > scripts/recover-from-remote.sh << 'EOF'
#!/bin/bash

BACKUP_SERVER="backup-server.com"
BACKUP_USER="backup_user"
REMOTE_BACKUP_PATH="/backups/n8n/"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1"
}

# List available remote backups
log_info "Available remote backups:"
ssh "${BACKUP_USER}@${BACKUP_SERVER}" "ls -la ${REMOTE_BACKUP_PATH}"

# Get latest backup
LATEST_BACKUP=$(ssh "${BACKUP_USER}@${BACKUP_SERVER}" "ls -t ${REMOTE_BACKUP_PATH}n8n_backup_*.tar.gz | head -1")

if [[ -z "$LATEST_BACKUP" ]]; then
    log_error "No remote backups found"
    exit 1
fi

log_info "Downloading latest backup: $(basename $LATEST_BACKUP)"

# Download backup
scp "${BACKUP_USER}@${BACKUP_SERVER}:${LATEST_BACKUP}" ./

# Restore from downloaded backup
./scripts/restore.sh --force "./$(basename $LATEST_BACKUP)"

log_info "Recovery from remote backup completed"
EOF

chmod +x scripts/recover-from-remote.sh
```

### Data Migration

#### 1. Migrate to New Server

```bash
# On old server - create migration backup
./scripts/backup.sh

# Copy backup to new server
scp backups/n8n_backup_*.tar.gz user@new-server:/home/user/

# On new server - setup and restore
git clone https://github.com/Eugene-WebDev/n8n-production-docker-stack.git
cd n8n-production-docker-stack
./scripts/setup.sh
# Edit .env with new server details
./scripts/restore.sh n8n_backup_*.tar.gz
```

#### 2. Change Domain Name

```bash
# Update .env with new domain
sed -i 's/old-domain.com/new-domain.com/g' .env

# Remove old SSL certificates
rm -rf letsencrypt/

# Restart services to get new certificates
docker compose down && docker compose up -d
```

## 📊 Backup Monitoring

### Backup Health Monitoring

```bash
# Create backup monitoring script
cat > scripts/backup-health-check.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="./backups"
EMAIL="admin@yourdomain.com"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_recent_backup() {
    # Check if backup exists from last 25 hours
    RECENT_BACKUP=$(find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -mtime -1 | head -1)
    
    if [[ -n "$RECENT_BACKUP" ]]; then
        log_info "Recent backup found: $(basename $RECENT_BACKUP)"
        return 0
    else
        log_info "No recent backup found (last 24 hours)"
        return 1
    fi
}

check_backup_integrity() {
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/n8n_backup_*.tar.gz 2>/dev/null | head -1)
    
    if [[ -z "$LATEST_BACKUP" ]]; then
        log_info "No backups found"
        return 1
    fi
    
    # Test if backup can be extracted
    if tar -tzf "$LATEST_BACKUP" >/dev/null 2>&1; then
        log_info "Backup integrity check passed: $(basename $LATEST_BACKUP)"
        return 0
    else
        log_info "Backup integrity check failed: $(basename $LATEST_BACKUP)"
        return 1
    fi
}

check_disk_space() {
    # Check if backup directory has enough space (>1GB)
    AVAILABLE_SPACE=$(df "$BACKUP_DIR" | tail -1 | awk '{print $4}')
    REQUIRED_SPACE=1048576  # 1GB in KB
    
    if [[ $AVAILABLE_SPACE -gt $REQUIRED_SPACE ]]; then
        log_info "Sufficient disk space available"
        return 0
    else
        log_info "Low disk space warning"
        return 1
    fi
}

# Run checks
ISSUES=0

if ! check_recent_backup; then
    ((ISSUES++))
fi

if ! check_backup_integrity; then
    ((ISSUES++))
fi

if ! check_disk_space; then
    ((ISSUES++))
fi

# Send alert if issues found
if [[ $ISSUES -gt 0 ]]; then
    SUBJECT="n8n Backup Health Issues - $ISSUES problems found"
    echo "Backup health check found $ISSUES issues. Please review the backup system." | \
        mail -s "$SUBJECT" "$EMAIL"
    exit 1
else
    log_info "All backup health checks passed"
    exit 0
fi
EOF

chmod +x scripts/backup-health-check.sh

# Add to crontab for daily monitoring
# 0 6 * * * /path/to/n8n-production-docker-stack/scripts/backup-health-check.sh
```

## 📚 Best Practices

### Backup Best Practices

1. **3-2-1 Rule**: 3 copies, 2 different media types, 1 offsite
2. **Test Restores**: Regularly test backup restoration
3. **Encrypt Sensitive Data**: Encrypt backups containing credentials
4. **Monitor Backup Health**: Automate backup verification
5. **Document Recovery Procedures**: Keep recovery documentation updated

### Recovery Best Practices

1. **Practice Recovery**: Regular disaster recovery drills
2. **Multiple Recovery Points**: Keep backups from different time periods
3. **Verify Data Integrity**: Always verify restored data
4. **Update Documentation**: Keep recovery procedures current
5. **Test New Environments**: Test restores on similar systems

## ❓ Troubleshooting

### Common Backup Issues

#### 1. Backup Script Permission Errors

```bash
# Fix script permissions
chmod +x scripts/*.sh

# Fix backup directory permissions
chmod 755 backups/
```

#### 2. Out of Disk Space

```bash
# Check disk usage
df -h

# Clean old backups
find backups/ -name "n8n_backup_*.tar.gz" -mtime +30 -delete

# Clean Docker system
docker system prune -a
```

#### 3. Backup Corruption

```bash
# Test backup integrity
tar -tzf backups/n8n_backup_20231201_120000.tar.gz

# If corrupted, use previous backup
ls -la backups/ | grep backup
```

### Common Restore Issues

#### 1. Encryption Key Mismatch

```bash
# Ensure same encryption key is used
grep N8N_ENCRYPTION_KEY .env

# If different, workflows/credentials may not be accessible
# Use backup with matching key or re-create credentials
```

#### 2. Permission Issues After Restore

```bash
# Fix n8n data permissions
sudo chown -R $USER:$USER n8n_data/
chmod -R 755 n8n_data/

# Fix SSL certificate permissions
chmod 600 letsencrypt/acme.json
```

#### 3. Services Won't Start After Restore

```bash
# Check configuration
docker compose config

# Check logs
docker compose logs

# Verify network exists
docker network create web
```

## 📞 Support

For backup and restore issues:

- 📧 Email: eugene@eugenewebdev.com
- 🐛 Issues: [GitHub Issues](https://github.com/Eugene-WebDev/n8n-production-docker-stack/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/Eugene-WebDev/n8n-production-docker-stack/discussions)

---

**Remember**: Regular backups are your safety net. Test your backup and restore procedures regularly to ensure they work when you need them most!
