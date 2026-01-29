---
name: Accessibility Audit
description: Comprehensive accessibility audit and remediation following WCAG guidelines
category: Accessibility
priority: 6
tags: [accessibility, a11y, wcag, usability]
---

# Accessibility Audit Specification

## Objective

Perform a comprehensive accessibility audit and remediation of the codebase. Ensure the application is usable by people with disabilities, following WCAG (Web Content Accessibility Guidelines) principles and best practices.

## Core Principles

- **Perceivable** - Information must be presentable in ways users can perceive
- **Operable** - Interface components must be operable by all users
- **Understandable** - Information and operation must be understandable
- **Robust** - Content must be robust enough for various assistive technologies

## Phase 1: Accessibility Assessment

### 1.1 Identify Accessibility-Relevant Code

1. **UI components and templates**
   - HTML templates
   - Component files (React, Vue, Angular, etc.)
   - CSS/styling files
   - Any markup generation

2. **User interaction handlers**
   - Event handlers
   - Form handling
   - Navigation logic
   - Modal/dialog management

3. **Dynamic content**
   - AJAX/fetch operations that update UI
   - Real-time updates
   - Notifications and alerts
   - Loading states

### 1.2 Audit Categories

#### Images and Media
- [ ] All images have meaningful alt text (or empty alt for decorative)
- [ ] Complex images have detailed descriptions
- [ ] Videos have captions/transcripts
- [ ] Audio has text alternatives

#### Semantic Structure
- [ ] Proper heading hierarchy (h1 → h2 → h3)
- [ ] Landmarks used appropriately (nav, main, aside, footer)
- [ ] Lists use proper list elements
- [ ] Tables have proper headers and scope

#### Keyboard Accessibility
- [ ] All interactive elements are keyboard accessible
- [ ] Focus is visible and logical
- [ ] No keyboard traps
- [ ] Skip links available for navigation

#### Forms and Inputs
- [ ] All inputs have associated labels
- [ ] Required fields are indicated
- [ ] Error messages are clear and associated
- [ ] Form validation is accessible

#### Color and Contrast
- [ ] Sufficient color contrast (4.5:1 for normal text, 3:1 for large)
- [ ] Color is not the only means of conveying information
- [ ] Focus indicators are visible

#### Interactive Elements
- [ ] Buttons and links are distinguishable
- [ ] Custom controls have proper ARIA
- [ ] Touch targets are adequately sized
- [ ] Interactive elements have accessible names

## Phase 2: Remediation

### 2.1 Semantic HTML

**Replace non-semantic elements:**
```
Before: <div onclick="...">Click me</div>
After:  <button type="button">Click me</button>

Before: <span class="link" onclick="...">Link text</span>
After:  <a href="...">Link text</a>
```

**Use proper landmarks:**
- `<header>` for page/section headers
- `<nav>` for navigation
- `<main>` for main content (one per page)
- `<aside>` for complementary content
- `<footer>` for page/section footers

### 2.2 ARIA Implementation

**Only use ARIA when necessary:**
1. Native HTML semantics are always preferred
2. ARIA supplements, never replaces native semantics
3. All interactive ARIA controls need keyboard support

**Common ARIA patterns:**
- `aria-label` / `aria-labelledby` for accessible names
- `aria-describedby` for additional descriptions
- `aria-expanded` for expandable controls
- `aria-hidden="true"` for decorative elements
- `role` attributes for custom widgets
- `aria-live` for dynamic content updates

### 2.3 Keyboard Navigation

**Ensure keyboard operability:**
- All clickable elements must be focusable
- Tab order follows logical reading order
- Custom widgets implement expected keyboard patterns
- Focus management for modals and dynamic content

**Implement focus management:**
```
- Modal opens → focus moves to modal
- Modal closes → focus returns to trigger
- Dynamic content → announce or move focus appropriately
```

### 2.4 Form Accessibility

**Associate labels with inputs:**
```
<label for="email">Email</label>
<input type="email" id="email" name="email">
```

**Error handling:**
- Identify errors clearly
- Associate error messages with inputs
- Provide suggestions for correction
- Allow error correction without losing data

### 2.5 Visual Accessibility

**Color contrast:**
- Verify contrast ratios meet WCAG requirements
- Provide alternatives to color-coded information

**Text and typography:**
- Text can be resized up to 200%
- No loss of content with zoom
- Adequate line height and spacing

**Motion and animation:**
- Respect `prefers-reduced-motion`
- Allow pausing of auto-playing content
- Avoid flashing content (3 flashes/second)

### 2.6 Dynamic Content

**Live regions for updates:**
```
aria-live="polite" - Announces when user is idle
aria-live="assertive" - Announces immediately (use sparingly)
```

**Loading states:**
- Announce loading to screen readers
- Provide progress indication
- Announce completion

## Phase 3: Testing

### 3.1 Automated Testing

1. **Check for existing accessibility tests**
   - axe-core integration
   - pa11y configuration
   - Lighthouse CI

2. **Run static analysis**
   - HTML validation
   - ARIA validation
   - Color contrast checking

### 3.2 Manual Verification

1. **Keyboard testing**
   - Navigate entire interface with Tab/Shift+Tab
   - Operate all controls with keyboard
   - Verify focus visibility

2. **Screen reader testing**
   - Content is announced logically
   - Interactive elements are identified
   - Dynamic updates are announced

### 3.3 Document Issues

- List remaining accessibility issues
- Prioritize by severity
- Note any that cannot be fixed and why

## Phase 4: Documentation

### 4.1 Update Documentation

- Document accessibility features
- Note keyboard shortcuts
- Describe any known limitations

### 4.2 Establish Patterns

- Create accessible component patterns
- Document ARIA usage for custom widgets
- Note testing requirements

## Deliverables

- [ ] Accessibility assessment completed
- [ ] Semantic HTML corrections applied
- [ ] ARIA attributes added where needed
- [ ] Keyboard navigation verified and fixed
- [ ] Form accessibility improved
- [ ] Color/contrast issues addressed
- [ ] All existing tests passing
- [ ] Summary of accessibility improvements in progress.txt

## Constraints

- **Progressive enhancement** - Start with semantic HTML
- **ARIA as supplement** - Not replacement for native semantics
- **No visual regressions** - Maintain design intent
- **Framework-agnostic** - Adapt to whatever UI framework is in use

## Success Criteria

- All identified accessibility issues addressed
- Keyboard navigation works throughout
- Screen reader announces content appropriately
- Color contrast meets WCAG requirements
- No functionality regressions
- Build and tests pass
