# Phase 1 — GKE foundation

Apply, verify and destroy the Terraform foundation. This runbook assumes the
single WSL2 environment described in `README.md`.

## Prerequisites

- `gcloud`, `terraform` (>= 1.6), `kubectl` on `PATH`
- `gcloud auth login` for the owner account
- A project with billing enabled and a billing account ID
- Application Default Credentials with a quota project, or the Billing Budget
  API rejects Terraform with a 403:

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project "$PROJECT_ID"
```

## 1. Bootstrap state, APIs and budget

```bash
cd ~/repos/aiops-observability-lab

cp infra/bootstrap/terraform.tfvars.example infra/bootstrap/terraform.tfvars
$EDITOR infra/bootstrap/terraform.tfvars   # project_id, billing_account

./scripts/setup/bootstrap-state.sh
terraform -chdir=infra/bootstrap apply -var-file=terraform.tfvars
```

`bootstrap-state.sh` is idempotent. It creates
`gs://<project-id>-tfstate` if missing, enables versioning, writes
`infra/bootstrap/backend.hcl`, initialises the GCS backend and imports the
bucket. Bootstrap then manages the bucket, the APIs and the monthly budget.

## 2. Network, storage, IAM and GKE

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
$EDITOR infra/terraform.tfvars             # at least project_id
cp infra/backend.hcl.example infra/backend.hcl
$EDITOR infra/backend.hcl                  # bucket = <project-id>-tfstate

terraform -chdir=infra init -backend-config=backend.hcl
terraform -chdir=infra plan -var-file=terraform.tfvars -out=phase1.tfplan
terraform -chdir=infra apply phase1.tfplan
```

## 3. Namespaces

```bash
gcloud container clusters get-credentials aiops-lab \
  --zone us-central1-a --project "$PROJECT_ID"

kubectl apply -k platform/
kubectl get namespaces --show-labels
```

Phase 1 creates the four namespaces and Pod Security Admission labels.
`LimitRange` and `ResourceQuota` wait for the first measured deployment, per
`platform/README.md`.

## 4. Verify

```bash
# Idempotence: exit code 0 means no diff, 2 means drift.
terraform -chdir=infra plan -var-file=terraform.tfvars -detailed-exitcode
terraform -chdir=infra/bootstrap plan -var-file=terraform.tfvars -detailed-exitcode

# Capacity and system overhead.
kubectl get node -o custom-columns='NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory,PODS:.status.allocatable.pods'
kubectl top node
kubectl top pods -A --sum

# Workload Identity boundary.
PROJECT_ID=winterarc1-510922 ZONE=us-central1-a CLUSTER=aiops-lab \
GSA_EMAIL=aiops-lab-wif-smoke@winterarc1-510922.iam.gserviceaccount.com \
SMOKE_BUCKET=winterarc1-510922-wif-smoke \
DENIED_BUCKET=winterarc1-510922-tempo \
  ./tests/contracts/verify-wif.sh
```

The WIF test must print `PASS` and deny the Tempo bucket. The smoke-test GSA has
`roles/storage.objectViewer` on one bucket only.

The measured Phase 1 idle footprint is recorded in
`docs/experiments/phase-1-capacity-baseline.md` (~120m CPU and ~1.1 GiB on one
`e2-standard-2`, leaving ~1.8 cores and ~4.8 GiB for workloads). Re-measure
after any node size or system add-on change rather than reusing those numbers.

The control-plane endpoint is public and, by default, not CIDR-restricted. For a
fixed workstation address, set `master_authorized_networks` in
`infra/terraform.tfvars` before applying.

## 5. Destroy

Destroy the main root first; it removes the cluster, network, buckets and
project-owned service accounts. Bootstrap (state bucket, APIs, budget) stays.

```bash
terraform -chdir=infra destroy -var-file=terraform.tfvars
```

The state bucket has `force_destroy = false` and holds the bootstrap state, so
destroying bootstrap is a decommissioning step, not a routine cleanup:

```bash
# Only when retiring the lab. Delete the state object, then the bucket.
gcloud storage rm --recursive "gs://${PROJECT_ID}-tfstate"
terraform -chdir=infra/bootstrap destroy -var-file=terraform.tfvars
```

## Cost note

The budget is an alert threshold, not a hard cap. With the defaults used here
(one `e2-standard-2` node, 50 GB `pd-balanced`, Cloud NAT, one zonal GKE
cluster) the run rate is roughly **$80–90 USD/month** if left running. The $25
budget will alert quickly. Destroy the main root when the session ends; the
bootstrap state bucket and budget cost effectively nothing.

The zonal cluster is also a billing choice: one zonal GKE Standard cluster per
billing account is not charged a control-plane fee.
