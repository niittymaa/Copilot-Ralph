# Ralph Optimizer

A meta-optimization framework for systematically testing and improving Ralph's agent configurations.

## Quick Start

```powershell
# Run the standard Tetris benchmark
.\benchmark.ps1

# Quick benchmark (5 iterations, faster)
.\benchmark.ps1 -Quick

# Compare all benchmark runs
.\benchmark.ps1 -Compare

# Benchmark with a specific model
.\benchmark.ps1 -Model gpt-4.1 -KeepProject
```

## Benchmark Tool

The benchmark uses a standardized Tetris game specification to measure Ralph's code generation quality.

```powershell
# Standard benchmark (15 iterations)
.\benchmark.ps1

# Quick benchmark (5 iterations)
.\benchmark.ps1 -Quick

# Keep the generated project for inspection
.\benchmark.ps1 -KeepProject

# Compare history of all benchmarks
.\benchmark.ps1 -Compare
```

### Benchmark Grades

| Score | Grade | Description |
|-------|-------|-------------|
| 90+ | A+ | Excellent |
| 80-89 | A | Great |
| 70-79 | B | Good |
| 60-69 | C | Acceptable |
| 50-59 | D | Needs Work |
| <50 | F | Poor |

## Advanced Usage

```powershell
# Analyze an existing project
.\optimizer.ps1 -Mode metrics -ProjectPath "path\to\project"

# Run baseline experiment (current agents)
.\optimizer.ps1 -Mode baseline

# Run full optimization loop
.\optimizer.ps1 -Mode optimize -MaxExperiments 5
```

## Modes

| Mode | Description |
|------|-------------|
| `metrics` | Analyze a project and display quality scores |
| `baseline` | Run experiment with current agents |
| `variant` | Run experiment with a specific agent variant |
| `optimize` | Full optimization loop with convergence detection |
| `analyze` | Compare all experiments and find best configuration |
| `report` | Generate detailed report of all experiments |

## Quality Metrics

The framework measures output quality across four categories:

### Structure (40% weight)
- **File Separation**: Separate files (js/css/html) vs monolithic
- **Directory Structure**: Proper organization (src/, tests/, etc.)
- **Module Count**: Number of distinct code files

### Code (30% weight)
- **Total Lines**: Raw line count
- **Function Count**: Number of defined functions
- **Function Length**: Smaller is better (ideal: 20-30 lines)
- **Comment Ratio**: Ideal range: 5-20%

### Quality (20% weight)
- **Test Files**: Number of test files created
- **Test Ratio**: Test lines / production lines

### Efficiency (10% weight)
- **Commits**: Number of iterations
- **Task Completion**: Completed / planned tasks

## Agent Variants

Predefined variants for A/B testing:

| Variant | Target |
|---------|--------|
| `structure-emphasis` | File separation and directory structure |
| `test-emphasis` | Test creation and coverage |
| `task-consolidation` | Larger, more consolidated tasks |
| `efficiency-focus` | Reducing wasted iterations |

## Example Usage

```powershell
# Compare two projects
.\optimizer.ps1 -Mode metrics -ProjectPath "D:\project-A"
.\optimizer.ps1 -Mode metrics -ProjectPath "D:\project-B"

# List available variants
.\optimizer.ps1 -Mode variant

# Run specific variant
.\optimizer.ps1 -Mode variant -VariantName structure-emphasis

# Full optimization with custom settings
.\optimizer.ps1 -Mode optimize -MaxExperiments 10 -MaxIterationsPerExperiment 20
```

## Convergence

The optimization loop stops when:
- 3 consecutive experiments with no improvement
- Score exceeds 90%
- Max experiments reached

## Output

Results are stored in `ralph/optimizer/results/`:
- `experiments.json` - All experiment data
- Individual experiment folders with full project output
