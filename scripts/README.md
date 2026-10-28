# scripts/

Developer and setup helpers. Nothing here is required by the cluster at runtime.

| Path | Purpose |
|---|---|
| `setup/setup-lab.sh` | One-time WSL2 migration + scaffold (re-runnable, supports `--dry-run`) |
| `setup/bootstrap-state.sh` | Create the GCS Terraform state bucket and import it into `infra/bootstrap` |
| `dev/pin-otel-demo-chart.sh` | Resolve and record the demo chart version into `CHART.lock` |
