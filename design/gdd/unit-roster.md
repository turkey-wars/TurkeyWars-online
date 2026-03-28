---
status: reverse-documented
source: src/unit_2d.gd, src/zez.gd, src/sim_battlefield.gd, src/game_state.gd
date: 2026-03-28
verified-by: User
---

# Unit Roster

> **Note**: Reverse-engineered from existing implementation. Stats reflect the active 2D battle system. 3D legacy stats are noted separately where they differ.

## 1. Overview

TurkeyWars fields four unit types in the 2D Battlefield: Soldier (melee), Rifleman (ranged), Tank (heavy AOE), and Rocket Launcher (long-range AOE with anti-Rifleman priority). Each unit has a point cost paid from the player's army budget in the Troop Selector. The four units form a loose counter triangle designed to reward mixed compositions.

## 2. Player Fantasy

Each unit type has a clear identity and feel: Soldiers are cheap cannon fodder that can overwhelm through numbers; Riflemen are glass-cannon snipers; Tanks are terrifying walls of HP; Rocket Launchers are the tactical wildcard that punishes Rifleman spam. Players should feel that there is no dominant single-unit strategy — the buff/nerf modifier each battle further disrupts any fixed optimal build.

## 3. Detailed Rules

### Unit Definitions (2D System)

#### Soldier (Melee)
| Stat | Value |
|------|-------|
| Cost | 280 pts |
| HP | 600 |
| Attack Damage | 200 |
| Attack Speed | 1.2 attacks/sec |
| Attack Range | 1.75 units |
| Movement Speed | 5.0 units/sec |
| AOE | None |
| Role | Frontline tank; absorbs damage, high individual HP |
| Counter | Rocket Launcher (AOE punishes clusters) |
| Countered by | Rifleman (range advantage before melee contact) |

#### Rifleman (Ranged)
| Stat | Value |
|------|-------|
| Cost | 550 pts |
| HP | 200 |
| Attack Damage | 35 |
| Attack Speed | ~0.70 attacks/sec (1.0/1.43) |
| Attack Range | 25.0 units |
| Movement Speed | 3.0 units/sec |
| AOE | None |
| Role | Long-range DPS; safe backline dealer |
| Counter | Rocket Launcher (preferred target, AOE splash) |
| Countered by | Tank (survives long enough to close; AOE clears groups) |

> Note: Rifleman is sprite-based — no physical projectile. Damage applies directly at the 50% animation mark.

#### Tank (Heavy)
| Stat | Value |
|------|-------|
| Cost | 2,000 pts |
| HP | 1,500 |
| Attack Damage | 300 |
| Attack Speed | 2.0 attacks/sec |
| Attack Range | 7.0 units |
| Movement Speed | 6.0 units/sec |
| AOE Radius | 4.0 units |
| AOE Damage | 25 per hit |
| Role | High-value bruiser; area control, front-line presence |
| Counter | Rocket Launcher (AOE damage + high ROF chips HP) |
| Countered by | Soldier swarm (cost-efficient HP pool vs single Tank) |

#### Rocket Launcher (Anti-Range AOE)
| Stat | Value |
|------|-------|
| Cost | 1,700 pts |
| HP | 300 |
| Attack Damage | 50 |
| Attack Speed | ~3.0 attacks/sec (1.0/0.33) |
| Attack Range | 50.0 units |
| Movement Speed | 3.0 units/sec |
| AOE Radius | 4.0 units |
| AOE Damage | 25 per hit |
| Role | Long-range AOE; hard counter to Riflemen and Tanks |
| Counter | Soldier (cheap, high HP, survives long enough to close the gap) |
| Countered by | Nothing directly — fragile (300 HP), dies quickly to focused fire |

> Rocket Launcher preferentially targets Riflemen. When no Riflemen remain it attacks the closest unit.

---

### Unit Costs Summary

| Unit | Cost | pts per HP | pts per DPS |
|------|------|------------|-------------|
| Soldier | 280 | 0.47 | ~1.17 |
| Rifleman | 550 | 2.75 | ~23.5 |
| Tank | 2,000 | 1.33 | ~3.33 |
| Rocket Launcher | 1,700 | 5.67 | ~11.3 |

---

### Counter Triangle

```
Rocket Launcher  →  defeats  →  Rifleman
Rifleman         →  defeats  →  Soldier (before contact)
Soldier (swarm)  →  defeats  →  Tank (cost-efficiency)
Tank             →  defeats  →  Rifleman (closes gap, AOE clears)
Rocket Launcher  →  defeats  →  Tank (high ROF AOE)
```

---

### Buff / Nerf Impact by Unit

| Unit | Buffed Effect | Nerfed Effect | Strategic Note |
|------|---------------|---------------|----------------|
| Soldier | 1,200 HP / 400 dmg | 300 HP / 100 dmg | Buffed Soldiers become near-unkillable swarms |
| Rifleman | 400 HP / 70 dmg | 100 HP / 17.5 dmg | Buffed: dangerous glass-cannon; Nerfed: easily wiped |
| Tank | 3,000 HP / 600 dmg | 750 HP / 150 dmg | Buffed Tanks are near-unstoppable without Rocket spam |
| Rocket Launcher | 600 HP / 100 dmg | 150 HP / 25 dmg | Buffed RL invalidates Rifleman compositions entirely |

---

### 3D Legacy Stats (unit.gd — for reference)

| Unit | HP | Damage | Atk Speed | Atk Range | Move Speed |
|------|----|--------|-----------|-----------|------------|
| Warrior | 200 | 25 | 1.0/sec | 1.5 | 4.0 |
| Ranger | 200 | 35 | ~0.7/sec | 25.0 | 3.0 |

3D Wizard/Tank and Rocket Launcher were not implemented in the 3D system.

---

### Balance Simulation Tool

`sim_battlefield.gd` provides a headless balance tuner. It:
1. Drafts two random armies within a 50,000-point budget (cost-weighted random).
2. Simulates up to 5,000 ticks (TIME_STEP = 0.1 s).
3. Adjusts unit costs based on which unit types appear more in winning armies:

```
ranger_cost        += composition_delta × 20.0
warrior_cost       += composition_delta × 20.0
wizard_cost        += composition_delta × 100.0   (5× multiplier)
rocket_cost        += composition_delta × 60.0    (3× multiplier)
```

Results saved to `balance_sim_results.json` every 20 battles.
This is a **dev tool** — not active in production builds.

## 4. Formulas

### DPS (approximate)
```
dps = attack_damage × attack_speed
```

### AOE Total Damage per Attack (at full cluster)
```
total = attack_damage + (nearby_unit_count × aoe_damage)
```

### Effective HP under Buff/Nerf
```
effective_hp = base_hp × modifier    (modifier = 2.0 / 1.0 / 0.5)
```

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Only Tanks on field (no Riflemen for Rocket to target) | Rocket Launcher falls back to closest unit |
| Buffed unit is the nerfed unit's natural counter | Counter advantage is amplified — composition decision is critical |
| Two armies of only Soldiers | Long melee grind; defender wins on draw |
| Single very expensive unit vs many cheap units | Swarm wins — HP pool of many Soldiers > single Tank cost-efficiency |

## 6. Dependencies

- `troop-selection.md` — unit costs and budget system
- `battle-system-2d.md` — stat application, target selection, AOE logic
- `sim_battlefield.gd` — dev tool for cost calibration

## 7. Tuning Knobs

| Parameter | Location | Current Value | Notes |
|-----------|----------|---------------|-------|
| Soldier cost | `game_state.gd` UNIT_COSTS | 280 | Also sim baseline |
| Rifleman cost | `game_state.gd` UNIT_COSTS | 550 | |
| Tank cost | `game_state.gd` UNIT_COSTS | 2,000 | |
| Rocket Launcher cost | `game_state.gd` UNIT_COSTS | 1,700 | |
| Tank / Rocket AOE radius | `unit_2d.gd` | 4.0 | Shared value |
| Tank / Rocket AOE damage | `unit_2d.gd` | 25 | Shared value |
| Sim cost adjustment rate | `sim_battlefield.gd` | ×20 / ×100 / ×60 | Per-type sensitivity |
| Sim budget | `sim_battlefield.gd` | 50,000 pts | Per army |

## 8. Acceptance Criteria

- [ ] Each unit type performs its intended role in a test battle (Rocket Launchers kill Riflemen first).
- [ ] A 50,000-pt Soldier swarm defeats a single 50,000-pt Tank army.
- [ ] Buff doubles effective unit performance observably in-battle.
- [ ] Nerf reduces unit survivability to the point of near-irrelevance.
- [ ] Simulation tool (dev) produces varied winning compositions across 100 simulated battles.
- [ ] Unit costs in `game_state.gd` match simulation tool costs in `sim_battlefield.gd`.
