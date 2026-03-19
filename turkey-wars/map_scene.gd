extends Node2D

const LOCAL_SESSION_SAVE_PATH := "user://local_session.json"

var _hovered_area: Area2D = null
var game_data: Dictionary = {}
var session_data: Dictionary = {}

var players: Array = []
var turn_index: int = 0
var province_owners: Dictionary = {}
var game_phase: String = "picking"

@onready var tooltip_panel = $UILayer/TooltipPanel
@onready var name_label = $UILayer/TooltipPanel/VBox/NameLabel
@onready var strength_label = $UILayer/TooltipPanel/VBox/StrengthLabel
@onready var army_label = $UILayer/TooltipPanel/VBox/ArmyLabel
@onready var player_army_label = $UILayer/TopLeftUI/PlayerArmyLabel

func _ready():
	_load_game_data()
	_load_or_init_session()

	tooltip_panel.visible = false

	for child in get_children():
		if child is Area2D:
			child.mouse_entered.connect(_on_area_mouse_entered.bind(child))
			child.mouse_exited.connect(_on_area_mouse_exited.bind(child))
			child.input_event.connect(_on_area_input_event.bind(child))
			
	_update_ui()
	_update_colors()

func _process(delta: float) -> void:
	if tooltip_panel.visible:
		tooltip_panel.global_position = get_global_mouse_position() + Vector2(10, 10)

func _load_game_data():
	var path = "res://assets/game_data.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json_text = file.get_as_text()
		var json = JSON.new()
		if json.parse(json_text) == OK:
			game_data = json.data
		else:
			print("JSON Parse Error")
	else:
		print("game_data.json not found!")

func _load_or_init_session():
	var player_names = ["Player1", "Player2"]
	
	if FileAccess.file_exists(LOCAL_SESSION_SAVE_PATH):
		var file = FileAccess.open(LOCAL_SESSION_SAVE_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			session_data = json.data
			if session_data.has("players") and session_data["players"].size() > 0:
				player_names = session_data["players"]
			
			if session_data.has("game_state"):
				_restore_game_state(session_data["game_state"])
				return
				
	_init_new_game_state(player_names)

func _init_new_game_state(player_names: Array):
	players = []
	province_owners.clear()
	turn_index = 0
	game_phase = "picking"
	
	var num_players = clampi(player_names.size(), 2, 5)
	var region_key = str(num_players)
	
	var available_regions = []
	for k in game_data.keys():
		var prov = game_data[k]
		if prov.has("regions") and prov["regions"].has(region_key):
			var r = prov["regions"][region_key]
			if not available_regions.has(r):
				available_regions.append(r)
				
	available_regions.shuffle()
	player_names.shuffle()
	
	for i in range(num_players):
		var p_name = player_names[i]
		var hue = float(i) / float(num_players)
		var c = Color.from_hsv(hue, 0.7, 0.9)
		
		var region_assigned = "Any"
		if i < available_regions.size():
			region_assigned = available_regions[i]
			
		players.append({
			"name": p_name,
			"region": region_assigned,
			"color": c.to_html(false),
			"army": 35000,
			"provinces": []
		})
		
	_save_session()

func _restore_game_state(state: Dictionary):
	players = state.get("players", [])
	province_owners = state.get("province_owners", {})
	turn_index = state.get("turn_index", 0)
	game_phase = state.get("game_phase", "picking")

func _save_session():
	session_data["game_state"] = {
		"players": players,
		"province_owners": province_owners,
		"turn_index": turn_index,
		"game_phase": game_phase
	}
	var file = FileAccess.open(LOCAL_SESSION_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(session_data, "	"))
		file.close()

func format_number(n: int) -> String:
	var s = str(n)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count == 3:
			res = "," + res
			count = 0
		res = s[i] + res
		count += 1
	return res

func get_strength_text_and_color(strength: int) -> Array:
	if strength == 1: return ["Very Easy", Color("00ff00")]
	elif strength == 2: return ["Easy", Color("90ee90")]
	elif strength == 3: return ["Normal", Color("ffa500")]
	elif strength == 4: return ["Strong", Color("ff4500")]
	elif strength == 5: return ["Very Strong", Color("ff0000")]
	return ["Unknown", Color("ffffff")]

func _update_ui():
	if players.size() > 0:
		var p = players[turn_index]
		var phase_text = "Picking Phase" if game_phase == "picking" else "Playing Phase"
		var army_str = format_number(int(p["army"]))
		player_army_label.text = "[%s] Turn: %s | Region: %s | Army: %s" % [phase_text, p["name"], p["region"], army_str]
		player_army_label.add_theme_color_override("font_color", Color(p["color"]))

func _is_province_selectable(province_name: String) -> bool:
	if game_phase != "picking": return false
	if province_owners.has(province_name): return false
	var p = players[turn_index]
	var p_data = game_data.get(province_name, {})
	if p_data.is_empty(): return false
	var region_key = str(players.size())
	var p_region = p_data.get("regions", {}).get(region_key, "")
	if p["region"] != "Any" and p_region != p["region"]: return false
	var adjacencies = p_data.get("adjacencies", [])
	for adj in adjacencies:
		if province_owners.has(adj) and province_owners[adj] != turn_index: return false
	return true

func _on_area_input_event(viewport: Node, event: InputEvent, shape_idx: int, area: Area2D):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_province_click(area.name)

func _handle_province_click(province_name: String):
	if players.size() == 0: return
	if game_phase != "picking": return
	
	if not _is_province_selectable(province_name): return
			
	province_owners[province_name] = turn_index
	players[turn_index]["provinces"].append(province_name)
	
	turn_index = int(turn_index) + 1
	if turn_index >= players.size():
		turn_index = 0
		game_phase = "playing"
		
	_update_ui()
	_update_colors()
	_save_session()

func _on_area_mouse_entered(area: Area2D):
	_hovered_area = area
	_update_colors()

	var province_name = area.name
	if game_data.has(province_name):
		var data = game_data[province_name]
		var tooltip_owner = "None"
		if province_owners.has(province_name):
			tooltip_owner = players[int(province_owners[province_name])]["name"]
		
		name_label.text = "Name: " + province_name + " (" + tooltip_owner + ")"
		
		var strength_val = int(data.get("strength", data.get("Strength", 0)))
		var strength_info = get_strength_text_and_color(strength_val)
		strength_label.text = "Strength: " + strength_info[0]
		strength_label.add_theme_color_override("font_color", strength_info[1])
		
		var army_val = int(data.get("initial_army", data.get("Initial_Army", 0)))
		army_label.text = "Army Size: " + format_number(army_val)
	else:
		name_label.text = "Name: " + province_name
		strength_label.text = "Strength: ?"
		strength_label.add_theme_color_override("font_color", Color.WHITE)
		army_label.text = "Army Size: ?"

	tooltip_panel.visible = true

func _on_area_mouse_exited(area: Area2D):
	if _hovered_area == area:
		_hovered_area = null
		tooltip_panel.visible = false
	_update_colors()

func _update_colors():
	for child in get_children():
		if child is Area2D:
			var target_color = Color(0.7, 0.7, 0.7)
			
			if game_phase == "picking":
				var selectable = _is_province_selectable(child.name)
				if selectable:
					target_color = Color(0.85, 0.85, 0.5)
				else:
					target_color = Color(0.4, 0.4, 0.4)
			
			if province_owners.has(child.name):
				var owner_idx = int(province_owners[child.name])
				target_color = Color(players[owner_idx]["color"])
				
			if child == _hovered_area:
				target_color = target_color.lightened(0.3)
				
			for node in child.get_children():
				if node is Polygon2D:
					node.color = target_color
