# 🤖 Copilot-Ralph

![Ralph](ralph/COPILOT-RALPH.jpg)

*"Me fail English? That's unpossible!"* — Ralph Wiggum

Autonomous AI coding agent framework for GitHub Copilot CLI using the Ralph Loop methodology.

Ralph runs AI coding agents in continuous iterations—reading specs, creating plans, implementing tasks, validating, and continuing until complete. Each iteration uses fresh context to maintain AI performance.

### Game demo built with Copilot Ralph:
[![Ralph VideoPreview Demo](https://img.youtube.com/vi/MS8qW55yjXg/maxresdefault.jpg)](https://www.youtube.com/watch?v=MS8qW55yjXg)

---

## ⚠️ Disclaimer

**USE AT YOUR OWN RISK**

Ralph autonomously modifies your codebase:
- Always use Git version control
- Review changes carefully
- Start with small, non-critical tasks
- Monitor execution

**Filesystem Access:** By default, Ralph grants Copilot CLI unrestricted filesystem access (`--allow-all-paths`) to enable autonomous operation across directories. This means the AI agent can read and write files **anywhere on your system**. You can restrict this in `ralph/config.json` by setting `allow_all_paths` to `false` and using `additional_dirs` to whitelist specific directories instead.

**Token Usage Warning:** Continuous autonomous loops consume significant AI tokens. Complex projects may require 20-50+ iterations. Monitor your GitHub Copilot usage and billing.

---

## Prerequisites

```bash
# Install GitHub Copilot CLI
npm install -g @github/copilot

# Authenticate
copilot auth

# Verify
copilot --version
```

Requires active GitHub Copilot subscription (Pro, Pro+, Business, or Enterprise).

---

## Quick Start

### One-Line Install (Recommended)

Run this at the root of any project to install and start Ralph:

**PowerShell (Windows/macOS/Linux):**
```powershell
irm https://raw.githubusercontent.com/niittymaa/Copilot-Ralph/main/install.ps1 | iex
```

**Bash (Linux/macOS/WSL):**
```bash
curl -fsSL https://raw.githubusercontent.com/niittymaa/Copilot-Ralph/main/install.sh | bash
```

This downloads only the `ralph/` folder into your project, sets up update tracking, and starts Ralph automatically.

#### Install Options

| Option | PowerShell | Bash |
|--------|-----------|------|
| Install only (don't start) | `iex "& { $(irm .../install.ps1) } -NoStart"` | `curl ... \| bash -s -- --no-start` |
| Force (skip prompts) | `iex "& { $(irm .../install.ps1) } -Force"` | `curl ... \| bash -s -- --force` |

### Manual Install

| Step | Action | Command |
|------|--------|---------|
| 1 | Copy `ralph/` folder to your project | Manual copy |
| 2 | Run Ralph | `./ralph/ralph.ps1` or `./ralph/ralph.sh` |

First run auto-creates `.github/instructions/`, `.github/agents/`, and `.ralph/`.

---

## Basic Commands

### PowerShell (Windows/macOS/Linux)

| Command | Function |
|---------|----------|
| `./ralph/ralph.ps1` | Auto mode: session menu → plan → build |
| `./ralph/ralph.ps1 -Mode continue` | Continue with spec menu |
| `./ralph/ralph.ps1 -Mode plan` | Plan only |
| `./ralph/ralph.ps1 -Mode build` | Build only (skip planning) |
| `./ralph/ralph.ps1 -Mode sessions` | Session management |
| `./ralph/ralph.ps1 -Mode benchmark` | Run Tetris benchmark |
| `./ralph/ralph.ps1 -Mode agents` | Update AGENTS.md |
| `./ralph/ralph.ps1 -NewSession "Name"` | Create new session |
| `./ralph/ralph.ps1 -Session "id"` | Switch session |
| `./ralph/ralph.ps1 -DryRun` | Preview (no tokens/changes) |
| `./ralph/ralph.ps1 -Model <name>` | Specify AI model |
| `./ralph/ralph.ps1 -ListModels` | Show available models |
| `./ralph/ralph.ps1 -MaxIterations N` | Limit iterations |
| `./ralph/ralph.ps1 -ShowVerbose` | Detailed output |
| `./ralph/ralph.ps1 -Memory status/on/off` | Memory system control |
| `./ralph/ralph.ps1 -CheckUpdate` | Check for updates |
| `./ralph/ralph.ps1 -Update` | Apply updates |

### Bash (Linux/macOS/WSL)

Same functionality with different syntax:
- `-m` for Mode (e.g., `-m plan`, `-m build`, `-m agents`)
- `-M` for Model
- `-L` for ListModels
- `-n` for MaxIterations
- `-V` for ShowVerbose
- `--memory` for Memory
- `--new-session` for NewSession
- `--session` for Session
- `--check-update` for CheckUpdate
- `--update` for Update

---

## Writing Specifications

### Option 1: Ralph-Assisted (Recommended)

Run Ralph without specs. Choose:
- **Interview Mode**: Focused Q&A
- **Quick Mode**: Single-prompt description

### Option 2: Manual

Create `.md` files in `ralph/specs/`:

```markdown
# Feature Name

## Overview
What you're building.

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Technical Requirements
- Requirement 1
- Requirement 2

## Out of Scope
- What's NOT included
```

See `ralph/specs/_example.template.md` for full template.

---

## Project Boilerplate Wizard

Create new projects from scratch with guided setup.

### Access

Select **[B] Project Boilerplate Wizard** from session menu.

### Platforms

- 🌐 Web Application
- ⚡ API / Backend
- 💻 Command-Line Tool
- 🖥️ Desktop Application
- 📱 Mobile Application
- 🔧 Full-Stack
- 📦 Library / Package

### Sample Stacks

- React + TypeScript
- Vue 3 + TypeScript
- Next.js
- Node + Express
- Python + FastAPI
- Python CLI
- Electron + React
- 30+ more presets

### Company-Inspired Stacks

Facebook, X (Twitter), Instagram, Reddit, Discord, GitHub, Spotify, Netflix, Slack, Notion, Figma, Uber, Airbnb, Tinder architectures.

### Custom Mode

Select individual technologies:
- Language: JavaScript, TypeScript, Python, Go, Rust, C#, Dart
- Framework: React, Vue, Express, FastAPI, Django, etc.
- UI: Tailwind, shadcn/ui, Material UI, Bootstrap
- Database: SQLite, PostgreSQL, MongoDB, Prisma, Drizzle
- Testing: Vitest, Jest, pytest, Playwright, Cypress
- Build Tools: Vite, Webpack, tsup, Poetry
- Linting: ESLint, Prettier, Ruff, Black

---

## Spec Presets

Ready-to-use specifications in `ralph/presets/`:

| Priority | Preset | Description |
|----------|--------|-------------|
| 🔥 5 | Security Hardening | Adversarial security audit |
| ♿ 6 | Accessibility Audit | WCAG compliance |
| 🌍 6 | Internationalization | i18n support |
| 🗄️ 7 | Database Migration | Schema migration with rollback |
| ⚡ 7 | Performance Optimization | Bottleneck resolution |
| ✅ 8 | Test Coverage | Coverage improvement |
| 🔧 10 | Code Refactoring | Professional standards |
| 🧹 15 | Codebase Cleanup | Remove redundancy, modernize |
| 🔍 20 | Project Structure Analysis | Architecture blueprint |
| 📚 25 | Project Documentation | Comprehensive markdown docs |
| 🔬 30 | Competitor Analysis | Research competitors |
| 📋 35 | Functions & Classes Listing | Complete API reference |

Lower priority numbers = higher priority tasks.

---

## Reference Files

Ralph analyzes specs, images (wireframes/mockups), and structured data for planning.

### Usage

Session menu → **[R] Use existing references**

### Supported Types

- 📄 Text/Markdown: `.md`, `.txt`, `.markdown`
- 📊 Structured Data: `.json`, `.yaml`, `.yml`, `.xml`, `.csv`, `.toml`
- 🖼️ Images: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`
- 💻 Code: `.py`, `.js`, `.ts`, `.ps1`, `.cs`, `.java`, `.go`, etc.

Images analyzed for UI structure, interactions, and functionality.

---

## Sessions

Isolated project contexts with independent plans, progress, and specs.

### Commands

```powershell
./ralph/ralph.ps1                              # Session selection menu
./ralph/ralph.ps1 -Mode sessions               # Interactive management
./ralph/ralph.ps1 -NewSession "Todo App"       # Create new
./ralph/ralph.ps1 -Session "todo-app-123456"   # Switch existing
```

### Modes

- **Isolated** (default): Session-specific `specs/` folder
- **Shared**: Uses `ralph/specs/` across sessions

### Structure

```
.ralph/
├── active-task           # Current session ID
├── memory.md             # Cross-session learnings
├── settings.json         # Memory enabled/disabled
└── tasks/
    └── <session-id>/
        ├── task.json              # Metadata
        ├── IMPLEMENTATION_PLAN.md # Plan
        ├── progress.txt           # Progress log
        └── specs/                 # Isolated specs (optional)
```

---

## Memory System

Cross-session knowledge persistence in `.ralph/memory.md`.

### Benefits

- Accumulate knowledge over time
- Avoid repeated mistakes
- Maintain consistent patterns
- Store working commands

### Sections

- **Patterns**: Code conventions, best practices
- **Commands**: Build, test, lint commands
- **Gotchas**: Pitfalls, edge cases
- **Decisions**: Architectural choices

### Commands

```powershell
./ralph/ralph.ps1 -Memory status   # Show status
./ralph/ralph.ps1 -Memory on       # Enable
./ralph/ralph.ps1 -Memory off      # Disable
```

Enabled by default. Manually edit `.ralph/memory.md` to add entries.

---

## Checkpoint & Recovery

Automatic checkpoints at key points:
- Before each phase
- After task completion
- On errors

Recovery menu appears after interruption:
- **[R]** Resume from checkpoint
- **[F]** Start fresh
- **[Q]** Quit

Checkpoint location: `.ralph/tasks/<session-id>/checkpoint.json`

---

## Project Structure

```
your-project/
├── ralph/                          # Self-contained framework (copy this)
│   ├── ralph.ps1                   # PowerShell entry point
│   ├── ralph.sh                    # Bash entry point
│   ├── init.ps1                    # State reset
│   ├── agents/                     # Agent prompts
│   │   ├── ralph.agent.md
│   │   ├── ralph-planner.agent.md
│   │   ├── ralph-spec-creator.agent.md
│   │   └── ralph-agents-updater.agent.md
│   ├── core/                       # 27 core modules
│   │   ├── loop.ps1 / loop.sh
│   │   ├── tasks.ps1 / tasks.sh
│   │   ├── display.ps1
│   │   ├── initialization.ps1
│   │   ├── statistics.ps1
│   │   ├── spinner.ps1 / spinner.sh
│   │   ├── venv.ps1 / venv.sh
│   │   ├── memory.ps1 / memory.sh
│   │   ├── dryrun.ps1
│   │   ├── specs.ps1
│   │   ├── presets.ps1 / presets.sh
│   │   ├── references.ps1
│   │   ├── boilerplate.ps1
│   │   ├── menus.ps1
│   │   ├── recovery.ps1
│   │   ├── checkpoint.ps1
│   │   ├── errors.ps1
│   │   ├── update.ps1
│   │   ├── logging.ps1
│   │   ├── github-auth.ps1
│   │   └── pathutils.ps1
│   ├── cli/                        # Zero-dependency CLI framework
│   │   ├── ps/                     # PowerShell implementation
│   │   └── sh/                     # POSIX shell implementation
│   ├── menus/                      # YAML menu definitions
│   ├── optimizer/                  # Benchmarking framework
│   │   ├── optimizer.ps1
│   │   └── benchmark.ps1
│   ├── scripts/                    # Utilities
│   │   ├── fork.ps1 / fork.sh
│   │   └── reset-to-upstream.ps1 / reset-to-upstream.sh
│   ├── templates/                  # Setup templates
│   ├── tests/                      # Test suite (184 tests)
│   │   └── ralph.tests.ps1
│   ├── specs/                      # Default/shared specs
│   ├── presets/                    # Preset specifications
│   ├── boilerplates/               # Project templates
│   └── references/                 # Reference materials
├── .github/                        # Auto-created by Ralph
│   ├── agents/                     # Agent prompts (copied from ralph/agents/)
│   └── instructions/
│       └── ralph.instructions.md   # Ralph config
├── .ralph/                         # Runtime data (gitignored)
│   ├── active-task
│   ├── memory.md
│   ├── settings.json
│   ├── upstream.json               # Fork tracking
│   ├── venv/                       # Python environment
│   └── tasks/                      # Session data
└── AGENTS.md                       # Operational guide (optional)
```

---

## AI Models

### Available Models

| Provider | Model | Type |
|----------|-------|------|
| Anthropic | claude-sonnet-4.5 | Default |
| Anthropic | claude-sonnet-4 | Standard |
| Anthropic | claude-haiku-4.5 | Fast/cheap |
| Anthropic | claude-opus-4.6 | Premium |
| Anthropic | claude-opus-4.6-fast | Premium |
| Anthropic | claude-opus-4.5 | Premium |
| OpenAI | gpt-5.2-codex | Standard |
| OpenAI | gpt-5.1-codex | Standard |
| OpenAI | gpt-4.1 | Fast/cheap |
| Google | gemini-3-pro-preview | Standard |

### Usage

```powershell
./ralph/ralph.ps1 -ListModels        # Show all models
./ralph/ralph.ps1 -Model <name>      # Use specific model
```

Press **[M]** at startup to change model interactively.

---

## Optimizer & Benchmarking

Systematically test agent configurations using standardized Tetris game spec.

### Commands

```powershell
./ralph/optimizer/benchmark.ps1                  # Standard (15 iterations)
./ralph/optimizer/benchmark.ps1 -Quick           # Quick (5 iterations)
./ralph/optimizer/benchmark.ps1 -KeepProject     # Keep generated project
./ralph/optimizer/benchmark.ps1 -Compare         # Compare history
./ralph/optimizer/benchmark.ps1 -Model <name>    # Specific model
```

### Metrics

**Structure (40%)**: File separation, directory organization, modules  
**Code (30%)**: Lines, functions, function length, comments  
**Quality (20%)**: Test files, coverage ratio  
**Efficiency (10%)**: Iteration count, task completion rate

### Grades

| Score | Grade |
|-------|-------|
| 90+ | A+ (Excellent) |
| 80-89 | A (Great) |
| 70-79 | B (Good) |
| 60-69 | C (Acceptable) |
| 50-59 | D (Needs Work) |
| <50 | F (Poor) |

### Advanced Optimizer

```powershell
./ralph/optimizer/optimizer.ps1 -Mode metrics -ProjectPath "path"  # Analyze
./ralph/optimizer/optimizer.ps1 -Mode baseline                     # Baseline
./ralph/optimizer/optimizer.ps1 -Mode optimize -MaxExperiments 5   # Optimize
./ralph/optimizer/optimizer.ps1 -Mode analyze                      # Compare
```

Results stored in `ralph/optimizer/results/`.

---

## CLI Framework

Zero-dependency terminal UI framework.

### Features

- Arrow-key navigation
- Multi-select checkboxes
- Hotkey support ([Q]uit, [B]ack)
- Scrollable menus
- Progress bars
- Text/password/number input
- Color support (16/256/TrueColor ANSI)
- Cross-platform (PowerShell 7+, POSIX sh)

### Modules

**PowerShell (`ralph/cli/ps/`)**:
- `api.ps1` - Unified API
- `colorUtils.ps1` - Color/formatting
- `keyReader.ps1` - Keyboard input
- `screenManager.ps1` - Cursor/viewport
- `menuRenderer.ps1` - Single-select
- `multiSelect.ps1` - Multi-checkbox
- `inputHandler.ps1` - Text input
- `globalKeyHandler.ps1` - Global hotkeys

**Shell (`ralph/cli/sh/`)**: Parallel POSIX implementations

### Menu System

YAML-based declarative menus in `ralph/menus/*.yaml`:
- Breadcrumb navigation
- Back button support
- Dynamic visibility
- Template variables
- Consistent UX

Platform support: Windows Terminal, iTerm2, Terminal.app, xterm, GNOME Terminal, Konsole, tmux, screen.

---

## Python Virtual Environment

Automatic Python venv creation at `.ralph/venv/` (gitignored).

| Mode | Behavior |
|------|----------|
| `auto` (default) | Creates/uses venv |
| `skip` | Uses system Python |
| `reset` | Deletes and recreates venv |

```powershell
./ralph/ralph.ps1 -Venv auto    # Default
./ralph/ralph.ps1 -Venv skip    # System Python
./ralph/ralph.ps1 -Venv reset   # Fresh venv
```

---

## Configuration

Settings in `ralph/config.json` (auto-created on first run, gitignored):

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `verbose_mode` | `bool` | `true` | Show detailed output and debug information |
| `developer_mode` | `bool` | `false` | Keep screen history between menus |
| `venv_mode` | `string` | `"auto"` | Python venv: `auto`, `always`, or `disabled` |
| `allow_all_paths` | `bool` | `true` | Grant Copilot CLI unrestricted filesystem access |
| `additional_dirs` | `string[]` | `[]` | Specific directories to grant access to via `--add-dir` |

### Path Permissions

By default, `allow_all_paths` is `true` so Ralph operates autonomously without "Permission denied" errors when accessing files outside the workspace (e.g., reference projects, shared documentation).

**To restrict access**, set `allow_all_paths` to `false` and optionally whitelist specific directories:

```json
{
  "allow_all_paths": false,
  "additional_dirs": ["D:\\Git\\other-project", "C:\\shared\\docs"]
}
```

See `ralph/config.example.json` for a fully documented template.

---

## Utility Scripts

### Fork Management

Create Ralph-powered projects:

```powershell
./ralph/scripts/fork.ps1              # Interactive
./ralph/scripts/fork.ps1 -Name my-app # Named fork
```

Creates fork on GitHub, clones to `.ralph/forks/<name>/`, saves upstream URL, opens in VS Code.

### Reset Fork to Upstream

Reset fork to match upstream exactly:

```powershell
./ralph/scripts/reset-to-upstream.ps1                        # Interactive
./ralph/scripts/reset-to-upstream.ps1 -UpstreamUrl <url>     # Manual URL
./ralph/scripts/reset-to-upstream.ps1 -Force                 # Skip confirmation
./ralph/scripts/reset-to-upstream.ps1 -Branch develop        # Specific branch
```

**Warning**: Permanently deletes all local changes.

Auto-detects upstream from `.ralph/upstream.json` or Git remote.

---

## Self-Update System

Update Ralph from upstream while preserving project files.

```powershell
./ralph/ralph.ps1 -CheckUpdate   # Check availability
./ralph/ralph.ps1 -Update        # Apply updates
```

Updates `ralph/` folder only. Preserves all project files outside `ralph/`.

Upstream detection order:
1. `.ralph/upstream.json` (GitHub forks)
2. `.ralph/source.json` (local copies)
3. Git remote 'upstream'
4. Default: `https://github.com/niittymaa/Copilot-Ralph.git`

---

## Testing

Comprehensive test suite (184 tests):

```powershell
./ralph/tests/ralph.tests.ps1          # Run all tests
./ralph/tests/ralph.tests.ps1 -Verbose # Detailed output
```

Coverage:
- File structure validation
- Mode parsing
- Agent prompt extraction
- Signal detection
- Utility functions
- Documentation consistency

---

## Copilot CLI Integration

Ralph uses native GitHub Copilot CLI with specific flags:

| Flag | Purpose |
|------|---------|
| `--allow-all-tools` | Non-interactive autonomous operation |
| `--allow-all-paths` | Unrestricted filesystem access (default: enabled) |
| `--add-dir <path>` | Grant access to specific additional directories |
| `-p <prompt>` | Programmatic mode |
| `--model <model>` | Specify AI model |
| `--agent <name>` | Use custom agent from `.github/agents/` |

`--allow-all-tools` is native Copilot CLI feature enabling autonomous tool usage without confirmation prompts.

`--allow-all-paths` is enabled by default so Ralph can operate autonomously across directories (e.g., reading reference files from other projects). Disable in `config.json` if you need restricted access.

---

## Core Principles

1. **Fresh Context Each Iteration**: Prevents AI confusion
2. **Backpressure Is Critical**: Tests must pass before completion
3. **Small Steps Only**: One task per iteration
4. **File-Based State**: All memory in files
5. **Let Ralph Ralph**: Trust the loop, observe and tune

---

## Validation Configuration

Add build/test commands to `AGENTS.md`:

```markdown
## Validation

- **Lint:** `npm run lint`
- **Test:** `npm test`
- **Build:** `npm run build`
```

Ralph runs these after each implementation.

---

## The Ralph Loop

```
🔄 Pick Task → 🔨 Implement → ✅ Validate → 📦 Commit → 🧹 Clear Context → 🔄 Repeat
```

File-based memory persists learnings via `progress.txt`. Backpressure (tests/lints/builds) forces self-correction.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Copilot CLI not found" | `npm install -g @github/copilot` then `copilot auth` |
| "Permission denied" from Copilot | Ensure `allow_all_paths` is `true` in `ralph/config.json` (default), or add specific dirs to `additional_dirs` |
| "Agent file not found" | Ensure `.github/agents/ralph.agent.md` exists |
| Nothing changed | Check `progress.txt` |
| Stuck in loop | Break large tasks into smaller ones in `IMPLEMENTATION_PLAN.md` |
| Appears hung | Press Ctrl+C |
| Python venv not creating | Verify Python 3: `python --version` |
| Tests failing | Run `./ralph/tests/ralph.tests.ps1` |

---

## Custom Agents

Located in `.github/agents/`:

| Agent | File | Purpose |
|-------|------|---------|
| ralph | `ralph.agent.md` | Main building agent |
| ralph-planner | `ralph-planner.agent.md` | Planning/gap analysis |
| ralph-spec-creator | `ralph-spec-creator.agent.md` | Spec creation/interview |
| ralph-agents-updater | `ralph-agents-updater.agent.md` | Auto-update AGENTS.md |

Invoke in Copilot Chat:
```
@ralph Implement the next task from IMPLEMENTATION_PLAN.md
```

---

## Session Logging

Automatic logging per session at `.ralph/tasks/<session-id>/session.log`.

Captures:
- Command executions
- AI model interactions
- File operations
- Errors and warnings
- Operation timestamps

---

## References

Ralph Loop methodology created by **Geoffrey Huntley**.

| Resource | Link |
|----------|------|
| Original Ralph | [ghuntley.com/ralph](https://ghuntley.com/ralph/) |
| Ralph Playbook | [claytonfarr.github.io/ralph-playbook](https://claytonfarr.github.io/ralph-playbook/) |
| Playbook Repo | [github.com/ClaytonFarr/ralph-playbook](https://github.com/ClaytonFarr/ralph-playbook) |
| Alternative Implementation | [github.com/snarktank/ralph](https://github.com/snarktank/ralph) |
| Video Walkthrough | [YouTube](https://www.youtube.com/watch?v=yAE3ONleUas) |
| GitHub Custom Agents | [GitHub Blog](https://github.blog/changelog/2025-10-28-custom-agents-for-github-copilot/) |

---

## License

MIT License - Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
