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
