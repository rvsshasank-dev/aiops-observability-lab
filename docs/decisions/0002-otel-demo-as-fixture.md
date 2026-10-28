# ADR-0002: OTel Demo consumed as a pinned chart, not forked

- **Status:** Accepted
- **Decision ID:** D-02
- **Deadline:** closed

## Context

Service development is not the learning objective. The demo already provides
realistic service calls, load generation and controllable faults. An earlier
fork of the demo exists at `~/repos/reference/microservices-demo`; it is
reference material, not the project.

## Decision

We will consume the upstream **OpenTelemetry Demo Helm chart at a pinned
version**, overriding only through `apps/otel-demo/values/`. We will not fork
service source, and we will not build the lab inside the demo fork.

If a source-level patch ever becomes unavoidable it goes in
`apps/otel-demo/patches/` with its own ADR stating why values could not express
the change.

## Options considered

| Option | Why rejected |
|---|---|
| Fork the demo and modify services | Turns the lab into application maintenance; pollutes every diff |
| Write our own microservices | Weeks of work that teaches nothing about operations |
| Consume chart unmodified, no overlay | Cannot redirect telemetry, set resources or rename |

## Consequences

**Positive:** diffable surface is small; upstream upgrades stay cheap; the
learning work is the deployment contract.
**Negative:** bounded by what chart values expose; feature-flag names drift
between releases.
**Mitigation:** pin the chart in `apps/otel-demo/CHART.lock` and re-verify flag
names at every bump — `scripts/dev/pin-otel-demo-chart.sh` exists for this.
