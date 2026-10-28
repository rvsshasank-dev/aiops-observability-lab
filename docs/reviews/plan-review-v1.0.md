# Plan review — v1.0

Review of *AIOps Observability Lab Build Plan* (v1.0, Oct 2026).
Tracked as a work queue. Close each item in the phase that consumes it.

## Blocking — resolve before the named milestone

- [ ] **B1 — No service topology source.** Phase 5 correlates on "the service
      graph" but nothing produces one. *Blocks M5.* Decide: `servicegraph`
      connector, span-edge extraction, or a checked-in manifest.
- [ ] **B2 — Platform metrics and K8s events unsourced.** No
      `kube-state-metrics`, no `kubeletstats`/cAdvisor, no events into Loki.
      INC-02, INC-03, INC-04 are unimplementable as written. *Blocks M4.*
- [ ] **B3 — Alertmanager will pre-group by service**, so Phase 7 scores
      Alertmanager's config rather than the correlator. Set
      `group_by: [alertname]`, short `group_wait`. *Blocks M5, M7.*
- [ ] **B4 — OTLP→Prometheus ingestion route unspecified** (remote-write vs
      native OTLP receiver). Determines every PromQL name in rules and runbooks.
      *Blocks M3.*
- [x] **B5 — No storage module for Tempo/Loki**; `infra/` has no buckets.
      *Blocks M1 or M3.* Closed by ADR-0006 and `infra/modules/storage`:
      Tempo, Loki and a WIF smoke-test bucket are provisioned with bucket-level
      IAM.
- [ ] **B6 — AIOps service is stateful** (dedup cache, open incidents) with no
      store and no single-replica invariant. *Blocks M5.*
- [ ] **B7 — Event contract has no `incident_id`**, so event → incident →
      bundle → assessment cannot be joined for replay. *Blocks M7.*
- [ ] **B8 — Evaluation has no control condition.** Add a deterministic-only
      baseline scored on the same incidents. *Blocks M8's claim.*

## Tightening

- [ ] **T1** Retention: concrete windows plus a `retention.size` cap. A full
      Prometheus disk makes a node NotReady and pollutes experiments.
- [ ] **T2** Single gateway + tail sampling: add a PDB, or document accepted
      trace loss on reschedule; tune `decision_wait` to 10–15s.
- [ ] **T3** Add `observability/alertmanager/` to the map. *(done in scaffold)*
- [ ] **T4** Define the v1 approval surface. Without a channel,
      "approval-required" is documentation, not enforcement.
- [ ] **T5** Add prompt injection to the risk register; treat all evidence as
      data, never instructions.
- [ ] **T6** Turn risk-register "early signal" prose into named metrics with
      thresholds.
- [ ] **T7** Validate every INC-* has a real trigger in the pinned chart before
      writing its experiment record.
- [ ] **T8** Phase 0's "recreatable from repo" holds for infra only until Argo
      CD exists — either narrow the claim or stand up Argo CD at M2.
- [x] **T9** State cost order of magnitude, including that the zonal choice is
      also a billing decision. Recorded in
      `docs/runbooks/phase-1-foundation.md`: one `e2-standard-2` node plus NAT
      and disk is roughly $80–90/month if left running; one zonal cluster per
      billing account has no control-plane fee.
- [ ] **T10** The signal-flow diagram is illegible inside a table cell.
- [ ] **T11** NetworkPolicy / webhook auth for the AIOps ingress: accept as lab
      risk, in writing.

## Sequencing note

GitOps arrives at Phase 6, after Phases 2–5 deploy by hand. Prefer standing up
Argo CD at M2 so the reproducibility claim is honest from the first workload.
