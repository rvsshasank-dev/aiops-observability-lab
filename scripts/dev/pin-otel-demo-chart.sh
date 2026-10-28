#!/usr/bin/env bash
# Resolve the OTel Demo chart version and record it in CHART.lock.
# Feature-flag names drift between releases; re-verify INC-* triggers after any bump.
set -euo pipefail

REPO_NAME="open-telemetry"
REPO_URL="https://open-telemetry.github.io/opentelemetry-demo"
LOCK="$(cd "$(dirname "$0")/../.." && pwd)/apps/otel-demo/CHART.lock"
WANT="${1:-}"

helm repo add "$REPO_NAME" "$REPO_URL" >/dev/null 2>&1 || true
helm repo update "$REPO_NAME" >/dev/null

if [ -z "$WANT" ]; then
  WANT=$(helm search repo "$REPO_NAME/opentelemetry-demo" --versions -o json \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["version"])')
fi

APP=$(helm search repo "$REPO_NAME/opentelemetry-demo" --version "$WANT" -o json \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["app_version"])')

echo "resolved chart $WANT (app $APP)"
echo
echo "Update $LOCK with:"
echo "  version: $WANT"
echo "  appVersion: $APP"
echo "  pinned_on: $(date -u +%Y-%m-%d)"
echo
echo "Then: helm template lab $REPO_NAME/opentelemetry-demo --version $WANT -f apps/otel-demo/values/lab.yaml | head -40"
