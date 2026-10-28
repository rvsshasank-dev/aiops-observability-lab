# Architecture

Living document. Update when a plane, boundary or data path changes.

## Planes

| Plane | Components | Owned by us? |
|---|---|---|
| Workload | OTel Demo (pinned chart) | Overlay only |
| Platform | GKE Standard, Terraform, IAM | Yes |
| Telemetry | Collector agent + gateway, Prometheus, Tempo, Loki, Grafana | Yes |
| Incident | Alertmanager, AIOps pipeline | Yes |
| Delivery | Cloud Build, Argo CD | Yes |

## Boundaries that matter

- **Agent tier** is node-local and stateless: collect, add k8s metadata, forward.
  Keep processing light.
- **Gateway tier** holds policy: batching, filtering, redaction, routing,
  tail sampling. One replica in v1 — tail sampling needs every span of a trace
  to reach the same process.
- **Correlator** owns service-level grouping. Alertmanager must *not* also
  group by service, or evaluation scores Alertmanager instead of our code.
- **Analyst** receives a bounded evidence bundle, never raw telemetry.

## Open architecture questions

Tracked as ADRs in `docs/decisions/`. See the deadline table there.
