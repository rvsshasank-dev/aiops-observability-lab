# Runbooks

## Build runbooks

These cover provisioning and teardown, not alert response.

| File | Covers |
|---|---|
| `phase-1-foundation.md` | Apply, verify and destroy the Terraform foundation |

## Alert runbooks

One file per `runbook_id` referenced by an alert rule, plus an `index.md` once
more than a handful exist. An alert whose `runbook_id` has no file here is an
incomplete alert.

## Template

| Section | Required content |
|---|---|
| Trigger | Alert name and threshold |
| Impact | User-visible symptom, in plain language |
| Checks | Read-only queries first, in order |
| Branches | Evidence-based decision paths |
| Mitigation | Approval-required actions, with the rollback for each |
| Rollback | Return to the recorded baseline |
| Validation | Recovery signals that prove it worked |
| Owner / version | Review metadata |

Rules: diagnostic checks are read-only by default. Any change action names its
rollback. Every query in a runbook should be the same query the evidence
retriever runs — do not maintain two versions of the truth.
