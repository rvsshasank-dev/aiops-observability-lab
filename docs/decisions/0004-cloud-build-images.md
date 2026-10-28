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
