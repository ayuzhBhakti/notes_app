# Notes app

Project context for AI agents lives in `docs/ai/` and is imported below. Human-readable docs are indexed in `docs/README.md`.

@docs/ai/AGENT_CONTEXT.md

## Documentation rule

After every task, before reporting it done:

1. Add an entry at the top of `docs/ai/TASK_LOG.md`.
2. Update every doc the change affects, using the table in `docs/README.md`.
3. Fix `docs/ai/AGENT_CONTEXT.md` if anything in it is no longer true.
4. Say in the final message which docs were updated.
