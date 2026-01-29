---
name: Codebase Cleanup
description: Complete audit to remove redundancy, fix issues, and modernize the codebase
category: Code Quality
priority: 15
tags: [cleanup, modernization, technical-debt]
---

# Codebase Cleanup Specification

## Objective

Perform a complete, uncompromising audit of the entire application and codebase. Remove all redundancy, fix all issues, and modernize to current standards. Backward compatibility is explicitly forbidden.

## Phase 1: Issue Discovery

### 1.1 Build & Runtime Analysis

1. **Collect all warnings and errors**
   - Compiler warnings
   - Linter violations
   - Type checker issues
   - Runtime deprecation notices

2. **Run static analysis**
   - Code quality tools
   - Complexity analyzers
   - Dead code detection

3. **Review test output**
   - Failing tests
   - Skipped tests
   - Flaky tests

### 1.2 Code Quality Issues

1. **Identify duplicated logic**
   - Copy-pasted code blocks
   - Similar functions that could be unified
   - Overlapping functionality across modules

2. **Find dead code**
   - Unused functions
   - Unreachable code paths
   - Commented-out code
   - Unused imports

3. **Detect anti-patterns**
   - God classes/functions
   - Circular dependencies
   - Leaky abstractions
   - Over-engineering

### 1.3 Naming Audit

Review all identifiers for:
- **Consistency** with language conventions
- **Clarity** - names should communicate intent
- **Accuracy** - names should match behavior
- **Appropriate scope indication**

## Phase 2: Cleanup Execution

### 2.1 Warning Resolution

**Resolve EVERY warning without exception:**
- Compiler/interpreter warnings
- Linter violations
- Type checker errors
- Deprecation warnings
- Static analysis findings

### 2.2 Dead Code Removal

Remove all:
- **Unused functions and methods**
- **Unused variables and imports**
- **Commented-out code** (use version control instead)
- **Obsolete files** not referenced anywhere
- **Unused dependencies**

### 2.3 Duplication Elimination

- **Extract common logic** into shared utilities
- **Unify similar implementations** under one solution
- **Remove redundant abstractions** that add no value
- **Consolidate configuration** scattered across files

### 2.4 Modernization

- **Update to current language features** - remove deprecated constructs
- **Use modern APIs** - replace legacy/obsolete calls
- **Update dependencies** - remove end-of-life packages
- **Apply current best practices** - follow updated standards

### 2.5 Naming Standardization

Apply language-specific conventions:
- **Variables**: camelCase/snake_case per language standard
- **Functions**: verbs that describe action
- **Classes**: nouns that describe the entity
- **Constants**: UPPER_CASE or language convention
- **Files**: consistent naming scheme

Remove problematic names:
- Misleading names (doX that actually does Y)
- Ambiguous abbreviations
- Implementation-detail leakage in public APIs
- Inconsistent patterns (mixing conventions)

### 2.6 Architectural Cleanup

- **Fix circular dependencies**
- **Establish clear module boundaries**
- **Remove unnecessary abstraction layers**
- **Simplify over-engineered solutions**

## Phase 3: Validation

### 3.1 Zero Tolerance Checks

After cleanup, the codebase must have:
- **Zero compiler/interpreter warnings**
- **Zero linter violations**
- **Zero type checker errors**
- **Zero failing tests**
- **Zero skipped tests** (fix or remove with justification)

### 3.2 Functionality Verification

- All tests pass
- Manual verification of critical paths
- No runtime errors or exceptions
- Build completes successfully

## Deliverables

- [ ] All warnings and errors resolved
- [ ] All dead code removed
- [ ] All duplication eliminated
- [ ] All naming standardized
- [ ] Dependencies updated to current versions
- [ ] Build succeeds with zero warnings
- [ ] All tests pass
- [ ] Changes documented in progress.txt

## Constraints

- **No backward compatibility** - remove legacy patterns completely
- **No transitional code** - no shims, polyfills, adapters, or compatibility layers
- **No speculative features** - remove unused "future-proofing"
- **Zero tolerance for warnings** - every warning must be fixed

## Forbidden Actions

Do NOT:
- Add compatibility wrappers
- Keep deprecated code "just in case"
- Suppress warnings without fixing root cause
- Skip failing tests

## Success Criteria

The final codebase must:
- Build with zero warnings
- Pass all tests with zero failures
- Have no deprecated constructs
- Use only current, supported dependencies
- Follow consistent naming throughout
- Contain no dead or redundant code
