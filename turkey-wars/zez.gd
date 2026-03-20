extends Node3D

func _ready() -> void:
	# Initialize the spring afternoon environment when the scene loads
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

func _spawn_armies():
	# Allow some engine frames for things to settle
	await get_tree().create_timer(0.2).timeout
	
	# For Attacker (Team 0)
	for i in range(5):
		_spawn_unit(0, false, preload("res://soldier_2d.tscn"))
	for i in range(5):
		_spawn_unit(0, true, preload("res://rifleman_2d.tscn"))
	_spawn_unit(0, true, preload("res://tank_2d.tscn"))
	
	# For Defender (Team 1)
	for i in range(5):
		_spawn_unit(1, false, preload("res://soldier_2d.tscn"))
	for i in range(5):
		_spawn_unit(1, true, preload("res://rifleman_2d.tscn"))
	_spawn_unit(1, true, preload("res://tank_2d.tscn"))

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
