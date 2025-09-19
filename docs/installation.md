# 📖 n8n Installation Guide

Complete step-by-step guide for setting up n8n with Traefik on Ubuntu VPS.

## Prerequisites

Before starting, ensure you have:

- **Ubuntu 20.04+** VPS with at least 2GB RAM
- **Domain name** with DNS pointing to your server
- **SSH access** to your server
- **sudo privileges** on the server
- **Basic terminal knowledge**

## Step 1: Prepare Your VPS

### 1.1 Connect to Your Server

```bash
ssh root@YOUR_SERVER_IP
```

### 1.2 Update System Packages

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.3 Create Dedicated User

Create a non-root user for better security:

```bash
# Create user
sudo adduser n8n_user

# Add to sudo group
sudo usermod -aG sudo n8n_user

# Switch to new user
su - n8n_user
```

## Step 2: Install Docker

### 2.1 Remove Old Docker Versions

```bash
sudo apt remove docker docker-engine docker.io containerd runc -y
```

### 2.2 Install Prerequisites

```bash
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```

### 2.3 Add Docker Repository

```bash
# Add Docker's GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### 2.4 Install Docker

```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### 2.5 Configure Docker for Non-Root User

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes (logout and login, or run):
newgrp docker

# Test installation
docker run hello-world
```

## Step 3: Setup n8n Project

### 3.1 Clone Repository

```bash
git clone https://github.com/Eugene-WebDev/n8n-production-docker-stack.git
cd n8n-production-docker-stack
```

### 3.2 Run Setup Script (Recommended)

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

**OR** follow manual setup below:

### 3.3 Manual Setup

#### Create Docker Network
```bash
docker network create web
```

#### Setup Directories
```bash
mkdir -p letsencrypt n8n_data backups
chmod 600 letsencrypt
```

#### Create Environment File
```bash
cp .env.example .env
```

## Step 4: Configure Environment

Edit the `.env` file with your settings:

```bash
nano .env
```

### 4.1 Required Configuration

Update these variables:

```bash
# Your domain name
N8N_HOST=n8n.yourdomain.com

# Your email for Let's Encrypt
ACME_EMAIL=your-email@example.com

# Generate strong encryption key (keep it secret!)
N8N_ENCRYPTION_KEY=your-very-strong-random-key-here
```

### 4.2 Generate Encryption Key

Use one of these methods:

```bash
# Method 1: Using openssl
openssl rand -base64 32

# Method 2: Using /dev/urandom
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1

# Method 3: Online generator
# Visit: https://www.random.org/strings/
```

## Step 5: Configure DNS

Point your domain to your server:

1. Login to your DNS provider
2. Create an **A record**:
   - **Name**: `n8n` (or your subdomain)
   - **Value**: `YOUR_SERVER_IP`
   - **TTL**: `300` (5 minutes)

Wait for DNS propagation (5-30 minutes).

### Verify DNS

```bash
nslookup n8n.yourdomain.com
# Should return your server IP
```

## Step 6: Configure Firewall

### 6.1 Install and Configure UFW

```bash
# Install UFW (if not installed)
sudo apt install ufw -y

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (IMPORTANT: Don't lock yourself out!)
sudo ufw allow ssh

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

## Step 7: Deploy n8n

### 7.1 Start Services

```bash
docker compose up -d
```

### 7.2 Monitor Deployment

Watch the logs to ensure everything starts correctly:

```bash
# Watch all logs
docker compose logs -f

# Watch specific service
docker compose logs -f traefik
docker compose logs -f n8n
```

### 7.3 Check Service Status

```bash
docker compose ps
```

You should see both services as "Up" and "healthy".

## Step 8: Access n8n

### 8.1 Open Browser

Navigate to: `https://n8n.yourdomain.com`

You should see:
- ✅ Valid SSL certificate (green padlock)
- ✅ n8n welcome screen

### 8.2 First Setup

1. **Create admin account** on first visit
2. **Set up your first workflow**
3. **Configure any needed credentials**

## Step 9: Verify Installation

### 9.1 SSL Certificate

Check SSL is working:
```bash
curl -I https://n8n.yourdomain.com
# Should return "HTTP/2 200"
```

### 9.2 Health Checks

```bash
# n8n health
docker compose exec n8n wget -q --spider http://localhost:5678/healthz && echo "n8n OK"

# Traefik health
docker compose exec traefik wget -q --spider http://localhost:8080/ping && echo "Traefik OK"
```

## Step 10: Backup Setup

### 10.1 Test Backup

```bash
./scripts/backup.sh
```

### 10.2 Setup Automated Backups (Optional)

Add to crontab for daily backups:

```bash
crontab -e

# Add this line for daily backup at 2 AM
0 2 * * * /home/n8n_user/n8n-production-docker-stack/scripts/backup.sh
```

## Troubleshooting

### Common Issues

#### 1. SSL Certificate Issues

**Problem**: "Certificate error" or "Not secure"

**Solutions**:
- Verify DNS is pointing to your server
- Check domain in `.env` file matches your actual domain
- Ensure email in `.env` is valid
- Wait up to 10 minutes for certificate generation
- Check Traefik logs: `docker compose logs traefik`

#### 2. Can't Access n8n

**Problem**: Site not loading or connection refused

**Solutions**:
- Check if services are running: `docker compose ps`
- Verify firewall allows ports 80 and 443
- Check logs: `docker compose logs -f`
- Verify DNS propagation: `nslookup n8n.yourdomain.com`

#### 3. Permission Errors

**Problem**: "Permission denied" when running Docker commands

**Solutions**:
- Add user to docker group: `sudo usermod -aG docker $USER`
- Log out and back in, or run: `newgrp docker`
- Check Docker daemon is running: `sudo systemctl status docker`

#### 4. Container Won't Start

**Problem**: Service keeps restarting or won't start

**Solutions**:
- Check logs: `docker compose logs [service-name]`
- Verify configuration in `.env` file
- Check disk space: `df -h`
- Verify network exists: `docker network ls | grep web`

### Getting Help

If you're still having issues:

1. **Check logs**: `docker compose logs -f`
2. **Verify configuration**: Review your `.env` file
3. **Test connectivity**: Use `curl` and `nslookup`
4. **Open an issue**: [GitHub Issues](https://github.com/Eugene-WebDev/n8n-production-docker-stack/issues)

## Next Steps

After successful installation:

1. **Security**: Review [security.md](security.md) for hardening tips
2. **Backups**: Setup automated backups
3. **Monitoring**: Consider adding monitoring stack
4. **Updates**: Use `./scripts/update.sh --backup` for updates
5. **Workflows**: Start building your automation workflows!

## Maintenance Commands

```bash
# View logs
docker compose logs -f

# Restart services
docker compose restart

# Update containers
./scripts/update.sh --backup

# Create backup
./scripts/backup.sh

# Stop services
docker compose down

# Start services
docker compose up -d
```

Congratulations! You now have a production-ready n8n installation with automatic SSL certificates and proper security configuration.
