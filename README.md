# jenkins-config

[![ci](https://github.com/docaohieu2808/jenkins-config/actions/workflows/ci.yml/badge.svg)](https://github.com/docaohieu2808/jenkins-config/actions/workflows/ci.yml)

Jenkins as code (ladder level L4). The controller is an image built from this repo: a pinned LTS core,
pinned plugins, and a Configuration as Code (JCasC) file that sets up the admin user, credentials, mail,
a shared library and a Kubernetes cloud with five ephemeral agent templates. No setup wizard, no clicking:
`git clone && docker compose up --build` gives the same server every time.

The shared library it registers lives in [jenkins-shared-library](https://github.com/docaohieu2808/jenkins-shared-library)
(level L6 of the Jenkins track).

## Level map

| Level | What it adds | Files | Proven in CI by |
| :-- | :-- | :-- | :-- |
| L1 | Reproducible controller: pinned core, plugins installed with `jenkins-plugin-cli`, wizard disabled | `Dockerfile`, `plugins.txt` | image builds, Jenkins becomes healthy |
| L2 | JCasC: admin user from env, credentials, mail, global library | `casc.yaml` | no config errors in the log, `verify-jcasc.groovy` checks the live state, admin login works, anonymous gets 403 |
| L3 | Kubernetes cloud: every build runs in a short-lived pod (node, java/maven, python, go, docker) | `casc.yaml`, `k8s/jenkins-agent-rbac.yaml` | a kind cluster: build runs on an ephemeral pod in the `python` tool container |
| L4 | Whole server as code: compose file, optional Traefik overlay, `.env` for every secret | `docker-compose.yml`, `docker-compose.traefik.yml`, `.env.example` | the compose file is what CI starts |

## Versions (checked 2026-10-26)

| Component | Version | Source |
| :-- | :-- | :-- |
| Jenkins core | `2.580.1-lts-jdk21` (current LTS line) | updates.jenkins.io, Docker Hub |
| Plugins | pinned in `plugins.txt` for core 2.580.1 | Jenkins update center |
| Inbound agent | `jenkins/inbound-agent:3391.va_37fa_a_305d6d-6-jdk21` | Docker Hub |
| Tool images | `node:24-slim`, `maven:3.9-eclipse-temurin-21`, `python:3.14-slim`, `golang:1.26`, `docker:29-dind` | Docker Hub, endoflife.date |

Changes from the first version of this repo: the setup wizard and the "install suggested plugins" manual step are
gone (they could never install `configuration-as-code` or `kubernetes`); Node 20 and Go 1.23 (end of life) were
replaced; `:latest` agent images are pinned; the controller no longer runs as root and no longer mounts the host
Docker CLI or a Docker socket proxy (builds run on pods, so it was dead weight and a root-equivalent hole).

## Run it

Needs Docker with Compose v2 and a Kubernetes cluster the controller can reach.

```bash
# 1. In the cluster: namespace, service account, minimum rights, and a token for it
kubectl apply -f k8s/jenkins-agent-rbac.yaml
kubectl -n jenkins create token jenkins --duration=8760h

# 2. Fill in .env (admin password, K8S_SERVER_URL, K8S_TOKEN, K8S_CA_CERT_B64, agent URL and tunnel)
cp .env.example .env && $EDITOR .env
#    base64 -w0 of the cluster CA: kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'

# 3. Build and start (waits for the health check)
docker compose up -d --build --wait
```

Open `http://localhost:8080` and log in as `JENKINS_ADMIN_USER`. Behind Traefik instead:
`JENKINS_HOST=jenkins.example.com docker compose -f docker-compose.yml -f docker-compose.traefik.yml up -d --build --wait`.

Both published ports bind to `JENKINS_BIND_IP` (default `127.0.0.1`). The agent port 50000 must be reachable
from the pods, so on a real setup set `JENKINS_BIND_IP` to an address the cluster can reach (for example a VPN
address) and make `JENKINS_AGENT_URL` and `JENKINS_TUNNEL` point at it.

### Secrets

Everything sensitive is an environment variable in `.env` (git-ignored): the admin password, the Kubernetes token
and CA, the Git password for the shared library, the SMTP password. JCasC reads them as `${NAME}`; nothing is
stored in `casc.yaml`. JCasC also reads Docker secrets from `/run/secrets/<NAME>` if you prefer files.

### Agent labels

Use these in `agent { label '...' }`:

| Label | Tool image | Use for |
| :-- | :-- | :-- |
| `node` | `node:24-slim` | Node.js |
| `java`, `maven` | `maven:3.9-eclipse-temurin-21` | Java/Maven |
| `python` | `python:3.14-slim` | Python |
| `go`, `golang` | `golang:1.26` | Go |
| `docker` | `docker:29-dind` (privileged) | image builds; run it only on a cluster you control |

In scripted pipelines the build steps run in the `jnlp` container; wrap them in `container('python') { ... }`
(the container name equals the tool name) to run inside the tool image.

### Update, back up, restore

- Update Jenkins: change the tag in `Dockerfile`, bump `plugins.txt` (Dependabot proposes the Dockerfile tag; the
  plugin pins are bumped by hand and CI tells you if they no longer fit the core), `docker compose up -d --build`.
- Backup: `docker compose stop jenkins`, tar the `jenkins_home` volume, `docker compose start jenkins`. Configuration is
  in git; the volume holds job history and build records.

## What CI checks

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on push, pull request, every Monday and on demand:

- `lint`: yamllint, hadolint, actionlint, shellcheck, `docker compose config` (plain and with the Traefik overlay),
  kubeconform `-strict` on the RBAC manifest.
- `jcasc`: builds the image with `docker compose`, waits for the health check, fails on any `ConfiguratorException`
  or `SEVERE` line, checks the admin login (random password from the environment) and that anonymous access is refused,
  runs [`ci/verify-jcasc.groovy`](ci/verify-jcasc.groovy) against the live controller (cloud, five templates, no
  `:latest` image, TLS verification on, credentials, library, mail), then loads the registered `auto-pipeline`
  library from a fixture Git repo and runs a pipeline that calls a step from it.
- `k8s-agent`: starts a kind cluster, applies the RBAC manifest, mints a token, starts the same controller on the
  kind network and runs a pipeline on the `python` template: a real pod is created, the inbound agent connects back,
  and `python --version` runs inside the tool container.

Actions are pinned to full commit SHAs; Dependabot covers the actions and the Dockerfile base image.

## Honest limits

- The Kubernetes cloud is verified against kind, not against the production k3s/Rancher setup. Point
  `K8S_SERVER_URL` at the cluster API (a Rancher proxy URL works too) and keep `skipTlsVerify: false`.
- Plugin versions are pinned in `plugins.txt`, and Dependabot does not read that file; update them yourself.
- `authorizationStrategy` is "logged-in users can do anything", fine for one admin. Add the matrix-auth or
  role-strategy plugin before adding a second person.
- The `docker` template is a privileged dind container; the CI run does not start it.
- The mail settings are applied and checked, but no mail is sent in CI.
