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
