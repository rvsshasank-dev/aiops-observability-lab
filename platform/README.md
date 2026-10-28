# platform/

Cluster-scoped configuration that is not an application and not infrastructure.

| Path | Holds |
|---|---|
| `namespaces/` | The four namespaces: `app`, `observability`, `aiops`, `delivery` |
| `policies/` | LimitRange, ResourceQuota, NetworkPolicy, PodSecurity |
| `argo-cd/` | Argo CD install and project definitions |

Phase 1 status: the four namespaces and their Pod Security Admission labels are
applied with `kubectl apply -k platform/`. Quotas, limits and NetworkPolicies
are deferred until the first workload is measured.

Rules: quotas start generous and are tightened from measurements, not guesses.
Every namespace gets a LimitRange and a ResourceQuota after its first measured
deployment, never before. The cluster-level Phase 1 idle baseline is in
`docs/experiments/phase-1-capacity-baseline.md`; it sizes Phase 2, it does not
justify per-namespace quotas on its own.
