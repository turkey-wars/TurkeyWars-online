---
status: reverse-documented
source: src/troop_selector.gd, src/game_state.gd
date: 2026-03-28
verified-by: User
---

# Troop Selection

> **Note**: Reverse-engineered from existing implementation. Captures current behaviour and clarified design intent.

## 1. Overview

The Troop Selector is the pre-battle screen where the attacker and (if human) the defender each spend their army's point budget on a composition of units before heading to the Battlefield. It also applies the session's randomly-assigned buff/nerf modifier — a strategic variable that players can and should factor into their army decisions.

## 2. Player Fantasy

Players feel the weight of command — every point matters, and the buff/nerf assignment creates genuine decisions. Seeing that Tanks are buffed this battle should push a smart player to spend more points on Rocket Launchers (the Tank counter) rather than blindly spamming the cheapest unit. The budget constraint keeps choices meaningful and prevents runaway dominant strategies.

## 3. Detailed Rules

### Flow
1. **Attacker phase** — attacker player (or bot) selects their army composition.
2. **Defender phase** — defender player (or bot) selects their army composition.
   - If the defender is a neutral city, a bot army is auto-generated.
3. Both armies are written to `GameState.attack_data` and the scene changes to `new_battlefield.tscn`.

### Budget
- Each player's budget equals their current `army` value in GameState (the same number shown on the map).
- **Capital defence exception**: `defender_budget = max(75,000, player.army)` — a floor is applied when defending a capital to ensure capitals are never trivially cheap to take.
- The budget is spent by adding units at their point cost; it cannot be exceeded.

### Units Available

| Unit | Cost | Role |
|------|------|------|
| Soldier (Melee) | 280 pts | Cheap frontline; absorbs damage |
| Rifleman (Range) | 550 pts | Ranged DPS; priority target for Rocket Launchers |
| Rocket Launcher | 1,700 pts | AOE + anti-Rifleman; counters range-heavy compositions |
| Tank | 2,000 pts | Massive HP + AOE; countered by Rocket Launchers |

### Buff / Nerf System
- At the start of each battle, two unit types are randomly assigned:
  - **Buffed unit**: ×2 HP, ×2 attack damage.
  - **Nerfed unit**: ×0.5 HP, ×0.5 attack damage.
- Both players can see which unit is buffed and which is nerfed on the Troop Selector UI.
- This is a **strategic variable** — players are expected to react to the assignment:
  - Avoid investing heavily in the nerfed unit type.
  - Consider countering the buffed unit type rather than mirroring it.
  - Example: if Tanks are buffed, Rocket Launchers become higher value.
- The modifier applies at unit spawn in the Battlefield (see `battle-system-2d.md`).
- A new pair is randomly assigned each battle; modifiers do not carry over between battles.

### UI Controls
- Each unit row shows: name (with BUFF / NERF badge if applicable), cost, current count, budget impact.
- Buttons: **−** (remove 1), **+** (add 1), **+10** (add 10 if budget allows).
- Budget bar updates in real time (0–100% of total budget spent).

### Bot Auto-Select
Bots build their army using inverse-cost weighted random selection:

```
weight(unit) = 1.0 / cost(unit)
```

Repeat until budget is exhausted:
1. Filter to units the bot can still afford.
2. Roll weighted random across affordable units.
3. Add one unit of the selected type; deduct cost.
4. Fallback: if no unit is affordable, add a Soldier if possible, else stop.

**Rocket Launcher modifier** (applied when the opposing army is rifle-heavy):
```
rifle_ratio  = attacker_rifle_points / total_attacker_points
rocket_mod   = 1.0 + (rifle_ratio × 4.0)   # up to 5× preference
```
This modifier is applied to neutral city defenders and player defenders, making bots naturally counter Rifleman spam.

### Neutral City Defenders
- When the defender index is −1 (neutral province), the Troop Selector auto-generates a defender army using the bot logic above.
- The budget for the neutral defender equals the province's `city_value` (from `game_data.json`).

## 4. Formulas

### Capital Defence Floor
```
defender_budget = max(75_000, player.army)
```

### Bot Weighted Selection
```
weight(unit) = 1.0 / cost(unit)
rocket_weight = weight(rocket) × (1.0 + rifle_ratio × 4.0)
```

### Buff / Nerf Application (applied at spawn, not selection)
```
if unit.unit_class == buffed_unit:
    hp           × = 2.0
    attack_damage × = 2.0
    aoe_damage   × = 2.0

elif unit.unit_class == nerfed_unit:
    hp           × = 0.5
    attack_damage × = 0.5
    aoe_damage   × = 0.5
```

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Player budget is 0 | Only free units (none exist) — player cannot field any army; treated as forfeit |
| Budget exactly equals one unit cost | Player can field exactly one unit |
| Buff and nerf assigned to same unit type | Not possible — two distinct types are always chosen |
| Bot can't afford any unit | Bot fields an empty army; will lose battle immediately |
| Capital defender has army < 75,000 | Floor of 75,000 applied; defender receives full budget regardless of map army size |

## 6. Dependencies

- `game-flow.md` — battle setup context, `attack_data` structure
- `strategy-map.md` — triggers Troop Selector when blitz conditions not met
- `battle-system-2d.md` — receives composed armies; applies buff/nerf at spawn
- `unit-roster.md` — unit costs, stats, and counter relationships

## 7. Tuning Knobs

| Parameter | Location | Current Value | Notes |
|-----------|----------|---------------|-------|
| Capital defence floor | `troop_selector.gd` | 75,000 pts | Minimum defender budget at capitals |
| Buff multiplier | `troop_selector.gd` / `zez.gd` | ×2.0 HP + damage | Applied at spawn |
| Nerf multiplier | `troop_selector.gd` / `zez.gd` | ×0.5 HP + damage | Applied at spawn |
| Rocket modifier cap | `troop_selector.gd` | 4.0 (→ 5× weight) | Anti-Rifleman preference for bots |
| Bot delay (auto-select) | `troop_selector.gd` | 1.0 s | Pause before bot confirms selection |

## 8. Acceptance Criteria

- [ ] Budget bar updates correctly as units are added/removed.
- [ ] Player cannot exceed their army budget.
- [ ] Capital defender always receives at least 75,000 budget.
- [ ] Buff/nerf badges display correctly on the UI for both players.
- [ ] Bot compositions vary across battles (not always the same army).
- [ ] Rocket Launcher bot preference scales correctly when facing a Rifleman-heavy attacker.
- [ ] Buff/nerf modifiers apply correctly at unit spawn in the Battlefield (verify via Simulation).
