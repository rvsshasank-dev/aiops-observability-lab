# infra/

Terraform only. Everything here is cloud infrastructure; nothing here is a
Kubernetes workload.

## Layout

```
infra/
  bootstrap/          root: APIs, GCS state bucket, monthly budget
  modules/network/    VPC, subnet, secondary ranges, Cloud NAT
  modules/storage/    GCS buckets for Tempo, Loki and the WIF smoke test
  modules/iam/        service accounts, bucket IAM, Workload Identity bindings
  modules/gke/        zonal GKE Standard cluster and managed node pool
  main.tf             root: composes the four modules
```

`bootstrap/` and the main root have separate state files in the same GCS
bucket:

| Root | GCS prefix |
|---|---|
| `infra/bootstrap` | `terraform/bootstrap` |
| `infra` | `terraform/lab` |

The state bucket is `gs://<project-id>-tfstate`. `scripts/setup/bootstrap-state.sh`
creates it with versioning and public access prevention, then imports it into
the bootstrap root. The bootstrap root is therefore on GCS from its first
apply, not just after a migration.

## Apply order

1. Copy the example variable files and fill in the project, billing account and
   project ID.
2. `./scripts/setup/bootstrap-state.sh`
3. `terraform -chdir=infra/bootstrap apply -var-file=terraform.tfvars`
4. Create `infra/backend.hcl` from `backend.hcl.example`, then
   `terraform -chdir=infra init -backend-config=backend.hcl`
5. `terraform -chdir=infra apply -var-file=terraform.tfvars`

The full sequence, verification commands and destroy procedure are in
`docs/runbooks/phase-1-foundation.md`.

## Rules

- Remote state in GCS from the first apply. `terraform.tfvars` and
  `backend.hcl` stay out of git; commit the `*.example` files.
- No service-account keys anywhere — Workload Identity Federation only.
- A second apply must be a no-op. CI or a session should prove this with
  `terraform plan -detailed-exitcode`.
- The lab is destroyed and recreated as part of Phase 1 validation. Main
  resources carry `deletion_protection = false` where the provider has it.
- D-06 is closed: Tempo and Loki use GCS buckets, not PVC-only storage.
