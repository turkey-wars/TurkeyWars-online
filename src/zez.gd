extends Node3D

# --- TEMPORARY SPAWN CONFIG (Until wired to Main Menu) ---
@export var attacker_warrior_count: int = 50
@export var attacker_ranger_count: int = 0
@export var attacker_wizard_count: int = 0
@export var attacker_rocket_launcher_count: int = 0

@export var defender_warrior_count: int = 0
@export var defender_ranger_count: int = 0
@export var defender_wizard_count: int = 10
@export var defender_rocket_launcher_count: int = 0
# ---------------------------------------------------------

var attacker_count_label: Label
var defender_count_label: Label
var battle_result_panel: PanelContainer
var battle_result_label: Label

# Detailed unit count labels
var attacker_unit_labels = {} # class -> Label
var defender_unit_labels = {} # class -> Label

var win_slider: ProgressBar
var target_win_ratio: float = 0.5

var battle_ended_flag = false
var initial_spawn_done = false

func _ready() -> void:
	# Initialize a random environment when the scene loads
	_setup_hud()
	_setup_random_environment()

func _setup_random_environment() -> void:
	var env_configs = [
		{
			"name": "Spring Afternoon",
			"sun_rot": Vector3(-25.0, 250.0, 0.0),
			"sun_color": Color(1.0, 0.92, 0.82),
			"sky_top": Color(0.25, 0.55, 0.85),
			"sky_horizon": Color(0.65, 0.75, 0.85),
			"exposure": 1.05
		},
		{
			"name": "High Noon Summer",
			"sun_rot": Vector3(-85.0, 0.0, 0.0),
			"sun_color": Color(1.0, 1.0, 0.95),
			"sky_top": Color(0.1, 0.4, 0.8),
			"sky_horizon": Color(0.5, 0.7, 0.9),
			"exposure": 1.2
		},
		{
			"name": "Golden Hour Sunset",
			"sun_rot": Vector3(-5.0, 260.0, 0.0),
			"sun_color": Color(1.0, 0.6, 0.2),
			"sky_top": Color(0.1, 0.2, 0.5),
			"sky_horizon": Color(1.0, 0.4, 0.1),
			"exposure": 1.1
		},
		{
			"name": "Overcast Winter",
			"sun_rot": Vector3(-30.0, 180.0, 0.0),
			"sun_color": Color(0.8, 0.8, 0.9),
			"sky_top": Color(0.4, 0.4, 0.5),
			"sky_horizon": Color(0.6, 0.6, 0.7),
			"exposure": 0.9
		},
		{
			"name": "Moonlight Night",
			"sun_rot": Vector3(-45.0, 45.0, 0.0),
			"sun_color": Color(0.3, 0.4, 0.6),
			"sky_top": Color(0.02, 0.05, 0.1),
			"sky_horizon": Color(0.05, 0.1, 0.2),
			"exposure": 0.6
		},
		{
			"name": "Early Autumn Morning",
			"sun_rot": Vector3(-15.0, 90.0, 0.0),
			"sun_color": Color(1.0, 0.85, 0.7),
			"sky_top": Color(0.3, 0.5, 0.7),
			"sky_horizon": Color(0.9, 0.7, 0.5),
			"exposure": 1.0
		},
		{
			"name": "Stormy Sky",
			"sun_rot": Vector3(-40.0, 210.0, 0.0),
			"sun_color": Color(0.7, 0.7, 0.8),
			"sky_top": Color(0.2, 0.2, 0.25),
			"sky_horizon": Color(0.4, 0.4, 0.45),
			"exposure": 0.85
		},
		{
			"name": "Martian Red",
			"sun_rot": Vector3(-35.0, 120.0, 0.0),
			"sun_color": Color(1.0, 0.5, 0.3),
			"sky_top": Color(0.5, 0.2, 0.1),
			"sky_horizon": Color(0.8, 0.4, 0.2),
			"exposure": 1.0
		},
		{
			"name": "Deep Space Nebula",
			"sun_rot": Vector3(-10.0, -10.0, 0.0),
			"sun_color": Color(0.8, 0.2, 0.9),
			"sky_top": Color(0.1, 0.0, 0.2),
			"sky_horizon": Color(0.3, 0.0, 0.5),
			"exposure": 0.75
		},
		{
			"name": "Alien Green",
			"sun_rot": Vector3(-60.0, 180.0, 0.0),
			"sun_color": Color(0.7, 1.0, 0.7),
			"sky_top": Color(0.0, 0.2, 0.0),
			"sky_horizon": Color(0.2, 0.5, 0.2),
			"exposure": 1.0
		}
	]
	
	var config = env_configs[randi() % env_configs.size()]
	print("Loading Environment: ", config["name"])

	# 1. Setup the Sun (DirectionalLight3D)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = config["sun_rot"]
	sun.light_color = config["sun_color"]
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)

	# 2. Setup the Sky Material
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = config["sky_top"]
	sky_material.sky_horizon_color = config["sky_horizon"]
	sky_material.ground_bottom_color = config["sky_top"].darkened(0.8)
	sky_material.ground_horizon_color = config["sky_horizon"]
	
	# 3. Apply Material to a Sky Resource
	var sky := Sky.new()
	sky.sky_material = sky_material

	# 4. Setup the Environment
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = config["exposure"]
	
	# Optimization
	env.volumetric_fog_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.glow_enabled = false

	# 5. Attach to a WorldEnvironment Node
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
	
	_spawn_armies()

	var bgm = AudioStreamPlayer.new()
	var stream = preload("res://assets/audio/sfx/battle_music.ogg")
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	bgm.stream = stream
	bgm.volume_db = -8.0
	bgm.autoplay = true
	add_child(bgm)

func _create_spring_afternoon_environment() -> void:
	# This function is now deprecated in favor of _setup_random_environment
	pass

func _spawn_armies():
	# Allow some engine frames for things to settle
	await get_tree().create_timer(0.2).timeout
	
	if GameState.attack_data.attacker_idx != -1:
		attacker_warrior_count = GameState.attack_data.attacker_army.get("warrior", 0)
		attacker_ranger_count = GameState.attack_data.attacker_army.get("ranger", 0)
		attacker_wizard_count = GameState.attack_data.attacker_army.get("wizard", 0)
		attacker_rocket_launcher_count = GameState.attack_data.attacker_army.get("rocket_launcher", 0)

		defender_warrior_count = GameState.attack_data.defender_army.get("warrior", 0)
		defender_ranger_count = GameState.attack_data.defender_army.get("ranger", 0)
		defender_wizard_count = GameState.attack_data.defender_army.get("wizard", 0)
		defender_rocket_launcher_count = GameState.attack_data.defender_army.get("rocket_launcher", 0)

	# For Attacker (Team 0)
	for i in range(attacker_warrior_count):
		_spawn_unit(0, false, preload("res://soldier_2d.tscn"))
	for i in range(attacker_ranger_count):
		_spawn_unit(0, true, preload("res://rifleman_2d.tscn"))
	for i in range(attacker_rocket_launcher_count):
		_spawn_unit(0, true, preload("res://rocket_launcher_2d.tscn"))
	for i in range(attacker_wizard_count):
		_spawn_unit(0, false, preload("res://tank_2d.tscn"))
	
	# For Defender (Team 1)
	for i in range(defender_warrior_count):
		_spawn_unit(1, false, preload("res://soldier_2d.tscn"))
	for i in range(defender_ranger_count):
		_spawn_unit(1, true, preload("res://rifleman_2d.tscn"))
	for i in range(defender_rocket_launcher_count):
		_spawn_unit(1, true, preload("res://rocket_launcher_2d.tscn"))
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
	
	# Apply Buffs and Nerfs
	if unit.unit_class == GameState.attack_data.buffed_unit:
		unit.hp *= 2.0
		unit.attack_damage *= 2.0
		if unit.aoe_damage > 0:
			unit.aoe_damage *= 2.0
		print("[DEBUG Zez] Buffed Unit Spawned: ", unit.unit_class, " | HP: ", unit.hp, " | DMG: ", unit.attack_damage)
	elif unit.unit_class == GameState.attack_data.nerfed_unit:
		unit.hp *= 0.5
		unit.attack_damage *= 0.5
		if unit.aoe_damage > 0:
			unit.aoe_damage *= 0.5
		print("[DEBUG Zez] Nerfed Unit Spawned: ", unit.unit_class, " | HP: ", unit.hp, " | DMG: ", unit.attack_damage)

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

	var attacker_name = "ATTACKERS"
	var defender_name = "DEFENDERS"
	if GameState.attack_data.attacker_idx != -1:
		attacker_name = GameState.players[GameState.attack_data.attacker_idx].name.to_upper()
		var def_idx = GameState.attack_data.defender_idx
		if def_idx != -1:
			defender_name = GameState.players[def_idx].name.to_upper()
		else:
			defender_name = GameState.attack_data.province.to_upper()

	# Left card: attackers
	var attacker_card := PanelContainer.new()
	attacker_card.offset_left = 20
	attacker_card.offset_top = 20
	attacker_card.offset_right = 350
	attacker_card.offset_bottom = 220
	attacker_card.custom_minimum_size.x = 330
	root.add_child(attacker_card)
	TWUIStyle.style_panel_container_accent(attacker_card)

	var attacker_vbox := VBoxContainer.new()
	attacker_vbox.add_theme_constant_override("separation", 2)
	attacker_card.add_child(attacker_vbox)

	var attackers_title_lbl := Label.new()
	attackers_title_lbl.text = attacker_name
	TWUIStyle.style_label(attackers_title_lbl, true)
	attackers_title_lbl.add_theme_color_override("font_color", TWUIStyle.COLOR_ACCENT_RED)
	attackers_title_lbl.add_theme_font_size_override("font_size", 48)
	attackers_title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	attackers_title_lbl.custom_minimum_size.x = 300
	attacker_vbox.add_child(attackers_title_lbl)

	attacker_unit_labels = _create_unit_breakdown(attacker_vbox, TWUIStyle.COLOR_ACCENT_RED)

	# Right card: defenders
	var defender_card := PanelContainer.new()
	defender_card.anchor_left = 1.0
	defender_card.anchor_right = 1.0
	defender_card.offset_left = -350
	defender_card.offset_top = 20
	defender_card.offset_right = -20
	defender_card.offset_bottom = 220
	defender_card.custom_minimum_size.x = 330
	root.add_child(defender_card)
	var def_card_sb := TWUIStyle.make_card_accent_stylebox()
	def_card_sb.border_color = TWUIStyle.COLOR_ACCENT_BLUE
	defender_card.add_theme_stylebox_override("panel", def_card_sb)

	var defender_vbox := VBoxContainer.new()
	defender_vbox.add_theme_constant_override("separation", 2)
	defender_card.add_child(defender_vbox)

	var defenders_title_lbl := Label.new()
	defenders_title_lbl.text = defender_name
	defenders_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	TWUIStyle.style_label(defenders_title_lbl, true)
	defenders_title_lbl.add_theme_color_override("font_color", TWUIStyle.COLOR_ACCENT_BLUE)
	defenders_title_lbl.add_theme_font_size_override("font_size", 48)
	defenders_title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	defenders_title_lbl.custom_minimum_size.x = 300
	defender_vbox.add_child(defenders_title_lbl)

	defender_unit_labels = _create_unit_breakdown(defender_vbox, TWUIStyle.COLOR_ACCENT_BLUE, true)

	# Win Indicator Slider at the top - Fixed centering and size
	win_slider = ProgressBar.new()
	win_slider.custom_minimum_size = Vector2(300, 10)
	win_slider.show_percentage = false
	win_slider.value = 50
	win_slider.set_anchors_preset(Control.PRESET_CENTER_TOP)
	win_slider.grow_horizontal = Control.GROW_DIRECTION_BOTH
	win_slider.offset_top = 24
	root.add_child(win_slider)
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = TWUIStyle.COLOR_ACCENT_BLUE
	sb_bg.corner_radius_top_left = 6
	sb_bg.corner_radius_top_right = 6
	sb_bg.corner_radius_bottom_left = 6
	sb_bg.corner_radius_bottom_right = 6
	
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = TWUIStyle.COLOR_ACCENT_RED
	sb_fg.corner_radius_top_left = 6
	sb_fg.corner_radius_top_right = 6
	sb_fg.corner_radius_bottom_left = 6
	sb_fg.corner_radius_bottom_right = 6
	
	win_slider.add_theme_stylebox_override("background", sb_bg)
	win_slider.add_theme_stylebox_override("fill", sb_fg)

	# Battle result banner
	battle_result_panel = PanelContainer.new()
	battle_result_panel.visible = false
	battle_result_panel.anchor_left = 0.5
	battle_result_panel.anchor_right = 0.5
	battle_result_panel.anchor_top = 0.5
	battle_result_panel.anchor_bottom = 0.5
	battle_result_panel.offset_left = -300
	battle_result_panel.offset_right = 300
	battle_result_panel.offset_top = -50
	battle_result_panel.offset_bottom = 50
	root.add_child(battle_result_panel)
	TWUIStyle.style_panel_container_accent(battle_result_panel)

	var banner_vbox := VBoxContainer.new()
	battle_result_panel.add_child(banner_vbox)

	battle_result_label = Label.new()
	battle_result_label.text = "VICTORY"
	TWUIStyle.style_label(battle_result_label, true)
	battle_result_label.add_theme_font_size_override("font_size", 64)
	battle_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_vbox.add_child(battle_result_label)

func _create_unit_breakdown(parent: Node, color: Color, align_right: bool = false) -> Dictionary:
	var labels = {}
	var types = [
		["melee", "Soldiers"],
		["range", "Riflemen"],
		["rocket_launcher", "Rocketeers"],
		["tank", "Tanks"]
	]
	
	for type_info in types:
		var type = type_info[0]
		var display = type_info[1]
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		if align_right: hbox.alignment = BoxContainer.ALIGNMENT_END
		parent.add_child(hbox)
		
		var name_lbl = Label.new()
		name_lbl.text = display
		TWUIStyle.style_label_muted(name_lbl)
		name_lbl.add_theme_font_size_override("font_size", 14)
		
		var count_lbl = Label.new()
		count_lbl.text = "0"
		TWUIStyle.style_label(count_lbl, true)
		count_lbl.add_theme_font_size_override("font_size", 18)
		count_lbl.add_theme_color_override("font_color", color)
		
		if align_right:
			hbox.add_child(count_lbl)
			hbox.add_child(name_lbl)
		else:
			hbox.add_child(name_lbl)
			hbox.add_child(count_lbl)
			
		labels[type] = count_lbl
		
	return labels

func _process(delta: float):
	_update_team_counters()
	if win_slider:
		win_slider.value = lerp(win_slider.value, target_win_ratio * 100.0, delta * 2.0)

func _update_team_counters():
	if not attacker_unit_labels or not defender_unit_labels:
		return

	var attacker_counts = {"melee": 0, "range": 0, "rocket_launcher": 0, "tank": 0}
	var defender_counts = {"melee": 0, "range": 0, "rocket_launcher": 0, "tank": 0}
	
	var attacker_total = 0
	var defender_total = 0

	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or u.current_state == u.State.DEAD:
			continue
			
		if u.team == 0:
			attacker_counts[u.unit_class] += 1
			attacker_total += 1
		else:
			defender_counts[u.unit_class] += 1
			defender_total += 1

	for type in attacker_counts:
		attacker_unit_labels[type].text = str(attacker_counts[type])
	for type in defender_counts:
		defender_unit_labels[type].text = str(defender_counts[type])

	var total = attacker_total + defender_total
	if total > 0:
		target_win_ratio = float(attacker_total) / float(total)
	else:
		target_win_ratio = 0.5

	if not battle_ended_flag:
		if initial_spawn_done:
			if attacker_total == 0 and defender_total == 0:
				call_deferred("_end_battle", false)
			elif attacker_total == 0:
				call_deferred("_end_battle", false)
			elif defender_total == 0:
				call_deferred("_end_battle", true)

func _end_battle(attacker_won: bool):
	if battle_ended_flag: return
	battle_ended_flag = true

	print("Battle Over. Attacker Won: ", attacker_won)

	_show_battle_result(attacker_won)

	# Small delay before changing scene
	await get_tree().create_timer(4.0).timeout

	GameState.resolve_battle(attacker_won)


func _show_battle_result(attacker_won: bool) -> void:
	if not battle_result_panel or not battle_result_label:
		return

	battle_result_panel.visible = true
	battle_result_panel.modulate.a = 0.0

	if attacker_won:
		battle_result_label.text = "VICTORY"
		battle_result_label.add_theme_color_override("font_color", TWUIStyle.COLOR_ACCENT_RED)
	else:
		battle_result_label.text = "DEFEAT"
		battle_result_label.add_theme_color_override("font_color", TWUIStyle.COLOR_ACCENT_BLUE)

	var tween := create_tween()
	tween.tween_property(battle_result_panel, "modulate:a", 1.0, 0.25)
