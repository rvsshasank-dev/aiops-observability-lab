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
