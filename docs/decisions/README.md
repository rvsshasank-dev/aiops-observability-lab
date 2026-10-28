# Architecture Decision Records

Every choice that is expensive to reverse gets an ADR — one file, one decision,
including the ones we rejected.

## Decision register

| ID | Decision | Status | Deadline | ADR |
|---|---|---|---|---|
| D-01 | GKE Standard, **zonal** | Locked | — | [0001](0001-gke-standard-zonal.md) |
| D-02 | OTel Demo consumed as pinned chart, not forked | Locked | — | [0002](0002-otel-demo-as-fixture.md) |
| D-03 | Rules-first correlation; LLM explains only | Locked | — | [0003](0003-rules-before-llm.md) |
| D-04 | Images built in Cloud Build, no local Docker | Locked | — | [0004](0004-cloud-build-images.md) |
| D-05 | OTLP → Prometheus ingestion route | **Open** | M2 | 0005 |
| D-06 | Tempo/Loki storage: GCS module vs PVC-only | **Accepted** | **M1** | [0006](0006-tempo-loki-storage-gcs-vs-pvc.md) |
| D-07 | Platform metrics and K8s events source | **Open** | M4 | 0007 |
| D-08 | Service topology source for correlation | **Open** | M5 | 0008 |
| D-09 | Alertmanager vs correlator grouping ownership | **Open** | M4 | 0009 |
| D-10 | AIOps state model and replica invariant | **Open** | M5 | 0010 |
| D-11 | Evaluation control condition | **Open** | M6 | 0011 |

**A deadline is a milestone, not a date.** A decision marked for M1 that is
still open is a blocker for M1 — do not provision around it and hope.

D-06 is accepted and implemented by `infra/modules/storage`: Tempo and Loki use
GCS buckets with bucket-level IAM and WIF bindings. The next M1/M2 decision is
D-05, the OTLP → Prometheus ingestion route.

## Writing one

Copy `0000-template.md`, allocate the next number, and state the decision in the
title. Keep it under a page. Record the option you rejected and the evidence
that would change your mind.
