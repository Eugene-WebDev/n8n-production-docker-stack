# 🛡️ n8n Security Guide

Comprehensive security hardening guide for your n8n production deployment.

## 🎯 Security Overview

This guide covers security best practices for:
- Server hardening
- Container security
- Network protection
- Data encryption
- Access control
- Monitoring and logging

## 🖥️ Server Security

### System Hardening

#### 1. Update System Regularly

```bash
# Set up automatic updates
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades

# Manual updates
sudo apt update && sudo apt upgrade -y

# Check for security updates
sudo apt list --upgradable | grep -i security
```

#### 2. Configure SSH Security

```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Recommended settings:
Port 2222                    # Change default port
PermitRootLogin no          # Disable root login
PasswordAuthentication no   # Use keys only
MaxAuthTries 3             # Limit login attempts
ClientAliveInterval 300    # Session timeout
ClientAliveCountMax 2
X11Forwarding no           # Disable X11
AllowUsers your_username   # Limit allowed users

# Restart SSH service
sudo systemctl restart sshd
```

#### 3. Setup SSH Key Authentication

```bash
# On your local machine, generate SSH key
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Copy public key to server
ssh-copy-id -i ~/.ssh/id_rsa.pub -p 2222 username@server

# Test key-based login
ssh -p 2222 username@server
```

#### 4. Configure Firewall (UFW)

```bash
# Reset firewall
sudo ufw --force reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow essential services
sudo ufw allow 2222/tcp          # SSH (custom port)
sudo ufw allow 80/tcp            # HTTP
sudo ufw allow 443/tcp           # HTTPS

# Rate limiting for SSH
sudo ufw limit 2222/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

#### 5. Install Fail2ban

```bash
# Install fail2ban
sudo apt install fail2ban -y

# Create configuration file
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit configuration
sudo nano /etc/fail2ban/jail.local
```

Add this configuration:
```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log

[docker-auth]
enabled = true
filter = docker-auth
logpath = /var/log/auth.log
```

```bash
# Start and enable fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Check status
sudo fail2ban-client status
```

## 🔐 Container Security

### Docker Security

#### 1. Run Containers as Non-Root

Update your `docker-compose.yml`:
```yaml
services:
  n8n:
    user: "1000:1000"  # Use UID:GID
    # ... rest of configuration
```

#### 2. Limit Container Resources

```yaml
services:
  n8n:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          memory: 512M
    # ... rest of configuration
```

#### 3. Read-Only Root Filesystem

```yaml
services:
  n8n:
    read_only: true
    tmpfs:
      - /tmp
      - /var/tmp
    volumes:
      - ./n8n_data:/home/node/.n8n
      - /tmp/n8n-tmp:/tmp/n8n  # Writable temp directory
    # ... rest of configuration
```

#### 4. Drop Unnecessary Capabilities

```yaml
services:
  n8n:
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    # ... rest of configuration
```

#### 5. Security Options

```yaml
services:
  n8n:
    security_opt:
      - no-new-privileges:true
      - apparmor:docker-default
    # ... rest of configuration
```

### Environment Variables Security

#### 1. Protect Sensitive Variables

```bash
# Never commit .env files
echo ".env" >> .gitignore

# Set strict permissions
chmod 600 .env

# Use strong encryption keys
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
```

#### 2. Secrets Management

For production, consider using Docker secrets:

```yaml
services:
  n8n:
    secrets:
      - n8n_encryption_key
      - smtp_password
    environment:
      - N8N_ENCRYPTION_KEY_FILE=/run/secrets/n8n_encryption_key

secrets:
  n8n_encryption_key:
    file: ./secrets/encryption_key.txt
  smtp_password:
    file: ./secrets/smtp_password.txt
```

## 🌐 Network Security

### TLS/SSL Configuration

#### 1. Strong TLS Configuration

Update Traefik configuration for better security:

```yaml
services:
  traefik:
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
      # Security headers
      - "--entrypoints.websecure.http.middlewares=security-headers@docker"
      # TLS options
      - "--entrypoints.websecure.http.tls.options=modern@file"
    labels:
      # Security headers middleware
      - "traefik.http.middlewares.security-headers.headers.frameDeny=true"
      - "traefik.http.middlewares.security-headers.headers.sslRedirect=true"
      - "traefik.http.middlewares.security-headers.headers.browserXssFilter=true"
      - "traefik.http.middlewares.security-headers.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.security-headers.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.security-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.security-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.security-headers.headers.stsSeconds=63072000"
```

Create TLS configuration file `config/traefik/tls.yml`:
```yaml
tls:
  options:
    modern:
      minVersion: "VersionTLS12"
      cipherSuites:
        - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
        - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
      curvePreferences:
        - "CurveP521"
        - "CurveP384"
```

#### 2. HSTS Configuration

Add HSTS headers for enhanced security:
```yaml
labels:
  - "traefik.http.middlewares.security-headers.headers.customResponseHeaders.Strict-Transport-Security=max-age=63072000; includeSubDomains; preload"
```

### Network Isolation

#### 1. Custom Networks

```yaml
networks:
  web:
    external: true
  internal:
    driver: bridge
    internal: true

services:
  n8n:
    networks:
      - web
      - internal

  database:  # If using external DB
    networks:
      - internal  # Only internal network
```

#### 2. Service Communication

Restrict communication between services:
```yaml
services:
  n8n:
    depends_on:
      - traefik
    networks:
      web:
        aliases:
          - n8n-app
```

## 🔒 Authentication and Access Control

### n8n Authentication

#### 1. Enable Basic Authentication

```bash
# Add to .env file
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-very-strong-password
```

#### 2. LDAP/SAML Integration (Enterprise)

For enterprise setups, consider:
- LDAP authentication
- SAML SSO integration
- OAuth2 providers

#### 3. API Access Control

```bash
# Restrict API access
N8N_API_DISABLED=true  # Disable if not needed
N8N_DISABLE_UI=false   # Keep UI enabled
```

### Traefik Dashboard Security

#### 1. Secure Dashboard Access

```yaml
services:
  traefik:
    labels:
      # Dashboard
      - "traefik.http.routers.traefik.rule=Host(`traefik.${N8N_HOST}`)"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=traefik-auth"
      # Basic auth middleware
      - "traefik.http.middlewares.traefik-auth.basicauth.users=admin:$$apr1$$H6uskkkW$$IgXLP6ewTrSuBkTrqE8wj/"
```

Generate password hash:
```bash
# Generate htpasswd hash
echo $(htpasswd -nb admin your-password) | sed -e s/\\$/\\$\\$/g
```

#### 2. IP Allowlist

```yaml
labels:
  - "traefik.http.middlewares.traefik-ipallowlist.ipallowlist.sourcerange=192.168.1.0/24,10.0.0.0/8"
  - "traefik.http.routers.traefik.middlewares=traefik-auth,traefik-ipallowlist"
```

## 💾 Data Protection

### Encryption at Rest

#### 1. Encrypt n8n Data

n8n encrypts sensitive data using the encryption key:
```bash
# Use a strong, random encryption key
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)

# Store securely and never change it
echo "Store this key safely: $N8N_ENCRYPTION_KEY"
```

#### 2. Encrypt Backup Files

```bash
# Encrypt backups with GPG
gpg --symmetric --cipher-algo AES256 n8n_backup_20231201_120000.tar.gz

# Decrypt when needed
gpg --decrypt n8n_backup_20231201_120000.tar.gz.gpg > backup.tar.gz
```

#### 3. Encrypted File System

For maximum security, use encrypted storage:
```bash
# Create encrypted partition
sudo cryptsetup luksFormat /dev/sdb1
sudo cryptsetup luksOpen /dev/sdb1 n8n_encrypted

# Mount encrypted partition
sudo mkfs.ext4 /dev/mapper/n8n_encrypted
sudo mount /dev/mapper/n8n_encrypted /opt/n8n
```

### Backup Security

#### 1. Secure Backup Storage

```bash
# Upload encrypted backups to remote storage
# Using rclone with encrypted remote
rclone copy backups/ remote:n8n-backups/ --include "*.gpg"

# Or using rsync with SSH
rsync -avz -e ssh backups/ user@backup-server:/backups/n8n/
```

#### 2. Backup Rotation

```bash
# Implement secure backup rotation
find backups/ -name "*.tar.gz" -mtime +30 -exec shred -vfz -n 3 {} \;
```

## 📊 Monitoring and Logging

### Security Monitoring

#### 1. Log Analysis

```bash
# Monitor failed login attempts
sudo journalctl -u ssh -f | grep "Failed password"

# Monitor Docker events
docker events --filter event=start --filter event=stop

# Monitor n8n access logs
docker compose logs n8n | grep -E "(login|auth|error)"
```

#### 2. Intrusion Detection

Install and configure AIDE:
```bash
# Install AIDE
sudo apt install aide -y

# Initialize database
sudo aideinit

# Check for changes
sudo aide --check
```

#### 3. Log Forwarding

Forward logs to external SIEM:
```yaml
services:
  n8n:
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://your-siem-server:514"
        tag: "n8n"
```

### Alerting

#### 1. Security Alerts

```bash
# Create alert script
cat > /usr/local/bin/security-alert.sh << 'EOF'
#!/bin/bash
ALERT_EMAIL="admin@yourdomain.com"
SUBJECT="n8n Security Alert"
MESSAGE="$1"

echo "$MESSAGE" | mail -s "$SUBJECT" "$ALERT_EMAIL"
EOF

chmod +x /usr/local/bin/security-alert.sh
```

#### 2. Automated Monitoring

```bash
# Add to crontab for regular security checks
crontab -e

# Check for unauthorized changes daily
0 2 * * * /usr/local/bin/aide --check || /usr/local/bin/security-alert.sh "AIDE detected changes"

# Check for failed logins hourly
0 * * * * grep "Failed password" /var/log/auth.log | tail -10 | /usr/local/bin/security-alert.sh
```

## 🔄 Security Maintenance

### Regular Security Tasks

#### 1. Security Updates

```bash
# Create update script
cat > scripts/security-update.sh << 'EOF'
#!/bin/bash
# Create backup first
./scripts/backup.sh

# Update system packages
sudo apt update && sudo apt upgrade -y

# Update containers
docker compose pull
docker compose down && docker compose up -d

# Check for vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image n8n-production-docker-stack_n8n
EOF

chmod +x scripts/security-update.sh
```

#### 2. Security Audits

```bash
# Weekly security audit script
cat > scripts/security-audit.sh << 'EOF'
#!/bin/bash
echo "=== n8n Security Audit Report ===" > security-audit.log
echo "Date: $(date)" >> security-audit.log
echo >> security-audit.log

echo "1. Failed login attempts:" >> security-audit.log
grep "Failed password" /var/log/auth.log | tail -20 >> security-audit.log

echo "2. Docker security scan:" >> security-audit.log
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image docker.n8n.io/n8nio/n8n:latest >> security-audit.log

echo "3. SSL certificate status:" >> security-audit.log
echo | openssl s_client -connect n8n.yourdomain.com:443 2>/dev/null | \
    openssl x509 -noout -dates >> security-audit.log

echo "4. Firewall status:" >> security-audit.log
sudo ufw status >> security-audit.log

# Email report
mail -s "n8n Security Audit Report" admin@yourdomain.com < security-audit.log
EOF

chmod +x scripts/security-audit.sh
```

### Incident Response

#### 1. Security Incident Procedure

1. **Immediate Response**:
   ```bash
   # Stop services
   docker compose down
   
   # Block suspicious IPs
   sudo ufw deny from SUSPICIOUS_IP
   
   # Change passwords
   # Rotate encryption keys (carefully!)
   ```

2. **Investigation**:
   ```bash
   # Collect logs
   docker compose logs > incident-logs.txt
   sudo journalctl > system-logs.txt
   
   # Check file integrity
   sudo aide --check
   ```

3. **Recovery**:
   ```bash
   # Restore from clean backup
   ./scripts/restore.sh clean-backup.tar.gz
   
   # Update all credentials
   # Apply security patches
   ```

## ✅ Security Checklist

### Pre-Production Checklist

- [ ] Server hardened and updated
- [ ] SSH configured with key authentication
- [ ] Firewall properly configured
- [ ] Fail2ban installed and configured
- [ ] Strong encryption keys generated
- [ ] TLS/SSL properly configured
- [ ] Security headers implemented
- [ ] Authentication enabled
- [ ] Logging and monitoring configured
- [ ] Backup encryption enabled
- [ ] Security documentation updated

### Ongoing Security Tasks

- [ ] Weekly security updates
- [ ] Monthly security audits
- [ ] Quarterly penetration testing
- [ ] Annual security policy review
- [ ] Regular backup testing
- [ ] SSL certificate renewal monitoring
- [ ] Access review and cleanup

## 📚 Additional Resources

### Security Tools

- **Vulnerability Scanners**: Nessus, OpenVAS, Trivy
- **Network Security**: Nmap, Wireshark, tcpdump
- **Log Analysis**: ELK Stack, Splunk, Graylog
- **Intrusion Detection**: AIDE, Tripwire, OSSEC

### Security Standards

- **NIST Cybersecurity Framework**
- **OWASP Top 10**
- **CIS Controls**
- **ISO 27001**

### Training Resources

- **Security Training**: SANS, Cybrary, Coursera
- **Certifications**: Security+, CISSP, CEH
- **Documentation**: Keep security procedures documented and updated

---

**Remember**: Security is an ongoing process, not a one-time setup. Regularly review and update your security measures to protect against evolving threats. Stay informed about security best practices and apply patches promptly.
For questions about security configurations or to report security issues, please contact: eugene@eugenewebdev.com
