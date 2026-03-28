# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript (statically typed where possible)
- **Rendering**: Forward Plus
- **Physics**: Jolt (Godot 4.6 default)

## Naming Conventions

- **Classes**: PascalCase (via `class_name`)
- **Variables**: snake_case (e.g. `attack_damage`, `current_state`)
- **Signals/Events**: snake_case past-tense verbs (e.g. `player_died`)
- **Files**: snake_case (e.g. `battle_manager.gd`, `map_scene.tscn`)
- **Scenes**: snake_case matching their primary script (e.g. `unit_2d.tscn`)
- **Constants/Enums**: ALL_CAPS for constants, PascalCase for enum types, ALL_CAPS members

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6 ms
- **Draw Calls**: [TO BE CONFIGURED]
- **Memory Ceiling**: [TO BE CONFIGURED]

## Testing

- **Framework**: [TO BE CONFIGURED]
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]
