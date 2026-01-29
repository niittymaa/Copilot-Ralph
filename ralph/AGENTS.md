# AGENTS.md

Operational guide for Ralph development. Keep brief (~60 lines).

## Build & Run

```bash
# PowerShell (Windows, macOS, Linux with pwsh)
./ralph/ralph.ps1                 # Auto mode (recommended)
./ralph/ralph.ps1 -Mode plan      # Planning only
./ralph/ralph.ps1 -Mode build     # Building only
./ralph/ralph.ps1 -DryRun         # Preview mode (no AI tokens spent)

# Bash (macOS, Linux)
./ralph/ralph.sh                  # Auto mode
./ralph/ralph.sh -m plan          # Planning only
```

## Validation

Run these after implementing to get immediate feedback:

- **Test:** `./ralph/tests/ralph.tests.ps1`
- **Lint:** Not configured
- **Build:** Not configured (PowerShell scripts don't compile)

## Key Files

| File | Purpose |
|------|---------|
| `ralph/ralph.ps1` | Main entry point |
| `ralph/core/loop.ps1` | Core orchestration (1303 lines) |
| `ralph/core/display.ps1` | UI/Display utilities |
| `ralph/core/statistics.ps1` | Git & session statistics |
| `ralph/core/specs.ps1` | Spec creation & management |
| `ralph/core/initialization.ps1` | File & state initialization |
| `ralph/agents/*.agent.md` | Agent prompts (source) |
| `ralph/templates/*` | First-run setup templates |
| `ralph/specs/*.md` | Ralph internal specs |
| `ralph/tests/*.ps1` | Test suite |

## Patterns

- **Completion signal**: `<promise>COMPLETE</promise>`
- **Planning complete**: `<promise>PLANNING_COMPLETE</promise>`
- **Spec created**: `<promise>SPEC_CREATED</promise>`
- **Task format**: `- [ ] Task` / `- [x] Done`
- **Template files**: Prefix with `_` to exclude from processing

## Codebase Structure

```
ralph/                      # Self-contained (copy to any project)
├── ralph.ps1               # Main entry (PowerShell)
├── ralph.sh                # Main entry (Bash)
├── init.ps1                # Project initialization
├── agents/                 # Agent prompts (copied to .github/agents/)
├── core/                   # Core modules (.ps1 + .sh pairs)
│   ├── loop.ps1/.sh        # Main orchestrator
│   ├── display.ps1         # UI and logging
│   ├── menus.ps1           # Menu system
│   ├── tasks.ps1/.sh       # Session management
│   ├── specs.ps1           # Specification handling
│   ├── presets.ps1/.sh     # Preset templates
│   ├── memory.ps1/.sh      # Cross-session memory
│   ├── statistics.ps1      # Git and session stats
│   ├── initialization.ps1  # File setup
│   ├── spinner.ps1/.sh     # Progress indicators
│   └── venv.ps1/.sh        # Python venv handling
├── cli/                    # Terminal UI framework (ps/ + sh/)
├── menus/                  # YAML menu definitions
├── presets/                # Pre-configured task templates
├── scripts/                # Utility scripts (.ps1 + .sh pairs)
└── tests/                  # Test suite
```

## Coding Standards

- PowerShell: Use `[CmdletBinding()]`, `Set-StrictMode -Version Latest`
- Bash: Use `set -euo pipefail`, quote variables
- Keep `.ps1` and `.sh` implementations in sync for cross-platform parity
- Test changes with `-DryRun` (PowerShell) before running live

## Operational Notes

- Ralph auto-creates `.github/agents/` from `ralph/agents/` on first run
- Sessions stored in `.ralph/tasks/<id>/`
- Memory system enabled by default (`.ralph/memory.md`)
