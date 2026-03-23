# Jenkins Config — JCasC + K8s Ephemeral Agents

Production Jenkins server managed entirely as code. Rebuild the entire server from `casc.yaml` — zero manual clicking.

## Architecture

```
Internet → Traefik (HTTPS) → Jenkins Controller (Docker, port 8082)
                                      ↓
                             JCasC (casc.yaml) — loads on startup
                                      ↓
                             K3s Cloud → Ephemeral K8s Agents
                             (node / java / python / go / docker)
```

- **Domain**: `jenkins.example.com`
- **Image**: `jenkins/jenkins:lts-jdk21`
- **Host port**: `8082` → container `8080`
- **JNLP agent port**: `50000`
- **Docker access**: via `tecnativa/docker-socket-proxy` (no raw socket exposure)

---

## Levels

| Level | What you get |
|-------|-------------|
| **L1** | Run Jenkins locally with `docker compose up -d`. Manual setup wizard. |
| **L2** | Configure JCasC (`casc.yaml`). Server rebuilds to exact state on restart. |
| **L3** | Add K8s cloud in JCasC. Builds run as ephemeral pods — no persistent agents. |
| **L4** | Add shared library in JCasC. Projects use `autoPipeline()` with zero config. |
| **MAX** | Full IaC: JCasC + docker-compose + kubeconfig versioned in git. Any server rebuild = `git clone && docker compose up`. |

---

## Prerequisites

- Docker + Docker Compose v2
- Traefik running with `traefik-network` external network
- K3s cluster accessible (for ephemeral agents)
- DNS record for `jenkins.example.com` pointing to Traefik

---

## Installation

### 1. Create external network (once)

```bash
docker network create traefik-network
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env — set GITLAB_PASSWORD and JENKINS_ADMIN_PASSWORD at minimum
```

Required env vars:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JENKINS_ADMIN_PASSWORD` | yes | — | Admin user password |
| `GITLAB_PASSWORD` | yes | — | GitLab credential for shared library |
| `JENKINS_VERSION` | no | `lts-jdk21` | Jenkins image tag |
| `JENKINS_HOST` | no | `jenkins.example.com` | Domain name |
| `JENKINS_PORT` | no | `8082` | Host port |
| `JENKINS_AGENT_PORT` | no | `50000` | JNLP agent port |
| `JAVA_OPTS` | no | `-Xmx2g -Xms512m ...` | JVM options |
| `TZ` | no | `Asia/Ho_Chi_Minh` | Timezone |

### 3. Place kubeconfig

```bash
# Copy your K3s kubeconfig — used by Jenkins to spawn K8s agents
cp ~/.kube/k3s-config.yaml ./k3s-kubeconfig.yaml
```

### 4. Start

```bash
docker compose up -d
docker compose logs -f jenkins   # wait for "Jenkins is fully up and running"
```

### 5. First-time setup (only if JCasC does NOT pre-configure admin)

```bash
# Get initial admin password
docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Open `https://jenkins.example.com`, enter password, install suggested plugins.

> After plugins are installed, JCasC applies automatically on next restart:
> `docker compose restart jenkins`

---

## Quick Start — Rebuild from scratch

```bash
git clone <this-repo> /opt/jenkins
cd /opt/jenkins
cp .env.example .env && vim .env          # set passwords
cp ~/.kube/k3s-config.yaml k3s-kubeconfig.yaml
docker compose up -d
```

Jenkins comes up with:
- Admin user pre-configured
- K3s cloud with 5 agent templates (node, java, python, go, docker)
- Shared library `auto-pipeline` registered
- GitLab credentials loaded

---

## JCasC Reference (`casc.yaml`)

Key sections:

```yaml
jenkins:
  numExecutors: 2          # local executors (builds run on K8s agents normally)
  clouds:
    - kubernetes:
        name: k3s
        serverUrl: https://rancher.example.com/k8s/clusters/local
        namespace: jenkins
        containerCap: 10   # max concurrent K8s builds
        templates:
          - name: node      # label: "node"
          - name: java      # label: "java maven"
          - name: python    # label: "python"
          - name: go        # label: "go golang"
          - name: docker    # label: "docker" — privileged, for image builds

credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              id: gitlab-creds
              username: hieudc
              password: ${GITLAB_PASSWORD}   # from .env

unclassified:
  globalLibraries:
    libraries:
      - name: auto-pipeline
        defaultVersion: master
        retriever:
          modernSCM:
            scm:
              gitSource:
                remote: https://git.example.com/cicd-auto-pipeline/jenkins-shared-library.git
                credentialsId: gitlab-creds
```

---

## K8s Agent Labels

Use these labels in `agent { label '...' }` in your Jenkinsfile:

| Label | Image | Use for |
|-------|-------|---------|
| `node` | `node:20-slim` | Node.js builds |
| `java` or `maven` | `maven:3.9-eclipse-temurin-21` | Java/Maven builds |
| `python` | `python:3.12-slim` | Python builds |
| `go` or `golang` | `golang:1.23` | Go builds |
| `docker` | `docker:dind` (privileged) | Docker image builds |

---

## Backup & Restore

```bash
# Backup
docker compose stop jenkins
docker run --rm \
  -v jenkins_home:/source:ro \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/jenkins_backup_$(date +%Y%m%d).tar.gz -C /source .
docker compose start jenkins

# Restore
docker compose stop jenkins
docker run --rm \
  -v jenkins_home:/target \
  -v $(pwd)/backups:/backup \
  alpine sh -c "rm -rf /target/* && tar xzf /backup/jenkins_backup_YYYYMMDD.tar.gz -C /target"
docker compose start jenkins
```

---

## Troubleshooting

```bash
# View logs
docker compose logs -f jenkins

# Shell into container
docker compose exec jenkins bash

# Force JCasC reload (without restart)
# Go to: Manage Jenkins → Configuration as Code → Reload existing configuration

# Reset admin password
docker compose exec jenkins rm /var/jenkins_home/config.xml
docker compose restart jenkins
docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Check K8s agent connectivity
# Manage Jenkins → Clouds → k3s → Test Connection
```

---

## Repository Structure

```
jenkins/
├── casc.yaml                  # Full Jenkins config as code
├── docker-compose.yml         # Jenkins + socket proxy
├── k3s-kubeconfig.yaml        # K3s cluster access (not committed)
└── .env                       # Secrets (not committed)
```
