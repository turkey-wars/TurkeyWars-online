extends Node3D

@export var warrior_scene: PackedScene
@export var ranger_scene: PackedScene
@export var wizard_scene: PackedScene

@export_group("Initial Troops - Attackers")
@export var attacker_frontline_warriors: int = 100
@export var attacker_backline_rangers: int = 0
@export var attacker_backline_wizards: int = 0

@export_group("Initial Troops - Defenders")
@export var defender_frontline_warriors: int = 0
@export var defender_backline_rangers: int = 25
@export var defender_backline_wizards: int = 10

@onready var attacker_front = $AttackerFrontline
@onready var attacker_back = $AttackerBackline
@onready var defender_front = $DefenderFrontline
@onready var defender_back = $DefenderBackine

var attacker_count_label: Label
var defender_count_label: Label

func _ready():
	if not warrior_scene:
		warrior_scene = load("res://warrior.tscn")
	if not ranger_scene:
		ranger_scene = load("res://ranger.tscn")
	if not wizard_scene:
		wizard_scene = load("res://wizard.tscn")
	
	# Hide the boundary boxes so they don't block the screen during gameplay
	attacker_front.visible = false
	attacker_back.visible = false
	defender_front.visible = false
	defender_back.visible = false

	_setup_hud()
	
	# Sync troops from game state if available
	if GameState.attack_data.province != "":
		attacker_frontline_warriors = GameState.attack_data.attacker_army.get("warrior", 0)
		attacker_backline_rangers = GameState.attack_data.attacker_army.get("ranger", 0)
		attacker_backline_wizards = GameState.attack_data.attacker_army.get("wizard", 0)
		
		defender_frontline_warriors = GameState.attack_data.defender_army.get("warrior", 0)
		defender_backline_rangers = GameState.attack_data.defender_army.get("ranger", 0)
		defender_backline_wizards = GameState.attack_data.defender_army.get("wizard", 0)

	# Wait a tiny bit just to let grass/scene load
	await get_tree().create_timer(0.5).timeout

	# Spawn Attackers (Left Team)
	for i in range(attacker_frontline_warriors):
		spawn_unit(0, false, warrior_scene)
	for i in range(attacker_backline_rangers):
		spawn_unit(0, true, ranger_scene)
	for i in range(attacker_backline_wizards):
		spawn_unit(0, true, wizard_scene)

	# Spawn Defenders (Right Team)
	for i in range(defender_frontline_warriors):
		spawn_unit(1, false, warrior_scene)
	for i in range(defender_backline_rangers):
		spawn_unit(1, true, ranger_scene)
	for i in range(defender_backline_wizards):
		spawn_unit(1, true, wizard_scene)

	initial_spawn_done = true
func _process(_delta: float):
	_update_team_counters()

func _setup_hud():
	var hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(root)

	attacker_count_label = Label.new()
	attacker_count_label.text = "Attackers: 0"
	attacker_count_label.position = Vector2(24, 14)
	attacker_count_label.add_theme_font_size_override("font_size", 28)
	attacker_count_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	root.add_child(attacker_count_label)

	defender_count_label = Label.new()
	defender_count_label.text = "Defenders: 0"
	defender_count_label.anchor_left = 1.0
	defender_count_label.anchor_right = 1.0
	defender_count_label.offset_left = -320
	defender_count_label.offset_right = -24
	defender_count_label.offset_top = 14
	defender_count_label.offset_bottom = 58
	defender_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	defender_count_label.add_theme_font_size_override("font_size", 28)
	defender_count_label.add_theme_color_override("font_color", Color(0.35, 0.55, 1.0))
	root.add_child(defender_count_label)

func _update_team_counters():
	if not attacker_count_label or not defender_count_label:
		return

	var attacker_alive = 0
	var defender_alive = 0
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u):
			continue
		if u.team == 0 and u.current_state != u.State.DEAD:
			attacker_alive += 1
		elif u.team == 1 and u.current_state != u.State.DEAD:
			defender_alive += 1

	attacker_count_label.text = "Attackers: %d" % attacker_alive
	defender_count_label.text = "Defenders: %d" % defender_alive
	
	if not battle_ended_flag:
		# Need to make sure units actually spawned first
		if initial_spawn_done:
			if attacker_alive == 0 and defender_alive == 0:
				call_deferred("_end_battle", false) # Draw counts as defend win for simplicity
			elif attacker_alive == 0:
				call_deferred("_end_battle", false)
			elif defender_alive == 0:
				call_deferred("_end_battle", true)

var battle_ended_flag = false
var initial_spawn_done = false

func _end_battle(attacker_won: bool):
	if battle_ended_flag: return
	battle_ended_flag = true
	
	print("Battle Over. Attacker Won: ", attacker_won)
	
	# Small delay before changing scene
	await get_tree().create_timer(3.0).timeout
	
	GameState.resolve_battle(attacker_won)

func spawn_unit(team: int, is_backline: bool, scene_to_spawn: PackedScene):
	var spawn_area: CSGBox3D = null
	if team == 0:
		spawn_area = attacker_back if is_backline else attacker_front
	else:
		spawn_area = defender_back if is_backline else defender_front
		
	var unit = scene_to_spawn.instantiate()
	unit.team = team
	unit.is_backline = is_backline
	add_child(unit)
	
	# Calculate random point inside the chosen visual box area
	# CSGBox3D's scale dictates its physical dimensions from -0.5 to 0.5 in local space.
	var sx = spawn_area.scale.x
	var sz = spawn_area.scale.z
	
	var rx = randf_range(-0.5, 0.5) * sx
	var rz = randf_range(-0.5, 0.5) * sz
	
	# Place unit precisely inside the target box area safely onto the ground
	unit.global_position = spawn_area.global_position + Vector3(rx, 0, rz)
	
	# Optional: Slightly color the units so you can tell teams apart easily right now
	if team == 0:
		pass
