# AIOps Observability Lab

An end-to-end GKE, OpenTelemetry and AI incident-correlation lab.

The workload is the official **OpenTelemetry Demo**, consumed as a pinned Helm
chart. Everything else in this repository is project-owned: the cluster, the
deployment overlays, the telemetry path, the alert taxonomy, the correlation
logic, the AI workflow and the evaluation.

> **Status:** Phase 1 (GKE foundation) applied on 2026-10-28. The zonal
> cluster, network, Tempo/Loki buckets, Workload Identity bindings, namespaces
> and monthly budget are live. See `docs/runbooks/phase-1-foundation.md` for
> the apply, verify and destroy sequence.

---

## Operating rules

1. **One environment.** All GCP, Kubernetes, Terraform and Helm work happens
   inside WSL2. Windows is an editor and browser only. One `gcloud` auth, one
   `~/.kube/config`, one state location.
2. **Two repositories, two purposes.** This repo is project code.
   `~/repos/reference/microservices-demo` is an input we read from, never a
   place we write. Never build the lab inside the demo fork.
3. **The demo is a fixture, not a fork.** We consume the upstream chart at a
   pinned version and override via values. We do not patch service source. If a
   source patch ever becomes unavoidable, it lives in
   `apps/otel-demo/patches/` with an ADR explaining why.
4. **Images build in Cloud Build.** No local Docker dependency.
5. **Measure, then claim.** No number goes in a doc, dashboard or CV until a
   recorded experiment produced it.

---

## Repository map

| Path | Holds | Does not hold |
|---|---|---|
| `docs/` | Architecture, ADRs, runbooks, experiment records, reviews | Code |
| `infra/` | Terraform: VPC, GKE, IAM, storage buckets, bootstrap | Kubernetes workloads |
| `platform/` | Cluster-scoped config: namespaces, quotas, policies, Argo CD | Application values |
| `apps/` | Workload overlays — values and chart pins | Service source code |
| `observability/` | Collector configs, rules, dashboards, backend config | Alert routing logic (that is `aiops/`) |
| `aiops/` | The incident pipeline: ingest, correlate, retrieve, analyse, score | Cluster provisioning |
| `gitops/` | Kustomize/Argo entry points mapping repo paths to cluster state | Source images |
| `tests/` | Contract tests, incident definitions, load profiles | Runtime config |
| `ci/` | Cloud Build and GitHub Actions definitions | Deployable manifests |
| `scripts/` | Developer and setup helpers | Anything the cluster needs at runtime |

### Plane → directory

| Plane | Directory | Responsibility |
|---|---|---|
| Workload | `apps/` | Services and traffic (upstream demo) |
| Platform | `infra/`, `platform/` | Compute, identity, policy |
| Telemetry | `observability/` | Receive, process, store, visualise |
| Incident | `aiops/` | Normalise, correlate, explain, score |
| Delivery | `ci/`, `gitops/` | Validate and deploy |

---

## Signal and incident flow

```
load generator / feature flags
            |
            v
  OTel Demo services (GKE)
            |  OTLP + k8s metadata
            v
  collector agent (DaemonSet)  ->  collector gateway (Deployment)
                                        |
                     +------------------+------------------+
                     v                  v                  v
                   Tempo            Prometheus            Loki
                  (traces)           (metrics)           (logs)
                     |                  |                  |
                     +------------------+------------------+
                                        v
                                     Grafana
                                        ^
   Prometheus rules --> Alertmanager --> AIOps ingress
                                        |
                         normalise -> dedupe -> correlate
                                        |
                              retrieve bounded evidence
                                        |
                              AI analyst (LLM, optional)
                                        |
                          evidence-linked assessment (JSON)
                                        |
                                  human review
```

**Safety boundary:** the model may summarise, rank hypotheses and propose
runbook steps. It does not run `kubectl`, change infrastructure, silence alerts
or modify workloads. Version 1 has no autonomous change path.

---

## Getting started

```bash
# toolchain sanity
gcloud config get-value project
terraform version && kubectl version --client && helm version --short

# the plan this repo implements
cat ~/repos/reference/"AIOps Observability Lab Build Plan.docx"  # or open in Word
```

Next: Phase 2 — adopt the pinned OpenTelemetry Demo on the Phase 1 cluster
(`docs/runbooks/phase-1-foundation.md` documents the foundation commands).

## Before every session

Confirm the budget alert and current spend, state the session's single
observable outcome, check pinned versions and Git state, confirm the previous
baseline is healthy, set a stop condition, and plan the cleanup command before
applying the change.
