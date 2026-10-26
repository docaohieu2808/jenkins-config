#!/usr/bin/env bash
# Create a Pipeline job from a Jenkinsfile, run it on a live Jenkins and assert its result.
#   run-pipeline.sh <jenkins-url> <job-name> <pipeline-file> <SUCCESS|FAILURE>
# Credentials come from JENKINS_USER_ID and JENKINS_API_TOKEN (the admin password works as token).
set -euo pipefail
url=${1:?jenkins url}; name=${2:?job name}; file=${3:?pipeline file}; expected=${4:?expected result}
cli=${CLI_JAR:-jenkins-cli.jar}
[ -f "$cli" ] || curl -fsSL -o "$cli" "$url/jnlpJars/jenkins-cli.jar"

xml=$(mktemp)
python3 - "$file" > "$xml" <<'PY'
import sys, xml.sax.saxutils as x
script = open(sys.argv[1]).read()
print('<flow-definition><definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition">'
      f'<script>{x.escape(script)}</script><sandbox>true</sandbox></definition></flow-definition>')
PY
java -jar "$cli" -s "$url" create-job "$name" < "$xml"
rm -f "$xml"

# `build -s` waits for the end; its exit code mirrors the result, which we check explicitly below.
java -jar "$cli" -s "$url" build "$name" -s -v || true

result=$(curl -fsS -u "$JENKINS_USER_ID:$JENKINS_API_TOKEN" "$url/job/$name/lastBuild/api/json?tree=result" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"])')
echo "job $name finished: $result (expected $expected)"
[ "$result" = "$expected" ]
