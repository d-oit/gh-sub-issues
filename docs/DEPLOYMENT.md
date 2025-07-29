# Deployment Guide

This guide covers different deployment scenarios for the GitHub Issue Manager, from local development to production automation.

## Table of Contents

- [Local Development Setup](#local-development-setup)
- [CI/CD Integration](#cicd-integration)
- [Production Deployment](#production-deployment)
- [Docker Deployment](#docker-deployment)
- [Security Considerations](#security-considerations)
- [Monitoring and Maintenance](#monitoring-and-maintenance)

## Local Development Setup

### Prerequisites

Ensure your development environment meets the following requirements:

```bash
# Check system requirements
bash --version    # Should be 4.0+
git --version     # Should be 2.0+
curl --version    # For GitHub CLI installation
```

### Installation Steps

1. **Clone and setup:**
   ```bash
   git clone https://github.com/d-oit/gh-sub-issues.git
   cd gh-sub-issues
   
   # Make scripts executable
   chmod +x gh-issue-manager.sh gh-release-manager.sh
   chmod +x tests/*.sh
   ```

2. **Install dependencies:**
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install jq bc curl
   
   # macOS
   brew install jq bc
   
   # Install GitHub CLI
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   sudo apt update
   sudo apt install gh
   ```

3. **Configure authentication:**
   ```bash
   # Authenticate with GitHub
   gh auth login
   
   # Verify authentication
   gh auth status
   ```

4. **Setup environment:**
   ```bash
   # Copy example configuration
   cp .env.example .env
   
   # Edit configuration (optional)
   nano .env
   ```

5. **Verify installation:**
   ```bash
   # Run basic tests
   ./tests/test-unit.sh
   
   # Test scripts
   ./gh-issue-manager.sh --help
   ./gh-release-manager.sh --help
   ```

### Development Workflow

```bash
# Enable debug logging for development
export ENABLE_LOGGING=true
export LOG_LEVEL=DEBUG

# Run tests before making changes
./tests/run-all-tests.sh

# Make your changes...

# Test your changes
./tests/test-unit.sh
./tests/test-enhanced-coverage.sh

# Run integration tests (requires GitHub repo)
./tests/test-gh-issue-manager.sh
```

## CI/CD Integration

### GitHub Actions Setup

The project includes comprehensive GitHub Actions workflows. Here's how to set them up:

1. **Enable workflows:**
   ```bash
   # Workflows are automatically enabled when you push to GitHub
   # Ensure you have the following files:
   ls .github/workflows/
   # Should show: ci.yml, release.yml, issue-automation.yml, etc.
   ```

2. **Configure secrets (if needed):**
   ```bash
   # Usually not needed as workflows use GITHUB_TOKEN
   # Only add custom secrets if you need cross-repo access
   ```

3. **Test workflows:**
   ```bash
   # Push to trigger CI
   git add .
   git commit -m "Test CI workflow"
   git push origin main
   
   # Check Actions tab in GitHub for results
   ```

### Custom CI/CD Integration

For other CI/CD systems, use this template:

```yaml
# Example for GitLab CI
test_scripts:
  stage: test
  image: ubuntu:latest
  before_script:
    - apt-get update
    - apt-get install -y curl jq bc git
    - curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    - apt-get update
    - apt-get install -y gh
  script:
    - chmod +x tests/*.sh gh-*.sh
    - ./tests/run-all-tests.sh
  only:
    - main
    - merge_requests
```

## Production Deployment

### Server Setup

1. **Prepare production server:**
   ```bash
   # Create dedicated user
   sudo useradd -m -s /bin/bash github-manager
   sudo su - github-manager
   
   # Install dependencies
   sudo apt update
   sudo apt install -y jq bc git curl
   
   # Install GitHub CLI
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   sudo apt update
   sudo apt install gh
   ```

2. **Deploy application:**
   ```bash
   # Clone repository
   git clone https://github.com/d-oit/gh-sub-issues.git /opt/github-manager
   cd /opt/github-manager
   
   # Set permissions
   chmod +x gh-issue-manager.sh gh-release-manager.sh
   chown -R github-manager:github-manager /opt/github-manager
   ```

3. **Configure authentication:**
   ```bash
   # Use service account or bot token
   echo "GITHUB_TOKEN=ghp_xxxxxxxxxxxx" > /opt/github-manager/.env
   chmod 600 /opt/github-manager/.env
   ```

4. **Setup logging:**
   ```bash
   # Create log directory
   mkdir -p /var/log/github-manager
   chown github-manager:github-manager /var/log/github-manager
   
   # Configure log rotation
   cat > /etc/logrotate.d/github-manager << EOF
   /var/log/github-manager/*.log {
       daily
       rotate 30
       compress
       delaycompress
       missingok
       notifempty
       create 644 github-manager github-manager
   }
   EOF
   ```

### Systemd Service Setup

Create a systemd service for automated operations:

```bash
# Create service file
sudo cat > /etc/systemd/system/github-manager.service << EOF
[Unit]
Description=GitHub Issue Manager
After=network.target

[Service]
Type=oneshot
User=github-manager
Group=github-manager
WorkingDirectory=/opt/github-manager
Environment=ENABLE_LOGGING=true
Environment=LOG_LEVEL=INFO
Environment=LOG_FILE=/var/log/github-manager/github-manager.log
ExecStart=/opt/github-manager/gh-release-manager.sh --dry-run

[Install]
WantedBy=multi-user.target
EOF

# Create timer for scheduled releases
sudo cat > /etc/systemd/system/github-manager.timer << EOF
[Unit]
Description=Run GitHub Manager weekly
Requires=github-manager.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable github-manager.timer
sudo systemctl start github-manager.timer
```

## Docker Deployment

### Dockerfile

Create a containerized deployment:

```dockerfile
# Dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    bc \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh

# Create app user
RUN useradd -m -s /bin/bash github-manager

# Copy application
COPY --chown=github-manager:github-manager . /app
WORKDIR /app

# Make scripts executable
RUN chmod +x gh-issue-manager.sh gh-release-manager.sh

# Switch to app user
USER github-manager

# Set environment
ENV ENABLE_LOGGING=true
ENV LOG_LEVEL=INFO
ENV LOG_FILE=/app/logs/github-manager.log

# Default command
CMD ["./gh-issue-manager.sh", "--help"]
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  github-manager:
    build: .
    environment:
      - ENABLE_LOGGING=true
      - LOG_LEVEL=INFO
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - PROJECT_URL=${PROJECT_URL}
    volumes:
      - ./logs:/app/logs
      - ./config:/app/config
    restart: unless-stopped

  # Optional: Add monitoring
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
```

### Kubernetes Deployment

```yaml
# k8s-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      app: github-manager
  template:
    metadata:
      labels:
        app: github-manager
    spec:
      containers:
      - name: github-manager
        image: github-manager:latest
        env:
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: github-secrets
              key: token
        - name: ENABLE_LOGGING
          value: "true"
        - name: LOG_LEVEL
          value: "INFO"
        volumeMounts:
        - name: logs
          mountPath: /app/logs
      volumes:
      - name: logs
        persistentVolumeClaim:
          claimName: github-manager-logs

---
apiVersion: v1
kind: Secret
metadata:
  name: github-secrets
type: Opaque
data:
  token: <base64-encoded-github-token>

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: github-manager-logs
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

## Security Considerations

### Token Management

1. **Use dedicated service accounts:**
   ```bash
   # Create GitHub App or use machine user
   # Limit token scope to minimum required permissions
   ```

2. **Secure token storage:**
   ```bash
   # Use environment variables, not files
   export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
   
   # Or use secure secret management
   # - Kubernetes secrets
   # - HashiCorp Vault
   # - AWS Secrets Manager
   ```

3. **Token rotation:**
   ```bash
   # Implement regular token rotation
   # Monitor token usage and expiration
   ```

### Network Security

1. **Firewall configuration:**
   ```bash
   # Allow only necessary outbound connections
   sudo ufw allow out 443/tcp  # HTTPS to GitHub
   sudo ufw allow out 80/tcp   # HTTP redirects
   ```

2. **TLS verification:**
   ```bash
   # Ensure GitHub CLI verifies TLS certificates
   gh config set git_protocol https
   ```

### File Permissions

```bash
# Secure file permissions
chmod 700 /opt/github-manager
chmod 600 /opt/github-manager/.env
chmod 644 /opt/github-manager/*.sh
chmod 600 /var/log/github-manager/*.log
```

## Monitoring and Maintenance

### Health Checks

Create health check scripts:

```bash
#!/bin/bash
# health-check.sh

# Check dependencies
command -v gh >/dev/null || exit 1
command -v jq >/dev/null || exit 1
command -v bc >/dev/null || exit 1

# Check GitHub authentication
gh auth status >/dev/null 2>&1 || exit 1

# Check disk space
df /var/log | awk 'NR==2 {if($5+0 > 90) exit 1}'

echo "Health check passed"
```

### Monitoring Setup

1. **Log monitoring:**
   ```bash
   # Monitor error rates
   tail -f /var/log/github-manager/github-manager.log | grep ERROR
   
   # Set up log aggregation (ELK, Splunk, etc.)
   ```

2. **Metrics collection:**
   ```bash
   # Track script execution metrics
   # - Success/failure rates
   # - Execution times
   # - API response times
   ```

3. **Alerting:**
   ```bash
   # Set up alerts for:
   # - Script failures
   # - Authentication issues
   # - API rate limit warnings
   # - Disk space issues
   ```

### Backup and Recovery

1. **Configuration backup:**
   ```bash
   # Backup configuration
   tar -czf github-manager-config-$(date +%Y%m%d).tar.gz \
     /opt/github-manager/.env \
     /opt/github-manager/config/
   ```

2. **Log backup:**
   ```bash
   # Archive old logs
   find /var/log/github-manager -name "*.log" -mtime +30 -exec gzip {} \;
   ```

3. **Recovery procedures:**
   ```bash
   # Document recovery steps
   # - Restore from backup
   # - Reconfigure authentication
   # - Verify functionality
   ```

### Performance Optimization

1. **Script optimization:**
   ```bash
   # Profile script execution
   time ./gh-issue-manager.sh "test" "test" "test" "test"
   
   # Monitor API usage
   gh api rate_limit
   ```

2. **Resource monitoring:**
   ```bash
   # Monitor system resources
   htop
   iotop
   nethogs
   ```

3. **Scaling considerations:**
   ```bash
   # For high-volume usage:
   # - Implement request queuing
   # - Add rate limiting
   # - Consider parallel processing
   ```

## Troubleshooting

### Common Deployment Issues

1. **Permission denied errors:**
   ```bash
   # Fix script permissions
   chmod +x gh-issue-manager.sh gh-release-manager.sh
   
   # Fix file ownership
   chown -R github-manager:github-manager /opt/github-manager
   ```

2. **Authentication failures:**
   ```bash
   # Re-authenticate GitHub CLI
   gh auth login --hostname github.com
   
   # Verify token permissions
   gh auth status
   ```

3. **Network connectivity:**
   ```bash
   # Test GitHub connectivity
   curl -I https://api.github.com
   
   # Test GitHub CLI
   gh api user
   ```

4. **Missing dependencies:**
   ```bash
   # Verify all dependencies
   ./tests/test-unit.sh
   
   # Install missing packages
   sudo apt install jq bc curl git
   ```

### Log Analysis

```bash
# Common log analysis commands
grep ERROR /var/log/github-manager/github-manager.log
grep "API rate limit" /var/log/github-manager/github-manager.log
awk '/WARN|ERROR/ {print $0}' /var/log/github-manager/github-manager.log

# Performance analysis
grep "Execution time" /var/log/github-manager/github-manager.log | \
  awk '{print $NF}' | sort -n
```

### Support and Maintenance

1. **Regular maintenance tasks:**
   - Update dependencies monthly
   - Rotate logs weekly
   - Review and update authentication tokens
   - Monitor GitHub API changes

2. **Update procedures:**
   ```bash
   # Update to latest version
   cd /opt/github-manager
   git pull origin main
   ./tests/run-all-tests.sh
   ```

3. **Emergency procedures:**
   - Document rollback procedures
   - Maintain emergency contact information
   - Keep backup authentication methods