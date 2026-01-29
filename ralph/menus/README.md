# Ralph Menu System

This folder contains YAML-based menu definitions for the Ralph CLI. The menu system provides:

- **Externalized menu configurations** - Menus are defined in YAML files, not hardcoded
- **Breadcrumb navigation** - Always visible location indicator (e.g., `🏠 Home > Session > Specs`)
- **Back navigation** - Press `[B]` to go back to previous menus
- **Consistent UX** - All menus render with the same style
- **Dynamic menus** - Context-aware item visibility and templates

## Menu Hierarchy

```
🏠 Sessions Home (sessions-home.yaml)
│   ├─ [1-9] Select session → Session Home
│   ├─ [N] New session
│   ├─ [D] Delete session
│   └─ [Q] Quit
│
└─ 📂 Session Home (session.yaml) - Session-specific settings
    ├─ [Enter] Start Ralph
    ├─ 📚 References (references.yaml) - Configure reference files
    ├─ 📝 Specs (specs-settings.yaml) - Configure specifications
    │   ├─ Use default spec folder
    │   ├─ Set custom spec folder
    │   ├─ Clear specs
    │   ├─ Build spec from prompt
    │   └─ Build spec via interview
    ├─ 🤖 AI Model - Change model
    ├─ 📊 Verbose mode - Toggle
    └─ 🔄 Max iterations - Set limit
```

## Menu File Format

Each `.yaml` file defines a menu with the following structure:

```yaml
---
id: menu-name
title: "🏠 MENU TITLE"
description: Optional description shown below title
color: Cyan  # Header color (Cyan, Magenta, Green, Yellow, White, Red)
show_back: true  # Show [B] Back option
show_quit: true  # Show [Q] Quit option
---

# Menu items
- key: 1
  label: First option
  action: action-name
  description: Optional item description
  color: Green
  condition: has_sessions  # Optional visibility condition

- key: 2
  label: Second option
  action: another-action
  submenu: other-menu  # Navigate to another menu

- separator: true  # Horizontal divider
```

## Available Menus

| File | Purpose |
|------|---------|
| `sessions-home.yaml` | Main entry point - lists all sessions |
| `session.yaml` | Session home with settings (references, specs, model, etc.) |
| `specs-settings.yaml` | Specification configuration for a session |
| `references.yaml` | Reference file management |
| `settings.yaml` | Global settings (model, verbose, memory, iterations) |
| `tasks.yaml` | Task management and progress tracking |
| `spec-mode.yaml` | Specification creation mode selection |
| `presets.yaml` | Preset template selection |
| `confirm-delete.yaml` | Delete confirmation |
| `confirm-reset.yaml` | Reset confirmation |

## Terminology

Ralph uses the following terminology:

- **Session** - A working context with its own specs, references, and settings
- **Specs** - Specifications/requirements that define what to build
- **References** - Supporting files (docs, images, code examples)
- **Task** - An individual work item from the implementation plan

## Conditions

Menu items can have visibility conditions:

- `has_sessions` - Sessions exist
- `has_specs` - Specifications are configured
- `has_references` - Reference files are loaded

## Templates

Labels and descriptions support `{{placeholder}}` syntax:

```yaml
- key: M
  label: "AI model ({{current_model}})"
  action: change-model
```

Available template variables:
- `{{session_name}}` - Current session name
- `{{specs_summary}}` - Specs configuration summary
- `{{references_summary}}` - References configuration summary
- `{{current_model}}` - Currently selected AI model
- `{{verbose_status}}` - Verbose mode (ON/OFF)
- `{{max_iterations}}` - Max iterations setting

## Adding New Menus

1. Create a new `.yaml` file in this folder
2. Define the menu structure following the format above
3. Use `Show-Menu -MenuId 'your-menu'` in PowerShell to display it
4. Or use `New-DynamicMenu` for programmatically built menus

## Navigation Stack

The menu system maintains a navigation stack. When navigating to a submenu:

1. Current menu state is pushed to the stack
2. Submenu is displayed with updated breadcrumb
3. Pressing `[B]` pops the stack and returns to previous menu

This enables deep navigation with easy back-tracking.
