# Configuration evals

Regression tests for the **agent's configuration** (`AGENTS.md`/`CLAUDE.md`, `.claude/**`,
these evals) — the `sdlc-evals` play. Each eval replays a real task from an older commit with
the *current* configuration and checks the outcome still meets the bar, so trimming a rule or a
skill that silently backed up a behavior gets caught before merge.

## Status: starter (manual only)

The workflow [`/.github/workflows/agent-evals.yml`](../.github/workflows/agent-evals.yml) runs
**only on demand** (`workflow_dispatch`) today, so it never blocks a PR before it can work. To
turn it on properly:

1. Add an `ANTHROPIC_API_KEY` repo secret (Settings → Secrets → Actions) with eval budget.
2. Write 20–50 real cases (see below); keep [`example-merge-sort.json`](example-merge-sort.json)
   as the template.
3. Enable the `pull_request` + `schedule` triggers in the workflow (commented there) and add the
   Dependabot guard to the job, then make it a required check.

## Writing an eval

One `evals/<name>.json` per case (schema in the `sdlc-evals` skill):

- `from` — the commit *before* the original change, so the run sees the code as it stood then.
- `prompt` — the request as a user would phrase it; tell it to run `make test`.
- `may_change` — paths the agent is allowed to touch; `check.sh` fails the run if it strays.
- `checks` — behavior checks (`make test`, "no existing test weakened", a policy script) over
  text greps.

Grade one locally before trusting CI: it must PASS against the known-good change and FAIL
against a deliberately bad one. The grader is [`check.sh`](check.sh).
