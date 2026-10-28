# Phase 1 — capacity baseline

- **Date:** 2026-10-28
- **Cluster:** `aiops-lab`, zone `us-central1-a`, GKE `1.36.4-gke.2046003`
- **Node pool:** `general`, 1 × `e2-standard-2`, 50 GB `pd-balanced`
- **Measurement point:** steady state after a full `terraform destroy` and
  re-apply, with only GKE system workloads running and the four lab namespaces
  applied.
- **Method:** single `kubectl top` samples taken ~15 minutes after node Ready,
  repeated at 30 s intervals. `kubectl top` reports a short-window average and
  is rounded.

This baseline exists so that Phase 2 requests are sized against measured
numbers instead of guesses (`platform/README.md` defers `LimitRange` and
`ResourceQuota` until this record exists).

## Node allocatable

| Resource | Allocatable |
|---|---|
| CPU | `1930m` |
| Memory | `6170224Ki` (~5.88 GiB) |
| Pods | `110` |

Allocatable is what remains after GKE's kube-reserved and eviction thresholds;
the machine itself has 2 vCPU and 8 GB.

## Idle system footprint

| Sample | CPU | Memory | CPU % | Memory % |
|---|---|---|---|---|
| 1 | `114m` | `1101Mi` | 5% | 18% |
| 2 | `123m` | `1118Mi` | 6% | 18% |
| 3 | `121m` | `1102Mi` | 6% | 18% |

Steady state is **~120m CPU and ~1.1 GiB**, i.e. 5–6% CPU and 18% memory.

Per-container sums from `kubectl top pods -A` were `53m` CPU and `509Mi`
across 18 pods (16 in `kube-system`, 2 in `gmp-system`). The gap between the
pod sum and node usage (~65m CPU, ~590Mi) is host-level overhead — kubelet,
containerd, the OS — which no pod request can account for.

Largest consumers:

| Pod | CPU | Memory |
|---|---|---|
| `fluentbit-gke` | `14m` | `60Mi` |
| `gke-metrics-agent` | `7m` | `100Mi` |
| `gmp-system/collector` | `5m` | `27Mi` |
| `konnectivity-agent` | `5m` | `29Mi` |
| `node-local-dns` | `3m` | `28Mi` |

Every other pod is `1–3m` and under `35Mi`.

An earlier sample taken while the cluster was still settling showed `1074m`
CPU (55%). That spike was transient startup work (image pulls, first
reconciliation) and is not representative of idle. Size against the steady
state, and leave headroom for the same spike on every node restart.

## Headroom for Phase 2 workloads

| Resource | Allocatable | Idle | Available |
|---|---|---|---|
| CPU | `1930m` | `~120m` | `~1810m` |
| Memory | `~6026Mi` | `~1100Mi` | `~4926Mi` |
| Pods | `110` | `18` | `92` |

Practical guidance:

- **Memory is the binding constraint.** A `e2-standard-2` leaves ~4.8 GiB for
  workloads; CPU leaves ~1.8 cores. Tempo, Loki, Prometheus and the app stack
  will not fit at default resource requests on one node.
- Keep total workload requests under roughly **3.5 GiB memory** and **1.4
  cores** on a single node so that a rolling restart (one node drained) still
  has somewhere to schedule. Beyond that, raise `max_node_count` (currently 3)
  or move to `e2-standard-4` before Phase 3.
- 92 free pod slots is ample; pod density is not a constraint at this size.
- Host overhead is charged against allocatable but invisible to pod requests,
  so a 100%-requested node will still OOM. Do not plan to fill memory.

## Recreate validation

| Check | Result |
|---|---|
| `terraform destroy` (main root) | 21 resources destroyed |
| `terraform apply` (main root) | 21 resources added |
| `kubectl apply -k platform/` | 4 namespaces recreated with PSA labels |
| Node Ready | yes, one node in the general pool |
| System pods Running | 18/18 |
| WIF contract test | `PASS`, Tempo bucket denied |
| `terraform -chdir=infra plan -detailed-exitcode` | `0` (no diff) |
| `terraform -chdir=infra/bootstrap plan -detailed-exitcode` | `0` (no diff) |

The cluster is reproducible from the state bucket alone, and both roots are
idempotent after the recreate. Bootstrap (state bucket, APIs, budget) is not
part of the recreate cycle and was left in place.

## Reproduce

```bash
gcloud container clusters get-credentials aiops-lab \
  --zone us-central1-a --project winterarc1-510922

kubectl get node -o custom-columns='NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory,PODS:.status.allocatable.pods'
kubectl top node
kubectl top pods -A --sum
kubectl top pods -A --no-headers --sort-by=cpu
```
