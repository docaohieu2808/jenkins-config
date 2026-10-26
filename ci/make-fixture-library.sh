#!/usr/bin/env bash
# Creates a one-step shared library as a git repo inside the running controller, the way a real
# library lives in Git, so the `auto-pipeline` library registered by JCasC can be loaded.
set -euo pipefail
docker exec jenkins bash -ec '
  mkdir -p /var/jenkins_home/fixture-lib/vars && cd /var/jenkins_home/fixture-lib
  printf "def call(String who) {\n    echo \"hello from the shared library, \${who}\"\n}\n" > vars/greet.groovy
  git init -q -b master
  git -c user.name=ci -c user.email=ci@example.com add -A
  git -c user.name=ci -c user.email=ci@example.com commit -q -m fixture
'
