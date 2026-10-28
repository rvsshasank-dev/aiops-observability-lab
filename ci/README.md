# ci/

| Path | Purpose |
|---|---|
| `cloudbuild/aiops-image.yaml` | Build and push the AIOps image, tagged by commit |
| `cloudbuild/validate.yaml` | Lint, render, policy and rule validation |
| `github/validate.yaml` | PR gate: fmt, validate, helm template diff, no credentials |

Split of responsibility: **GitHub Actions validates, Cloud Build builds.**
Neither is allowed to `terraform apply`. Terraform apply is a separate, manually
approved workflow.

Rules: publish rendered diffs as review artifacts. No credentials and no
unredacted telemetry in build logs.
