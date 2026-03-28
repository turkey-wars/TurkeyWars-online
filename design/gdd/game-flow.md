---
status: reverse-documented
source: src/game_state.gd, src/main_menu.gd, src/map_scene.gd
date: 2026-03-28
verified-by: User
---

# Game Flow

> **Note**: Reverse-engineered from existing implementation. Captures current behaviour and clarified design intent.

## 1. Overview

TurkeyWars is a turn-based grand strategy game for 2–5 players (human and/or bot) competing to conquer the provinces of Turkey. A session alternates between two layers: the **Strategy Map** (turn-based territorial control) and the **Battlefield** (real-time tactical combat). A player wins by capturing every opponent's capital city, eliminating them from the game.

## 2. Player Fantasy

Players feel like Ottoman-era generals commanding armies across a recognisable map of Turkey — carefully picking starting territory, expanding through weaker neighbours, and engineering decisive battles to crush rival capitals. The game rewards reading the map, composing smart armies, and exploiting the random buff/nerf modifier each battle introduces.

## 3. Detailed Rules

### Session Setup
- 1–5 players configured at the main menu (name + human/bot flag).
- A "world name" is chosen; the session is saved to `user://saves/{world_name}.json`.
- Players are assigned starting regions based on player count (2→East/West, 3→East/Middle/West, 4→four quadrants, 5→five zones) sourced from `game_data.json`.

### Phase 1 — Picking
- Players take turns (0 → 1 → … → n-1 → 0) selecting a starting capital province.
- A province is selectable only if:
  - It belongs to the player's assigned region.
  - It is not already owned.
  - It is not adjacent to an already-owned province.
- After player 0 completes their **second** selection the phase transitions to Playing.

### Phase 2 — Playing
- Each turn the active player may attack one adjacent province.
- A province is attackable only if it shares a border with a province the player owns.
- Attacking transitions to the **Troop Selector** scene, then the **Battlefield**, then returns to the map.
- After the battle resolves, `next_turn()` cycles to the next living player.
- Bot players execute automatically after a 1.2 s delay.

### Elimination
- A player is eliminated when their **capital province** is captured by an opponent.
- On elimination:
  - `players[idx].alive = false`.
  - All of the eliminated player's non-capital provinces become neutral cities (army = their previous `city_value`).
- Eliminated players are skipped in turn order.

### Win Condition
- Last player with a living capital wins.
- The game checks alive status after every `resolve_battle()` call.

### Save / Load
- The session autosaves to `user://saves/{world_name}.json` after every turn.
- Save data includes: `players`, `province_owners`, `capitals`, `current_turn`, `game_phase`.
- The Load Session page lists all files under `user://saves/`.

### Online Multiplayer *(in progress — this session)*
- Main menu exposes a "New Session → Online" path.
- Implementation is planned for the current development session.
- When complete, online sessions will allow remote players to join by session code and take turns across the network.

## 4. Formulas

### Battle Outcome (Map-Level Resolution for Blitz / Bot Sim)
```
roll = randf() * (attacker_army + defender_army)
attacker_wins = (roll < attacker_army)
```

### Post-Battle Army Adjustment
```
winner.army += city_value / 10   (bonus)
loser.army  -= city_value / 10   (penalty, clamped to 0)
```

### Capital Defense Floor (Troop Selector)
```
defender_budget = max(75_000, player.army)   # only when defending capital
```

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Both teams reach 0 units in Battlefield | Defender wins (`resolve_battle(false)`) |
| Eliminated player's capital attacked again | Not possible — province is neutral after elimination |
| Only one player alive at session start | Not validated; requires ≥2 players in lobby |
| Bot attacks and wins the last enemy capital | Elimination logic runs normally; game ends |
| Load file missing `game_state` key | Falls back to `_init_new_game_state()` |

## 6. Dependencies

- `strategy-map.md` — turn execution and blitz logic
- `troop-selection.md` — battle setup and army composition
- `battle-system-2d.md` — real-time combat resolution
- `game_data.json` — province definitions and region assignments

## 7. Tuning Knobs

| Parameter | Location | Current Value | Notes |
|-----------|----------|---------------|-------|
| Bot delay | `map_scene.gd` | 1.2 s | Time before bot executes its turn |
| Capital defence floor | `troop_selector.gd` | 75,000 pts | Minimum defender budget at capitals |
| Army bonus/penalty divisor | `game_state.gd` | 10 | `city_value / 10` awarded per battle |
| Max players | `main_menu.gd` | 5 | Bot count slider upper bound |

## 8. Acceptance Criteria

- [ ] A 2-player session (1 human, 1 bot) completes from menu to victory screen without crash.
- [ ] Eliminating a bot removes it from turn order and neutralises its provinces.
- [ ] A saved session loads and resumes from the correct turn and province state.
- [ ] Win condition triggers after the final opponent's capital is captured.
- [ ] Online session allows two human players to complete a full game turn cycle.
