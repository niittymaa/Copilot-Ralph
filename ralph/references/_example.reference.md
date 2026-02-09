# Reference Files Guide

## What Are Reference Files?

Reference files are **supporting materials** that help Ralph understand your project context. Unlike specs (which define WHAT to build), references provide context, examples, and visual guidance.

## All File Types Accepted

Ralph accepts **any file type** in the references folder. You can put anything here — individual files, subfolders, or entire codebases. Ralph will recursively explore everything.

### 🖼️ Images
- **UI mockups** - Sketches, wireframes, or designs of the interface
- **Architecture diagrams** - System design, data flow, component relationships
- **Screenshots** - Examples from existing apps or competitors
- Formats like `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.bmp`, `.svg` are analyzed visually

### 📄 Documentation
- **API documentation** - Existing API specs you want to integrate with
- **Style guides** - Design systems, branding guidelines
- **README files** - Context about the project
- Formats like `.md`, `.txt` are inlined into the prompt

### 📊 Data Files
- **JSON/YAML** - Configuration examples, data schemas
- **CSV** - Sample data, user lists
- Formats like `.json`, `.yaml`, `.yml`, `.xml`, `.csv` are parsed and inlined

### 💻 Code & Projects
- **Example implementations** - Reference code from other projects
- **Entire codebases** - Put a whole project folder here and Ralph will explore it
- **Any programming language** - `.py`, `.js`, `.ts`, `.cs`, `.java`, `.go`, `.rs`, `.html`, `.css`, `.vue`, `.jsx`, `.tsx`, etc.

### 📎 Any Other Files
- **Any extension works** - Ralph reads unknown file types as text
- **Subfolders supported** - Nest files however you want

## Usage Examples

### Example 1: UI Design from Images
```
ralph/references/
├── homepage-mockup.png
├── login-screen.png
└── dashboard-layout.png
```
Ralph will analyze these images and understand the UI structure, layout patterns, and visual design when creating implementation specs.

### Example 2: Reference Codebase
```
ralph/references/
└── existing-app/
    ├── src/
    │   ├── components/
    │   │   ├── Header.tsx
    │   │   └── Sidebar.tsx
    │   ├── utils/
    │   │   └── helpers.ts
    │   └── App.tsx
    ├── package.json
    └── README.md
```
Ralph will explore the codebase structure, understand patterns, and use them as reference for building similar features.

### Example 3: Mixed References
```
ralph/references/
├── api-docs/
│   ├── endpoints.md
│   └── auth-flow.yaml
├── design/
│   ├── mockup.png
│   └── color-palette.svg
└── sample-data.json
```
Ralph will use all of these — browsing folders, reading docs, analyzing images, and parsing data files.

## Best Practices

### ✅ Do
- **Put anything relevant** - Files, folders, entire projects
- **Use clear filenames** - `user-registration-flow.png` instead of `image1.png`
- **Organize with subfolders** - Group related references together
- **Include context** - Add a README.md explaining the references

### ❌ Don't
- **Mix specs and references** - Keep specs in `spec/` or `specs/` folders
- **Include private/sensitive data** - Be cautious with production data or secrets
- **Use template files here** - This folder is for actual reference materials

## Working Without Specs

Ralph can work with **references only**! If you provide:
- UI mockup images
- Example code or projects
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
2. **Add your reference files** to this folder (any files, any subfolders)
3. **Run Ralph** and select "Use default references folder"
4. Ralph will discover all files and use them as context

---

**Note**: This is an example file (starts with `_`). Ralph will skip files starting with underscore, so you can keep notes here without affecting the build.
