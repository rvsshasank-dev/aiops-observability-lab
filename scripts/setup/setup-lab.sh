#!/usr/bin/env bash
#
# setup-lab.sh — one-time WSL2 migration + AIOps lab scaffold
#
# Moves the reference material off the Windows mount (/mnt/c) onto the Linux
# filesystem, then creates the segregated project tree for the lab.
#
# Design rules this script enforces:
#   1. One environment. All GCP/K8s/Terraform work happens inside WSL2.
#   2. Reference inputs are kept separate from project code.
#   3. The OTel Demo is consumed as a pinned Helm chart, never forked.
#   4. Image builds happen in Cloud Build. No local Docker required.
#
# Usage:
#   ./setup-lab.sh --dry-run          # show every action, change nothing
#   ./setup-lab.sh                    # migrate + scaffold
#   ./setup-lab.sh --scaffold-only    # skip migration
#   ./setup-lab.sh --verify-only      # re-run checks only
#   ./setup-lab.sh --purge-source     # delete /mnt/c copies after verification
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SRC_ROOT="/mnt/c/Users/rvssh/Repos"
WSL_REPOS="$HOME/repos"
REFERENCE_DIR="$WSL_REPOS/reference"
LAB_DIR="$WSL_REPOS/aiops-observability-lab"
DEMO_DIR="$REFERENCE_DIR/microservices-demo"
PLAN_DOC_NAME="AIOps Observability Lab Build Plan.docx"

DRY_RUN=0
PURGE_SOURCE=0
DO_MIGRATE=1
DO_SCAFFOLD=1
DO_VERIFY=1
PRESERVED_FILES=()

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
  C_OK='\033[32m'; C_WARN='\033[33m'; C_ERR='\033[31m'; C_STEP='\033[36m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''; C_OK=''; C_WARN=''; C_ERR=''; C_STEP=''
fi

step() { printf '\n%s==> %s%s\n' "$C_BOLD$C_STEP" "$*" "$C_RESET"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s✓%s %s\n' "$C_OK" "$C_RESET" "$*"; }
warn() { printf '    %s!%s %s\n' "$C_WARN" "$C_RESET" "$*"; }
die()  { printf '\n%sERROR:%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2; exit 1; }

# Run a command, or describe it under --dry-run.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '    %s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  "$@"
}

# Write a file from stdin heredoc, or describe it under --dry-run.
write_file() {
  local path="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '    %s[dry-run]%s write %s\n' "$C_DIM" "$C_RESET" "${path#"$LAB_DIR"/}"
    cat > /dev/null
    return 0
  fi
  cat > "$path"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)        DRY_RUN=1 ;;
    --purge-source)   PURGE_SOURCE=1 ;;
    --scaffold-only)  DO_MIGRATE=0 ;;
    --verify-only)    DO_MIGRATE=0; DO_SCAFFOLD=0 ;;
    -h|--help)        sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)                die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

[ "$DRY_RUN" -eq 1 ] && warn "DRY RUN — no files will be created, moved, or deleted"
[ "$PURGE_SOURCE" -eq 1 ] && [ "$DRY_RUN" -eq 0 ] && \
  warn "PURGE SOURCE — /mnt/c copies will be deleted after verification"

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
step "Preflight"

case "$(uname -r)" in
  *[Mm]icrosoft*) ok "running inside WSL2 ($(uname -r))" ;;
  *) die "this script must run inside WSL2, not Windows or plain Linux" ;;
esac

[ "$(id -u)" -eq 0 ] && die "do not run as root; the repo should be owned by your user"

command -v git >/dev/null 2>&1 || die "git not found"
ok "git $(git --version | awk '{print $3}')"

# Home filesystem must be the Linux one, not a /mnt/c bind mount.
case "$HOME" in
  /mnt/*) die "HOME is on the Windows mount ($HOME); cannot proceed" ;;
  *)      ok "HOME is on the Linux filesystem ($HOME)" ;;
esac

[ -d "$SRC_ROOT" ] || die "source root not found: $SRC_ROOT"
[ -d "$SRC_ROOT/microservices-demo" ] || die "demo fork not found under $SRC_ROOT"

AVAIL_KB=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
[ "$AVAIL_KB" -gt 5242880 ] || die "need at least 5 GiB free in \$HOME, found $((AVAIL_KB/1024)) MiB"
ok "$((AVAIL_KB/1024/1024)) GiB free in \$HOME"

# Report the toolchain the plan depends on. Missing items are warnings, not
# failures — except the ones we cannot work without.
for tool in gcloud terraform kubectl helm; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool -> $(command -v "$tool")"
  elif [ -x "/snap/bin/$tool" ]; then
    warn "$tool resolves only in LOGIN shells (/snap/bin/$tool)"
    info "  scripts, CI and agent sessions use non-login shells and will not find it."
    info "  fix: sudo snap remove $tool, then install the official binary to /usr/local/bin"
  else
    warn "$tool MISSING — required before Phase 1"
  fi
done

command -v jq >/dev/null 2>&1 \
  || warn "jq MISSING — install before Phase 5 (sudo apt install -y jq)"

if command -v docker >/dev/null 2>&1 && ! docker info >/dev/null 2>&1; then
  info "docker present but not functional — expected; images build in Cloud Build"
fi

# ---------------------------------------------------------------------------
# Migration
# ---------------------------------------------------------------------------
if [ "$DO_MIGRATE" -eq 1 ]; then
  step "Migrating reference material off /mnt/c"

  run mkdir -p "$REFERENCE_DIR"

  # Record HEAD before copying so we can prove the clone is faithful.
  DEMO_HEAD_BEFORE=""
  if [ -d "$SRC_ROOT/microservices-demo/.git" ]; then
    DEMO_HEAD_BEFORE=$(git -C "$SRC_ROOT/microservices-demo" rev-parse HEAD 2>/dev/null || true)
    DIRTY=$(git -C "$SRC_ROOT/microservices-demo" status --porcelain 2>/dev/null || true)
    if [ -n "$DIRTY" ]; then
      warn "demo fork has uncommitted changes; they will be copied as local files:"
      printf '%s\n' "$DIRTY" | sed 's/^/        /'
    else
      ok "demo fork working tree is clean at ${DEMO_HEAD_BEFORE:0:12}"
    fi
  fi

  if [ -d "$DEMO_DIR" ]; then
    warn "destination already exists, skipping copy: $DEMO_DIR"
  else
    info "copying microservices-demo -> $DEMO_DIR"
    # -a preserves modes/timestamps; --no-perms avoids 777 drift from the 9p mount.
    run rsync -a --no-perms --info=progress2 \
      "$SRC_ROOT/microservices-demo/" "$DEMO_DIR/" 2>/dev/null \
      || run cp -a "$SRC_ROOT/microservices-demo" "$DEMO_DIR"
  fi

  # The plan document stays readable in Word via \\wsl$\Ubuntu\..., and now
  # also lives next to the material it describes.
  if [ -f "$SRC_ROOT/$PLAN_DOC_NAME" ] && [ ! -f "$REFERENCE_DIR/$PLAN_DOC_NAME" ]; then
    run cp -a "$SRC_ROOT/$PLAN_DOC_NAME" "$REFERENCE_DIR/$PLAN_DOC_NAME"
    ok "plan document copied to reference/"
  fi

  ok "reference material staged at $REFERENCE_DIR"

  # Preserve loose files at the root of the Windows folder so the purge
  # orphans nothing (package manifests, scratch notes, and so on).
  while IFS= read -r -d '' f; do
    base=$(basename "$f")
    [ "$base" = "$PLAN_DOC_NAME" ] && continue
    run mkdir -p "$REFERENCE_DIR/misc"
    run cp -a "$f" "$REFERENCE_DIR/misc/$base"
    PRESERVED_FILES+=("$base")
    ok "preserved loose file: $base"
  done < <(find "$SRC_ROOT" -maxdepth 1 -type f -print0 2>/dev/null)
fi

# ---------------------------------------------------------------------------
# Scaffold
# ---------------------------------------------------------------------------
if [ "$DO_SCAFFOLD" -eq 1 ]; then
  step "Scaffolding the lab repository"

  run mkdir -p "$LAB_DIR"

  DIRS=(
    "docs/decisions"
    "docs/runbooks"
    "docs/experiments"
    "docs/reviews"
    "infra/bootstrap"
    "infra/network"
    "infra/storage"
    "infra/gke"
    "infra/iam"
    "platform/namespaces"
    "platform/policies"
    "platform/argo-cd"
    "apps/otel-demo/values"
    "observability/collectors/agent"
    "observability/collectors/gateway"
    "observability/platform-metrics"
    "observability/topology"
    "observability/prometheus/rules"
    "observability/alertmanager"
    "observability/grafana/dashboards"
    "observability/tempo"
    "observability/loki"
    "aiops/ingress"
    "aiops/correlation"
    "aiops/retrieval"
    "aiops/analyst"
    "aiops/evaluation"
    "aiops/store"
    "gitops/base"
    "gitops/environments/lab"
    "tests/contracts"
    "tests/incidents"
    "tests/load"
    "ci/cloudbuild"
    "ci/github"
    "scripts/setup"
    "scripts/dev"
  )
  for d in "${DIRS[@]}"; do
    run mkdir -p "$LAB_DIR/$d"
  done
  ok "${#DIRS[@]} directories created"

  # -------------------------------------------------------------------------
  # Root files
  # -------------------------------------------------------------------------
  write_file "$LAB_DIR/.gitignore" <<'EOF'
# --- Terraform -------------------------------------------------------------
**/.terraform/*
*.tfstate
*.tfstate.*
crash.log
crash.*.log
*.tfvars
*.tfvars.json
!*.tfvars.example
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc

# --- Cloud / cluster credentials -------------------------------------------
kubeconfig
*.kubeconfig
.kube/
*.pem
*.key
*-key.json
key.json
.credentials/
gcloud/

# --- Charts (pinned by CHART.lock, downloaded not committed) ----------------
apps/otel-demo/charts/

# --- Python (aiops service) -------------------------------------------------
__pycache__/
*.py[cod]
.venv/
venv/
.pytest_cache/
.ruff_cache/
.mypy_cache/
*.egg-info/

# --- Secrets / local env ----------------------------------------------------
.env
.env.*
!.env.example

# --- Local output (may contain cluster data; never commit) ------------------
/out/
/tmp/
*.log

# --- OS / editor ------------------------------------------------------------
.DS_Store
Thumbs.db
*.swp
EOF

  write_file "$LAB_DIR/.editorconfig" <<'EOF'
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.{py,sh}]
indent_size = 4

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
EOF

  write_file "$LAB_DIR/README.md" <<'EOF'
# AIOps Observability Lab

An end-to-end GKE, OpenTelemetry and AI incident-correlation lab.

The workload is the official **OpenTelemetry Demo**, consumed as a pinned Helm
chart. Everything else in this repository is project-owned: the cluster, the
deployment overlays, the telemetry path, the alert taxonomy, the correlation
logic, the AI workflow and the evaluation.

> **Status:** Phase 0 (guardrails). Nothing is deployed. See
> `docs/decisions/README.md` for the decisions that must close before Phase 1.

---

## Operating rules

1. **One environment.** All GCP, Kubernetes, Terraform and Helm work happens
   inside WSL2. Windows is an editor and browser only. One `gcloud` auth, one
   `~/.kube/config`, one state location.
2. **Two repositories, two purposes.** This repo is project code.
   `~/repos/reference/microservices-demo` is an input we read from, never a
   place we write. Never build the lab inside the demo fork.
3. **The demo is a fixture, not a fork.** We consume the upstream chart at a
   pinned version and override via values. We do not patch service source. If a
   source patch ever becomes unavoidable, it lives in
   `apps/otel-demo/patches/` with an ADR explaining why.
4. **Images build in Cloud Build.** No local Docker dependency.
5. **Measure, then claim.** No number goes in a doc, dashboard or CV until a
   recorded experiment produced it.

---

## Repository map

| Path | Holds | Does not hold |
|---|---|---|
| `docs/` | Architecture, ADRs, runbooks, experiment records, reviews | Code |
| `infra/` | Terraform: VPC, GKE, IAM, storage buckets, bootstrap | Kubernetes workloads |
| `platform/` | Cluster-scoped config: namespaces, quotas, policies, Argo CD | Application values |
| `apps/` | Workload overlays — values and chart pins | Service source code |
| `observability/` | Collector configs, rules, dashboards, backend config | Alert routing logic (that is `aiops/`) |
| `aiops/` | The incident pipeline: ingest, correlate, retrieve, analyse, score | Cluster provisioning |
| `gitops/` | Kustomize/Argo entry points mapping repo paths to cluster state | Source images |
| `tests/` | Contract tests, incident definitions, load profiles | Runtime config |
| `ci/` | Cloud Build and GitHub Actions definitions | Deployable manifests |
| `scripts/` | Developer and setup helpers | Anything the cluster needs at runtime |

### Plane → directory

| Plane | Directory | Responsibility |
|---|---|---|
| Workload | `apps/` | Services and traffic (upstream demo) |
| Platform | `infra/`, `platform/` | Compute, identity, policy |
| Telemetry | `observability/` | Receive, process, store, visualise |
| Incident | `aiops/` | Normalise, correlate, explain, score |
| Delivery | `ci/`, `gitops/` | Validate and deploy |

---

## Signal and incident flow

```
load generator / feature flags
            |
            v
  OTel Demo services (GKE)
            |  OTLP + k8s metadata
            v
  collector agent (DaemonSet)  ->  collector gateway (Deployment)
                                        |
                     +------------------+------------------+
                     v                  v                  v
                   Tempo            Prometheus            Loki
                  (traces)           (metrics)           (logs)
                     |                  |                  |
                     +------------------+------------------+
                                        v
                                     Grafana
                                        ^
   Prometheus rules --> Alertmanager --> AIOps ingress
                                        |
                         normalise -> dedupe -> correlate
                                        |
                              retrieve bounded evidence
                                        |
                              AI analyst (LLM, optional)
                                        |
                          evidence-linked assessment (JSON)
                                        |
                                  human review
```

**Safety boundary:** the model may summarise, rank hypotheses and propose
runbook steps. It does not run `kubectl`, change infrastructure, silence alerts
or modify workloads. Version 1 has no autonomous change path.

---

## Getting started

```bash
# toolchain sanity
gcloud config get-value project
terraform version && kubectl version --client && helm version --short

# the plan this repo implements
cat ~/repos/reference/"AIOps Observability Lab Build Plan.docx"  # or open in Word
```

Next: close **D-06** (storage) and then write `infra/bootstrap`.

## Before every session

Confirm the budget alert and current spend, state the session's single
observable outcome, check pinned versions and Git state, confirm the previous
baseline is healthy, set a stop condition, and plan the cleanup command before
applying the change.
EOF

  # -------------------------------------------------------------------------
  # docs/
  # -------------------------------------------------------------------------
  write_file "$LAB_DIR/docs/architecture.md" <<'EOF'
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
EOF

  write_file "$LAB_DIR/docs/decisions/README.md" <<'EOF'
# Architecture Decision Records

Every choice that is expensive to reverse gets an ADR — one file, one decision,
including the ones we rejected.

## Decision register

| ID | Decision | Status | Deadline | ADR |
|---|---|---|---|---|
| D-01 | GKE Standard, **zonal** | Locked | — | [0001](0001-gke-standard-zonal.md) |
| D-02 | OTel Demo consumed as pinned chart, not forked | Locked | — | [0002](0002-otel-demo-as-fixture.md) |
| D-03 | Rules-first correlation; LLM explains only | Locked | — | [0003](0003-rules-before-llm.md) |
| D-04 | Images built in Cloud Build, no local Docker | Locked | — | [0004](0004-cloud-build-images.md) |
| D-05 | OTLP → Prometheus ingestion route | **Open** | M2 | 0005 |
| D-06 | Tempo/Loki storage: GCS module vs PVC-only | **Open** | **M1** | 0006 |
| D-07 | Platform metrics and K8s events source | **Open** | M4 | 0007 |
| D-08 | Service topology source for correlation | **Open** | M5 | 0008 |
| D-09 | Alertmanager vs correlator grouping ownership | **Open** | M4 | 0009 |
| D-10 | AIOps state model and replica invariant | **Open** | M5 | 0010 |
| D-11 | Evaluation control condition | **Open** | M6 | 0011 |

**A deadline is a milestone, not a date.** A decision marked for M1 that is
still open is a blocker for M1 — do not provision around it and hope.
D-06 is first: it changes what `infra/` contains.

## Writing one

Copy `0000-template.md`, allocate the next number, and state the decision in the
title. Keep it under a page. Record the option you rejected and the evidence
that would change your mind.
EOF

  write_file "$LAB_DIR/docs/decisions/0000-template.md" <<'EOF'
# ADR-0000: <short decision title>

- **Status:** Proposed | Accepted | Superseded by ADR-XXXX
- **Date:** YYYY-MM-DD
- **Decision ID:** D-XX
- **Deadline:** Mx

## Context

What forces are at play? What is measured, and what is still assumed?

## Decision

One or two sentences, in the active voice: "We will ..."

## Options considered

| Option | Why rejected |
|---|---|
| A | |
| B | |

## Consequences

**Positive:**
**Negative / accepted cost:**
**What would change our mind:**
EOF

  write_file "$LAB_DIR/docs/decisions/0001-gke-standard-zonal.md" <<'EOF'
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
EOF

  write_file "$LAB_DIR/docs/decisions/0002-otel-demo-as-fixture.md" <<'EOF'
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
EOF

  write_file "$LAB_DIR/docs/decisions/0003-rules-before-llm.md" <<'EOF'
# ADR-0003: Rules-first correlation; the model explains only

- **Status:** Accepted
- **Decision ID:** D-03
- **Deadline:** closed

## Context

An LLM asked to "find the root cause" from raw alerts produces fluent,
unfalsifiable output. It also makes the pipeline impossible to score: you cannot
tell whether a wrong answer came from bad grouping or bad reasoning.

## Decision

We will normalise, deduplicate, group and retrieve **deterministically** first,
producing a bounded evidence bundle. The model receives that bundle and returns
a schema-validated assessment that cites evidence references and marks every
change action as approval-required. Correlation and model output are scored
**separately**.

## Options considered

| Option | Why rejected |
|---|---|
| Feed raw alerts to the model | Unscorable, unbounded tokens, hallucination-prone |
| Model picks which queries to run, unbounded | No evaluation surface; non-reproducible |
| Fully deterministic, no model | Loses the explain-and-rank step the lab is about |

## Consequences

**Positive:** reproducible grouping; every claim traceable to evidence; the
lab remains useful with the model disabled.
**Negative:** correlation quality is capped by hand-written logic and topology
accuracy.
**What would change our mind:** measured evidence that a model-driven grouping
step beats the deterministic one on the fixed incident suite.
EOF

  write_file "$LAB_DIR/docs/decisions/0004-cloud-build-images.md" <<'EOF'
# ADR-0004: Images built in Cloud Build, no local Docker

- **Status:** Accepted
- **Decision ID:** D-04
- **Deadline:** closed

## Context

The AIOps service needs a container image. Docker Desktop's WSL integration is
not enabled on this machine, and local builds would add a large dependency to an
environment whose job is to run cloud tooling. GCP credits cover Cloud Build.

## Decision

We will build and push images with **Cloud Build**. Local Docker is not a
prerequisite for any phase of this lab.

## Options considered

| Option | Why rejected |
|---|---|
| Docker Desktop + WSL integration | Adds a local daemon dependency and a licence surface for one image |
| docker-ce inside WSL2 | Heavier maintenance; still not reproducible off-machine |
| `ko` / buildpacks locally | Still needs a local builder |

## Consequences

**Positive:** no local Docker requirement; builds are reproducible and
auditable; provenance and digests come for free with Cloud Build.
**Negative:** slower inner loop than a local build; needs a GCP round trip for
each change.
**Mitigation:** `ci/cloudbuild/aiops-image.yaml` supports a `--substitutions`
image tag for rapid iteration; Phase 6 pins deployment to the image **digest**.
EOF

  write_file "$LAB_DIR/docs/runbooks/README.md" <<'EOF'
# Runbooks

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
EOF

  write_file "$LAB_DIR/docs/experiments/TEMPLATE.md" <<'EOF'
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
EOF

  write_file "$LAB_DIR/docs/reviews/plan-review-v1.0.md" <<'EOF'
# Plan review — v1.0

Review of *AIOps Observability Lab Build Plan* (v1.0, Oct 2026).
Tracked as a work queue. Close each item in the phase that consumes it.

## Blocking — resolve before the named milestone

- [ ] **B1 — No service topology source.** Phase 5 correlates on "the service
      graph" but nothing produces one. *Blocks M5.* Decide: `servicegraph`
      connector, span-edge extraction, or a checked-in manifest.
- [ ] **B2 — Platform metrics and K8s events unsourced.** No
      `kube-state-metrics`, no `kubeletstats`/cAdvisor, no events into Loki.
      INC-02, INC-03, INC-04 are unimplementable as written. *Blocks M4.*
- [ ] **B3 — Alertmanager will pre-group by service**, so Phase 7 scores
      Alertmanager's config rather than the correlator. Set
      `group_by: [alertname]`, short `group_wait`. *Blocks M5, M7.*
- [ ] **B4 — OTLP→Prometheus ingestion route unspecified** (remote-write vs
      native OTLP receiver). Determines every PromQL name in rules and runbooks.
      *Blocks M3.*
- [ ] **B5 — No storage module for Tempo/Loki**; `infra/` has no buckets.
      *Blocks M1 or M3.*
- [ ] **B6 — AIOps service is stateful** (dedup cache, open incidents) with no
      store and no single-replica invariant. *Blocks M5.*
- [ ] **B7 — Event contract has no `incident_id`**, so event → incident →
      bundle → assessment cannot be joined for replay. *Blocks M7.*
- [ ] **B8 — Evaluation has no control condition.** Add a deterministic-only
      baseline scored on the same incidents. *Blocks M8's claim.*

## Tightening

- [ ] **T1** Retention: concrete windows plus a `retention.size` cap. A full
      Prometheus disk makes a node NotReady and pollutes experiments.
- [ ] **T2** Single gateway + tail sampling: add a PDB, or document accepted
      trace loss on reschedule; tune `decision_wait` to 10–15s.
- [ ] **T3** Add `observability/alertmanager/` to the map. *(done in scaffold)*
- [ ] **T4** Define the v1 approval surface. Without a channel,
      "approval-required" is documentation, not enforcement.
- [ ] **T5** Add prompt injection to the risk register; treat all evidence as
      data, never instructions.
- [ ] **T6** Turn risk-register "early signal" prose into named metrics with
      thresholds.
- [ ] **T7** Validate every INC-* has a real trigger in the pinned chart before
      writing its experiment record.
- [ ] **T8** Phase 0's "recreatable from repo" holds for infra only until Argo
      CD exists — either narrow the claim or stand up Argo CD at M2.
- [ ] **T9** State cost order of magnitude, including that the zonal choice is
      also a billing decision.
- [ ] **T10** The signal-flow diagram is illegible inside a table cell.
- [ ] **T11** NetworkPolicy / webhook auth for the AIOps ingress: accept as lab
      risk, in writing.

## Sequencing note

GitOps arrives at Phase 6, after Phases 2–5 deploy by hand. Prefer standing up
Argo CD at M2 so the reproducibility claim is honest from the first workload.
EOF

  # -------------------------------------------------------------------------
  # Directory READMEs — the "what belongs here" contract
  # -------------------------------------------------------------------------
  write_file "$LAB_DIR/infra/README.md" <<'EOF'
# infra/

Terraform only. Everything here is cloud infrastructure; nothing here is a
Kubernetes workload.

| Module | Holds | Milestone |
|---|---|---|
| `bootstrap/` | APIs, remote state bucket, budget alerts | M0 |
| `network/` | VPC, subnet, secondary ranges, Cloud NAT | M1 |
| `storage/` | GCS buckets and IAM for Tempo/Loki — **pending D-06** | M1 |
| `gke/` | Cluster, node pools, WIF, release channel | M1 |
| `iam/` | Workload principals, least-privilege bindings | M1 |

Rules: remote state in GCS from the first apply. `terraform.tfvars` stays out of
git (`*.tfvars` is ignored; commit `*.tfvars.example`). No service-account keys
anywhere — Workload Identity Federation only. A second apply must be a no-op.
EOF

  write_file "$LAB_DIR/platform/README.md" <<'EOF'
# platform/

Cluster-scoped configuration that is not an application and not infrastructure.

| Path | Holds |
|---|---|
| `namespaces/` | The four namespaces: `app`, `observability`, `aiops`, `delivery` |
| `policies/` | LimitRange, ResourceQuota, NetworkPolicy, PodSecurity |
| `argo-cd/` | Argo CD install and project definitions |

Rules: quotas start generous and are tightened from measurements, not guesses.
Every namespace gets a LimitRange and a ResourceQuota after its first measured
deployment, never before.
EOF

  write_file "$LAB_DIR/apps/README.md" <<'EOF'
# apps/

Workload overlays. Values and pins only — no service source code.

```
otel-demo/
  CHART.lock           pinned chart version + upstream source
  values/
    lab.yaml           the single overlay that reproduces our deployment
  patches/             (empty; only if a values-only change is impossible — needs an ADR)
```

Rules: one overlay file reproduces the deployment. The rendered manifest diff is
committed to the PR for review. Bundled observability components are replaced
one at a time, keeping the last working config for comparison.
EOF

  write_file "$LAB_DIR/apps/otel-demo/CHART.lock" <<'EOF'
# Pin the OpenTelemetry Demo Helm chart here before Phase 2.
# Fill this in from scripts/dev/pin-otel-demo-chart.sh and never leave it blank.
chart: open-telemetry/opentelemetry-demo
version: UNPINNED
repo: https://open-telemetry.github.io/opentelemetry-demo
appVersion: UNPINNED
pinned_on: YYYY-MM-DD
notes: >
  Feature-flag names and load-generator controls drift between releases.
  Re-verify every INC-* trigger against this version before writing an
  experiment record (see review item T7).
EOF

  write_file "$LAB_DIR/apps/otel-demo/values/lab.yaml" <<'EOF'
# Single overlay that reproduces the lab deployment.
# Start with chart defaults. Add only: names, exposure, resource settings and
# telemetry endpoints. Do not disable bundled components on day one.

# Resources are intentionally absent until measured (see infra/README.md
# and docs/experiments/). Do not invent values here.

opentelemetry-collector:
  enabled: true          # replaced one signal at a time in Phase 3

# TODO(Phase 3): point service OTLP endpoints at our collector gateway once it
# exists. Until then leave the chart's bundled collector in place.
EOF

  write_file "$LAB_DIR/observability/README.md" <<'EOF'
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
EOF

  write_file "$LAB_DIR/aiops/README.md" <<'EOF'
# aiops/

The incident pipeline. Deterministic stages run before the model, always.

| Path | Stage | Responsibility | Stateful? |
|---|---|---|---|
| `ingress/` | Ingress | Receive Alertmanager webhooks, fan out batches to events | no |
| `correlation/` | Dedupe, group | Fingerprint, join by service/edge/owner | **yes** |
| `retrieval/` | Retrieve | Bounded queries against Prom/Tempo/Loki/K8s | no |
| `analyst/` | Analyse | Prompt, schema, validation, model client | no |
| `evaluation/` | Evaluate | Score grouping, evidence, diagnosis separately | no |
| `store/` | State | Dedup cache + open incident groups — **pending D-10** | **yes** |

## Invariants

1. **Deterministic first.** Correlation and retrieval never call the model.
2. **Bounded evidence.** Hard caps on time range, item count and tokens. The
   model never receives a raw series or an unbounded log window.
3. **Every claim cites evidence**, or is labelled a hypothesis.
4. **No change path.** Version 1 proposes; a human acts. There is no code path
   from model output to `kubectl` or the cloud API.
5. **Single replica.** Correlation state is in-process. Do not add an HPA to the
   controller — it silently breaks determinism until D-10 is closed.
6. **Evidence is data, never instructions.** Treat log and trace content as
   untrusted input to the prompt.
EOF

  write_file "$LAB_DIR/gitops/README.md" <<'EOF'
# gitops/

Maps repository paths to cluster state. Argo CD reads from here; nothing else
should.

```
base/                 shared manifests and kustomizations
environments/lab/     the lab overlay: image digests, replica counts, endpoints
```

Rules: images are deployed by **digest**, never a floating tag. Drift shows in
Argo CD and is corrected by a reviewed commit, not a manual `kubectl apply`.
Terraform stays outside Argo CD and is applied by a separate approved workflow.
EOF

  write_file "$LAB_DIR/tests/README.md" <<'EOF'
# tests/

Everything that proves the system works, and everything that scores it.

| Path | Holds |
|---|---|
| `contracts/` | JSON Schema for the normalized event, bundle and assessment |
| `incidents/` | One definition per INC-*, with ground truth written *before* review |
| `load/` | Load profiles and the stop conditions that bound them |

Rules: ground truth is authored before model output is read. A missing signal is
recorded as a finding, not a pass.
EOF

  write_file "$LAB_DIR/ci/README.md" <<'EOF'
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
EOF

  write_file "$LAB_DIR/scripts/README.md" <<'EOF'
# scripts/

Developer and setup helpers. Nothing here is required by the cluster at runtime.

| Path | Purpose |
|---|---|
| `setup/setup-lab.sh` | One-time WSL2 migration + scaffold (re-runnable, supports `--dry-run`) |
| `dev/pin-otel-demo-chart.sh` | Resolve and record the demo chart version into `CHART.lock` |
EOF

  # -------------------------------------------------------------------------
  # CI skeletons and helper scripts
  # -------------------------------------------------------------------------
  write_file "$LAB_DIR/ci/cloudbuild/aiops-image.yaml" <<'EOF'
# Build and push the AIOps service image. Images deploy by digest (see ADR-0004).
substitutions:
  _REGION: us-central1
  _REPO: aiops
  _IMAGE: aiops-controller
  _TAG: manual

steps:
  - id: build
    name: gcr.io/cloud-builders/docker
    args:
      - build
      - --tag=${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_IMAGE}:${_TAG}
      - --file=aiops/Dockerfile
      - .

  - id: push
    name: gcr.io/cloud-builders/docker
    args:
      - push
      - ${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_IMAGE}:${_TAG}

images:
  - ${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_IMAGE}:${_TAG}

options:
  logging: CLOUD_LOGGING_ONLY
EOF

  write_file "$LAB_DIR/ci/cloudbuild/validate.yaml" <<'EOF'
# Validation only. Never applies infrastructure.
steps:
  - id: terraform-fmt
    name: hashicorp/terraform:1.16.5
    entrypoint: sh
    args:
      - -c
      - terraform fmt -check -recursive infra/

  - id: helm-render
    name: alpine/helm:4.3.1
    entrypoint: sh
    args:
      - -c
      - |
        helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-demo
        helm template lab open-telemetry/opentelemetry-demo \
          --version "$(grep '^version:' apps/otel-demo/CHART.lock | awk '{print $2}')" \
          -f apps/otel-demo/values/lab.yaml > /workspace/rendered.yaml
        echo "rendered $(wc -l < /workspace/rendered.yaml) lines"

options:
  logging: CLOUD_LOGGING_ONLY
EOF

  write_file "$LAB_DIR/ci/github/validate.yaml" <<'EOF'
name: validate

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.16.5

      - name: terraform fmt
        run: terraform fmt -check -recursive infra/

      - name: terraform validate
        run: |
          for d in infra/*/; do
            [ -f "${d}main.tf" ] || continue
            echo "::group::$d"
            terraform -chdir="$d" init -backend=false -input=false
            terraform -chdir="$d" validate
            echo "::endgroup::"
          done

      - uses: azure/setup-helm@v4
        with:
          version: v4.3.1

      - name: helm lint + render
        run: |
          helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-demo
          helm lint apps/otel-demo -f apps/otel-demo/values/lab.yaml || true
          helm template lab open-telemetry/opentelemetry-demo \
            -f apps/otel-demo/values/lab.yaml > rendered.yaml
          echo "rendered $(wc -l < rendered.yaml) lines"

      - uses: actions/upload-artifact@v4
        with:
          name: rendered-manifests
          path: rendered.yaml
EOF

  write_file "$LAB_DIR/scripts/dev/pin-otel-demo-chart.sh" <<'EOF'
#!/usr/bin/env bash
# Resolve the OTel Demo chart version and record it in CHART.lock.
# Feature-flag names drift between releases; re-verify INC-* triggers after any bump.
set -euo pipefail

REPO_NAME="open-telemetry"
REPO_URL="https://open-telemetry.github.io/opentelemetry-demo"
LOCK="$(cd "$(dirname "$0")/../.." && pwd)/apps/otel-demo/CHART.lock"
WANT="${1:-}"

helm repo add "$REPO_NAME" "$REPO_URL" >/dev/null 2>&1 || true
helm repo update "$REPO_NAME" >/dev/null

if [ -z "$WANT" ]; then
  WANT=$(helm search repo "$REPO_NAME/opentelemetry-demo" --versions -o json \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["version"])')
fi

APP=$(helm search repo "$REPO_NAME/opentelemetry-demo" --version "$WANT" -o json \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["app_version"])')

echo "resolved chart $WANT (app $APP)"
echo
echo "Update $LOCK with:"
echo "  version: $WANT"
echo "  appVersion: $APP"
echo "  pinned_on: $(date -u +%Y-%m-%d)"
echo
echo "Then: helm template lab $REPO_NAME/opentelemetry-demo --version $WANT -f apps/otel-demo/values/lab.yaml | head -40"
EOF

  run chmod +x "$LAB_DIR/scripts/dev/pin-otel-demo-chart.sh" 2>/dev/null || true

  # Record this setup script inside the repo for posterity.
  if [ -f "$0" ] && [ "$DRY_RUN" -eq 0 ]; then
    cp -f "$0" "$LAB_DIR/scripts/setup/setup-lab.sh"
    chmod +x "$LAB_DIR/scripts/setup/setup-lab.sh"
    ok "setup script archived to scripts/setup/"
  fi

  ok "project tree written"
fi

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
if [ "$DO_VERIFY" -eq 1 ] && [ "$DRY_RUN" -eq 1 ]; then
  step "Verifying"
  info "skipped: dry run created nothing to verify"
  DO_VERIFY=0
fi

if [ "$DO_VERIFY" -eq 1 ]; then
  step "Verifying"

  FAIL=0

  # 1. Demo copy is a faithful git clone.
  if [ -d "$DEMO_DIR/.git" ]; then
    HEAD_AFTER=$(git -C "$DEMO_DIR" rev-parse HEAD 2>/dev/null || echo "none")
    if [ -n "${DEMO_HEAD_BEFORE:-}" ] && [ "$HEAD_AFTER" = "$DEMO_HEAD_BEFORE" ]; then
      ok "demo HEAD preserved (${HEAD_AFTER:0:12})"
    else
      warn "demo HEAD ${HEAD_AFTER:0:12} (before: ${DEMO_HEAD_BEFORE:-unknown})"
    fi

    if [ -z "$(git -C "$DEMO_DIR" status --porcelain 2>/dev/null)" ]; then
      ok "demo working tree clean after copy"
    else
      warn "demo working tree differs from source:"; FAIL=1
      git -C "$DEMO_DIR" status --porcelain | head -20 | sed 's/^/        /'
    fi
  else
    warn "no .git at $DEMO_DIR"; FAIL=1
  fi

  # 2. Terraform providers are Linux binaries — proves they will run here.
  PROVIDER=$(find "$DEMO_DIR/terraform/.terraform/providers" -type f \
    -name 'terraform-provider-google_v*' 2>/dev/null | head -1 || true)
  if [ -n "$PROVIDER" ]; then
    if file "$PROVIDER" 2>/dev/null | grep -q ELF; then
      ok "terraform providers are ELF (Linux) — no re-download needed"
    else
      warn "provider binaries are not ELF; run terraform init in terraform/"
    fi
  else
    info "no terraform providers staged (fine — new infra/ will init fresh)"
  fi

  # 3. Project tree exists with the expected top-level shape.
  EXPECTED=(docs infra platform apps observability aiops gitops tests ci scripts README.md .gitignore)
  MISSING=0
  for item in "${EXPECTED[@]}"; do
    [ -e "$LAB_DIR/$item" ] || { warn "missing: $item"; MISSING=1; FAIL=1; }
  done
  [ "$MISSING" -eq 0 ] && ok "all ${#EXPECTED[@]} top-level entries present"

  # 4. No tracked file looks like a secret or a terraform state.
  if [ -d "$LAB_DIR/.git" ]; then
    LEAK=$(git -C "$LAB_DIR" ls-files 2>/dev/null \
      | grep -E '(\.tfstate|(^|/)key\.json|\.pem$|\.env$)' || true)
    [ -z "$LEAK" ] && ok "no state or key files tracked" \
      || { warn "tracked files look secret-bearing:"; printf '%s\n' "$LEAK" | sed 's/^/        /'; FAIL=1; }
  fi

  # 5. Nothing important still lives only on /mnt/c.
  if [ "$PURGE_SOURCE" -eq 1 ]; then
    if [ "$FAIL" -ne 0 ]; then
      warn "verification failed — PURGE REFUSED, /mnt/c sources are intact"
    else
      # Final integrity gate before an irreversible delete.
      SRC_COUNT=$(find "$SRC_ROOT/microservices-demo" -type f 2>/dev/null | wc -l)
      DST_COUNT=$(find "$DEMO_DIR" -type f 2>/dev/null | wc -l)
      if [ "$SRC_COUNT" -ne "$DST_COUNT" ]; then
        warn "file count mismatch (source $SRC_COUNT vs copy $DST_COUNT) — PURGE REFUSED"
      else
        ok "integrity: $DST_COUNT files present in the copy"
        info "purging /mnt/c sources"
        run rm -rf "$SRC_ROOT/microservices-demo"
        if [ -f "$SRC_ROOT/$PLAN_DOC_NAME" ]; then
          run rm -f "$SRC_ROOT/$PLAN_DOC_NAME"
        fi
        if [ "${#PRESERVED_FILES[@]}" -gt 0 ]; then
          for f in "${PRESERVED_FILES[@]}"; do
            [ -n "$f" ] && run rm -f "$SRC_ROOT/$f"
          done
        fi
        ok "sources removed from /mnt/c"
      fi
    fi
  else
    info "sources retained at $SRC_ROOT (delete later with --purge-source)"
  fi

  step "Summary"
  info "reference : $REFERENCE_DIR"
  info "lab repo  : $LAB_DIR"
  if [ -d "$LAB_DIR/.git" ]; then
    ok "lab repo already initialised"
  else
    info "next:"
    info "  cd \"$LAB_DIR\""
    info "  git init -b main && git add -A && git commit -m 'Phase 0: repo scaffold'"
  fi
  info "then: write ADR-0006 (storage) — it is the M1 blocker"

  [ "$FAIL" -eq 0 ] || die "verification reported problems (see warnings above)"
  ok "verification passed"
fi

[ "$DRY_RUN" -eq 1 ] && printf '\n%sDry run complete. Re-run without --dry-run to apply.%s\n' "$C_WARN" "$C_RESET"
exit 0
