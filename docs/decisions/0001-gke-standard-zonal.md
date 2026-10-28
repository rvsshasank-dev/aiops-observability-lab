# ADR-0001: GKE Standard, zonal

- **Status:** Accepted
- **Decision ID:** D-01
- **Deadline:** closed

## Context

The lab exists to learn node-pool control, requests/limits, autoscaling and
resource pressure. That rules out Autopilot, which hides node management.

## Decision

We will run a **zonal** GKE Standard cluster, one general-purpose autoscaling
node pool to start.

## Options considered

| Option | Why rejected |
|---|---|
| GKE Autopilot | Removes the node-level learning the lab is built around |
| GKE Standard, regional | Replicates the control plane for HA the lab does not need, and bills for it |
| kind / k3d locally | No real node pressure, no cloud IAM, no realistic autoscaling |

## Consequences

**Positive:** direct node-pool control; realistic resource behaviour; one zonal
cluster per billing account is not billed a control-plane fee.
**Negative:** no control-plane HA. This is a lab, not a production design — say
so in any write-up.
**What would change our mind:** needing multi-zone scheduling experiments.
