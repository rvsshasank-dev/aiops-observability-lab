# ADR-0006: Tempo/Loki storage: GCS object storage vs PVC-only

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision ID:** D-06
- **Deadline:** M1

## Context

Tempo (traces) and Loki (logs) need durable storage for the lab. The repo already plans `infra/storage/` for GCS buckets and IAM for Tempo/Loki (pending this decision). Constraints from the lab:
- All cloud resources via Terraform, remote state in GCS
- No service account keys; Workload Identity Federation only
- One environment in WSL2, measure-then-claim
- M1 blocker

Options: store blocks/chunks/indexes on GCS (object storage) or rely solely on PersistentVolumeClaims (PVCs) attached to StatefulSets.

## Decision

We will use **Google Cloud Storage (GCS) buckets** provisioned via Terraform (`infra/storage/`) with least-privilege IAM and Workload Identity Federation for Tempo and Loki object storage. We will not use PVC-only for long-term trace/log storage in this lab.

## Options considered

| Option | Why rejected |
| --- | --- |
| A: PVC-only (StatefulSet with PVCs, no object storage) | Simpler to start but less durable/cost-flexible for retention experiments, harder to resize/backup/restore cleanly, and doesn't match the planned `infra/storage/` module. Also makes it harder to run multiple replicas or recover state across node failures in a realistic way. |
| B: GCS object storage via Terraform module + WIF | Slightly more infra to provision/IAM, but aligns with cloud-native patterns for Tempo/Loki, enables retention/cost control, fits remote-state/GCS-first approach, and unblocks the planned `infra/storage/` layout. Requires careful bucket naming/lifecycle/IAM. |

## Consequences

**Positive:**
- Durable, decoupled storage for traces/logs
- Easier to experiment with retention and cost
- Consistent with "remote state in GCS" and Terraform-first approach
- Matches planned module structure (`infra/storage/`)

**Negative / accepted cost:**
- Need to provision buckets and IAM bindings in Terraform
- Need WIF configuration for collector/gateway/Tempo/Loki service accounts
- Slightly more moving parts before first apply

**What would change our mind:**
- If GCS costs become prohibitive for the lab budget and we cannot demonstrate value, or if vendor constraints make object storage unusable in this environment. Also if a concrete experiment shows PVC-only meets retention/reliability needs with lower complexity and acceptable tradeoffs.
