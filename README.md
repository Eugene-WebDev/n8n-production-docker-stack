# 🚀 n8n-production-docker-stack

Production-ready n8n deployment with Traefik reverse proxy, automatic SSL certificates, and Docker Compose.

## 📋 Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

## ✨ Features

- **🔒 Automatic SSL** - Let's Encrypt certificates via Traefik
- **🔄 Reverse Proxy** - Traefik with Docker provider
- **📦 Docker Compose** - Single-command deployment
- **🛡️ Security Hardened** - Proper user permissions and network isolation
- **🔧 Production Ready** - Optimized for VPS deployment
- **📈 Future Proof** - n8n runners and latest features enabled
- **🌍 Multi-timezone** - Configurable timezone support

## 🔧 Prerequisites

- Ubuntu 20.04+ VPS
- Domain name with DNS pointing to your server
- SSH access to your server
- Basic Docker knowledge

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/Eugene-WebDev/n8n-production-docker-stack.git
cd n8n-production-docker-stack
```

### 2. Run Setup Script
```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### 3. Configure Environment
```bash
cp .env.example .env
nano .env  # Edit with your domain and settings
```

### 4. Deploy
```bash
docker compose up -d
```

Your n8n instance will be available at `https://yourdomain.com` with automatic SSL!

## 📁 Repository Structure

```
n8n-production-docker-stack/
├── README.md
├── docker-compose.yml           # Main compose file
├── .env.example                # Environment template
├── .gitignore                  # Git ignore rules
├── scripts/
│   ├── setup.sh               # Automated setup script
│   ├── backup.sh              # Backup workflows and data
│   ├── restore.sh             # Restore from backup
│   └── update.sh              # Update containers
├── config/
│   └── traefik/
│       └── traefik.yml        # Traefik static config
├── docs/
│   ├── installation.md       # Detailed installation guide
│   ├── configuration.md      # Configuration options
│   ├── troubleshooting.md    # Common issues and fixes
│   ├── backup-restore.md     # Backup procedures
│   └── security.md           # Security recommendations
├── examples/
│   ├── nginx-alternative.yml  # Alternative with nginx
│   └── monitoring.yml         # Optional monitoring stack
└── LICENSE
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `N8N_HOST` | Your domain name | `n8n.example.com` |
| `N8N_PORT` | Internal n8n port | `5678` |
| `N8N_PROTOCOL` | Protocol (https/http) | `https` |
| `WEBHOOK_URL` | Webhook base URL | `https://n8n.example.com/` |
| `GENERIC_TIMEZONE` | Server timezone | `Europe/Warsaw` |
| `N8N_ENCRYPTION_KEY` | Encryption key (generate random) | Required |
| `ACME_EMAIL` | Email for Let's Encrypt | Required |

### Security Settings

- ✅ User isolation with dedicated `n8n` user
- ✅ Docker socket protection
- ✅ Network segregation
- ✅ SSL/TLS encryption
- ✅ Environment variable protection

## 🔄 Maintenance

### Update Containers
```bash
./scripts/update.sh
```

### Backup Data
```bash
./scripts/backup.sh
```

### View Logs
```bash
docker compose logs -f n8n
docker compose logs -f traefik
```

### Restart Services
```bash
docker compose restart
```

## 🛠️ Troubleshooting

### Common Issues

1. **SSL Certificate Issues**
   - Check domain DNS pointing to server
   - Verify email in ACME configuration
   - Check Traefik logs: `docker compose logs traefik`

2. **Permission Errors**
   - Ensure user is in docker group
   - Check file permissions in n8n_data folder

3. **Proxy Errors**
   - Verify N8N_TRUST_PROXY=true
   - Check network configuration

See [docs/troubleshooting.md](docs/troubleshooting.md) for detailed solutions.

## 🔐 Security

- Use strong encryption keys
- Regular backups
- Monitor access logs
- Keep containers updated
- Use firewall rules

See [docs/security.md](docs/security.md) for security hardening guide.

## 📚 Documentation

- [📖 Installation Guide](docs/installation.md) - Step-by-step setup
- [⚙️ Configuration](docs/configuration.md) - All configuration options
- [🔧 Troubleshooting](docs/troubleshooting.md) - Common issues and fixes
- [💾 Backup & Restore](docs/backup-restore.md) - Data management
- [🛡️ Security](docs/security.md) - Security best practices

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Support

- 📧 Email: eugene@eugenewebdev.com
- 🐛 Issues: [GitHub Issues](https://github.com/Eugene-WebDev/n8n-production-docker-stack/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/Eugene-WebDev/n8n-production-docker-stack/discussions)

## ⭐ Acknowledgments

- n8n team for the amazing automation platform
- Traefik team for the excellent reverse proxy
- Docker team for containerization technology

---

**Made with ❤️ by [Eugene-WebDev](https://github.com/Eugene-WebDev)**

*If this helped you, please consider giving it a ⭐!*
