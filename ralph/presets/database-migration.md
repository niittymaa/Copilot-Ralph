---
name: Database Migration
description: Analyze and implement database schema migrations with safety checks and rollback support
category: Database
priority: 7
tags: [database, migration, schema, data]
---

# Database Migration Specification

## Objective

Analyze the current database state and implement schema migrations safely. Focus on creating reversible migrations, preserving data integrity, and ensuring zero-downtime deployments where possible.

## Core Principles

- **Safety first** - Never lose production data
- **Reversibility** - All migrations should be reversible
- **Idempotency** - Migrations can be run multiple times safely
- **Framework-agnostic** - Detect and use existing migration tools
- **Incremental changes** - Small, focused migrations over large ones

## Phase 1: Database Assessment

### 1.1 Discover Migration Infrastructure

1. **Identify migration framework**
   - Search for migration configuration files
   - Check for migration directories (migrations/, db/migrate/, alembic/, etc.)
   - Examine ORM configuration
   - Review database connection setup

2. **Common frameworks to detect**
   - SQL-based: Flyway, Liquibase, dbmate, golang-migrate
   - ORM-based: Django, Rails, Alembic, Prisma, TypeORM, Sequelize
   - Language-specific: Knex, Diesel, Entity Framework

3. **Understand current state**
   - Existing migrations and their status
   - Schema version tracking mechanism
   - Migration naming conventions
   - Up/down or forward-only migrations

### 1.2 Analyze Schema Requirements

1. **Document current schema**
   - Tables and relationships
   - Indexes and constraints
   - Data types and defaults
   - Foreign key relationships

2. **Identify required changes**
   - New tables or columns
   - Modified columns (type, constraints)
   - Index additions or modifications
   - Relationship changes
   - Data transformations

3. **Assess risk levels**
   - Non-destructive (additive) changes - Low risk
   - Destructive changes (drops, renames) - High risk
   - Data migrations - Variable risk

## Phase 2: Migration Planning

### 2.1 Migration Strategy

**Categorize changes by type:**

1. **Safe changes (can run anytime)**
   - Adding nullable columns
   - Adding new tables
   - Adding indexes (with care for large tables)
   - Adding constraints with defaults

2. **Careful changes (require planning)**
   - Adding NOT NULL columns (need default or backfill)
   - Renaming columns/tables (requires code coordination)
   - Changing column types (data conversion needed)
   - Dropping indexes (performance impact)

3. **Dangerous changes (require extra care)**
   - Dropping columns or tables
   - Removing constraints
   - Truncating data
   - Changing primary keys

### 2.2 Zero-Downtime Patterns

**Column rename pattern:**
1. Add new column
2. Write to both columns (code change)
3. Backfill old → new
4. Read from new column (code change)
5. Drop old column

**Column type change pattern:**
1. Add new column with new type
2. Dual-write to both
3. Backfill with conversion
4. Switch reads to new column
5. Drop old column

**Table rename pattern:**
1. Create new table
2. Dual-write to both
3. Backfill data
4. Switch reads
5. Drop old table

## Phase 3: Migration Implementation

### 3.1 Create Migration Files

**Follow framework conventions:**
- Use framework's migration generator if available
- Follow existing naming patterns
- Include timestamp or version number
- Use descriptive names

**Migration structure:**
```
UP migration:
- Make schema changes
- Transform data if needed
- Add new constraints

DOWN migration:
- Reverse schema changes
- Restore original constraints
- Note: Data loss may occur on rollback
```

### 3.2 Schema Changes

**Adding columns:**
- Specify appropriate data type
- Set sensible defaults for NOT NULL
- Consider index requirements
- Add foreign key constraints as needed

**Modifying columns:**
- Handle existing data appropriately
- Validate data fits new constraints
- Update dependent code first if needed

**Removing columns:**
- Verify column is unused in code
- Consider soft-delete pattern
- Backup data if valuable

### 3.3 Data Migrations

**For data transformations:**
- Use batched updates for large tables
- Include progress logging
- Handle nulls and edge cases
- Validate data after migration

**For backfills:**
- Process in chunks to avoid locking
- Add appropriate WHERE clauses
- Consider off-peak execution

### 3.4 Index Management

**Adding indexes:**
- Use CONCURRENTLY where supported (PostgreSQL)
- Consider table size and locking
- Add indexes in separate migrations

**Removing indexes:**
- Verify index is not used
- Check query performance impact

## Phase 4: Safety Measures

### 4.1 Pre-Migration Checks

1. **Validate migration syntax**
   - Run migration in dry-run mode if available
   - Check SQL syntax
   - Verify rollback works

2. **Test on copy of data**
   - Run against test database
   - Verify data integrity after migration
   - Test rollback procedure

3. **Backup verification**
   - Ensure recent backup exists
   - Verify backup restoration procedure

### 4.2 Migration Execution

**Best practices:**
- Run during low-traffic periods for risky changes
- Monitor database performance during execution
- Have rollback plan ready
- Log migration progress

### 4.3 Post-Migration Validation

1. **Verify schema state**
   - All expected changes applied
   - Constraints are in place
   - Indexes exist

2. **Validate data integrity**
   - Row counts match expectations
   - Data relationships intact
   - No orphaned records

3. **Application verification**
   - Application starts correctly
   - Basic functionality works
   - No database errors in logs

## Phase 5: Documentation

### 5.1 Migration Documentation

- Document the purpose of each migration
- Note any manual steps required
- Record rollback considerations
- Update schema documentation

### 5.2 Operational Notes

- Migration execution commands
- Rollback procedures
- Performance considerations
- Dependencies between migrations

## Deliverables

- [ ] Database assessment completed
- [ ] Migration files created following framework conventions
- [ ] Up and down migrations implemented
- [ ] Data transformations handled safely
- [ ] Migrations tested on development database
- [ ] All application tests passing
- [ ] Migration documentation in progress.txt

## Constraints

- **Use existing migration framework** - Don't introduce new tools
- **Reversible migrations** - All changes should be reversible
- **No data loss** - Preserve existing data unless explicitly required
- **Incremental changes** - One logical change per migration

## Success Criteria

- All migrations run successfully
- Rollback migrations work correctly
- Data integrity maintained
- Application functions correctly
- All tests pass
- No database errors
