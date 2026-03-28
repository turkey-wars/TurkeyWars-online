extends CharacterBody3D

enum Team { ATTACKER, DEFENDER }
enum State { IDLE, MOVE, ATTACK, DEAD }

@export var team: Team = Team.ATTACKER

# Core Unit Stats
@export var cost: int = 100
@export var hp: float = 200.0
@export var attack_damage: float = 25.0
@export var attack_speed: float = 1.0 # Attacks per second
@export var attack_range: float = 1.5
@export var movement_speed: float = 4.0
@export var is_ranged: bool = false
@export var is_backline: bool = false
@export var projectile_scene: PackedScene

# Internal References
@export_node_path("AnimationPlayer") var anim_player_path
@onready var anim: AnimationPlayer = get_node_or_null(anim_player_path)

var current_state: State = State.IDLE
var target: Node3D = null
var next_attack_time: float = 0.0

# Animation Name Caching
var anim_idle := ""
var anim_run := ""
var anim_attack := ""
var anim_death := ""

func _ready():
    add_to_group("units")
    
    # Slight upscale so units read better from the current camera distance.
    scale = Vector3(1.55, 1.55, 1.55)

    # Team tinting directly on troop materials (no ring/outline overlays).
    var tint = Color(0.95, 0.25, 0.25) if team == Team.ATTACKER else Color(0.28, 0.45, 0.98)
    var visual_root = get_node_or_null("Visual")
    if visual_root:
        _apply_team_color(visual_root, tint)
    
    
    
    
    # Auto-detect animation names by keyword (foolproof for different asset packs)
    
    
        
    if anim:
        anim_idle = _find_anim("idle")
        anim_run = _find_anim("run")
        if anim_run == "": anim_run = _find_anim("walk")
        
        # New aggressive attack string search
        anim_attack = _find_anim("sword_attack")
        if anim_attack == "": anim_attack = _find_anim("bow_shoot")
        if anim_attack == "": anim_attack = _find_anim("staff_attack")
        if anim_attack == "": anim_attack = _find_anim("spell1")
        if anim_attack == "": anim_attack = _find_anim("spell2")
        if anim_attack == "": anim_attack = _find_anim("attack")
        if anim_attack == "": anim_attack = _find_anim("slash")
        if anim_attack == "": anim_attack = _find_anim("punch")
        
        anim_death = _find_anim("death")
        if anim_death == "": anim_death = _find_anim("die")
        
        # Force loop modes for the essential looped animations
        if anim_idle: anim.get_animation(anim_idle).loop_mode = Animation.LOOP_LINEAR
        if anim_run: anim.get_animation(anim_run).loop_mode = Animation.LOOP_LINEAR
        if anim_attack: anim.get_animation(anim_attack).loop_mode = Animation.LOOP_LINEAR
        if anim_death: anim.get_animation(anim_death).loop_mode = Animation.LOOP_NONE

func _physics_process(delta: float):
    if current_state == State.DEAD:
        # Check gravity on corpse
        if not is_on_floor():
            velocity.y -= 9.8 * delta
            move_and_slide()
        return
        
    # Gravity logic
    if not is_on_floor():
        velocity.y -= 9.8 * delta

    target = _get_closest_enemy()
    
    if not target:
        if current_state != State.IDLE:
            _change_state(State.IDLE)
        velocity.x = 0
        velocity.z = 0
        move_and_slide()
        return
        
    var dist = global_position.distance_to(target.global_position)
    
    # Simple AI Behavior
    if dist <= attack_range:
        # In Range: Attack
        velocity.x = 0
        velocity.z = 0
        if current_state != State.ATTACK:
            _change_state(State.ATTACK)
            
        next_attack_time -= delta
        if next_attack_time <= 0:
            _perform_attack()
            next_attack_time = 1.0 / attack_speed
            
        # Always look at target
        _look_at_target()
            
    else:
        # Out of Range: Move
        if current_state != State.MOVE:
            _change_state(State.MOVE)
            
        var dir = global_position.direction_to(target.global_position)
        dir.y = 0
        dir = dir.normalized()
        
        velocity.x = dir.x * movement_speed
        velocity.z = dir.z * movement_speed
        
        _look_at_target()
        
    move_and_slide()

func _look_at_target():
    if not target: return
    # Face target
    var target_pos = target.global_position
    target_pos.y = global_position.y # Ensure flat rotation
    var dir = global_position.direction_to(target_pos)
    if dir.length_squared() > 0.01:
        look_at(global_position - dir, Vector3.UP) # GLTF models typically face +Z, Godot defaults -Z. We subtract dir to fix rotation.

func _get_closest_enemy() -> Node3D:
    var units = get_tree().get_nodes_in_group("units")
    var best_target = null
    var best_dist = INF
    
    for u in units:
        if u.current_state == State.DEAD: continue
        if u.team != self.team:
            var dist = global_position.distance_to(u.global_position)
            # Add some dynamic priority to engaging nearest
            if dist < best_dist:
                best_dist = dist
                best_target = u
                
    return best_target

func _change_state(new_state: State):
    current_state = new_state
    if current_state == State.ATTACK:
        next_attack_time = 1.0 / attack_speed
    if not anim: return

    anim.speed_scale = 1.0
    
    match current_state:
        State.IDLE:
            if anim_idle: anim.play(anim_idle)
        State.MOVE:
            if anim_run: anim.play(anim_run)
        State.ATTACK:
            if anim_attack:
                var playback_speed = 1.0
                var attack_anim_res = anim.get_animation(anim_attack)
                if attack_anim_res and attack_anim_res.length > 0.0:
                    playback_speed = max(0.01, attack_anim_res.length * attack_speed)
                anim.play(anim_attack, -1.0, playback_speed)
                anim.seek(0, true)
            
func _perform_attack():
    # Attempt to deliver damage on the impact frame
    # We estimate the punch connects around 30% of the way into the attack speed
    var hit_delay = (1.0 / attack_speed) * 0.3
    if is_ranged: hit_delay = (1.0 / attack_speed) * 0.5 # Wait a bit longer to release arrow
    await get_tree().create_timer(hit_delay).timeout
    
    if current_state == State.DEAD or not target: return
    
    if is_ranged and projectile_scene:
        var proj = projectile_scene.instantiate()
        get_parent().add_child(proj)
        # Spawn arrow approximately at bow/chest height
        proj.global_position = global_position + Vector3(0, 1.2, 0)
        proj.fire(target, attack_damage)
    else:
        # Re-verify distance just in case target moved away
        var dist = global_position.distance_to(target.global_position)
        if dist <= attack_range * 1.5:
            target.take_damage(attack_damage)

func take_damage(amount: float):
    if current_state == State.DEAD: return
    
    hp -= amount
    if hp <= 0:
        die()

func die():
    current_state = State.DEAD
    remove_from_group("units")
    
    if anim and anim_death:
        anim.play(anim_death)
        
    # Disable physics collision instantly so others can walk through
    var col = get_node_or_null("CollisionShape3D")
    if col: col.set_deferred("disabled", true)
    
    # Visually fade out the corpse by sinking it and scaling down smoothly
    await get_tree().create_timer(2.0).timeout # Lie on the ground for a bit
    
    var t = create_tween()
    t.tween_property(self, "scale", Vector3.ZERO, 1.5).set_trans(Tween.TRANS_SINE)
    await t.finished
    queue_free()

func _apply_team_color(node: Node, team_color: Color):
    if node is MeshInstance3D and node.mesh:
        for i in range(node.mesh.get_surface_count()):
            # Fallback to mesh material if override doesn't exist
            var mat = node.get_active_material(i)
            if mat and (mat is StandardMaterial3D or mat is ORMMaterial3D):
                var new_mat = mat.duplicate()
                # Blend toward team color instead of hard-multiplying, so texture detail stays readable.
                new_mat.albedo_color = new_mat.albedo_color.lerp(team_color, 0.55)
                new_mat.emission_enabled = true
                new_mat.emission = team_color * 0.15
                node.set_surface_override_material(i, new_mat)
    
    for child in node.get_children():
        _apply_team_color(child, team_color)

func _find_anim(keyword: String) -> String:
    for a in anim.get_animation_list():
        if keyword.to_lower() in a.to_lower():
            return a
    return ""
