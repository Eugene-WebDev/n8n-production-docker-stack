# 🔧 n8n Troubleshooting Guide

Comprehensive guide to diagnose and fix common issues with your n8n production deployment.

## 📋 Quick Diagnostics

### Health Check Commands

```bash
# Check all services status
docker compose ps

# Check Docker network
docker network ls | grep web

# Test container connectivity
docker compose exec n8n ping traefik
docker compose exec traefik ping n8n

# Check disk space
df -h

# Check memory usage
free -h

# Check system logs
journalctl -u docker.service --since "1 hour ago"
```

### Log Analysis

```bash
# View all logs
docker compose logs

# Follow logs in real-time
docker compose logs -f

# View specific service logs
docker compose logs traefik
docker compose logs n8n

# View last 50 lines
docker compose logs --tail=50

# Filter logs by time
docker compose logs --since "2h"
```

## 🚨 SSL/TLS Certificate Issues

### Problem: "Your connection is not private" / Certificate errors

#### Symptoms:
- Browser shows SSL warning
- Certificate appears invalid or self-signed
- HTTPS not working

#### Diagnosis:
```bash
# Check Traefik logs for ACME errors
docker compose logs traefik | grep -i acme
docker compose logs traefik | grep -i certificate

# Check Let's Encrypt directory
ls -la letsencrypt/
cat letsencrypt/acme.json | jq .

# Test SSL certificate
openssl s_client -connect n8n.yourdomain.com:443 -servername n8n.yourdomain.com
```

#### Solutions:

**1. DNS Not Propagated**
```bash
# Check DNS resolution
nslookup n8n.yourdomain.com
dig n8n.yourdomain.com

# Wait for DNS propagation (can take up to 48 hours)
# Try different DNS servers
nslookup n8n.yourdomain.com 8.8.8.8
```

**2. Invalid Email in ACME Configuration**
```bash
# Check .env file
grep ACME_EMAIL .env

# Update with valid email
ACME_EMAIL=your-real-email@example.com
docker compose down && docker compose up -d
```

**3. Firewall Blocking Ports**
```bash
# Check firewall status
sudo ufw status

# Allow required ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check if ports are listening
netstat -tlnp | grep :80
netstat -tlnp | grep :443
```

**4. Rate Limiting by Let's Encrypt**
```bash
# Check for rate limit errors in logs
docker compose logs traefik | grep -i "rate limit"

# If rate limited, wait 1 week or use staging environment
# Add to docker-compose.yml temporarily:
# - "--certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
```

**5. Certificate File Permissions**
```bash
# Fix acme.json permissions
chmod 600 letsencrypt/acme.json
docker compose restart traefik
```

## 🌐 Network and Connectivity Issues

### Problem: Cannot access n8n web interface

#### Symptoms:
- Site not loading
- Connection timeout
- "This site can't be reached"

#### Diagnosis:
```bash
# Test local connectivity
curl -I http://localhost:80
curl -I https://localhost:443

# Test from container
docker compose exec traefik wget -q --spider http://n8n:5678/healthz

# Check port binding
docker compose ps
netstat -tlnp | grep :80
netstat -tlnp | grep :443
```

#### Solutions:

**1. Service Not Running**
```bash
# Check service status
docker compose ps

# Start stopped services
docker compose up -d

# Check for startup errors
docker compose logs
```

**2. Network Issues**
```bash
# Recreate network
docker network rm web
docker network create web
docker compose down && docker compose up -d

# Check network connectivity
docker network inspect web
```

**3. Port Conflicts**
```bash
# Check what's using ports 80/443
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Kill conflicting processes
sudo systemctl stop apache2
sudo systemctl stop nginx
```

**4. Firewall Issues**
```bash
# Check firewall rules
sudo ufw status numbered

# Reset firewall if needed
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## 🔐 Authentication and Permissions

### Problem: Permission denied errors

#### Symptoms:
- "Permission denied" when running Docker commands
- Cannot access files in n8n_data directory
- Container startup failures due to permissions

#### Solutions:

**1. Docker Group Issues**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Or logout and login again
exit
ssh user@server
```

**2. File Permission Issues**
```bash
# Fix n8n data permissions
sudo chown -R $USER:$USER n8n_data/
chmod -R 755 n8n_data/

# Fix Let's Encrypt permissions
sudo chown -R $USER:$USER letsencrypt/
chmod 600 letsencrypt/acme.json
```

**3. SELinux Issues (CentOS/RHEL)**
```bash
# Check SELinux status
sestatus

# Temporarily disable if causing issues
sudo setenforce 0

# Or set appropriate contexts
sudo setsebool -P httpd_can_network_connect 1
```

## 💾 Container and Docker Issues

### Problem: Container keeps restarting

#### Symptoms:
- Service shows as "Restarting"
- Container exits immediately after start
- Health check failures

#### Diagnosis:
```bash
# Check container status
docker compose ps

# View container logs
docker compose logs [service-name]

# Check container resource usage
docker stats

# Inspect container details
docker inspect n8n-production-docker-stack_n8n_1
```

#### Solutions:

**1. Resource Constraints**
```bash
# Check system resources
free -h
df -h

# Increase container resources in docker-compose.yml
services:
  n8n:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

**2. Configuration Errors**
```bash
# Validate docker-compose.yml
docker compose config

# Check environment variables
docker compose exec n8n env | grep N8N
```

**3. Volume Mount Issues**
```bash
# Check volume permissions
ls -la n8n_data/

# Recreate volumes
docker compose down -v
docker compose up -d
```

### Problem: Out of disk space

#### Symptoms:
- "No space left on device" errors
- Containers failing to start
- Cannot create new files

#### Solutions:
```bash
# Check disk usage
df -h
du -sh * | sort -hr

# Clean Docker system
docker system prune -a

# Clean old containers and images
docker container prune
docker image prune -a

# Clean volumes (CAUTION: This removes data)
docker volume prune

# Clean build cache
docker builder prune -a
```

## 🔄 Backup and Restore Issues

### Problem: Backup script fails

#### Symptoms:
- Backup script exits with errors
- Incomplete backups
- Cannot restore from backup

#### Solutions:

**1. Permission Issues**
```bash
# Make script executable
chmod +x scripts/backup.sh

# Check script permissions
ls -la scripts/
```

**2. Missing Dependencies**
```bash
# Install required tools
sudo apt update
sudo apt install tar gzip curl -y
```

**3. Disk Space Issues**
```bash
# Check available space
df -h ./backups/

# Clean old backups
find ./backups/ -name "n8n_backup_*.tar.gz" -mtime +7 -delete
```

### Problem: Restore fails

#### Solutions:
```bash
# Stop services before restore
docker compose down

# Extract backup manually
tar -xzf backups/n8n_backup_YYYYMMDD_HHMMSS.tar.gz

# Check backup contents
tar -tzf backups/n8n_backup_YYYYMMDD_HHMMSS.tar.gz

# Verify encryption key matches
grep N8N_ENCRYPTION_KEY .env
```

## 🚀 Performance Issues

### Problem: n8n is slow or unresponsive

#### Symptoms:
- Slow page loading
- Workflows timing out
- High CPU/memory usage

#### Diagnosis:
```bash
# Check container resources
docker stats

# Check system load
top
htop

# Check n8n logs for errors
docker compose logs n8n | grep -i error
```

#### Solutions:

**1. Resource Optimization**
```bash
# Increase container limits in docker-compose.yml
services:
  n8n:
    environment:
      - DB_SQLITE_POOL_SIZE=10
      - N8N_PAYLOAD_SIZE_MAX=32
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
```

**2. Database Optimization**
```bash
# Clean old executions
docker compose exec n8n n8n execute --file="/usr/local/lib/node_modules/n8n/dist/commands/executionCleanup.js"

# Or set execution retention in .env
EXECUTIONS_DATA_MAX_AGE=168  # 7 days
```

**3. Upgrade to PostgreSQL**
```yaml
# Add to docker-compose.yml for better performance
services:
  postgres:
    image: postgres:13
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=your-secure-password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  n8n:
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=your-secure-password

volumes:
  postgres_data:
```

## 🔍 Advanced Debugging

### Debug Mode

Enable debug logging:
```bash
# Update .env file
N8N_LOG_LEVEL=debug

# Restart services
docker compose down && docker compose up -d

# Follow debug logs
docker compose logs -f n8n
```

### Health Checks

Test individual components:
```bash
# Test n8n health endpoint
curl http://localhost:5678/healthz

# Test from inside container
docker compose exec n8n wget -q --spider http://localhost:5678/healthz

# Test Traefik API
curl http://localhost:8080/ping

# Test SSL handshake
openssl s_client -connect n8n.yourdomain.com:443
```

### Network Debugging

```bash
# Test container network connectivity
docker compose exec n8n ping traefik
docker compose exec traefik ping n8n

# Check routing rules
docker compose exec traefik wget -qO- http://localhost:8080/api/http/routers

# Check services
docker compose exec traefik wget -qO- http://localhost:8080/api/http/services
```

## 📞 Getting Help

### Before Asking for Help

1. **Check logs**: `docker compose logs -f`
2. **Run diagnostics**: Use commands from "Quick Diagnostics" section
3. **Search existing issues**: Check GitHub issues and discussions
4. **Try basic fixes**: Restart services, check DNS, verify firewall

### Information to Include

When seeking help, include:

```bash
# System information
uname -a
docker --version
docker compose version

# Service status
docker compose ps

# Recent logs
docker compose logs --tail=100

# Configuration (sanitized)
cat .env | sed 's/=.*/=***HIDDEN***/'

# Network information
docker network ls
docker network inspect web
```

### Support Channels

- 🐛 **GitHub Issues**: [Report bugs and issues](https://github.com/Eugene-WebDev/n8n-production-docker-stack/issues)
- 💬 **Discussions**: [Ask questions and share experiences](https://github.com/Eugene-WebDev/n8n-production-docker-stack/discussions)
- 📧 **Email**: eugene@eugenewebdev.com (for complex issues)

## 📚 Additional Resources

- [n8n Official Documentation](https://docs.n8n.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Documentation](https://docs.docker.com/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

---

**Remember**: Most issues can be resolved by carefully checking logs, verifying configuration, and ensuring all prerequisites are met. Take your time to read error messages - they often contain the solution!
