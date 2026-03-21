extends Node3D

# --- TEMPORARY SPAWN CONFIG (Until wired to Main Menu) ---
@export var attacker_warrior_count: int = 50
@export var attacker_ranger_count: int = 0
@export var attacker_wizard_count: int = 0

@export var defender_warrior_count: int = 0
@export var defender_ranger_count: int = 0
@export var defender_wizard_count: int = 10
# ---------------------------------------------------------

var attacker_count_label: Label
var defender_count_label: Label
var battle_result_panel: PanelContainer
var battle_result_label: Label

var battle_ended_flag = false
var initial_spawn_done = false

func _ready() -> void:
	# Initialize the spring afternoon environment when the scene loads
	_setup_hud()
	_create_spring_afternoon_environment()

func _create_spring_afternoon_environment() -> void:
	# 1. Setup the Sun (DirectionalLight3D)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun_430PM"
	
	# 4:30 PM Positioning: 
	# X = -25° (Sun is getting lower), Y = 250° (Setting in the West/South-West)
	sun.rotation_degrees = Vector3(-25.0, 250.0, 0.0)
	
	# Spring lighting: Bright, clear, with a slight late-afternoon warmth
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5 # Soften shadows for a clear spring day
	
	add_child(sun)

	# 2. Setup the Sky Material (ProceduralSkyMaterial)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.55, 0.85) # Crisp blue spring sky
	sky_material.sky_horizon_color = Color(0.65, 0.75, 0.85) # Slight atmospheric haze at the horizon
	sky_material.ground_bottom_color = Color(0.15, 0.20, 0.15) # Earthy green reflection from spring grass
	sky_material.ground_horizon_color = Color(0.65, 0.75, 0.85)
	
	# 3. Apply Material to a Sky Resource
	var sky := Sky.new()
	sky.sky_material = sky_material

	# 4. Setup the Environment
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	
	# Lighting and Tonemapping
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.6, 0.7, 0.8)
	env.ambient_light_energy = 1.0
	
	# ACES Tonemapping is highly recommended in Godot 4 for realistic light handling
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	
	# Optional: Very subtle volumetric fog to simulate slight spring pollen/atmosphere
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.002 # Extremely low density to keep it "clear"
	env.volumetric_fog_albedo = Color(0.85, 0.90, 0.95)

	# 5. Attach to a WorldEnvironment Node
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env

	add_child(world_env)
	print("Godot 4.6: 4:30 PM Spring Clear Sky loaded successfully.")
	
	# After environment setup, spawn 2D units
	_spawn_armies()

	var bgm = AudioStreamPlayer.new()
	var stream = preload("res://assets/audio/sfx/battle_music.ogg")
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	bgm.stream = stream
	bgm.volume_db = -8.0
	bgm.autoplay = true
	add_child(bgm)

func _spawn_armies():
	# Allow some engine frames for things to settle
	await get_tree().create_timer(0.2).timeout
	
	if GameState.attack_data.attacker_idx != -1:
		attacker_warrior_count = GameState.attack_data.attacker_army.get("warrior", 0)
		attacker_ranger_count = GameState.attack_data.attacker_army.get("ranger", 0)
		attacker_wizard_count = GameState.attack_data.attacker_army.get("wizard", 0)
		defender_warrior_count = GameState.attack_data.defender_army.get("warrior", 0)
		defender_ranger_count = GameState.attack_data.defender_army.get("ranger", 0)
		defender_wizard_count = GameState.attack_data.defender_army.get("wizard", 0)

	# For Attacker (Team 0)
	for i in range(attacker_warrior_count):
		_spawn_unit(0, false, preload("res://soldier_2d.tscn"))
	for i in range(attacker_ranger_count):
		_spawn_unit(0, true, preload("res://rifleman_2d.tscn"))
	for i in range(attacker_wizard_count):
		_spawn_unit(0, false, preload("res://tank_2d.tscn"))
	
	# For Defender (Team 1)
	for i in range(defender_warrior_count):
		_spawn_unit(1, false, preload("res://soldier_2d.tscn"))
	for i in range(defender_ranger_count):
		_spawn_unit(1, true, preload("res://rifleman_2d.tscn"))
	for i in range(defender_wizard_count):
		_spawn_unit(1, false, preload("res://tank_2d.tscn"))

	initial_spawn_done = true

func _spawn_unit(team: int, is_backline: bool, scene: PackedScene):
	var spawner_name = ""
	if team == 0:
		spawner_name = "AttackerBackline" if is_backline else "AttackerFrontline"
	else:
		spawner_name = "DefenderBackline" if is_backline else "DefenderFrontline"
		
	var spawner_node: CSGBox3D = get_parent().get_node(spawner_name)
	if not spawner_node:
		print("Error: Could not find " + spawner_name)
		return
		
	var unit = scene.instantiate()
	unit.team = team
	unit.is_backline = is_backline
	get_parent().add_child(unit)
	
	var sx = spawner_node.scale.x
	var sz = spawner_node.scale.z
	
	var rx = randf_range(-0.5, 0.5) * sx
	var rz = randf_range(-0.5, 0.5) * sz
	
	# Set baseline spawn height appropriately based on the spawner box elevation
	unit.global_position = spawner_node.global_position + Vector3(rx, 0, rz)


func _setup_hud():
	var hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(root)

	# Left card: attackers — gold left-accent with big red count.
	var attacker_card := PanelContainer.new()
	attacker_card.anchor_left = 0.0
	attacker_card.anchor_right = 0.0
	attacker_card.anchor_top = 0.0
	attacker_card.anchor_bottom = 0.0
	attacker_card.offset_left = 20
	attacker_card.offset_top = 14
	attacker_card.offset_right = 240
	attacker_card.offset_bottom = 130
	root.add_child(attacker_card)
	TWUIStyle.style_panel_container_accent(attacker_card)

	var attacker_vbox := VBoxContainer.new()
	attacker_vbox.add_theme_constant_override("separation", 4)
	attacker_card.add_child(attacker_vbox)

	var attackers_title := Label.new()
	attackers_title.text = "ATTACKERS"
	TWUIStyle.style_label_muted(attackers_title)
	attacker_vbox.add_child(attackers_title)

	attacker_count_label = Label.new()
	attacker_count_label.text = "0"
	TWUIStyle.style_label(attacker_count_label, true)
	attacker_count_label.add_theme_color_override("font_color", TWUIStyle.COLOR_ACCENT_RED)
	attacker_count_label.add_theme_font_size_override("font_size", 42)
	attacker_vbox.add_child(attacker_count_label)

	# Right card: defenders — blue accent with big blue count.
	var defender_card := PanelContainer.new()
	defender_card.anchor_left = 1.0
	defender_card.anchor_right = 1.0
	defender_card.anchor_top = 0.0
	defender_card.anchor_bottom = 0.0
	defender_card.offset_left = -240
	defender_card.offset_top = 14
	defender_card.offset_right = -20
	defender_card.offset_bottom = 130
	root.add_child(defender_card)
	var def_card_sb := TWUIStyle.make_card_accent_stylebox()
	def_card_sb.border_color = TWUIStyle.COLOR_ACCENT_BLUE
	defender_card.add_theme_stylebox_override("panel", def_card_sb)

	var defender_vbox := VBoxContainer.new()
	defender_vbox.add_theme_constant_override("separation", 4)
	defender_card.add_child(defender_vbox)

	var defenders_title := Label.new()
	defenders_title.text = "DEFENDERS"
	TWUIStyle.style_label_muted(defenders_title)
	defender_vbox.add_child(defenders_title)

	defender_count_label = Label.new()
	defender_count_label.text = "0"
	TWUIStyle.style_label(defender_count_label, true)
	defender_count_label.add_theme_color_override("font_color", TWUIStyle.COLOR_ACCENT_BLUE)
	defender_count_label.add_theme_font_size_override("font_size", 42)
	defender_vbox.add_child(defender_count_label)

	# Battle result banner — centered, fades in on victory.
	battle_result_panel = PanelContainer.new()
	battle_result_panel.visible = false
	battle_result_panel.anchor_left = 0.5
	battle_result_panel.anchor_right = 0.5
	battle_result_panel.anchor_top = 0.0
	battle_result_panel.anchor_bottom = 0.0
	battle_result_panel.offset_left = -380
	battle_result_panel.offset_right = 380
	battle_result_panel.offset_top = 120
	battle_result_panel.offset_bottom = 210
	root.add_child(battle_result_panel)
	TWUIStyle.style_panel_container_accent(battle_result_panel)

	var banner_vbox := VBoxContainer.new()
	battle_result_panel.add_child(banner_vbox)

	battle_result_label = Label.new()
	battle_result_label.text = "VICTORY"
	TWUIStyle.style_label(battle_result_label, true)
	battle_result_label.add_theme_font_size_override("font_size", 32)
	battle_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_vbox.add_child(battle_result_label)

func _process(_delta: float):
	_update_team_counters()

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

	attacker_count_label.text = "%d" % attacker_alive
	defender_count_label.text = "%d" % defender_alive

	if not battle_ended_flag:
		# Need to make sure units actually spawned first
		if initial_spawn_done:
			if attacker_alive == 0 and defender_alive == 0:
				call_deferred("_end_battle", false) # Draw counts as defend win for simplicity
			elif attacker_alive == 0:
				call_deferred("_end_battle", false)
			elif defender_alive == 0:
				call_deferred("_end_battle", true)

func _end_battle(attacker_won: bool):
	if battle_ended_flag: return
	battle_ended_flag = true

	print("Battle Over. Attacker Won: ", attacker_won)

	_show_battle_result(attacker_won)

	# Small delay before changing scene
	await get_tree().create_timer(3.0).timeout

	GameState.resolve_battle(attacker_won)


func _show_battle_result(attacker_won: bool) -> void:
	if not battle_result_panel or not battle_result_label:
		return

	battle_result_panel.visible = true
	battle_result_panel.modulate.a = 0.0

	if attacker_won:
		battle_result_label.text = "Attackers Victory"
		battle_result_label.add_theme_color_override("font_color", TWUIStyle.COLOR_ACCENT_RED)
	else:
		battle_result_label.text = "Defenders Victory"
		battle_result_label.add_theme_color_override("font_color", TWUIStyle.COLOR_ACCENT_BLUE)

	var tween := create_tween()
	tween.tween_property(battle_result_panel, "modulate:a", 1.0, 0.18)
