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
