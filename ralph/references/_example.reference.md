# Reference Files Guide

## What Are Reference Files?

Reference files are **supporting materials** that help Ralph understand your project context. Unlike specs (which define WHAT to build), references provide context, examples, and visual guidance.

## Supported Reference Types

### 🖼️ Images
- **UI mockups** - Sketches, wireframes, or designs of the interface
- **Architecture diagrams** - System design, data flow, component relationships
- **Screenshots** - Examples from existing apps or competitors
- **Inspiration** - Visual references for design style

**Supported formats**: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.bmp`, `.svg`

### 📄 Documentation
- **API documentation** - Existing API specs you want to integrate with
- **Style guides** - Design systems, branding guidelines
- **README files** - Context about the project
- **Meeting notes** - Discussions about requirements

**Supported formats**: `.md`, `.txt`

### 📊 Data Files
- **JSON/YAML** - Configuration examples, data schemas
- **CSV** - Sample data, user lists
- **XML** - Legacy formats, configurations

**Supported formats**: `.json`, `.yaml`, `.yml`, `.xml`, `.csv`

### 💻 Code Samples
- **Example implementations** - Reference code from other projects
- **Code snippets** - Patterns or utilities to follow
- **Third-party examples** - How libraries are used

**Supported formats**: `.ps1`, `.py`, `.js`, `.ts`, `.cs`, `.java`, `.go`, etc.

## Usage Examples

### Example 1: UI Design from Images
```
ralph/references/
├── homepage-mockup.png
├── login-screen.png
└── dashboard-layout.png
```
Ralph will analyze these images and understand the UI structure, layout patterns, and visual design when creating implementation specs.

### Example 2: API Integration
```
ralph/references/
├── stripe-api-docs.md
├── auth-flow-diagram.png
└── example-api-response.json
```
Ralph will use these to understand the API structure and integration requirements.

### Example 3: Design System
```
ralph/references/
├── design-system.md
├── color-palette.png
├── component-library.md
└── typography-guide.md
```
Ralph will follow the design system guidelines when generating UI code.

## Best Practices

### ✅ Do
- **Organize by purpose** - Group related references together
- **Use clear filenames** - `user-registration-flow.png` instead of `image1.png`
- **Include context** - Add a README.md explaining the references
- **Keep it relevant** - Only include files that help understand the project

### ❌ Don't
- **Mix specs and references** - Keep specs in `spec/` or `specs/` folders
- **Use template files here** - This folder is for actual reference materials
- **Include private/sensitive data** - Be cautious with production data or secrets
- **Upload huge files** - Optimize images, use reasonable file sizes

## Working Without Specs

Ralph can work with **references only**! If you provide:
- UI mockup images
- Example code
- Documentation

Ralph will:
1. Analyze the references
2. Extract requirements from visuals and examples
3. Generate specs automatically
4. Build the implementation

This is great for:
- Prototyping from designs
- Cloning existing functionality
- Building from visual references

## Getting Started

1. **Delete this file** when you add your own references
2. **Add your reference files** to this folder
3. **Run Ralph** and select "Use default references folder"
4. Ralph will analyze all files and use them as context

---

**Note**: This is an example file (starts with `_`). Ralph will skip files starting with underscore, so you can keep notes here without affecting the build.
