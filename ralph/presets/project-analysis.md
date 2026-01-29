---
name: Project Structure Analysis
description: Deep analysis and blueprint of the entire codebase architecture
category: Analysis
priority: 20
tags: [analysis, documentation, architecture, blueprint]
---

# Project Structure Analysis Specification

## Objective

Perform a comprehensive deep-dive analysis of the entire codebase. Generate a complete blueprint that documents the architecture, patterns, conventions, and structure in a way that enables complete understanding of the project.

## Deliverable

Create a **PROJECT_ANALYSIS.md** file in the project root containing the complete analysis.

## Analysis Phases

### Phase 1: High-Level Overview

#### 1.1 Project Identification
- Project name and purpose
- Primary technology stack (languages, frameworks, runtime)
- Project type (web app, CLI, library, API, etc.)
- Target platform(s)

#### 1.2 Directory Structure Map
Create a complete tree of the project with annotations:
```
project-root/
├── src/                 # Source code
│   ├── components/      # UI components
│   ├── services/        # Business logic
│   └── utils/           # Shared utilities
├── tests/               # Test files
├── docs/                # Documentation
└── config/              # Configuration files
```

### Phase 2: Technical Analysis

#### 2.1 Architecture Pattern
- Architectural style (MVC, MVVM, Clean Architecture, etc.)
- Layer organization
- Dependency flow diagram (text-based)

#### 2.2 Entry Points
- Application entry point(s)
- CLI commands (if applicable)
- API endpoints (if applicable)
- Event handlers and listeners

#### 2.3 Core Components
For each major component/module:
- **Purpose**: What it does
- **Location**: Where it lives
- **Dependencies**: What it uses
- **Dependents**: What uses it
- **Key files**: Main implementation files

#### 2.4 Data Flow
- How data enters the system
- How data is processed/transformed
- How data is stored/persisted
- How data exits the system

### Phase 3: Code Conventions

#### 3.1 Naming Conventions
Document actual patterns found:
- Variable naming (camelCase, snake_case, etc.)
- Function/method naming
- Class/type naming
- File naming
- Directory naming

#### 3.2 Code Organization
- How files are organized within directories
- Import/export patterns
- Module boundary conventions
- Where different types of code belong

#### 3.3 Coding Style
- Formatting patterns (indentation, line length)
- Comment style and expectations
- Documentation conventions
- Error handling patterns

### Phase 4: Build & Runtime

#### 4.1 Build System
- Build tool(s) used
- Build commands
- Build output location
- Build configuration files

#### 4.2 Dependencies
- Package manager(s) used
- Key dependencies and their purposes
- Development dependencies
- Dependency lock files

#### 4.3 Configuration
- Configuration file locations
- Environment variable usage
- Runtime configuration patterns
- Secrets management approach

### Phase 5: Testing

#### 5.1 Test Strategy
- Testing frameworks used
- Test file organization
- Test naming conventions
- Coverage expectations

#### 5.2 Test Types Present
- Unit tests
- Integration tests
- End-to-end tests
- Other test types

### Phase 6: Key Patterns & Decisions

#### 6.1 Design Patterns
Document patterns actively used:
- Creational patterns (Factory, Singleton, etc.)
- Structural patterns (Adapter, Decorator, etc.)
- Behavioral patterns (Observer, Strategy, etc.)

#### 6.2 Architectural Decisions
- Why certain approaches were chosen
- Trade-offs made
- Technical debt acknowledged

#### 6.3 Integration Points
- External services/APIs
- Databases
- Message queues
- Third-party services

### Phase 7: Critical Paths

Identify and document:
- **Hot paths** - Performance-critical code
- **Security-sensitive** - Authentication, authorization, data handling
- **Error-prone areas** - Complex logic, known issues
- **Extension points** - How to add new features

## Output Format

The PROJECT_ANALYSIS.md should include:

1. **Executive Summary** (1-2 paragraphs)
2. **Quick Reference**
   - Build commands
   - Test commands
   - Key file locations
3. **Detailed Analysis** (all phases above)
4. **Appendices**
   - Complete file listing with descriptions
   - Dependency graph
   - Glossary of project-specific terms

## Tasks

- [ ] Explore all directories and files
- [ ] Identify technology stack
- [ ] Map component relationships
- [ ] Document naming conventions
- [ ] Record build/test commands
- [ ] Identify key patterns
- [ ] Generate PROJECT_ANALYSIS.md
- [ ] Update AGENTS.md with discovered commands

## Success Criteria

The analysis should enable:
- A new developer to understand the project structure in 30 minutes
- Easy location of any type of code
- Understanding of how to add new features
- Knowledge of build and test procedures
