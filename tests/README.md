# tests/

Everything that proves the system works, and everything that scores it.

| Path | Holds |
|---|---|
| `contracts/` | JSON Schema for the normalized event, bundle and assessment, plus the WIF boundary check |
| `incidents/` | One definition per INC-*, with ground truth written *before* review |
| `load/` | Load profiles and the stop conditions that bound them |

`contracts/verify-wif.sh` proves that a Kubernetes ServiceAccount reaches one
permitted GCS bucket through Workload Identity and is denied the telemetry
bucket.

Rules: ground truth is authored before model output is read. A missing signal is
recorded as a finding, not a pass.
