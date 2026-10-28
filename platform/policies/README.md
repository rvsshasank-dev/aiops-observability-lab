# policies/

Baseline cluster policy lives here. Phase 1 applies Pod Security Admission
labels on the namespaces; `LimitRange` and `ResourceQuota` are intentionally
deferred until each namespace has a measured first deployment.

When they are added, start generous, record the measurement, then tighten:

| Policy | Starts at | Tightened from |
|---|---|---|
| `LimitRange` | one container ceiling, no default limits | observed request/limit pairs |
| `ResourceQuota` | object counts only | measured CPU/memory peaks |
| `NetworkPolicy` | default deny plus explicit DNS/ingress | observed flows |

A quota written before a measurement is a guess, and a guess that blocks
admission is worse than no quota.
