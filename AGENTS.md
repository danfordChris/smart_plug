# AGENTS.md

Project agent instructions.

## Workflow Authority

- Canonical workflow policy: `ai/workflow-contract/spec/*`
- Repo adapter: `ai/workflow-contract/adapters/smart_plug.md`
- Canonical validator: `python3 ai/workflow-contract/scripts/validate_workflow.py`

## Start Here

1. Classify the task.
2. Run `python3 ai/workflow-contract/scripts/validate_workflow.py`.
3. Read `docs/design/domain/project-introduction.md`.
4. Read `docs/design/architecture/system-architecture.md` and `docs/design/architecture/security-and-recovery.md`.
5. Read `docs/design/integrations/sonoff-s60tpg.md`.
6. Read `docs/implementation/`.
7. If behavior is unresolved, read or create `docs/changes/proposed/`.
8. Load required repo skill(s).
9. Inspect target service code before editing.

## Documentation Workflow

Use `$documentation-framework` for:

- design docs
- implementation docs
- backlog, phase, task, and status updates
- proposed changes
- docs-vs-code reconciliation
- workflow validation failures

Layer rules:

- `docs/design/`: approved product/system truth.
- `docs/implementation/`: execution plans, phases, tasks, and status only.
- `docs/changes/proposed/`: unresolved proposals only.

Do not define net-new behavior in implementation docs. Put unresolved behavior in `docs/changes/proposed` until accepted.
