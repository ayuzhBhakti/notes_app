# Notes app

Read `docs/ai/AGENT_CONTEXT.md` before making changes. It holds the project context, the rules that break things if ignored, and the commands to run. Human-readable docs are indexed in `docs/README.md`.

## Documentation rule

After every task, before reporting it done:

1. Add an entry at the top of `docs/ai/TASK_LOG.md`.
2. Update every doc the change affects, using the table in `docs/README.md`.
3. Fix `docs/ai/AGENT_CONTEXT.md` if anything in it is no longer true.
4. Say in the final message which docs were updated.
