# observability/

The telemetry path. Config only — no application code, no alert *routing* logic
(routing lives in `aiops/`).

| Path | Holds | Milestone |
|---|---|---|
| `collectors/agent/` | DaemonSet config: receive, k8s metadata, forward | M3 |
| `collectors/gateway/` | Deployment config: batch, redact, route, tail sample | M3 |
| `platform-metrics/` | `kube-state-metrics`, kubeletstats, K8s events — **pending D-07** | M4 |
| `topology/` | Service-graph derivation for correlation — **pending D-08** | M5 |
| `prometheus/rules/` | Recording and alerting rules, one file per symptom family | M4 |
| `alertmanager/` | Routing, receivers, `group_by` — **pending D-09** | M4 |
| `grafana/dashboards/` | Provisioned dashboards as JSON | M3 |
| `tempo/` | Trace backend config and retention | M3 |
| `loki/` | Log backend config and retention | M3 |

Rules: every alert rule carries `severity`, `service_name`, `namespace`,
`symptom`, `signal`, `runbook_id` and `correlation_key`. Every rule names an
observable symptom, never an unproven cause. Metric labels stay bounded — no
user IDs, raw URLs, request IDs, error strings or trace IDs.
