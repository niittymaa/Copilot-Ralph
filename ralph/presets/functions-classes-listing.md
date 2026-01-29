---
name: Functions & Classes Listing
description: Generate a complete reference of all functions, classes, and APIs in the project
category: Analysis
priority: 35
tags: [analysis, api-reference, functions, classes, inventory]
---

# Functions & Classes Listing Specification

## Objective

Generate a complete, organized reference document listing all functions, classes, methods, and APIs in the project. This serves as a quick lookup reference and helps understand the codebase scope.

## Deliverable

Create a **CODE_REFERENCE.md** file in the project root containing the complete listing.

## Phase 1: Discovery

### 1.1 Language Detection

Identify all programming languages in the project to determine what constructs to look for:

| Language | Constructs to Find |
|----------|-------------------|
| Python | classes, functions, methods, decorators |
| JavaScript/TypeScript | classes, functions, methods, arrow functions, exports |
| Java/Kotlin | classes, interfaces, methods, enums |
| C# | classes, interfaces, methods, structs, enums |
| Go | structs, functions, methods, interfaces |
| Rust | structs, traits, functions, impl blocks |
| PHP | classes, traits, functions, methods |
| Ruby | classes, modules, methods |
| C/C++ | structs, classes, functions |

### 1.2 Source File Inventory

List all source files that contain code to analyze:
- Main source directories
- Library code
- Utility modules
- Test files (if applicable)

## Phase 2: Extraction

### 2.1 Class/Type Definitions

For each class/struct/interface/type, document:
- **Name**: The identifier
- **File**: Where it's defined
- **Line**: Line number
- **Type**: class/struct/interface/enum/type alias
- **Extends/Implements**: Parent classes/interfaces
- **Description**: Brief purpose (from docstring if available)

### 2.2 Functions/Methods

For each function or method, document:
- **Name**: The identifier
- **File**: Where it's defined
- **Line**: Line number
- **Parent**: Containing class/module (if applicable)
- **Visibility**: public/private/protected (if applicable)
- **Parameters**: List with types if available
- **Return type**: If available
- **Description**: Brief purpose (from docstring if available)

### 2.3 Constants & Exports

For each significant constant or export:
- **Name**: The identifier
- **File**: Where it's defined
- **Type**: constant/export/enum value
- **Value**: The value (if simple and non-sensitive)

## Phase 3: Organization

### 3.1 By Module/File

Organize listings hierarchically:
```
src/
├── components/
│   ├── Button.tsx
│   │   ├── class Button
│   │   ├── function handleClick()
│   │   └── function render()
│   └── Modal.tsx
│       ├── class Modal
│       └── function open()
└── utils/
    └── helpers.ts
        ├── function formatDate()
        └── function parseJSON()
```

### 3.2 By Type

Also create categorical listings:
- All classes (alphabetical)
- All interfaces
- All functions
- All constants

### 3.3 By Visibility

Group by access level:
- Public API (exported/public)
- Internal (package-private)
- Private

## Output Format

### CODE_REFERENCE.md Structure

```markdown
# Code Reference: [Project Name]

## Summary

| Metric | Count |
|--------|-------|
| Files | X |
| Classes | X |
| Interfaces | X |
| Functions | X |
| Methods | X |
| Constants | X |

## By Module

### src/components/

#### Button.tsx

**Classes:**
| Name | Line | Description |
|------|------|-------------|
| Button | 15 | Primary button component |

**Functions/Methods:**
| Name | Line | Visibility | Parameters | Returns | Description |
|------|------|------------|------------|---------|-------------|
| handleClick | 25 | private | event: MouseEvent | void | Handles click events |
| render | 45 | public | - | JSX.Element | Renders the button |

[Continue for each file...]

## Alphabetical Index

### Classes
- [Button](src/components/Button.tsx#L15) - Primary button component
- [Modal](src/components/Modal.tsx#L10) - Modal dialog component

### Functions
- [formatDate](src/utils/helpers.ts#L5) - Formats date to string
- [handleClick](src/components/Button.tsx#L25) - Handles click events
- [parseJSON](src/utils/helpers.ts#L20) - Safely parses JSON

### Interfaces
- [ButtonProps](src/components/Button.tsx#L5) - Button component props
- [ModalOptions](src/components/Modal.tsx#L5) - Modal configuration

## Public API

Functions and classes exported for external use:

### Exports from index.ts
| Export | Type | Source |
|--------|------|--------|
| Button | class | src/components/Button.tsx |
| formatDate | function | src/utils/helpers.ts |

## Statistics

### By File Type
| Extension | Files | Functions | Classes |
|-----------|-------|-----------|---------|
| .ts | 15 | 45 | 12 |
| .tsx | 8 | 24 | 8 |

### Largest Files (by function count)
1. src/utils/helpers.ts - 25 functions
2. src/api/client.ts - 18 functions
3. src/components/Form.tsx - 15 functions
```

## Tasks

- [ ] Detect programming languages used
- [ ] Inventory all source files
- [ ] Extract class definitions
- [ ] Extract function definitions
- [ ] Extract interface/type definitions
- [ ] Extract constants and exports
- [ ] Organize by module
- [ ] Create alphabetical index
- [ ] Generate summary statistics
- [ ] Create CODE_REFERENCE.md

## Extraction Guidelines

### What to Include
- All public classes and functions
- Protected/internal functions (marked as internal)
- Significant private functions (core logic)
- All interfaces and type definitions
- Exported constants

### What to Exclude
- Generated code
- Minified/bundled files
- Dependencies (node_modules, vendor, etc.)
- Build output
- Trivial getters/setters (optionally)

### Handling Large Codebases

For very large projects:
- Focus on public API first
- Group by package/module
- Link to source files rather than inline details
- Consider separate files per module

## Success Criteria

Reference is complete when:
- Every source file examined
- All public classes documented
- All public functions documented
- All interfaces/types documented
- Alphabetical index complete
- Statistics accurate
- Links to source files work
