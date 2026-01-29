---
name: Simple Tetris
description: A classic Tetris game with falling tetrominoes, line clearing, and scoring
category: game
---

# Simple Tetris - Baseline Test Specification

## Overview

Build a browser-based classic Tetris game with all 7 standard tetromino shapes, rotation, line clearing, and progressive difficulty.

## Core Mechanics

### Tetromino Pieces
- All 7 standard shapes: I, O, T, S, Z, J, L
- Each shape has distinct color
- Rotation with basic wall-kick
- Preview of next piece

### Game Grid
- Standard 10 columns x 20 rows
- Pieces fall from top center
- Collision detection with walls, floor, and placed pieces

### Line Clearing
- Complete horizontal lines are cleared
- Multiple simultaneous line clears award bonus points
- Blocks above cleared lines fall down

### Controls
- Left/Right arrows: Move piece horizontally
- Down arrow: Soft drop (faster fall)
- Up arrow or Space: Rotate clockwise
- Hard drop key for instant placement

## Technical Requirements

### File Structure
- Separate HTML, CSS, and JavaScript files
- Optional: Test file for game logic

### Code Organization
- Use classes for Tetromino, GameBoard entities
- Separate game state management from rendering
- Use requestAnimationFrame for game loop

### Visual Requirements
- Grid-based canvas rendering
- Ghost piece showing landing position (optional)
- UI showing score, level, lines, next piece
- Start, pause, and game over screens

## Acceptance Criteria

1. [ ] Game loads and displays 10x20 grid
2. [ ] Tetrominoes fall from top
3. [ ] All 7 piece types work correctly
4. [ ] Pieces can be moved left/right
5. [ ] Pieces can be rotated
6. [ ] Collision detection works
7. [ ] Complete lines are cleared
8. [ ] Score increases with line clears
9. [ ] Game ends when pieces stack to top
10. [ ] Level/speed progression works
