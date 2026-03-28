---
status: reverse-documented
source: src/unit.gd, src/battle_manager.gd
date: 2026-03-28
verified-by: User
legacy: true
superseded-by: battle-system-2d.md
---

# Battle System — 3D (Legacy)

> **Note**: Reverse-engineered from existing implementation.
> **This system is superseded by `battle-system-2d.md`.** `unit.gd` and `battle_manager.gd` remain in `src/` for reference and possible future use (e.g. a cinematic battle mode), but `new_battlefield.tscn` / `zez.gd` is the active runtime path.

## 1. Overview

The 3D Battle System is a real-time auto-battler using full 3D character models with procedurally-detected skeletal animations. Two armies are spawned into a 3D battlefield scene and fight to the last unit. The system supports Warriors (melee) and Rangers (ranged with physical projectiles), with team colour tinting to distinguish sides.

## 2. Player Fantasy

Cinematic 3D battles with full character animations — swords clashing, arrows flying, units falling. The team colour tinting (red vs blue) makes it immediately legible which side is winning. Designed to feel like a real-time battle scene rather than an abstract simulation.

## 3. Detailed Rules

### Scene Entry
- `BattleManager` node reads spawn counts from `GameState.attack_data` (or falls back to exported defaults).
- Units are spawned into designated `SpawnArea` nodes for each team's frontline and backline.

### Default Spawn Counts (BattleManager exports)
| Zone | Default |
|------|---------|
| Attacker frontline Warriors | 100 |
| Attacker backline Rangers | 0 |
| Attacker backline Wizards | 0 |
| Defender frontline Warriors | 0 |
| Defender backline Rangers | 25 |
| Defender backline Wizards | 10 |

These are overridden by `GameState.attack_data` when populated from the Troop Selector.

### Unit State Machine
Each unit runs: **IDLE → MOVE → ATTACK → DEAD**

| State | Behaviour |
|-------|-----------|
| IDLE | Play idle animation; velocity = 0 |
| MOVE | Play run/walk animation; move toward closest enemy at `movement_speed` |
| ATTACK | Play attack animation (speed-scaled by `attack_speed`); deal damage at hit_delay |
| DEAD | Play death animation (one-shot); disable collision; sink + scale to zero over 1.5 s; `queue_free()` |

### Procedural Animation Detection
Since animation names vary across character packs, the system searches the AnimationPlayer's animation list for keywords:
- **Idle**: `"idle"`
- **Run/Walk**: `"run"` or `"walk"`
- **Attack**: `"sword_attack"`, `"bow_shoot"`, `"staff_attack"`, `"spell1"`, `"spell2"`, `"attack"`, `"slash"`, `"punch"`
- **Death**: `"death"`, `"die"`

Loop modes are set automatically: idle/run loop; attack loops; death plays once.

### Target Selection
- All units in the `"units"` group, alive, on the opposing team.
- Closest distance wins.

### Melee Combat
```
hit_delay = (1.0 / attack_speed) * 0.3     # damage at 30% through animation
```
Damage applied if `distance ≤ attack_range × 1.5` at hit time.

### Ranged Combat (Projectile)
```
hit_delay = (1.0 / attack_speed) * 0.5     # projectile spawned at 50% through animation
```
- Projectile spawned at `global_position + (0, 1.2, 0)` (chest height).
- Projectile speed: 25.0 units/sec.
- Travel height offset: +1.0 above target.
- Impact distance threshold: 0.8 units.
- Projectile freed on target death or impact.

### Team Colour Tinting
- Attacker: `Color(0.95, 0.25, 0.25)` — red.
- Defender: `Color(0.28, 0.45, 0.98)` — blue.
- Material albedo lerped 55% toward team colour at spawn.

### Battle End
| Condition | Result |
|-----------|--------|
| Attacker alive count = 0 | `resolve_battle(false)` |
| Defender alive count = 0 | `resolve_battle(true)` |
| Both = 0 simultaneously | `resolve_battle(false)` — draw favours defender |

3.0 s delay before resolution call.

## 4. Formulas

### Hit Timing
```
Melee:  hit_delay = (1.0 / attack_speed) * 0.3
Ranged: hit_delay = (1.0 / attack_speed) * 0.5
```

### Team Colour Lerp
```
albedo_color = lerp(original_colour, team_colour, 0.55)
```

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| AnimationPlayer has no recognised animation name | State plays nothing (silent fail) |
| Projectile target dies in flight | Projectile freed immediately |
| Both teams reach 0 simultaneously | Defender wins |

## 6. Dependencies

- `unit-roster.md` — base unit stats
- `game-flow.md` — `resolve_battle()` post-battle state update
- 3D character asset pack (`res://assets/character_pack/`)

## 7. Tuning Knobs

| Parameter | Location | Current Value | Notes |
|-----------|----------|---------------|-------|
| Melee hit timing | `unit.gd` | 30% into animation | Earlier feel vs 2D system's 50% |
| Ranged hit timing | `unit.gd` | 50% into animation | Projectile spawn moment |
| Projectile speed | `projectile.gd` | 25.0 units/sec | |
| Team colour blend | `unit.gd` | 55% lerp | Higher = more saturated team colour |
| Death sink duration | `unit.gd` | 1.5 s | Time to sink + scale to zero |

## 8. Acceptance Criteria

*(Legacy — acceptance criteria apply only if this system is reinstated as active.)*

- [ ] Procedural animation detection correctly identifies idle/run/attack/death for all included character models.
- [ ] Team colour tinting distinguishes attacker (red) from defender (blue) at a glance.
- [ ] Projectiles travel at correct speed and free on target death.
- [ ] Battle end triggers correctly for all three end conditions.
