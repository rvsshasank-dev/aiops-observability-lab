# INC-XX — <fault name>

- **Date:**
- **Commit / chart / manifest versions:**
- **Load profile:** baseline | ramp | spike | soak | recovery
- **Stop condition:**

## Hypothesis (written before running)

What should happen, and which signal should show it first?

## Fault

One controlled change only. Record the exact flag or Kubernetes edit.

## Expected signals

| Signal | Expected |
|---|---|
| Metric | |
| Trace | |
| Log | |
| Kubernetes event | |

## Observed

| Time (UTC) | Source | Observation |
|---|---|---|
| | | |

## Alert timing

| Alert | Fired | Resolved |
|---|---|---|
| | | |

## Correlation result

Incident group and members:

## AI assessment

Paste the versioned JSON. Include `incident_id`, `model_version`, `prompt_hash`.

## Comparison

| Measure | Deterministic bundle only | Bundle + LLM |
|---|---|---|
| Time to hypothesis | | |
| Correct cause in top 3 | | |

## Cleanup verified

- [ ] Fault reverted
- [ ] Recovery profile run
- [ ] Alerts resolved
- [ ] Baseline confirmed
