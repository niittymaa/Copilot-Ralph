---
description: 'Ralph orchestrator instructions - AI coding agent configuration'
applyTo: '**/*'
---

# Ralph Instructions

This project uses Ralph - an autonomous AI coding agent orchestrator for GitHub Copilot CLI.

## Running Ralph

```bash
./ralph/ralph.ps1              # Auto mode (recommended)
./ralph/ralph.ps1 -Mode plan   # Planning only
./ralph/ralph.ps1 -Mode build  # Building only
./ralph/ralph.ps1 -Mode sessions  # Session management
```

## Key Paths

| Path | Purpose |
|------|---------|
| `specs/*.md` | Feature specifications (source of truth) |
| `.ralph/tasks/<id>/*` | Session-specific files (Ralph manages) |
| `.ralph/active-task` | Current session ID (Ralph manages) |
| `.github/agents/*.agent.md` | Agent prompts (auto-generated) |

## Completion Patterns

When completing Ralph tasks, use these signals:

- `<promise>COMPLETE</promise>` - Task completed
- `<promise>PLANNING_COMPLETE</promise>` - Planning phase done
- `<promise>SPEC_CREATED</promise>` - Specification created
- `<promise>AGENTS_UPDATED</promise>` - AGENTS.md updated

## Task Format

- Pending: `- [ ] Task description`
- Complete: `- [x] Task description`
- Template files: Prefix with `_` (e.g., `_example.template.md`)

## Boundaries

- Do not modify files in `ralph/` (orchestrator internals)
- Create specs in `specs/` folder
- Session files are managed by Ralph in `.ralph/`
