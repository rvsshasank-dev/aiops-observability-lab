#!/usr/bin/env bash
#
# bootstrap-state.sh — create the GCS state bucket and import it into bootstrap.
#
# Run this once per project, before the first `terraform apply` in
# infra/bootstrap. It is idempotent: an existing bucket is described, not
# recreated, and an already-imported bucket is left alone.
#
# Usage:
#   PROJECT_ID=my-project BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX \
#     ./scripts/setup/bootstrap-state.sh
#
# Requires infra/bootstrap/terraform.tfvars (copy the .example file first).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BOOTSTRAP_DIR="$LAB_ROOT/infra/bootstrap"
TFVARS="$BOOTSTRAP_DIR/terraform.tfvars"

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value core/project 2>/dev/null || true)}"
REGION="${REGION:-us-central1}"
STATE_BUCKET="${STATE_BUCKET:-${PROJECT_ID}-tfstate}"

step() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

command -v gcloud >/dev/null 2>&1 || die "gcloud not found"
command -v terraform >/dev/null 2>&1 || die "terraform not found"
[ -n "$PROJECT_ID" ] || die "PROJECT_ID is empty; set it or configure gcloud"
[ -f "$TFVARS" ] || die "missing $TFVARS — copy terraform.tfvars.example and fill it in"

step "State bucket"
if gcloud storage buckets describe "gs://$STATE_BUCKET" --project "$PROJECT_ID" >/dev/null 2>&1; then
  info "exists: gs://$STATE_BUCKET"
else
  info "creating: gs://$STATE_BUCKET ($REGION)"
  gcloud storage buckets create "gs://$STATE_BUCKET" \
    --project "$PROJECT_ID" \
    --location "$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention
fi

# Terraform owns these settings after import; set them now so the backend is
# safe even before the first apply.
gcloud storage buckets update "gs://$STATE_BUCKET" \
  --project "$PROJECT_ID" \
  --versioning >/dev/null
info "versioning enabled"

step "Backend configuration"
cat > "$BOOTSTRAP_DIR/backend.hcl" <<EOF
bucket = "$STATE_BUCKET"
prefix = "terraform/bootstrap"
EOF
info "wrote infra/bootstrap/backend.hcl"

step "Terraform init"
terraform -chdir="$BOOTSTRAP_DIR" init -input=false -backend-config=backend.hcl

step "Import the pre-created bucket"
if terraform -chdir="$BOOTSTRAP_DIR" state show google_storage_bucket.tfstate >/dev/null 2>&1; then
  info "already tracked in state"
else
  terraform -chdir="$BOOTSTRAP_DIR" import \
    -input=false \
    -var-file="$TFVARS" \
    google_storage_bucket.tfstate "$STATE_BUCKET"
fi

step "Next"
info "terraform -chdir=infra/bootstrap apply -var-file=terraform.tfvars"
