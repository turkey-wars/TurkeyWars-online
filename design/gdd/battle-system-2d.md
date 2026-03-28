---
status: reverse-documented
source: src/unit_2d.gd, src/zez.gd, src/sim_battlefield.gd
date: 2026-03-28
verified-by: User
---

# Battle System — 2D (Active)

> **Note**: Reverse-engineered from existing implementation. This is the **active** battle system. The legacy 3D system is documented separately in `battle-system-3d.md`.

## 1. Overview

The 2D Battle System is a real-time auto-battler where two pre-composed armies clash on a procedurally-styled battlefield. Units are 2D billboard sprites placed in a 3D Forward Plus scene. Combat is fully automatic — players watch the outcome, with a win-ratio slider giving live feedback. The system reads army composition from `GameState.attack_data`, applies buff/nerf modifiers at spawn, runs the battle to completion, then returns the result to the Strategy Map.

## 2. Player Fantasy

Players feel the visceral satisfaction (or dread) of watching their strategic decisions play out. The randomised battlefield lighting creates visual variety across battles. The unit-counter system means a well-composed army reliably beats a poorly-composed one — skill in the Troop Selector translates to outcomes on the field. The HUD win slider communicates momentum so players always know how the battle is going.

## 3. Detailed Rules

### Scene Entry
- Scene: `new_battlefield.tscn`, driven by `zez.gd`.
- On `_ready()`: reads `GameState.attack_data` for troop counts, applies buff/nerf, spawns units into the appropriate spawn zones, starts BGM.

### Spawn Zones
Each army has two spawn zones:
- **Frontline** — Melee units (Soldiers).
- **Backline** — Ranged units (Riflemen, Rocket Launchers, Tanks).

Units spawn at random positions within their zone's `CSGBox3D` bounds.

### Buff / Nerf Application at Spawn
```
if unit.unit_class == attack_data.buffed_unit:
    hp × = 2.0,  attack_damage × = 2.0,  aoe_damage × = 2.0

elif unit.unit_class == attack_data.nerfed_unit:
    hp × = 0.5,  attack_damage × = 0.5,  aoe_damage × = 0.5
```

### Unit State Machine
Each unit runs: **IDLE → MOVE → ATTACK → DEAD**

| State | Behaviour |
|-------|-----------|
| IDLE | Play idle animation; velocity = 0 |
| MOVE | Play walk animation; move toward current target at `movement_speed` |
| ATTACK | Play attack animation (scaled to `1.0 / attack_speed` duration); deal damage at 50% through animation |
| DEAD | Play die animation (one-shot); disable collision; wait 3.0 s; `queue_free()` |

Target is re-evaluated every 0.1–0.15 s (staggered across units to distribute CPU load).

### Target Selection
- **Rocket Launcher**: prefers Riflemen (range-class units) above all others; falls back to closest unit if no Riflemen remain.
- **All other units**: target the closest living enemy unit.

### Melee Combat
- Attack triggers when `distance ≤ attack_range`.
- Damage applied directly to `target.hp` at the 50% animation mark.

### Ranged Combat (Rifleman)
- Sprite-based; no physical projectile.
- Damage applied directly at the 50% animation mark (same as melee).
- Attack range: 25.0 units.

### AOE Combat (Tank and Rocket Launcher)
```
On attack hit:
  target.hp      -= attack_damage          (direct hit)
  nearby_units.hp -= aoe_damage            (all units within aoe_radius, excluding target)
  spawn explosion sprite at impact_pos + (0, 1.0, 0)
```

AOE radius: 4.0 units for both Tank and Rocket Launcher.
AOE damage: 25 per hit for both.

### Sprite Facing
```
sprite.flip_h = default_faces_left XOR (target.x > unit.x)
```
Units always face the direction they are attacking.

### Collision
- `collision_layer = 2`, `collision_mask = 1` (environment only).
- Units pass through each other — no congestion, no blocking.

### SFX
| Unit | Audio | Volume |
|------|-------|--------|
| Soldier | melee_01/02/03.ogg (random) | 0.0 dB |
| Rifleman | rifle_continuous.ogg | −14.0 dB |
| Tank | tank_01/02.ogg (random) | 0.0 dB |
| Rocket Launcher | tank_01/02.ogg (random) | 0.0 dB |

Pitch variation: ±0.15 (range 0.85–1.15) per attack for organic feel.
BGM: `battle_music.ogg` looped at −8.0 dB.

### Environment Randomisation
10 preset lighting configs selected randomly at scene load:
Spring, Summer, Golden Hour, Winter, Moonlight, Autumn, Storm, Martian, Nebula, Alien.
Each preset defines sun rotation/colour/energy, sky gradient colours, and tonemap exposure (0.6–1.2).

### HUD
| Element | Description |
|---------|-------------|
| Attacker card (left) | Unit type breakdown + remaining count |
| Defender card (right) | Unit type breakdown + remaining count |
| Win slider (top centre) | `attacker_units / total_units` ratio, updated each frame |
| Result banner (centre) | "VICTORY" (red) or "DEFEAT" (blue) — shown at battle end |

### Battle End
- `_update_team_counters()` runs each frame counting living units per team.

| Condition | Result |
|-----------|--------|
| Attacker units = 0 | `resolve_battle(false)` — defender wins |
| Defender units = 0 | `resolve_battle(true)` — attacker wins |
| Both = 0 simultaneously | `resolve_battle(false)` — defender wins (draw favours defender) |

- 3.0 s delay after end condition is met (banner display time) before calling `resolve_battle()`.
- `resolve_battle()` updates map state and transitions back to `map_scene.tscn`.

### Animation System
- Sprite frames loaded dynamically from `res://assets/new_battlefield_units/{class}/{state}/`.
- States: `idle`, `walk`, `attack`, `die`.
- Ranged units use `idle_attack` folder instead of `attack` (sprite sheet distinction).
- Base animation speed: 45 fps, scaled by `attack_speed` ratio.

## 4. Formulas

### Attack Timing
```
hit_delay = (1.0 / attack_speed) * 0.5    # damage at 50% through animation
```

### AOE
```
direct_damage   = attack_damage            # to primary target
splash_damage   = aoe_damage (25)          # to all units within aoe_radius (4.0)
```

### Win Slider
```
ratio = attacker_alive_count / (attacker_alive_count + defender_alive_count)
```

### Buff / Nerf (applied at spawn)
```
buffed:  hp × 2.0,  attack_damage × 2.0,  aoe_damage × 2.0
nerfed:  hp × 0.5,  attack_damage × 0.5,  aoe_damage × 0.5
```

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Unit's target dies mid-animation | Target re-selected on next 0.1–0.15 s tick |
| No enemy units alive at spawn | Battle ends immediately; defender wins |
| Buffed unit also has AOE | AOE damage is also doubled (`aoe_damage × 2.0`) |
| All Riflemen eliminated; Rocket Launcher re-targets | Falls back to closest unit |
| Battle exceeds expected duration | No hard timeout in zez.gd; simulation has 5,000-tick safety limit |

## 6. Dependencies

- `troop-selection.md` — provides army composition and buff/nerf assignment
- `unit-roster.md` — unit base stats, costs, class identifiers
- `game-flow.md` — `resolve_battle()` post-battle state update
- `res://assets/new_battlefield_units/` — sprite sheet assets per unit/state

## 7. Tuning Knobs

| Parameter | Location | Current Value | Notes |
|-----------|----------|---------------|-------|
| AOE radius | `unit_2d.gd` | 4.0 units | Tank and Rocket Launcher |
| AOE damage | `unit_2d.gd` | 25 per hit | Splash damage value |
| Hit timing | `unit_2d.gd` | 50% into animation | `(1.0/attack_speed) * 0.5` |
| Target re-evaluation interval | `unit_2d.gd` | 0.1–0.15 s | Staggered to reduce CPU spikes |
| Battle end delay | `zez.gd` | 3.0 s | Banner display before returning to map |
| BGM volume | `zez.gd` | −8.0 dB | Battle music level |
| Base animation speed | `unit_2d.gd` | 45 fps | Scaled by unit attack_speed |

## 8. Acceptance Criteria

- [ ] All 4 unit types spawn, animate, and attack correctly.
- [ ] Buff/nerf modifiers visibly affect unit durability and damage output.
- [ ] Rocket Launchers target Riflemen preferentially when Riflemen are present.
- [ ] AOE splash damages units within 4.0 radius on Tank/Rocket attacks.
- [ ] Win slider updates in real time and accurately reflects unit ratio.
- [ ] Battle end triggers correctly for all three end conditions (attacker wins, defender wins, draw).
- [ ] 3.0 s delay after battle end before returning to map.
- [ ] Environment preset changes visually between battles.
- [ ] SFX plays on attack with pitch variation; BGM loops for full battle duration.
