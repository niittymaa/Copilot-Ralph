---
name: Performance Optimization
description: Identify and resolve performance bottlenecks with language-agnostic profiling and optimization strategies
category: Optimization
priority: 7
tags: [performance, optimization, profiling, efficiency]
---

# Performance Optimization Specification

## Objective

Systematically identify and resolve performance bottlenecks across the codebase. Focus on measurable improvements using profiling data rather than premature optimization.

## Core Principles

- **Measure first** - Profile before optimizing
- **Language-agnostic** - Apply universal optimization patterns
- **Data-driven decisions** - Base changes on actual metrics
- **No premature optimization** - Fix proven bottlenecks, not suspected ones
- **Maintain correctness** - Performance gains must not break functionality

## Phase 1: Performance Assessment

### 1.1 Understand the System

1. **Identify performance-critical paths**
   - Entry points (API endpoints, CLI commands, event handlers)
   - Hot paths (frequently executed code)
   - User-facing operations
   - Background processing

2. **Document current baseline**
   - Note any existing performance tests or benchmarks
   - Identify existing profiling tools in the project
   - Check for performance-related configuration

3. **Map resource usage patterns**
   - CPU-intensive operations
   - Memory allocation patterns
   - I/O operations (disk, network, database)
   - Concurrency and parallelism usage

### 1.2 Identify Optimization Targets

1. **Code-level patterns to review**
   - Nested loops and O(n²) or worse algorithms
   - Repeated computations in loops
   - Unnecessary object creation
   - String concatenation in loops
   - Synchronous blocking operations

2. **Data structure efficiency**
   - Appropriate collection types for access patterns
   - Excessive copying vs. references
   - Memory layout and cache efficiency

3. **I/O patterns**
   - N+1 query patterns
   - Unbatched network requests
   - Unbuffered file operations
   - Missing caching opportunities

## Phase 2: Optimization Implementation

### 2.1 Algorithmic Improvements

**Replace inefficient algorithms:**

1. **Reduce time complexity**
   - Use hash-based lookups (O(1)) instead of linear search (O(n))
   - Pre-compute and cache expensive calculations
   - Use appropriate data structures for access patterns

2. **Reduce space complexity**
   - Stream processing vs. loading everything in memory
   - Lazy evaluation for expensive computations
   - Memory pooling for frequently allocated objects

3. **Early termination**
   - Break out of loops when result is found
   - Short-circuit boolean expressions
   - Return early on failure conditions

### 2.2 I/O Optimization

1. **Batch operations**
   - Combine multiple database queries
   - Batch network requests
   - Buffer file writes

2. **Async/parallel processing**
   - Parallelize independent I/O operations
   - Use async patterns for non-blocking I/O
   - Implement proper concurrency controls

3. **Caching strategies**
   - Cache expensive computations
   - Cache external API responses (with appropriate TTL)
   - Use memoization for pure functions

### 2.3 Memory Optimization

1. **Reduce allocations**
   - Reuse objects where safe
   - Pre-size collections when size is known
   - Use object pooling for frequent allocations

2. **Avoid memory leaks**
   - Ensure proper cleanup of resources
   - Clear references that are no longer needed
   - Review event listener cleanup

3. **Efficient data handling**
   - Use streaming for large data sets
   - Implement pagination for large result sets
   - Compress data when appropriate

### 2.4 Common Patterns to Apply

**Loop optimization:**
- Move invariant computations outside loops
- Avoid function calls in loop conditions
- Use iterators instead of index-based access when appropriate

**String handling:**
- Use string builders for concatenation in loops
- Avoid unnecessary string conversions
- Intern frequently used strings if language supports

**Collection handling:**
- Choose the right collection type for access pattern
- Pre-size collections when possible
- Use views/slices instead of copies

## Phase 3: Database Optimization

### 3.1 Query Optimization

1. **Identify slow queries**
   - N+1 patterns (multiple queries where one would suffice)
   - Missing indexes for common query patterns
   - Overfetching (selecting more columns than needed)
   - Full table scans

2. **Implement improvements**
   - Add appropriate indexes
   - Use eager loading to prevent N+1
   - Select only required fields
   - Use query analysis tools if available

### 3.2 Connection Management

- Use connection pooling
- Proper connection cleanup
- Appropriate timeout configuration

## Phase 4: Validation

### 4.1 Verify Improvements

1. **Test functionality**
   - Run all existing tests
   - Verify behavior is unchanged
   - Check edge cases still work

2. **Measure improvements**
   - Compare before/after where measurable
   - Document performance gains
   - Note any tradeoffs

### 4.2 Ensure No Regressions

- Build must succeed
- All tests must pass
- No new bugs introduced

## Deliverables

- [ ] Performance assessment completed
- [ ] Algorithmic improvements implemented
- [ ] I/O optimizations applied
- [ ] Memory optimizations applied
- [ ] Database queries optimized (if applicable)
- [ ] All tests passing
- [ ] Performance improvements documented in progress.txt

## Constraints

- **Correctness over speed** - Never sacrifice correctness for performance
- **Maintainability** - Optimized code must still be readable
- **No breaking changes** - Existing APIs and behavior preserved
- **Proportional effort** - Focus on biggest bottlenecks first

## Success Criteria

- Identified bottlenecks are resolved
- No functionality regressions
- All tests pass
- Code remains maintainable
- Improvements are documented with rationale
