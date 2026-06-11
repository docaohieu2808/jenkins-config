# Jenkins Production Deployment

Production-ready Jenkins CI/CD server với Docker Compose và Traefik integration.

## Architecture

- **Server**: YOUR_SERVER_IP (Server-2 - DevOps Tools)
- **Domain**: jenkins.example.com
- **Port**: 8082 (host) → 8080 (container)
- **Image**: jenkins/jenkins:lts-jdk21

## Prerequisites

1. **Docker & Docker Compose** installed
2. **Traefik network** exists:
   ```bash
   docker network create traefik-network || true
   ```
3. **DNS record** for `jenkins.example.com` pointing to Traefik load balancer

## Quick Start

### 1. Clone và cấu hình

```bash
cd /opt/jenkins-production
cp .env.example .env
# Edit .env if needed
```

### 2. Start Jenkins

```bash
docker compose up -d
```

### 3. Get Initial Admin Password

```bash
# Wait for Jenkins to start (may take 1-2 minutes)
docker compose logs -f jenkins

# Get password
docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 4. Complete Setup Wizard

1. Open: https://jenkins.example.com
2. Enter initial admin password
3. Install suggested plugins (or select specific ones)
4. Create admin user
5. Configure Jenkins URL

## Recommended Plugins

After setup, install these plugins for DevOps workflows:

### Pipeline & Build
- **Pipeline** - Pipeline as code
- **Blue Ocean** - Modern UI for pipelines
- **Pipeline: Stage View** - Visualize pipeline stages

### Source Control
- **Git** - Git integration
- **GitHub** - GitHub integration
- **GitLab** - GitLab integration

### Docker & Container
- **Docker Pipeline** - Build & push Docker images
- **Docker** - Docker support
- **Kubernetes** - K8s integration (optional)

### Credentials & Security
- **Credentials Binding** - Inject credentials
- **SSH Agent** - SSH credentials
- **HashiCorp Vault** - Vault integration (optional)

### Notifications
- **Slack Notification** - Slack alerts
- **Email Extension** - Email notifications

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JENKINS_VERSION` | lts-jdk21 | Jenkins image version |
| `JENKINS_HOST` | jenkins.example.com | Domain for Jenkins |
| `JENKINS_PORT` | 8082 | Host port |
| `JENKINS_AGENT_PORT` | 50000 | JNLP agent port |
| `JAVA_OPTS` | -Xmx2g -Xms512m... | JVM options |
| `TZ` | Asia/Ho_Chi_Minh | Timezone |

## Docker-in-Docker Builds

Jenkins is configured to build Docker images using the host's Docker daemon:

```groovy
// Jenkinsfile example
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                script {
                    docker.build("myapp:${BUILD_NUMBER}")
                }
            }
        }
        stage('Push') {
            steps {
                script {
                    docker.withRegistry('https://registry.example.com', 'harbor-credentials') {
                        docker.image("myapp:${BUILD_NUMBER}").push()
                    }
                }
            }
        }
    }
}
```

## Backup & Restore

### Backup

```bash
# Stop Jenkins
docker compose stop jenkins

# Backup volume
docker run --rm \
  -v jenkins_home:/source:ro \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/jenkins_backup_$(date +%Y%m%d).tar.gz -C /source .

# Start Jenkins
docker compose start jenkins
```

### Restore

```bash
# Stop Jenkins
docker compose stop jenkins

# Restore volume
docker run --rm \
  -v jenkins_home:/target \
  -v $(pwd)/backups:/backup \
  alpine sh -c "rm -rf /target/* && tar xzf /backup/jenkins_backup_YYYYMMDD.tar.gz -C /target"

# Start Jenkins
docker compose start jenkins
```

## Troubleshooting

### Check logs
```bash
docker compose logs -f jenkins
```

### Enter container
```bash
docker compose exec jenkins bash
```

### Restart Jenkins
```bash
docker compose restart jenkins
```

### Reset admin password
```bash
docker compose exec jenkins rm /var/jenkins_home/config.xml
docker compose restart jenkins
# Get new initial password
docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## Security Recommendations

1. **Change admin password** immediately after setup
2. **Enable CSRF protection** (enabled by default)
3. **Configure authorization** - Use Matrix-based security
4. **Limit agent access** - Only allow trusted agents
5. **Regular backups** - Schedule daily backups
6. **Update regularly** - Keep Jenkins and plugins updated
