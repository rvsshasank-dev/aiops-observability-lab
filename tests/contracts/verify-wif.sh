#!/usr/bin/env bash
#
# verify-wif.sh — prove that a Kubernetes ServiceAccount can reach exactly one
# GCS bucket through Workload Identity Federation, and is denied another.
#
# Usage:
#   PROJECT_ID=my-project ZONE=us-central1-a CLUSTER=aiops-lab \
#   GSA_EMAIL=aiops-lab-wif-smoke@my-project.iam.gserviceaccount.com \
#   SMOKE_BUCKET=my-project-wif-smoke DENIED_BUCKET=my-project-tempo \
#     ./tests/contracts/verify-wif.sh
#
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
ZONE="${ZONE:?set ZONE}"
CLUSTER="${CLUSTER:?set CLUSTER}"
GSA_EMAIL="${GSA_EMAIL:?set GSA_EMAIL}"
SMOKE_BUCKET="${SMOKE_BUCKET:?set SMOKE_BUCKET}"
DENIED_BUCKET="${DENIED_BUCKET:?set DENIED_BUCKET}"

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found" >&2; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo "gcloud not found" >&2; exit 1; }

gcloud container clusters get-credentials "$CLUSTER" \
  --zone "$ZONE" --project "$PROJECT_ID" >/dev/null

kubectl -n default delete job wif-smoke-test --ignore-not-found >/dev/null
kubectl -n default delete serviceaccount wif-smoke-test --ignore-not-found >/dev/null

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: wif-smoke-test
  namespace: default
  annotations:
    iam.gke.io/gcp-service-account: ${GSA_EMAIL}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: wif-smoke-test
  namespace: default
spec:
  backoffLimit: 0
  template:
    spec:
      serviceAccountName: wif-smoke-test
      restartPolicy: Never
      containers:
        - name: gcloud
          image: google/cloud-sdk:slim
          imagePullPolicy: IfNotPresent
          command: ["/bin/bash", "-lc"]
          args:
            - |
              set -euo pipefail
              echo "permitted bucket: gs://${SMOKE_BUCKET}"
              gcloud storage ls "gs://${SMOKE_BUCKET}" >/dev/null
              echo "denied bucket:    gs://${DENIED_BUCKET}"
              if gcloud storage ls "gs://${DENIED_BUCKET}" >/dev/null 2>&1; then
                echo "FAIL: WIF identity can read the telemetry bucket"
                exit 1
              fi
              echo "PASS: WIF identity reached only the permitted bucket"
EOF

if ! kubectl -n default wait --for=condition=complete job/wif-smoke-test --timeout=300s; then
  kubectl -n default describe job wif-smoke-test || true
  kubectl -n default logs job/wif-smoke-test || true
  exit 1
fi

kubectl -n default logs job/wif-smoke-test

echo
echo "cleanup: kubectl -n default delete job/wif-smoke-test serviceaccount/wif-smoke-test"
