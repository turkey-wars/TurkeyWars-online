---
status: reverse-documented
source: src/map_scene.gd, src/game_state.gd, src/assets/game_data.json
date: 2026-03-28
verified-by: User
---

# Strategy Map

> **Note**: Reverse-engineered from existing implementation. Captures current behaviour and clarified design intent.

## 1. Overview

The Strategy Map is the primary game loop screen. It presents an SVG-rendered political map of Turkey's 81 provinces, where players take turns expanding their territory by attacking adjacent provinces. It hosts two sequential phases (Picking and Playing), manages bot turn execution, and provides the visual context for all territorial decisions.

## 2. Player Fantasy

Players feel like commanders surveying a war room — provinces light up as targets, the map fills with their colour as territory grows, and the tension mounts as rival armies close in on capitals. The blitz mechanic rewards decisive overwhelming force; the adjacency rule forces players to think about the shape of their empire, not just its size.

## 3. Detailed Rules

### Map Structure
- 81 provinces sourced from `game_data.json`, each with:
  - `adjacencies[]` — list of bordering province IDs.
  - `strength` — 1–5 integer representing defensive difficulty (used for tooltip display and neutral army sizing).
  - `initial_army` — starting neutral city strength (20,000–42,000).
  - `regions{}` — region assignment per player count (2–5).
- Province polygon boundaries come from `turkey_final_provinces.json` (SVG path data).

### Picking Phase
- Players cycle through turn order selecting starting capitals.
- A province is valid to pick if:
  1. It falls within the player's assigned region for the current player count.
  2. It is unclaimed (`province_owners` has no entry).
  3. No adjacent province is already owned by any player.
- Picking phase ends after player 0 completes their second selection.
- Province colour coding during picking:
  - **Gold** — valid/selectable for the current player.
  - **Team colour** — already owned.
  - **Grey** — not selectable (wrong region, adjacent to owned, or taken).

### Playing Phase
- The active player selects one of their provinces, then selects an adjacent target.
- Valid attack targets must share a border with at least one province the attacker owns.
- Selecting a valid target triggers one of two outcomes: **Blitz** or **Full Battle**.
- Province colour coding during playing:
  - **Team colour** — owned by that player.
  - **Highlighted grey** — attackable (adjacent to attacker's territory) when it is that player's turn.

### Blitz (Instant Conquest)
Blitz bypasses the Battlefield entirely and resolves the attack on the map immediately.

**vs. Neutral province:**
```
is_blitz = (city_value / attacker_army) < 0.85
```

**vs. Player province:**
```
is_blitz = (defender_army / attacker_army) < 0.40
```

On blitz:
- Province ownership transfers to attacker immediately.
- Army adjustments applied (`city_value / 10` gained/lost).
- If the blitzed province was a capital → defender eliminated.

These thresholds are **intentional and tuned** — do not adjust without a balance review.

### Full Battle
When blitz conditions are not met, the game transitions to the Troop Selector → Battlefield flow. See `troop-selection.md` and `battle-system-2d.md`.

### Turn Progression
- After each action (blitz, battle resolution, or skipped turn), `next_turn()` advances to the next living player.
- Eliminated players are skipped automatically.
- Bot players execute after a 1.2 s delay via deferred call.

### Bot AI
Bot target selection follows a strict priority order:

1. **Neutral expansion** — attack a neutral province where `city_value < bot_army * 0.60`. Picks the weakest qualifying neutral adjacent to bot territory.
2. **Weak enemy non-capital** — attack an enemy province where `enemy_army < bot_army`. Picks the weakest qualifying enemy.
3. **Enemy capital** — only attempted when `bot_army > 100,000`.
4. **Skip** — if no qualifying target exists.

Bot army composition in Troop Selector uses inverse-cost weighted random selection (see `troop-selection.md`).

### UI Elements
| Element | Description |
|---------|-------------|
| Top-left panel | Active player name + team colour indicator (gold accent) |
| Tooltip panel | Province name, owner, strength (colour-coded 1–5), army size (comma-formatted) — appears on hover |
| Right panel | "ARMIES" list: all players' army sizes; eliminated players show strikethrough + "ELIMINATED" |
| Toast notifications | Fade-in 0.18 s, hold 1.25 s, fade-out 0.25 s — used for turn announcements and events |

## 4. Formulas

### Blitz Check (Neutral)
```
is_blitz = (city_value / attacker_army) < 0.85
```

### Blitz Check (Player)
```
is_blitz = (defender_army / attacker_army) < 0.40
```

### Bot Neutral Attack Threshold
```
qualifies = (city_value < bot_army * 0.60)
```

### Army Adjustment (Blitz and Battle)
```
winner.army += city_value / 10
loser.army  -= city_value / 10   (clamped ≥ 0)
```

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Blitz captures a capital | Defender eliminated immediately; provinces neutralised |
| Bot has no valid targets | Turn skipped; `next_turn()` called |
| Player clicks non-adjacent province | No action; selection cleared |
| All provinces owned (no neutrals remain) | Bot skips neutral expansion tier; proceeds to player targets |
| Two players simultaneously reduced to capitals only | Both can still attack; game continues until one capital is captured |

## 6. Dependencies

- `game-flow.md` — phase transitions, elimination, win condition
- `troop-selection.md` — triggered when blitz conditions not met
- `battle-system-2d.md` — battlefield resolution
- `game_data.json` — province adjacency graph, strength values, region assignments
- `turkey_final_provinces.json` — province polygon boundaries for rendering

## 7. Tuning Knobs

| Parameter | Location | Current Value | Notes |
|-----------|----------|---------------|-------|
| Blitz threshold (neutral) | `map_scene.gd` | 0.85 | Intentional — do not adjust without balance review |
| Blitz threshold (player) | `map_scene.gd` | 0.40 | Intentional — do not adjust without balance review |
| Bot neutral attack threshold | `map_scene.gd` | 0.60 × bot_army | Aggression cap for neutral expansion |
| Bot capital attack threshold | `map_scene.gd` | 100,000 army | Minimum bot army before targeting capitals |
| Bot turn delay | `map_scene.gd` | 1.2 s | Readability pause before bot acts |
| Toast hold duration | `map_scene.gd` | 1.25 s | Notification visibility window |

## 8. Acceptance Criteria

- [ ] All 81 provinces render correctly with accurate adjacency highlighting.
- [ ] Picking phase only allows valid province selections per the three rules above.
- [ ] Blitz triggers correctly at the specified thresholds and skips Battlefield.
- [ ] Bot never attacks a province it doesn't border.
- [ ] Bot respects the 100,000 army threshold before attacking capitals.
- [ ] Tooltip displays correct province name, owner, strength, and army on hover.
- [ ] Eliminated player is greyed out in the ARMIES panel with "ELIMINATED" label.
