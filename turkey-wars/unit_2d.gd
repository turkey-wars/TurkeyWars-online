extends CharacterBody3D

enum Team { ATTACKER, DEFENDER }
enum State { IDLE, MOVE, ATTACK, DEAD }

@export var team: Team = Team.ATTACKER
@export var unit_class: String = "melee"

@export var hp: float = 600.0
@export var attack_damage: float = 200.0
@export var attack_speed: float = 1.2
@export var attack_range: float = 1.75
@export var movement_speed: float = 5.0
@export var is_ranged: bool = false
@export var is_backline: bool = false
@export var default_faces_left: bool = false

var current_state: State = State.IDLE
var target: Node3D = null
var attack_timer: float = 0.0

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var team_ring: MeshInstance3D = $TeamRing
@onready var coll_shape: CollisionShape3D = $CollisionShape3D

static var frames_cache = {}

static var sfx_loaded = false
static var sfx_melee = []
static var sfx_range = []
static var sfx_tank = []

var audio_player: AudioStreamPlayer3D

func _ready():
	add_to_group("units")

	if not sfx_loaded:
		sfx_melee.append(preload("res://assets/audio/sfx/melee_01.ogg"))
		sfx_melee.append(preload("res://assets/audio/sfx/melee_02.ogg"))
		sfx_melee.append(preload("res://assets/audio/sfx/melee_03.ogg"))
		sfx_range.append(preload("res://assets/audio/sfx/rifle_continuous.ogg"))
		sfx_tank.append(preload("res://assets/audio/sfx/tank_01.ogg"))
		sfx_tank.append(preload("res://assets/audio/sfx/tank_02.ogg"))
		sfx_loaded = true

	audio_player = AudioStreamPlayer3D.new()
	if unit_class == "melee" or unit_class == "tank":
		audio_player.volume_db = -0.0
	elif unit_class == "range":
		audio_player.volume_db = -14.0
	add_child(audio_player)

	if not frames_cache.has(unit_class):
		frames_cache[unit_class] = _load_frames(unit_class)
	sprite.sprite_frames = frames_cache[unit_class]

	sprite.play("idle")

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.2, 0.2) if team == Team.ATTACKER else Color(0.2, 0.4, 0.9)
	team_ring.material_override = mat

static func _load_frames(cls: String) -> SpriteFrames:
	var sf = SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	
	var base_path = "res://assets/new_battlefield_units/" + cls + "/"
	var states = ["idle", "walk", "attack", "die"]
	
	for state in states:
		sf.add_animation(state)
		sf.set_animation_loop(state, state != "die")
		# Give a base 1.5x kick to the static generic animations (idle, walk, die)
		sf.set_animation_speed(state, 45.0) 
		
		# Fallback logic: "range" unit uses "idle_attack" folder instead of "attack"!
		var folder_name = state
		var d = DirAccess.open(base_path + folder_name + "/")
		if d == null and state == "attack":
			folder_name = "idle_attack"
			d = DirAccess.open(base_path + folder_name + "/")
			
		var path = base_path + folder_name + "/"
		if d:
			var valid_files = []
			for f in d.get_files():
				if f.ends_with(".png") or f.ends_with(".png.import"):
					var t_name = f.replace(".import", "")
					var base_f = t_name.get_basename()
					# Exclude base sprite sheet images inside the folders and only load sequence images
					if base_f.length() > 0 and base_f.right(1).is_valid_int():
						if not valid_files.has(t_name):
							valid_files.append(t_name)
			
			valid_files.sort()
			for img in valid_files:
				var load_path = path + img
				var t = load(load_path)
				if t:
					sf.add_frame(state, t)
	return sf

func _physics_process(delta: float):
	if current_state == State.DEAD:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
			move_and_slide()
		return
		
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	target = _get_closest_enemy()
	if not target:
		_change_state(State.IDLE)
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
		
	var dist = global_position.distance_to(target.global_position)
	
	if dist <= attack_range:
		_change_state(State.ATTACK)
		velocity.x = 0
		velocity.z = 0
		
		attack_timer -= delta
		if attack_timer <= 0:
			attack_timer = 1.0 / attack_speed
			target.take_damage(attack_damage)
			_play_attack_sfx()
	else:
		_change_state(State.MOVE)
		var dir = global_position.direction_to(target.global_position)
		dir.y = 0
		dir = dir.normalized()
		velocity.x = dir.x * movement_speed
		velocity.z = dir.z * movement_speed
		
	# Face the correct horizontal direction
	if target.global_position.x > global_position.x:
		sprite.flip_h = default_faces_left
	else:
		sprite.flip_h = not default_faces_left
		
	move_and_slide()

func _change_state(new_state: State):
	if current_state == new_state: return
	current_state = new_state
	
	sprite.speed_scale = 1.0
	
	if current_state == State.IDLE:
		sprite.play("idle")
	elif current_state == State.MOVE:
		sprite.play("walk")
	elif current_state == State.ATTACK:
		sprite.play("attack")
		var fps = sprite.sprite_frames.get_animation_speed("attack")
		var count = sprite.sprite_frames.get_frame_count("attack")
		if count > 0 and fps > 0:
			var anim_length = float(count) / fps
			var desired_time = 1.0 / attack_speed
			sprite.speed_scale = anim_length / desired_time
		# Hit delay aligns proportionally
		attack_timer = (1.0 / attack_speed) * 0.5 

func _get_closest_enemy() -> Node3D:
	var units = get_tree().get_nodes_in_group("units")
	var best_tgt = null
	var min_dist = INF
	for u in units:
		if u.current_state == State.DEAD: continue
		if u.team != self.team:
			var d = global_position.distance_to(u.global_position)
			if d < min_dist:
				min_dist = d
				best_tgt = u
	return best_tgt

func take_damage(dmg: float):
	if current_state == State.DEAD: return
	hp -= dmg
	if hp <= 0:
		_die()

func _die():
	current_state = State.DEAD
	remove_from_group("units")
	if coll_shape:
		coll_shape.set_deferred("disabled", true)
	if team_ring:
		team_ring.visible = false
	sprite.speed_scale = 1.0
	sprite.play("die")
	
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _play_attack_sfx():
		if audio_player == null: return
		var streams = []
		if unit_class == "melee": streams = sfx_melee
		elif unit_class == "range": streams = sfx_range
		elif unit_class == "tank": streams = sfx_tank
		
		if streams.size() > 0:
				var stream = streams[randi() % streams.size()]
				audio_player.stream = stream
				audio_player.pitch_scale = randf_range(0.85, 1.15)
				audio_player.play()
