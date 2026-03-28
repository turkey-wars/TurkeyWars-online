# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 48 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.6 (Forward Plus renderer)
- **Language**: GDScript (statically typed where possible)
- **Version Control**: Git with trunk-based development
- **Build System**: Godot export system (via Editor or `godot --headless --export-release`)
- **Asset Pipeline**: Godot import system; map data via JSON in `src/assets/`

> **Note**: Use Godot-specialist agents (`godot-specialist`, `godot-gdscript-specialist`,
> `godot-shader-specialist`). See `docs/engine-reference/godot/VERSION.md` for
> post-cutoff API changes (Godot 4.4–4.6 not in LLM training data).

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **Source root**: `src/` is the Godot project root (`src/project.godot`).
> All `.gd` and `.tscn` files live under `src/`. Open `src/project.godot` in the editor.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
