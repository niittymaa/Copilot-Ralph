# 🤖 Copilot-Ralph

![Ralph](ralph/COPILOT-RALPH.jpg)

> *"Me fail English? That's unpossible!"* — Ralph Wiggum

An autonomous AI coding agent for **GitHub Copilot CLI** using the **Ralph Loop** methodology.

Ralph runs AI coding agents in a continuous loop—reading specs, creating plans, implementing tasks one at a time, validating, and continuing until everything is done. Each iteration uses fresh context to keep AI in its "smart zone".

---

## ⚠️ Important Disclaimer

> **USE AT YOUR OWN RISK**
>
> Ralph is an autonomous AI coding agent that makes real changes to your codebase. While designed to be helpful, you should:
>
> - ✅ **Always use version control (Git)** - Commit your work before running Ralph
> - ✅ **Review changes carefully** - Ralph will modify, create, and sometimes delete files
> - ✅ **Start with small tasks** - Test Ralph on non-critical projects first
> - ✅ **Monitor the process** - Watch what Ralph is doing, especially initially
>
> **💰 Token Usage Warning**
>
> Ralph runs in a continuous autonomous loop, which means:
> - 🔄 **High token consumption** - Each iteration calls AI models (can be expensive)
> - ⏱️ **Long-running sessions** - Complex projects may need dozens of iterations
> - 💵 **Cost can add up quickly** - Monitor your GitHub Copilot usage and billing
> - 🎯 **Use `-MaxIterations`** to limit costs while testing
>
> Estimate: A typical project might use 20-50 iterations. Each iteration consumes tokens equivalent to a full AI conversation. Plan accordingly!

---

## 🚀 Quick Start (Step by Step)

### 📋 Prerequisites

> ⚠️ **You need these before starting!**

```bash
# 1️⃣ Install GitHub Copilot CLI
npm install -g @github/copilot

# 2️⃣ Log in to your GitHub account
copilot auth

# 3️⃣ Make sure it works
copilot --version
```

✅ Requires an active GitHub Copilot subscription (Pro, Pro+, Business, or Enterprise).

---

### 🎯 Step-by-Step Setup

| Step | What to Do                               | Command/Action                            |
|:----:|------------------------------------------|-------------------------------------------|
| 1️⃣  | **Copy `ralph/` folder** to your project | Just copy the folder!                     |
| 2️⃣  | **Run Ralph!**                           | `./ralph/ralph.ps1` or `./ralph/ralph.sh` |

> On first run, Ralph automatically creates `.github/instructions/`, `.github/agents/`, and `.ralph/`. Specs are in `ralph/specs/`. AGENTS.md is optional.

---

### 🎬 What Happens When You Run Ralph?

```
┌─────────────────────────────────────────────────────────────┐
│  🟢 START: ./ralph/ralph.ps1                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🔧 First run? ──▶  Auto-creates project structure          │
│                                                             │
│  📂 Session?   ──▶  Select existing or create new session   │
│                                                             │
│  📋 Auto mode  ──▶  Ralph updates AGENTS.md from codebase   │
│                                                             │
│  📁 No specs?  ──▶  Ralph asks: "What do you want to build?"│
│                                                             │
│  📝 Has specs? ──▶  Ralph creates a plan automatically      │
│                                                             │
│  🔨 Has plan?  ──▶  Ralph builds task by task               │
│                                                             │
│  ✅ All done?  ──▶  Ralph stops and says "COMPLETE!"        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📖 Basic Commands

### PowerShell (Windows) 🪟

| Command                                | What It Does                                                        |
|----------------------------------------|---------------------------------------------------------------------|
| `./ralph/ralph.ps1`                    | 🚀 **Auto mode** - Shows session menu, plans if needed, then builds |
| `./ralph/ralph.ps1 -Mode continue`     | 🔄 **Continue project** - Shows spec menu (use existing or add new) |
| `./ralph/ralph.ps1 -Mode plan`         | 📝 Only create/update the plan                                      |
| `./ralph/ralph.ps1 -Mode build`        | 🔨 Only build (skip planning)                                       |
| `./ralph/ralph.ps1 -Mode sessions`     | 📂 **Session management** - List, switch, create, delete sessions   |
| `./ralph/ralph.ps1 -Mode benchmark`    | 📊 **Run benchmark** - Test Ralph quality with Tetris spec          |
| `./ralph/ralph.ps1 -NewSession "Name"` | ➕ Create a new session and switch to it                             |
| `./ralph/ralph.ps1 -Session "id"`      | 🔀 Switch to an existing session                                    |

### Bash (Linux/macOS/WSL) 🐧

| Command                                 | What It Does                                                        |
|-----------------------------------------|---------------------------------------------------------------------|
| `./ralph/ralph.sh`                      | 🚀 **Auto mode** - Shows session menu, plans if needed, then builds |
| `./ralph/ralph.sh -m continue`          | 🔄 **Continue project** - Shows spec menu (use existing or add new) |
| `./ralph/ralph.sh -m plan`              | 📝 Only create/update the plan                                      |
| `./ralph/ralph.sh -m build`             | 🔨 Only build (skip planning)                                       |
| `./ralph/ralph.sh -m sessions`          | 📂 **Session management** - List, switch, create, delete sessions   |
| `./ralph/ralph.sh -m benchmark`         | 📊 **Run benchmark** - Test Ralph quality with Tetris spec          |
| `./ralph/ralph.sh --new-session "Name"` | ➕ Create a new session and switch to it                             |
| `./ralph/ralph.sh --session "id"`       | 🔀 Switch to an existing session                                    |

---

## ✍️ Writing Specifications

You can create specs in two ways:

### 🎤 Option 1: Let Ralph Help (Recommended)

Run `./ralph/ralph.ps1` (or `./ralph/ralph.sh`) without any specs. Ralph will offer:

| Mode                   | Description                                                   |
|------------------------|---------------------------------------------------------------|
| 🎙️ **Interview Mode** | Ralph asks focused questions to understand your feature       |
| ⚡ **Quick Mode**       | Describe your feature in one prompt, Ralph generates the spec |

### ✏️ Option 2: Write Manually

Create markdown files in `ralph/specs/` (files starting with `_` are treated as templates and ignored):

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

📄 See `ralph/specs/_example.template.md` for a full template.

---

## 🏗️ Project Boilerplate Wizard

The **Boilerplate Wizard** helps you create new projects from scratch with a guided, step-by-step setup. It's perfect for starting fresh with industry-standard tech stacks.

### Starting the Wizard

When you run Ralph, select **[B] Project Boilerplate Wizard** from the session menu:

```
═══════════════════════════════════════════════════════════════
  RALPH - SESSION SELECTION
═══════════════════════════════════════════════════════════════

  [N] New session (fresh start)
  [B] Project Boilerplate Wizard      ← Start here for new projects!
  [P] Start from preset
  [Q] Quit
```

### How It Works

The wizard guides you through 4 simple steps:

| Step | What You Choose |
|:----:|-----------------|
| 1️⃣ | **Target Platform** - Web, API, CLI, Desktop, Mobile, Full-Stack, or Library |
| 2️⃣ | **Configuration Mode** - Preset Stack or Custom (pick technologies one by one) |
| 3️⃣ | **Tech Stack** - Choose from popular combinations or build your own |
| 4️⃣ | **Review & Confirm** - See summary and start building |

### Available Platforms

| Platform | Description |
|----------|-------------|
| 🌐 **Web Application** | Browser-based apps (SPA, SSR, static sites) |
| ⚡ **API / Backend** | REST APIs, GraphQL servers, microservices |
| 💻 **Command-Line Tool** | Terminal applications and scripts |
| 🖥️ **Desktop Application** | Native or cross-platform desktop apps |
| 📱 **Mobile Application** | iOS, Android, or cross-platform mobile |
| 🔧 **Full-Stack** | Combined frontend and backend |
| 📦 **Library / Package** | Reusable npm, PyPI, NuGet packages |

### Popular Tech Stacks

Each preset includes a curated combination of technologies with a specific **Hello World goal**:

| Stack | Technologies | Hello World Goal |
|-------|-------------|------------------|
| **React + TypeScript** | React, TypeScript, Tailwind, Vite, Vitest | Task Manager App |
| **Vue 3 + TypeScript** | Vue 3, TypeScript, Tailwind, Vite | Notes Application |
| **Next.js** | Next.js, React, TypeScript, Tailwind | Blog with API |
| **Node + Express** | Node.js, Express, TypeScript, SQLite | RESTful CRUD API |
| **Python + FastAPI** | Python, FastAPI, SQLite, pytest | API with Auto-Docs |
| **Python CLI** | Python, Typer, Rich, pytest | System Info CLI |
| **Electron + React** | Electron, React, TypeScript, Tailwind | Markdown Editor |
| *...and 30+ more* | See wizard for full list | |

### Company-Inspired Stacks

Build apps inspired by major tech platforms with their signature architectures:

| Stack | Inspired By | Hello World Goal |
|-------|-------------|------------------|
| **Facebook Stack** | React + GraphQL + Relay | Social Feed App |
| **X (Twitter) Stack** | React + Node + Redis + WebSocket | Microblog Platform |
| **Instagram Stack** | React Native + Django + PostgreSQL | Photo Sharing App |
| **Reddit Stack** | React + FastAPI + PostgreSQL | Community Forum |
| **Discord Stack** | Electron + React + WebSocket | Chat Application |
| **GitHub App Stack** | Node + Probot + GraphQL | GitHub Bot |
| **Spotify Stack** | React + FastAPI + PostgreSQL | Music Player App |
| **Netflix Stack** | React + Node + GraphQL | Video Streaming App |
| **Slack Stack** | Electron + React + WebSocket | Team Messenger |
| **Notion Stack** | React + Node + PostgreSQL | Collaborative Workspace |
| **Figma Stack** | React + Canvas + WebSocket | Design Canvas App |
| **Uber Stack** | React Native + Go + PostgreSQL | Ride Request App |
| **Airbnb Stack** | React + Node + PostgreSQL | Booking Marketplace |
| **Tinder Stack** | React Native + Node + MongoDB | Swipe Matching App |

### Custom Mode

Don't see what you need? Use **Custom Configuration** to pick technologies individually:

1. **Language** - JavaScript, TypeScript, Python, Go, Rust, C#, Dart
2. **Framework** - React, Vue, Express, FastAPI, Django, etc.
3. **UI Framework** - Tailwind, shadcn/ui, Material UI, Bootstrap
4. **Database** - SQLite, PostgreSQL, MongoDB, Prisma, Drizzle
5. **Testing** - Vitest, Jest, pytest, Playwright, Cypress
6. **Build Tools** - Vite, Webpack, tsup, Poetry
7. **Linting** - ESLint, Prettier, Ruff, Black

### What Ralph Creates

After completing the wizard, Ralph automatically:

1. ✅ Creates a new session with your configuration
2. ✅ Generates a detailed specification with your tech stack
3. ✅ Defines clear success criteria for the Hello World goal
4. ✅ **On build start:** Creates project structure (`.github/`)
5. ✅ Starts building your project from scratch

> **Note:** Project files are only created when you confirm and start the build process. The wizard itself is non-destructive - you can explore options without creating any files.

You'll get a complete, working project starter that:
- Follows industry best practices
- Has all dependencies properly configured
- Includes example code demonstrating each technology
- Has linting, testing, and build scripts ready
- Includes a README with setup instructions

### Navigation

The wizard supports full navigation:
- **Number keys** - Select an option
- **[B]** - Go back to previous step
- **[Q]** - Cancel wizard
- **[Enter]** - Confirm selection

---

## 🎯 Spec Presets

Ralph includes **ready-to-use presets** for common development tasks. These presets provide battle-tested specifications you can use immediately.

### Available Presets

| Priority | Preset | Description |
|:--------:|--------|-------------|
| 🔥 5 | **Security Hardening** | Comprehensive adversarial security audit and hardening of the entire repository |
| ♿ 6 | **Accessibility Audit** | Comprehensive accessibility audit and remediation following WCAG guidelines |
| 🌍 6 | **Internationalization (i18n)** | Implement or improve internationalization support for multi-language applications |
| 🗄️ 7 | **Database Migration** | Analyze and implement database schema migrations with safety checks and rollback support |
| ⚡ 7 | **Performance Optimization** | Identify and resolve performance bottlenecks with language-agnostic profiling and optimization strategies |
| ✅ 8 | **Test Coverage Improvement** | Analyze and improve test coverage across the codebase with language-agnostic strategies |
| 🔧 10 | **Code Refactoring** | Comprehensive code refactoring to professional standards with documentation |
| 🧹 15 | **Codebase Cleanup** | Complete audit to remove redundancy, fix issues, and modernize the codebase |
| 🔍 20 | **Project Structure Analysis** | Deep analysis and blueprint of the entire codebase architecture |
| 📚 25 | **Project Documentation** | Comprehensive documentation of all project features in markdown format |
| 🔬 30 | **Competitor Analysis** | Analyze the project and research competitors via web search |
| 📋 35 | **Functions & Classes Listing** | Generate a complete reference of all functions, classes, and APIs in the project |

### Using Presets

Presets are stored in `ralph/presets/` and can be used as templates for your specs:

```powershell
# Copy a preset to your specs folder
Copy-Item ralph/presets/security-hardening.md ralph/specs/

# Or create your own spec based on a preset
Get-Content ralph/presets/refactoring.md | Out-File ralph/specs/my-refactor.md
```

```bash
# Copy a preset to your specs folder
cp ralph/presets/security-hardening.md ralph/specs/

# Or create your own spec based on a preset
cp ralph/presets/refactoring.md ralph/specs/my-refactor.md
```

💡 **Tip:** Lower priority numbers (like 5) are higher priority tasks that should be done first.

---

## 📁 Reference Files

Ralph can analyze multiple reference sources including specs, images (wireframes/mockups), and structured data to build comprehensive project plans.

### Using References

From the session menu, select **[R] Use existing references** to:

| Option | Description |
|--------|-------------|
| **Use default spec folder** | Load files from `ralph/specs/` directory |
| **Add reference directory** | Add custom folders containing specs or assets |
| **Add reference file** | Add individual files (specs, images, data) |

### Supported File Types

| Category | Extensions |
|----------|------------|
| 📄 **Text/Markdown** | `.md`, `.txt`, `.markdown` |
| 📊 **Structured Data** | `.json`, `.yaml`, `.yml`, `.xml`, `.csv`, `.toml` |
| 🖼️ **Images** | `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg` |
| 💻 **Code** | `.py`, `.js`, `.ts`, `.ps1`, `.cs`, `.java`, `.go`, etc. |

### Image Analysis

When you include UI wireframes or mockups, Ralph will:
- Analyze visual structure and component hierarchy
- Identify user interaction patterns and flows
- Extract implied functionality from visual elements
- Build tasks in UX-optimal order

> **Note:** Reference files are only read during analysis. After planning completes, Ralph no longer needs access to the original files - the understanding is captured in the implementation plan.

---

## 🔄 Start Fresh

When continuing an existing project with pending tasks, Ralph shows a menu:

```
  RALPH - PROJECT MENU
  
  Project Status:
    • Specs: 2 specification(s)
    • Tasks: 5 pending, 3 completed

  [1] Continue building (use existing specs)
  [2] Add new spec to project
  [3] Start fresh (reset plan and progress)
  [Q] Quit
```

| Option              | What It Does                                |
|---------------------|---------------------------------------------|
| **[1] Continue**    | Keep working on existing tasks              |
| **[2] Add spec**    | Add a new specification to the project      |
| **[3] Start fresh** | Reset plan and progress, rebuild from specs |
| **[Q] Quit**        | Exit Ralph                                  |

**Start Fresh** is useful when:
- 🔁 You want to rebuild the same specs from scratch
- 🛠️ The plan got into a bad state
- 🆕 You're starting a new phase of development

> 💾 **Note:** Your specs in `ralph/specs/*.md` are **never** deleted. Only the plan and progress files are reset.

---

## 📂 Sessions - Isolated Project Contexts

Ralph uses **sessions** to keep projects completely isolated. Each session has its own implementation plan, progress log, and specs folder. When you start Ralph, you'll be prompted to select or create a session.

### Why Use Sessions?

| Scenario                         | Solution                                             |
|----------------------------------|------------------------------------------------------|
| Building a new app from scratch  | Create a new session with its own specs              |
| Want to try a different approach | Create a new session without affecting existing work |
| Working on multiple projects     | Each project gets its own session                    |
| Experimenting with a new idea    | Create an isolated session to keep things clean      |

### Session Commands

```powershell
# Run Ralph - shows session selection menu first
./ralph/ralph.ps1

# Interactive session management
./ralph/ralph.ps1 -Mode sessions

# Create a new session directly
./ralph/ralph.ps1 -NewSession "Todo App"

# Switch to an existing session
./ralph/ralph.ps1 -Session "todo-app-20260115-123456"

# Press [S] during Ralph settings to switch sessions
```

### Session Structure

```
your-project/
├── ralph/                    # Self-contained Ralph (copy this folder!)
│   ├── ralph.ps1             # Entry point (PowerShell)
│   ├── ralph.sh              # Entry point (Bash)
│   ├── agents/               # Agent prompts (source)
│   ├── core/                 # Modular core scripts (14 modules)
│   │   ├── loop.ps1          # Main orchestration
│   │   ├── display.ps1       # UI/Display functions
│   │   ├── statistics.ps1    # Git & session tracking
│   │   ├── specs.ps1         # Specification handling
│   │   ├── initialization.ps1 # File & state setup
│   │   └── [9 more modules]  # menus, tasks, memory, presets, venv, spinner, references, boilerplate, dryrun
│   ├── specs/                # Specifications (shared specs live here)
│   │   └── *.md
│   └── templates/            # Setup templates
├── AGENTS.md                 # Project operational guide (optional)
├── .github/
│   ├── agents/               # Agent prompts (auto-created from ralph/agents/)
│   └── instructions/
│       └── ralph.instructions.md  # Ralph-specific config (auto-created)
└── .ralph/
    ├── active-task           # Current active session ID
    └── tasks/                # Session folders
        └── todo-app-20260115-123456/
            ├── task.json              # Session metadata
            ├── IMPLEMENTATION_PLAN.md # Session-specific plan
            ├── progress.txt           # Session-specific progress
            └── specs/                 # Session-specific specs (if isolated)
                └── *.md
```

### Specs Modes

When creating a session, choose between:

| Mode                   | Description                                                      |
|------------------------|------------------------------------------------------------------|
| **Isolated** (default) | Session has its own `specs/` folder - completely independent     |
| **Shared**             | Session uses `ralph/specs/` folder - shared across sessions      |

### Session Startup Menu

When you run `./ralph/ralph.ps1`, you'll see:

| Option              | What It Does                  |
|---------------------|-------------------------------|
| **[N] New session** | Create a new isolated session |
| **[1-N]**           | Switch to a session by number |
| **[D] Delete**      | Remove a session              |
| **[Enter]**         | Continue with active session  |
| **[Q] Quit**        | Exit Ralph                    |

---

## 🔍 Dry Run Mode (Preview)

Test Ralph without spending AI tokens or modifying files:

```powershell
./ralph/ralph.ps1 -DryRun              # Preview what would happen
./ralph/ralph.ps1 -DryRun -Mode plan   # Preview planning phase
```

**Features:**
- Zero cost (no AI tokens), zero risk (no file changes)
- Full support for Boilerplate Wizard (shows available stacks/platforms)
- Preview project setup, planning, and building phases
- Great for testing and learning

📖 **Details:** See the dry-run module at `ralph/core/dryrun.ps1` for implementation details.

---

## 🧠 Memory System - Cross-Session Learnings

Ralph includes a **memory system** that persists learnings across ALL sessions. When enabled, discoveries, patterns, and gotchas are stored in `.ralph/memory.md` and automatically read by Ralph in every iteration.

### Why Use Memory?

| Benefit | Description |
|---------|-------------|
| **Compound Knowledge** | Learnings accumulate over time, making Ralph smarter with each session |
| **Avoid Repeating Mistakes** | Gotchas and pitfalls are remembered and avoided |
| **Consistent Patterns** | Code conventions discovered are followed in future sessions |
| **Build Commands** | Working commands are stored and reused |

### Memory Commands

```powershell
# PowerShell
./ralph/ralph.ps1 -Memory status   # Show memory status and entries
./ralph/ralph.ps1 -Memory on       # Enable memory system
./ralph/ralph.ps1 -Memory off      # Disable memory system
```

```bash
# Bash
./ralph/ralph.sh --memory status   # Show memory status and entries
./ralph/ralph.sh --memory on       # Enable memory system
./ralph/ralph.sh --memory off      # Disable memory system
```

### Memory Sections

The memory file (`.ralph/memory.md`) contains four sections:

| Section | What's Stored |
|---------|---------------|
| **Patterns** | Code patterns, conventions, and best practices discovered |
| **Commands** | Build, test, lint commands that work for this project |
| **Gotchas** | Common pitfalls, edge cases, and things to watch out for |
| **Decisions** | Architectural decisions, design choices, and rationale |

### Settings Menu

You can also toggle memory from the **Settings** menu during a session:

```
  [L] Memory system (ON)    ← Toggle memory on/off
```

### Memory File Location

```
.ralph/
├── memory.md        ← Cross-session learnings (persists across ALL sessions)
├── settings.json    ← Memory enabled/disabled setting
└── tasks/
    └── <session>/   ← Session-specific files
```

> 💡 **Tip:** Memory is enabled by default. You can manually edit `.ralph/memory.md` to add your own entries.

---

## 🔄 Checkpoint & Recovery System

Ralph automatically creates checkpoints during execution to enable graceful recovery from errors or interruptions.

### How It Works

Checkpoints are automatically saved at key points:
- 📍 Before starting each phase (planning, building)
- ✅ After completing each task
- ⚠️ When errors occur (with error state captured)

### Recovery Process

If Ralph is interrupted (error, crash, Ctrl+C), the next time you run Ralph:

```
═══════════════════════════════════════════════════════════════
  RECOVERY AVAILABLE
═══════════════════════════════════════════════════════════════

  Previous session interrupted at: Building (Task 3/8)
  Last checkpoint: 2026-01-25 15:30:42

  [R] Resume from checkpoint
  [F] Start fresh (discard checkpoint)
  [Q] Quit
```

### What Gets Saved

Each checkpoint captures:
- 📋 Current phase (spec-creation, planning, building)
- 🔢 Iteration count and task progress
- 📁 File states before changes
- 🎯 Active task and pending tasks
- ⚙️ Configuration and settings

### Checkpoint Storage

```
.ralph/
└── tasks/
    └── <session-id>/
        ├── checkpoint.json    # Latest checkpoint state
        ├── task.json          # Session metadata
        └── ...
```

Checkpoints are automatically cleaned up when sessions complete successfully.

---

## 📁 Project Structure

```
your-project/
├── 📁 ralph/                         # 🚀 Self-contained Ralph (copy this folder!)
│   ├── ralph.ps1                     # 🪟 Entry point (PowerShell)
│   ├── ralph.sh                      # 🐧 Entry point (Bash)
│   ├── init.ps1                      # Reset state
│   ├── agents/                       # Agent prompts (source)
│   │   ├── ralph.agent.md            # Building agent
│   │   ├── ralph-planner.agent.md    # Planning agent
│   │   ├── ralph-spec-creator.agent.md  # Spec creation agent
│   │   └── ralph-agents-updater.agent.md # AGENTS.md auto-updater
│   ├── core/                         # Core scripts
│   │   ├── loop.ps1 / loop.sh        # Orchestrator
│   │   ├── tasks.ps1 / tasks.sh      # Multi-task support
│   │   ├── spinner.ps1 / spinner.sh  # Animated progress
│   │   └── venv.ps1 / venv.sh        # Python venv management
│   ├── scripts/                      # Utility scripts
│   │   ├── fork.ps1 / fork.sh        # Create new Ralph-powered projects
│   │   └── reset-to-upstream.*       # Reset fork to upstream
│   ├── templates/                    # Setup templates
│   │   ├── AGENTS.template.md        # AGENTS.md template
│   │   ├── spec.template.md          # Spec template
│   │   └── ralph.instructions.md     # Ralph instructions template
│   ├── tests/                        # Test suite
│   │   └── ralph.tests.ps1           # Comprehensive tests (184 tests)
│   ├── specs/                        # 📝 Your specifications (default/shared)
│   │   ├── _example.template.md      # Template (ignored by Ralph)
│   │   └── *.md                      # Your specs
│   ├── IMPLEMENTATION_PLAN.md        # Default task list (auto-generated)
│   └── progress.txt                  # Default learnings log
├── 📁 .github/                       # GitHub config (auto-created by Ralph)
│   ├── agents/                       # 🤖 Agent prompts (copied from ralph/agents/)
│   └── instructions/
│       └── ralph.instructions.md     # ⚡ Ralph config (auto-created)
├── 📁 .ralph/                        # 🗑️ Runtime data (gitignored)
│   ├── active-task                   # Currently active session ID
│   ├── upstream.json                 # Original repository URL (fork tracking)
│   ├── venv/                         # Python virtual environment
│   ├── forks/                        # Local fork clones
│   └── tasks/                        # Session contexts
│       └── <session-id>/             # Each session has isolated files
│           ├── task.json             # Session metadata
│           ├── IMPLEMENTATION_PLAN.md
│           ├── progress.txt
│           └── specs/                # Session-specific specs (if isolated)
└── 📄 AGENTS.md                      # 📋 Operational guide (optional)
```

---

## 🔓 Copilot CLI Flags

Ralph uses the native GitHub Copilot CLI with specific flags for autonomous operation:

| Flag                | Purpose                                                                          |
|---------------------|----------------------------------------------------------------------------------|
| `--allow-all-tools` | Allows all tools to run without confirmation (required for non-interactive mode) |
| `-p <prompt>`       | Programmatic mode - runs with a prompt string                                    |
| `--model <model>`   | Specifies which AI model to use                                                  |
| `--agent <name>`    | Uses a custom agent from `.github/agents/`                                       |

The `--allow-all-tools` flag is a **native Copilot CLI feature** (not Ralph-specific) that enables the AI to use file editing, terminal commands, and other tools without prompting for user confirmation each time. This is essential for Ralph's autonomous loop to function without human intervention.

---

## 🌟 Core Principles

|  #  | Principle                        | Why                                     |
|:---:|----------------------------------|-----------------------------------------|
| 1️⃣ | **Fresh Context Each Iteration** | Prevents AI confusion                   |
| 2️⃣ | **Backpressure Is Critical**     | Tests must pass before marking complete |
| 3️⃣ | **Small Steps Only**             | One task per iteration                  |
| 4️⃣ | **File-Based State**             | All memory lives in files               |
| 5️⃣ | **Let Ralph Ralph**              | Trust the loop, observe and tune        |

---

## ⚙️ Configuring Validation

If you have an `AGENTS.md` file, add your project's validation commands:

```markdown
## Validation

- **Lint:** `npm run lint`
- **Test:** `npm test`
- **Build:** `npm run build`
```

🔒 Ralph will run these after each implementation to ensure quality.

> **Note:** Ralph uses `.github/instructions/ralph.instructions.md` for its own config (auto-created). AGENTS.md is for your project's build/test commands.

---

## 🔧 Auto File Recovery

Ralph automatically creates required files if they're missing:

| File                                         | Created When          |
|----------------------------------------------|-----------------------|
| `.github/instructions/ralph.instructions.md` | On startup if missing |
| `ralph/progress.txt`                         | On startup if missing |
| `ralph/IMPLEMENTATION_PLAN.md`               | On startup if missing |

This ensures Ralph never fails due to missing state files.

---

## 🧠 AI Model Selection

Ralph supports multiple AI models. Choose the best one for your task:

### Available Models

| Provider  | Model                  | Description                       |
|-----------|------------------------|-----------------------------------|
| Anthropic | `claude-sonnet-4.5`    | Claude Sonnet 4.5 (Ralph default) |
| Anthropic | `claude-sonnet-4`      | Claude Sonnet 4                   |
| Anthropic | `claude-haiku-4.5`     | Claude Haiku 4.5 (fast/cheap)     |
| Anthropic | `claude-opus-4.5`      | Claude Opus 4.5 (premium)         |
| OpenAI    | `gpt-5.2-codex`        | GPT-5.2 Codex                     |
| OpenAI    | `gpt-5.1-codex`        | GPT-5.1 Codex                     |
| OpenAI    | `gpt-4.1`              | GPT-4.1 (fast/cheap)              |
| Google    | `gemini-3-pro-preview` | Gemini 3 Pro (preview)            |

### Usage

```powershell
# List all available models
./ralph/ralph.ps1 -ListModels

# Use a specific model
./ralph/ralph.ps1 -Model claude-sonnet-4
./ralph/ralph.ps1 -Model gpt-4.1
```

```bash
# List all available models
./ralph/ralph.sh -L

# Use a specific model
./ralph/ralph.sh -M claude-sonnet-4
./ralph/ralph.sh -M gpt-4.1
```

**Interactive Selection:** Press **[M]** at Ralph's startup prompt to change the model without restarting.

---

## 📖 Advanced Commands

### PowerShell (Windows) 🪟

| Command                                    | What It Does                                     |
|--------------------------------------------|--------------------------------------------------|
| `./ralph/ralph.ps1 -Mode agents`           | 📋 Only update AGENTS.md from codebase analysis  |
| `./ralph/ralph.ps1 -Model claude-sonnet-4` | 🧠 Use specific AI model                         |
| `./ralph/ralph.ps1 -ListModels`            | 📋 Show available AI models                      |
| `./ralph/ralph.ps1 -MaxIterations 20`      | 🔢 Limit to 20 build cycles (default: unlimited) |
| `./ralph/ralph.ps1 -ShowVerbose`           | 🔍 Show detailed output                          |
| `./ralph/ralph.ps1 -Manual`                | 📋 Copy/paste mode for Copilot Chat              |
| `./ralph/ralph.ps1 -Delegate`              | 🤖 Hand off to background agent                  |
| `./ralph/ralph.ps1 -Venv auto`             | 🐍 Auto-create Python venv (default)             |
| `./ralph/ralph.ps1 -Venv skip`             | ⏭️ Skip Python venv isolation                    |
| `./ralph/ralph.ps1 -Venv reset`            | 🔄 Reset Python venv before running              |

### Bash (Linux/macOS/WSL) 🐧

| Command                               | What It Does                                     |
|---------------------------------------|--------------------------------------------------|
| `./ralph/ralph.sh -m agents`          | 📋 Only update AGENTS.md from codebase analysis  |
| `./ralph/ralph.sh -M claude-sonnet-4` | 🧠 Use specific AI model                         |
| `./ralph/ralph.sh -L`                 | 📋 Show available AI models                      |
| `./ralph/ralph.sh -n 20`              | 🔢 Limit to 20 build cycles (default: unlimited) |
| `./ralph/ralph.sh -V`                 | 🔍 Show detailed output (verbose mode)           |
| `./ralph/ralph.sh --manual`           | 📋 Copy/paste mode for Copilot Chat              |
| `./ralph/ralph.sh -d`                 | 🤖 Hand off to background agent                  |
| `./ralph/ralph.sh --venv auto`        | 🐍 Auto-create Python venv (default)             |
| `./ralph/ralph.sh --venv skip`        | ⏭️ Skip Python venv isolation                    |
| `./ralph/ralph.sh --venv reset`       | 🔄 Reset Python venv before running              |

---

## 🔁 Iteration Control

By default, Ralph runs **continuously until all tasks are completed** (unlimited iterations). Before starting the build phase, Ralph prompts you:

```
═══════════════════════════════════════════════════════════════
  BUILD ITERATION SETTINGS
═══════════════════════════════════════════════════════════════

  Pending tasks: 5

  [Enter] Run until complete (unlimited iterations) - RECOMMENDED
  [N]     Specify maximum iteration count
  [Q]     Cancel and exit
```

| Option    | Behavior                                      |
|-----------|-----------------------------------------------|
| **Enter** | 🟢 Run until all tasks complete (recommended) |
| **N**     | 🟡 Set a maximum iteration limit              |
| **Q**     | 🔴 Cancel before starting                     |

### Command Line Override

```powershell
./ralph/ralph.ps1 -MaxIterations 10   # Stop after 10 iterations
./ralph/ralph.ps1 -MaxIterations 0    # Unlimited (default)
```

```bash
./ralph/ralph.sh -n 10                # Stop after 10 iterations
./ralph/ralph.sh -n 0                 # Unlimited (default)
```

---

## 🧠 What is the Ralph Loop?

**Ralph** is an autonomous coding methodology that prevents context pollution:

| Principle                           | Why It Matters                                 |
|-------------------------------------|------------------------------------------------|
| 🧹 **Fresh context each iteration** | Prevents AI confusion                          |
| 💾 **File-based memory**            | Persists learnings via `progress.txt`          |
| 🔙 **Backpressure**                 | Tests, lints, and builds force self-correction |

```
🔄 Pick Task → 🔨 Implement → ✅ Validate → 📦 Commit → 🧹 Clear Context → 🔄 Repeat
```

---

## 🛠️ Utility Scripts

The `scripts/` folder contains helpful utilities that are **not part of Ralph core** but make working with your fork easier.

### 🔄 Reset Fork to Upstream

Resets your fork to match the original upstream repository exactly. Useful when you want to start fresh or sync with the latest changes from the original repo.

| Script                                | Platform                |
|---------------------------------------|-------------------------|
| `ralph/scripts/reset-to-upstream.ps1` | 🪟 Windows (PowerShell) |
| `ralph/scripts/reset-to-upstream.sh`  | 🐧 Linux/macOS/WSL      |

**Features:**
- ✅ Works from any subdirectory in the repo
- ✅ Auto-detects upstream URL from `.ralph/upstream.json`
- ✅ Detects if you're in a fork
- ✅ Shows uncommitted changes before reset
- ✅ Explains exactly what will happen
- ✅ Requires explicit "yes" confirmation
- ✅ Supports manual upstream URL override

**Usage:**
```powershell
# Interactive (auto-detects upstream from config)
./ralph/scripts/reset-to-upstream.ps1

# Override upstream URL
./ralph/scripts/reset-to-upstream.ps1 -UpstreamUrl "https://github.com/user/repo.git"

# Skip confirmation
./ralph/scripts/reset-to-upstream.ps1 -Force

# Specify branch
./ralph/scripts/reset-to-upstream.ps1 -Branch develop
```

```bash
# Interactive (auto-detects upstream from config)
./ralph/scripts/reset-to-upstream.sh

# Override upstream URL
./ralph/scripts/reset-to-upstream.sh -u "https://github.com/user/repo.git"

# Skip confirmation
./ralph/scripts/reset-to-upstream.sh -f

# Specify branch
./ralph/scripts/reset-to-upstream.sh -b develop
```

> ⚠️ **Warning:** This will permanently delete ALL local changes and overwrite your fork's history!

> 💡 **Auto-Detection:** When you create a fork using `fork.ps1` or `fork.sh`, the upstream URL is automatically saved to `.ralph/upstream.json`. The reset script uses this saved URL, so you don't need to specify it manually.

### 🍴 Fork Management

Create new Ralph-powered projects from your fork:

```powershell
./ralph/scripts/fork.ps1                    # Interactive mode
./ralph/scripts/fork.ps1 -Name my-project   # Create fork named 'my-project'
```

```bash
./ralph/scripts/fork.sh                     # Interactive mode
./ralph/scripts/fork.sh -n my-project       # Create fork named 'my-project'
```

**What it does:**
1. ✅ Detects if current repo is original or fork
2. ✅ If forked, asks whether to fork from original or current repo
3. ✅ Creates fork on GitHub with your chosen name
4. ✅ Clones to `.ralph/forks/<name>/` (gitignored)
5. ✅ **Saves upstream URL to `.ralph/upstream.json` for easy syncing**
6. ✅ Opens in VS Code automatically

---

## 📋 Key Files

| File                                         | Purpose                                      |     Who Edits     |
|----------------------------------------------|----------------------------------------------|:-----------------:|
| `.github/instructions/ralph.instructions.md` | Ralph-specific config (auto-created)         |     🤖 Ralph      |
| `AGENTS.md`                                  | Build/test commands, project info (optional) | 👤 You + 🤖 Ralph |
| `ralph/specs/*.md`                           | Feature requirements (default/shared)        |    👤 **You**     |
| `.github/agents/*.md`                        | Agent behavior                               |  👤 You (rarely)  |
| `ralph/IMPLEMENTATION_PLAN.md`               | Default task list                            |     🤖 Ralph      |
| `ralph/progress.txt`                         | Default learnings log                        |     🤖 Ralph      |
| `.ralph/active-task`                         | Currently active task ID                     |     🤖 Ralph      |
| `.ralph/tasks/<id>/*`                        | Task-specific files                          |     🤖 Ralph      |

---

## 🔄 How It Works

```
┌──────────────────────────────────────────────────────────────┐
│                     🤖 RALPH LOOP                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌───────────┐    ┌────────────┐    ┌───────────────────┐   │
│  │ ralph.ps1 │───▶│ agent.md   │───▶│ copilot -p        │   │
│  └───────────┘    └────────────┘    └─────────┬─────────┘   │
│                                               │              │
│                                               ▼              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   💾 FILE SYSTEM                       │  │
│  │  • IMPLEMENTATION_PLAN.md  • ralph/specs/*            │  │
│  │  • AGENTS.md               • progress.txt             │  │
│  └───────────────────────────────────────────────────────┘  │
│                        │                                     │
│                        ▼                                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 🔍 Check for <promise>COMPLETE</promise>            │    │
│  └──────────────┬──────────────────────┬───────────────┘    │
│                 │                      │                     │
│            ✅ COMPLETE            🔄 CONTINUE                │
│                 │                      │                     │
│                 ▼                      ▼                     │
│              🎉 Exit             Next Iteration              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

---

## 📊 Optimizer & Benchmark Framework

Ralph includes a **meta-optimization framework** for systematically testing and improving agent configurations. This framework uses a standardized Tetris game specification to measure code generation quality.

### Running Benchmarks

```powershell
# Standard benchmark (15 iterations)
./ralph/optimizer/benchmark.ps1

# Quick benchmark (5 iterations, faster)
./ralph/optimizer/benchmark.ps1 -Quick

# Keep the generated project for inspection
./ralph/optimizer/benchmark.ps1 -KeepProject

# Compare history of all benchmarks
./ralph/optimizer/benchmark.ps1 -Compare

# Benchmark with a specific model
./ralph/optimizer/benchmark.ps1 -Model gpt-4.1
```

### Benchmark Grades

| Score | Grade | Description |
|-------|-------|-------------|
| 90+   | A+    | Excellent   |
| 80-89 | A     | Great       |
| 70-79 | B     | Good        |
| 60-69 | C     | Acceptable  |
| 50-59 | D     | Needs Work  |
| <50   | F     | Poor        |

### Quality Metrics

The framework measures output quality across four categories:

**Structure (40% weight)**
- File separation, directory organization, module count

**Code (30% weight)**
- Lines, function count, function length, comment ratio

**Quality (20% weight)**
- Test files, test coverage ratio

**Efficiency (10% weight)**
- Iteration count, task completion rate

### Advanced Optimizer

```powershell
# Analyze an existing project
./ralph/optimizer/optimizer.ps1 -Mode metrics -ProjectPath "path\to\project"

# Run baseline experiment (current agents)
./ralph/optimizer/optimizer.ps1 -Mode baseline

# Run full optimization loop
./ralph/optimizer/optimizer.ps1 -Mode optimize -MaxExperiments 5

# Compare all experiments
./ralph/optimizer/optimizer.ps1 -Mode analyze
```

### Agent Variants

Test different optimization strategies:
- **structure-emphasis** - Focus on file separation
- **test-emphasis** - Focus on test creation
- **task-consolidation** - Larger consolidated tasks
- **efficiency-focus** - Reduce wasted iterations

Results are stored in `ralph/optimizer/results/` with convergence detection (stops after 3 consecutive no-improvement runs).

---

## 🎨 CLI Framework (Zero Dependencies)

Ralph includes a **fully modular terminal UI framework** built from scratch with zero external dependencies. It powers Ralph's menus, wizards, and interactive prompts.

### Features

| Feature | Description |
|---------|-------------|
| **Arrow-Key Navigation** | Navigate menus with ↑ ↓ keys |
| **Multi-Select** | Checkbox menus with spacebar |
| **Hotkey Support** | Global keys like [Q]uit, [B]ack |
| **Scrollable Menus** | Handle hundreds of items smoothly |
| **Progress Bars** | Visual progress indicators |
| **Text Input** | Text/password/number input with validation |
| **Color Support** | 16/256/TrueColor ANSI escape codes |
| **Cross-Platform** | PowerShell 7+ and POSIX sh implementations |

### Modules

**PowerShell (`ralph/cli/ps/`)**
- `api.ps1` - High-level unified API
- `colorUtils.ps1` - Color/formatting utilities
- `keyReader.ps1` - Keyboard input handling
- `screenManager.ps1` - Cursor/viewport control
- `menuRenderer.ps1` - Single-select menus
- `multiSelect.ps1` - Multi-checkbox menus
- `inputHandler.ps1` - Text input with validation
- `globalKeyHandler.ps1` - Global hotkey system

**Shell (`ralph/cli/sh/`)**
- Parallel POSIX sh implementations
- stty-based keyboard handling

### Menu System (YAML-Based)

Define menus declaratively in `ralph/menus/*.yaml`:

**Features:**
- Breadcrumb navigation
- Back button support
- Dynamic visibility conditions
- Template variable substitution
- Consistent UX across all interactions

**Menu Files:**
- `sessions-home.yaml` - Main entry
- `session.yaml` - Session settings
- `specs-settings.yaml` - Spec configuration
- `references.yaml` - Reference management
- `tasks.yaml` - Task tracking
- `presets.yaml` - Preset selection
- And more...

### Platform Support

✅ **Windows**: Windows Terminal (PowerShell 7+)  
✅ **macOS**: iTerm2, Terminal.app (PowerShell 7+ / Bash)  
✅ **Linux**: xterm, GNOME Terminal, Konsole (PowerShell 7+ / Bash)  
✅ **Remote**: tmux / screen compatible

---

## 🔍 Verbose Mode

See exactly what Ralph is doing under the hood:

```powershell
./ralph/ralph.ps1 -ShowVerbose
```

```bash
./ralph/ralph.sh -V
./ralph/ralph.sh --verbose
```

**Interactive Toggle:** Press **[V]** at Ralph's startup prompt to enable verbose mode.

**What you'll see:**
- 📄 Agent prompt loading and length
- 🔧 Copilot CLI command arguments
- 📡 Live output streaming from Copilot CLI
- ⏱️ Duration and output size for each operation
- 🔄 Internal state changes

Without verbose mode, Ralph shows a clean animated spinner during operations.

---

## 🐍 Python Virtual Environment

Ralph automatically creates a Python virtual environment to keep your system clean!

| Mode             | What Happens                                          |
|------------------|-------------------------------------------------------|
| `auto` (default) | 🟢 Creates venv if needed, uses it for all operations |
| `skip`           | 🟡 No venv - uses system Python (not recommended)     |
| `reset`          | 🔴 Deletes old venv, creates fresh one                |

📍 **Venv location:** `.ralph/venv/` (automatically ignored by git)

---

## 🤖 Custom Agents

Ralph uses GitHub Copilot's custom agents in `.github/agents/`:

| Agent                   | File                            | Purpose                 |
|-------------------------|---------------------------------|-------------------------|
| 🔨 ralph                | `ralph.agent.md`                | Main building agent     |
| 📝 ralph-planner        | `ralph-planner.agent.md`        | Planning/gap analysis   |
| 🎤 ralph-spec-creator   | `ralph-spec-creator.agent.md`   | Spec creation/interview |
| 📋 ralph-agents-updater | `ralph-agents-updater.agent.md` | Auto-update AGENTS.md   |

💬 Invoke directly in Copilot Chat:
```
@ralph Implement the next task from IMPLEMENTATION_PLAN.md
```

---

## 🔧 Troubleshooting

| Problem                              | Solution                                                        |
|--------------------------------------|-----------------------------------------------------------------|
| ❌ "Copilot CLI not found"            | Run `npm install -g @github/copilot` then `copilot auth`        |
| ❌ "Agent file not found"             | Ensure `.github/agents/ralph.agent.md` exists                   |
| ❌ Loop completes but nothing changed | Check `progress.txt` for clues                                  |
| ❌ Stuck in a loop                    | Break large tasks into smaller ones in `IMPLEMENTATION_PLAN.md` |
| ❌ Ralph appears hung                 | Press Ctrl+C to cancel                                          |
| ❌ Python venv not creating           | Ensure Python 3 is installed: `python --version`                |
| ❌ Tests failing                      | Run `./ralph/tests/ralph.tests.ps1` to verify installation      |

---

## 🧪 Testing

Ralph includes a comprehensive test suite to verify all features work correctly:

```powershell
# Run all tests (184 tests)
./ralph/tests/ralph.tests.ps1

# Run with verbose output
./ralph/tests/ralph.tests.ps1 -Verbose
```

Tests cover:
- ✅ File structure validation
- ✅ Mode parsing (auto, plan, build, agents)
- ✅ Agent prompt extraction
- ✅ Signal detection
- ✅ Utility functions
- ✅ Documentation consistency

---

## 🔄 Self-Update System

Ralph can automatically update itself from the upstream repository while preserving your project files.

### Checking for Updates

```powershell
# Check if updates are available (PowerShell)
./ralph/ralph.ps1 -CheckUpdate

# Apply available updates
./ralph/ralph.ps1 -Update
```

```bash
# Check if updates are available (Bash)
./ralph/ralph.sh --check-update

# Apply available updates
./ralph/ralph.sh --update
```

### Update Behavior

When updating, Ralph:
- ✅ **Updates** all files in `ralph/` folder from upstream
- ✅ **Preserves** all your project files outside `ralph/`
- ✅ **Preserves** custom files you added to `ralph/`
- ✅ **Detects** if you're on the main repository (skips self-update)

### Upstream Detection

Ralph automatically detects the upstream source from:
1. `.ralph/upstream.json` (for GitHub forks)
2. `.ralph/source.json` (for local copies)
3. Git remote named 'upstream'
4. Falls back to default: `https://github.com/niittymaa/Copilot-Ralph.git`

> 💡 **Tip:** The upstream URL is automatically saved when you create a fork using `fork.ps1` or `fork.sh`.

---

## 📋 Session Logging

Ralph automatically logs all operations for debugging and audit purposes.

### Log Files

```
.ralph/
└── tasks/
    └── <session-id>/
        ├── session.log           # Complete session log
        ├── IMPLEMENTATION_PLAN.md
        └── progress.txt
```

### Log Contents

Logs capture:
- 🔧 Command executions
- 🤖 AI model interactions
- 📁 File operations
- ⚠️ Errors and warnings
- ⏱️ Timestamps for all operations

Logs are automatically created and maintained per session, making it easy to debug issues or review what Ralph did.

---

## 🔐 GitHub Authentication

Ralph integrates with GitHub Copilot CLI's built-in authentication system.

### First-Time Setup

```bash
# Install Copilot CLI
npm install -g @github/copilot

# Authenticate with GitHub
copilot auth

# Verify installation
copilot --version
```

### Authentication Features

- ✅ Automatic token management via Copilot CLI
- ✅ Support for GitHub Copilot Pro, Business, and Enterprise
- ✅ Seamless integration with GitHub's authentication flow
- ✅ No manual token configuration needed

Ralph automatically uses the authenticated session from Copilot CLI - no additional setup required!

---

## 📚 References

The Ralph Loop methodology was created by **Geoffrey Huntley**. This implementation builds on his original concept and the community resources that followed.

### 🔗 Links

| Resource                          | Link                                                                                      |
|-----------------------------------|-------------------------------------------------------------------------------------------|
| 🏠 **Original Ralph**             | [ghuntley.com/ralph](https://ghuntley.com/ralph/)                                         |
| 📖 **Ralph Playbook**             | [claytonfarr.github.io/ralph-playbook](https://claytonfarr.github.io/ralph-playbook/)     |
| 💻 **Playbook Repo**              | [github.com/ClaytonFarr/ralph-playbook](https://github.com/ClaytonFarr/ralph-playbook)    |
| 🔧 **Alternative Implementation** | [github.com/snarktank/ralph](https://github.com/snarktank/ralph)                          |
| 🎥 **Video Walkthrough**          | [YouTube](https://www.youtube.com/watch?v=yAE3ONleUas)                                    |
| 📄 **GitHub Custom Agents**       | [GitHub Blog](https://github.blog/changelog/2025-10-28-custom-agents-for-github-copilot/) |

---

## 📄 License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.