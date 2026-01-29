---
name: Internationalization (i18n)
description: Implement or improve internationalization support for multi-language applications
category: Localization
priority: 6
tags: [i18n, internationalization, localization, l10n, translation]
---

# Internationalization (i18n) Specification

## Objective

Implement or improve internationalization support across the codebase, enabling the application to support multiple languages and locales. Focus on extracting hardcoded strings, implementing proper i18n patterns, and ensuring the codebase is ready for localization.

## Core Principles

- **Separation of concerns** - Content separate from code
- **Language-agnostic implementation** - Detect and use existing i18n frameworks
- **No hardcoded strings** - All user-facing text externalized
- **Cultural awareness** - Handle dates, numbers, currencies appropriately
- **Scalability** - Easy to add new languages

## Phase 1: i18n Assessment

### 1.1 Discover Existing Infrastructure

1. **Identify i18n framework**
   - Search for i18n configuration files
   - Check package manifests for i18n libraries
   - Look for translation file directories (locales/, i18n/, lang/, translations/)
   - Examine existing translation files (.json, .yaml, .po, .xliff, .properties)

2. **Map current state**
   - Existing language/locale files
   - Default language configuration
   - Translation loading mechanism
   - Locale switching implementation

3. **Identify patterns in use**
   - Translation function calls (t(), $t, i18n(), gettext, etc.)
   - Interpolation syntax
   - Pluralization handling
   - Date/number formatting

### 1.2 Find Hardcoded Strings

1. **User-facing text locations**
   - UI templates and components
   - Error messages
   - Validation messages
   - Notifications and alerts
   - Email templates
   - PDF/document generation
   - CLI output

2. **String categories to extract**
   - Labels and headings
   - Button text
   - Placeholder text
   - Help text and tooltips
   - Status messages
   - Confirmation dialogs

3. **Exclude from extraction**
   - Log messages (typically not translated)
   - Developer-facing errors
   - Internal identifiers
   - Technical values

## Phase 2: Implementation

### 2.1 Setup i18n Infrastructure (if not exists)

1. **Choose appropriate patterns**
   - Key-based translations (recommended)
   - Namespace organization for large apps
   - Fallback language configuration

2. **Create translation file structure**
   ```
   locales/
   ├── en/
   │   ├── common.json
   │   ├── errors.json
   │   └── [feature].json
   └── [other-locales]/
   ```

3. **Implement translation loading**
   - Lazy loading for large translation sets
   - Caching strategy
   - Fallback handling

### 2.2 String Extraction

**Replace hardcoded strings with translation keys:**

```
Before: "Welcome back, {name}!"
After:  t('greeting.welcome', { name: userName })

Before: "Save Changes"
After:  t('actions.save')

Before: "{count} items"
After:  t('items.count', { count }, count)  // with pluralization
```

**Key naming conventions:**
- Use dot notation for hierarchy (section.subsection.key)
- Descriptive but concise keys
- Group by feature or page
- Consistent naming patterns

### 2.3 Handle Dynamic Content

1. **Interpolation**
   - Variable substitution in translations
   - Safe HTML rendering where needed
   - Component embedding (if framework supports)

2. **Pluralization**
   - Implement plural forms correctly
   - Handle zero, one, few, many, other cases
   - Use ICU message format if available

3. **Gender and grammar**
   - Context-aware translations where needed
   - Grammatical variations

### 2.4 Date, Time, and Number Formatting

1. **Use locale-aware formatting**
   - Dates (respect locale date formats)
   - Times (12h vs 24h)
   - Numbers (decimal/thousand separators)
   - Currencies (symbol, position, decimals)

2. **Relative time**
   - "2 days ago", "in 3 hours"
   - Use relative time formatters

3. **Time zones**
   - Display in user's timezone
   - Store in UTC

### 2.5 RTL (Right-to-Left) Support

If supporting RTL languages:

1. **Layout considerations**
   - Use logical properties (start/end vs left/right)
   - Mirror layouts appropriately
   - Handle bidirectional text

2. **CSS adjustments**
   - dir="rtl" attribute support
   - Logical CSS properties
   - Icon mirroring where appropriate

## Phase 3: Translation Management

### 3.1 Create Base Translations

1. **Extract to default locale**
   - All strings in primary language
   - Proper key organization
   - Context comments for translators

2. **Add translator context**
   - Comments explaining usage
   - Character limits if UI constrained
   - Placeholders documentation

### 3.2 Translation File Format

Organize translations logically:

```json
{
  "common": {
    "actions": {
      "save": "Save",
      "cancel": "Cancel",
      "delete": "Delete"
    },
    "status": {
      "loading": "Loading...",
      "error": "An error occurred"
    }
  },
  "feature": {
    "title": "Feature Title",
    "description": "Feature description"
  }
}
```

### 3.3 Missing Translation Handling

- Configure fallback behavior
- Log missing translations in development
- Display key or fallback in production

## Phase 4: Validation

### 4.1 Verify Implementation

1. **Test language switching**
   - All strings update correctly
   - No hardcoded strings remain
   - Layout adjusts properly

2. **Test interpolation**
   - Variables render correctly
   - Pluralization works
   - Special characters handled

3. **Test formatting**
   - Dates display in locale format
   - Numbers format correctly
   - Currencies display properly

### 4.2 Quality Checks

- No broken translation keys
- No missing translations for default locale
- Consistent key naming
- All tests pass

## Deliverables

- [ ] i18n infrastructure set up or verified
- [ ] Hardcoded strings extracted to translation files
- [ ] Translation keys organized logically
- [ ] Date/number formatting localized
- [ ] Pluralization implemented where needed
- [ ] All tests passing
- [ ] Summary of i18n changes in progress.txt

## Constraints

- **Use existing framework** - Don't replace working i18n setup
- **Preserve meaning** - Translations must convey same intent
- **No breaking changes** - Existing functionality preserved
- **Framework-agnostic** - Adapt to whatever i18n library is in use

## Success Criteria

- No user-facing hardcoded strings remain
- Language switching works correctly
- All formatting respects locale
- Build and tests pass
- Translation files are well-organized
