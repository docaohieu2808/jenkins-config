#!/usr/bin/env bash
# Writes .env for CI. Admin password is random and masked; the K8s values default to harmless
# placeholders (the JCasC job only needs them to parse) unless the caller exports real ones.
set -euo pipefail
pw=$(openssl rand -hex 24)
echo "::add-mask::$pw"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=ci-ca" -keyout /dev/null -out ci-ca.pem 2>/dev/null
{
  echo "JENKINS_ADMIN_USER=admin"
  echo "JENKINS_ADMIN_PASSWORD=$pw"
  echo "K8S_SERVER_URL=${K8S_SERVER_URL:-https://k8s.example.internal:6443}"
  echo "K8S_TOKEN=${K8S_TOKEN:-ci-placeholder-token}"
  echo "K8S_CA_CERT_B64=${K8S_CA_CERT_B64:-$(base64 -w0 ci-ca.pem)}"
  echo "JENKINS_AGENT_URL=${JENKINS_AGENT_URL:-http://192.0.2.10:8080/}"
  echo "JENKINS_TUNNEL=${JENKINS_TUNNEL:-192.0.2.10:50000}"
  echo "SHARED_LIB_REMOTE=file:///var/jenkins_home/fixture-lib"
  echo "JENKINS_PUBLIC_URL=http://localhost:8080/"
} > .env
rm -f ci-ca.pem
