extends Node3D

var target: Node3D = null
var damage: float = 0.0
var speed: float = 25.0

func fire(t: Node3D, d: float):
    target = t
    damage = d
    # Face target immediately
    if is_instance_valid(target):
        var target_pos = target.global_position + Vector3(0, 1.0, 0)
        look_at(target_pos, Vector3.UP)

func _physics_process(delta: float):
    if not is_instance_valid(target) or target.current_state == target.State.DEAD:
        queue_free()
        return
        
    var target_pos = target.global_position + Vector3(0, 1.0, 0) # Aim at chest
    var dir = global_position.direction_to(target_pos)
    
    # Rotate pointing to target
    if global_position.distance_squared_to(target_pos) > 0.01:
        look_at(target_pos, Vector3.UP)
        
    global_position += dir * speed * delta
    
    if global_position.distance_to(target_pos) < 0.8:
        target.take_damage(damage)
        queue_free()
