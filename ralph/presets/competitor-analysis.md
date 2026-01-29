---
name: Competitor Analysis
description: Analyze the project and research competitors via web search
category: Analysis
priority: 30
tags: [analysis, competitors, market-research, web-search]
---

# Competitor Analysis Specification

## Objective

Analyze the current project/application and identify competing products or solutions. Research competitors through web search to understand the competitive landscape, feature gaps, and market positioning.

## Deliverable

Create a **COMPETITOR_ANALYSIS.md** file in the project root containing the complete analysis.

## Phase 1: Project Understanding

### 1.1 Project Classification

Determine:
- **Project type**: Library, framework, application, service, tool
- **Primary purpose**: What problem does it solve?
- **Target users**: Who would use this?
- **Core features**: What are the main capabilities?
- **Technology domain**: Web, mobile, CLI, data, AI, etc.

### 1.2 Value Proposition

Identify:
- What makes this project useful?
- What pain points does it address?
- What workflows does it improve?
- What alternatives might users consider?

### 1.3 Search Keywords

Generate search terms to find competitors:
- Direct product names (if known)
- Problem-space keywords
- Technology-specific terms
- "Alternative to [similar product]"
- "[Use case] tool/library/framework"

## Phase 2: Competitor Research

### 2.1 Discovery

Use web search to find:
- Direct competitors (same solution approach)
- Indirect competitors (different approach, same problem)
- Established players in the space
- Emerging alternatives
- Open source alternatives
- Commercial alternatives

### 2.2 Per-Competitor Analysis

For each significant competitor, document:

#### Basic Information
- **Name**: Product/project name
- **URL**: Website or repository
- **Type**: Open source / Commercial / Freemium
- **Maturity**: Established / Growing / New / Declining

#### Feature Comparison
- Core features
- Unique features (that we don't have)
- Missing features (that we have)
- Integration capabilities

#### Technical Aspects
- Technology stack
- Supported platforms
- Performance claims
- Scalability approach

#### Adoption & Community
- GitHub stars (if applicable)
- Downloads/usage metrics
- Community size
- Documentation quality
- Support options

#### Business Model
- Pricing (if commercial)
- License (if open source)
- Enterprise offerings
- Support tiers

## Phase 3: Comparative Analysis

### 3.1 Feature Matrix

Create a comparison table:

| Feature | Our Project | Competitor A | Competitor B | Competitor C |
|---------|-------------|--------------|--------------|--------------|
| Feature 1 | ✓ | ✓ | ✗ | ✓ |
| Feature 2 | ✓ | ✗ | ✓ | ✓ |
| Feature 3 | ✗ | ✓ | ✓ | ✗ |

### 3.2 SWOT Analysis

**Strengths** (vs competitors)
- What do we do better?
- What unique capabilities do we have?

**Weaknesses** (vs competitors)
- Where do competitors excel?
- What features are we missing?

**Opportunities**
- Underserved user needs
- Feature gaps in market
- Emerging use cases

**Threats**
- Well-funded competitors
- Market consolidation
- Technology shifts

### 3.3 Positioning Map

Describe where the project fits on key dimensions:
- Simplicity ←→ Power
- Beginner ←→ Expert
- Free ←→ Paid
- Specialized ←→ General purpose

## Phase 4: Strategic Insights

### 4.1 Differentiation Opportunities

Based on analysis:
- Features to add
- Unique angles to emphasize
- Underserved niches

### 4.2 Competitive Advantages

Current strengths to leverage:
- Technical advantages
- Community advantages
- Ease of use
- Cost advantages

### 4.3 Recommendations

Actionable suggestions:
- Short-term improvements
- Long-term strategy
- Marketing positioning
- Partnership opportunities

## Output Format

### COMPETITOR_ANALYSIS.md Structure

```markdown
# Competitor Analysis: [Project Name]

## Executive Summary
Brief overview of competitive landscape (3-5 sentences)

## Our Project Profile
- Type: [type]
- Purpose: [description]
- Target Users: [audience]
- Key Features: [list]

## Competitors Identified

### [Competitor 1 Name]
[Full analysis per template above]

### [Competitor 2 Name]
[Full analysis per template above]

[Additional competitors...]

## Feature Comparison Matrix
[Table]

## SWOT Analysis
[Analysis]

## Market Positioning
[Description and recommendations]

## Strategic Recommendations
[Actionable items]

## Appendix
- Search terms used
- Sources referenced
- Date of analysis
```

## Tasks

- [ ] Analyze project to understand its purpose and features
- [ ] Generate search terms for competitor research
- [ ] Search web for competitors
- [ ] Document at least 3-5 competitors in detail
- [ ] Create feature comparison matrix
- [ ] Perform SWOT analysis
- [ ] Generate strategic recommendations
- [ ] Create COMPETITOR_ANALYSIS.md

## Notes

- Use web search capabilities to find current information
- Focus on relevance over quantity
- Include both open source and commercial options
- Consider international competitors if relevant
- Date-stamp the analysis for future reference

## Success Criteria

Analysis is complete when:
- At least 3 competitors thoroughly researched
- Feature comparison table included
- SWOT analysis completed
- Actionable recommendations provided
- All sources cited
