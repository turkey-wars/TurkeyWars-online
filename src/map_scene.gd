extends Node2D

var _hovered_area: Area2D = null
var game_data: Dictionary = {}
var session_data: Dictionary = {}
var province_labels: Dictionary = {}

var players: Array = []
var turn_index: int = 0
var province_owners: Dictionary = {}
var game_phase: String = "picking"

@onready var tooltip_panel = $UILayer/TooltipPanel
@onready var name_label = $UILayer/TooltipPanel/VBox/NameLabel
@onready var strength_label = $UILayer/TooltipPanel/VBox/StrengthLabel
@onready var army_label = $UILayer/TooltipPanel/VBox/ArmyLabel
@onready var player_army_label = $UILayer/TopLeftUI/PlayerArmyLabel
@onready var right_panel = $UILayer/RightPanel
@onready var all_players_army_label: RichTextLabel = $UILayer/RightPanel/AllPlayersArmyLabel

var _toast_panel: PanelContainer
var _toast_label: Label
var _is_bot_acting: bool = false

func _ready():
	_is_bot_acting = false # Reset on scene load/return
	_load_game_data()
	_load_or_init_session()

	_setup_map_background()
	_setup_camera()
	_setup_map_hud()
	_setup_toast()

	for child in get_children():
		if child is Area2D:
			child.mouse_entered.connect(_on_area_mouse_entered.bind(child))
			child.mouse_exited.connect(_on_area_mouse_exited.bind(child))
			child.input_event.connect(_on_area_input_event.bind(child))
			
			var province_id = child.name
			if game_data.has(province_id):
				var label = Label.new()
				label.name = "ArmyLabel"
				
				var polygon_node = null
				for grandchild in child.get_children():
					if grandchild is Polygon2D:
						polygon_node = grandchild
						break
				
				if polygon_node:
					var points = polygon_node.polygon
					if points.size() > 0:
						var min_pos = points[0]
						var max_pos = points[0]
						for p in points:
							min_pos.x = min(min_pos.x, p.x)
							min_pos.y = min(min_pos.y, p.y)
							max_pos.x = max(max_pos.x, p.x)
							max_pos.y = max(max_pos.y, p.y)
						var center = (min_pos + max_pos) / 2
						label.position = center - Vector2(30, 15)
						label.size = Vector2(60, 30)

				child.add_child(label)
				province_labels[province_id] = label

	_update_ui()
	_update_colors()


# ── Private setup helpers ──────────────────────────────────────────────────

func _setup_map_background() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.color        = Color(0.055, 0.068, 0.048, 1.0)
	# CRITICAL: do not consume mouse events — Area2D inputs must pass through.
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg)


func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(600.0, 220.0)
	add_child(cam)
	cam.make_current()

	var base_width = 1920.0
	var base_height = 1080.0
	var current_width = get_viewport_rect().size.x
	var current_height = get_viewport_rect().size.y

	var zoom_factor_x = base_width / current_width
	var zoom_factor_y = base_height / current_height
	
	# Use the larger zoom factor to ensure content fits within the smaller dimension
	# and then adjust based on the original 1.5 zoom.
	cam.zoom = Vector2(max(zoom_factor_x, zoom_factor_y) * 1.5, max(zoom_factor_x, zoom_factor_y) * 1.5)


func _setup_map_hud() -> void:
	# TopLeft status card — gold accent marks the active-turn panel.
	TWUIStyle.style_panel_container_accent($UILayer/TopLeftUI)
	TWUIStyle.style_label(player_army_label, true)
	player_army_label.add_theme_font_size_override("font_size", 28)

	# Tooltip card.
	TWUIStyle.style_tooltip(tooltip_panel)
	TWUIStyle.style_label(name_label, true)
	TWUIStyle.style_label(strength_label, false)
	TWUIStyle.style_label(army_label, false)
	tooltip_panel.visible = false

	# Right panel — rebuild with a titled header before the RichText.
	TWUIStyle.style_panel_container_accent(right_panel)
	_build_armies_panel()


func _build_armies_panel() -> void:
	var rtl := all_players_army_label
	right_panel.remove_child(rtl)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(vbox)

	var header_lbl := Label.new()
	header_lbl.text = tr("ARMIES")
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TWUIStyle.style_label_muted(header_lbl)
	vbox.add_child(header_lbl)

	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", TWUIStyle.make_gold_separator_stylebox())
	vbox.add_child(sep)

	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(rtl)
	TWUIStyle.style_rich_text(rtl)
	rtl.add_theme_font_size_override("normal_font_size", 18)

	# --- Add Return to Main Menu Button ---
	var menu_btn := Button.new()
	menu_btn.text = tr("RETURN TO MAIN MENU")
	menu_btn.custom_minimum_size.y = 40
	TWUIStyle.style_button(menu_btn)
	menu_btn.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(menu_btn)
	# --------------------------------------

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _process(_delta: float) -> void:
	if tooltip_panel.visible:
		tooltip_panel.global_position = get_viewport().get_mouse_position() + Vector2(10, 10)

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
	var players_info = [] # Array of {name, is_bot}
	var save_path = GameState.last_save_path
	
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			session_data = json.data
			if session_data.has("players_info"):
				players_info = session_data["players_info"]
				player_names = []
				for p in players_info:
					player_names.append(p["name"])
			elif session_data.has("players") and session_data["players"].size() > 0:
				player_names = session_data["players"]
			
			if session_data.has("game_state"):
				_restore_game_state(session_data["game_state"])
				return
				
	_init_new_game_state(player_names, players_info)

func _init_new_game_state(player_names: Array, players_info: Array = []):
	print("[DEBUG MapScene] Initializing NEW Game State.")
	players = []
	province_owners.clear()
	GameState.capitals.clear()
	GameState.players = [] # CLEAR IT
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
	
	# If we don't have players_info (local multiplayer), create it
	if players_info.is_empty():
		for p_name in player_names:
			players_info.append({"name": p_name, "is_bot": false})
	else:
		# If it's single player, the first one is the human, but we might want to shuffle the rest
		# Actually, let's keep the human first if they are at index 0
		var human = players_info[0]
		var bots = players_info.slice(1)
		bots.shuffle()
		players_info = [human] + bots

	for i in range(num_players):
		var p_info = players_info[i]
		var p_name = p_info["name"]
		var is_bot = p_info.get("is_bot", false)
		
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
			"provinces": [],
			"alive": true,
			"is_bot": is_bot
		})
	
	# Sync GameState
	GameState.players = players
	GameState.province_owners = province_owners
	GameState.current_turn = turn_index
	GameState.game_phase = game_phase
	
	_save_session()

func _restore_game_state(state: Dictionary):
	print("!!! [DEBUG CRITICAL] RESTORE GAME STATE CALLED !!!")
	print("!!! Persistent GameState Players Count: ", GameState.players.size())
	
	if GameState.players.size() > 0:
		print("!!! Using PERSISTENT GameState (Battle Return) !!!")
		players = GameState.players
		province_owners = GameState.province_owners
		turn_index = GameState.current_turn
		game_phase = GameState.game_phase
	else:
		print("!!! Using JSON GameState (Initial Load) !!!")
		players = state.get("players", [])
		province_owners = state.get("province_owners", {})
		GameState.capitals = state.get("capitals", {})
		turn_index = state.get("turn_index", 0)
		game_phase = state.get("game_phase", "picking")
		
		# Sync Global GameState
		GameState.players = players
		GameState.province_owners = province_owners
		GameState.current_turn = turn_index
		GameState.game_phase = game_phase

	for i in range(players.size()):
		var p = players[i]
		print("!!! Player [", i, "]: ", p.name, " | BotFlag: ", p.get("is_bot", "MISSING"), " | Alive: ", p.alive)


func _save_session():
	session_data["game_state"] = {
		"players": players,
		"province_owners": province_owners,
		"capitals": GameState.capitals,
		"turn_index": turn_index,
		"game_phase": game_phase
	}
	var file = FileAccess.open(GameState.last_save_path, FileAccess.WRITE)
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
	if strength == 1: return [tr("Very Easy"), Color("00ff00")]
	elif strength == 2: return [tr("Easy"), Color("90ee90")]
	elif strength == 3: return [tr("Normal"), Color("ffa500")]
	elif strength == 4: return [tr("Strong"), Color("ff4500")]
	elif strength == 5: return [tr("Very Strong"), Color("ff0000")]
	return [tr("Unknown"), Color("ffffff")]

func _update_ui():
	if players.size() > 0:
		var p = players[turn_index]
		print("!!! [DEBUG UI] Current Turn Index: ", turn_index, " | Name: ", p.name, " | IsBot: ", p.get("is_bot", "MISSING"))
		
		player_army_label.text = tr(p["name"]) + tr("'s Turn")
		player_army_label.add_theme_color_override("font_color", Color(p["color"]))

		if all_players_army_label:
			var bbcode = ""
			for i in range(players.size()):
				var pp = players[i]
				var is_alive = GameState._is_player_alive(i)
				var color_hex = Color(pp["color"]).to_html(false)
				var army_val = format_number(int(pp["army"]))
				
				if is_alive:
					# Significantly larger text for the sidebar
					bbcode += "[font_size=28][color=#%s]%s:[/color][/font_size]\n" % [color_hex, pp["name"]]
					bbcode += "[font_size=64][b]%s[/b][/font_size]\n\n" % army_val
				else:
					bbcode += "[color=#888888][s]%s[/s][/color] [font_size=16][i](%s)[/i][/font_size]\n\n" % [pp["name"], tr("ELIMINATED")]
			all_players_army_label.text = bbcode
		
		# Trigger Bot Turn if applicable
		if p.get("is_bot", false) and not _is_bot_acting:
			print("!!! [DEBUG UI] BOT TURN DETECTED - TRIGGERING BOT BRAIN !!!")
			_run_bot_turn()

func _run_bot_turn():
	print("!!! [BOT BRAIN] STARTING LOGIC FOR: ", players[turn_index].name, " (index ", turn_index, ") !!!")
	_is_bot_acting = true
	# Re-verify it is still a bot's turn before starting logic (sanity check)
	var p = players[turn_index]
	if not p.get("is_bot", false):
		print("!!! [BOT BRAIN] ABORTED - Player is NOT a bot: ", p.name)
		_is_bot_acting = false
		return
		
	print("!!! [BOT BRAIN] Waiting for delay... !!!")
	await get_tree().create_timer(1.2).timeout
	
	# Check again after timer (sanity check for turn changes during timer)
	p = players[turn_index]
	if not p.get("is_bot", false):
		print("!!! [BOT BRAIN] ABORTED (After Timer) - Player is NOT a bot: ", p.name)
		_is_bot_acting = false
		return

	print("!!! [BOT BRAIN] Executing Action in phase: ", game_phase, " !!!")
	if game_phase == "picking":
		var selectable_provinces = []
		for child in get_children():
			if child is Area2D and _is_province_selectable(child.name):
				selectable_provinces.append(child.name)
		
		if selectable_provinces.size() > 0:
			var picked = selectable_provinces.pick_random()
			_execute_pick(picked)
	
	elif game_phase == "playing":
		var target_prov = _get_bot_target_province()
		if target_prov != "":
			print("!!! [BOT BRAIN] Attacking Province: ", target_prov, " !!!")
			_execute_attack(target_prov)
		else:
			print("!!! [BOT BRAIN] No targets found. Passing. !!!")
			_is_bot_acting = false # RESET BEFORE TURN CHANGE
			GameState.next_turn()
			turn_index = GameState.current_turn
			_update_ui()
			return

	_is_bot_acting = false

func _execute_pick(province_name: String):
	print("[DEBUG MapScene] Bot Picks: ", province_name)
	province_owners[province_name] = turn_index
	if not GameState.capitals.has(turn_index):
		GameState.capitals[turn_index] = province_name

	GameState.players = players
	GameState.province_owners = province_owners
	GameState.next_turn()
	turn_index = GameState.current_turn
	
	if turn_index == 0:
		game_phase = "playing"
		GameState.game_phase = game_phase
		
	_is_bot_acting = false # RESET BEFORE UI UPDATE
	_update_ui()
	_update_colors()
	_save_session()

func _execute_attack(province_name: String):
	var p_data = game_data.get(province_name, {})
	var city_val = int(p_data.get("initial_army", p_data.get("Initial_Army", 10000)))
	var defender_size_for_ratio = 0
	var def_idx = province_owners.get(province_name, -1)

	if def_idx == -1:
		defender_size_for_ratio = city_val
		GameState.neutral_cities[province_name] = city_val
	else:
		defender_size_for_ratio = int(players[def_idx].get("army", 0))

	var attacker_size = int(players[turn_index].get("army", 0))
	var ratio = float(defender_size_for_ratio) / float(attacker_size) if attacker_size > 0 else 999.0
	var is_blitz = false
	if def_idx == -1 and ratio < 0.85:
		is_blitz = true
	elif def_idx != -1 and ratio < 0.4:
		is_blitz = true

	if is_blitz:
		_instant_conquer(province_name, def_idx, city_val)
		return
	
	# Bot simulation check
	var is_attacker_bot = players[turn_index].get("is_bot", false)
	var is_defender_bot = true if def_idx == -1 else players[def_idx].get("is_bot", false)

	if is_attacker_bot and is_defender_bot:
		# Bot vs Bot (or Bot vs Neutral) can be simulated
		print("[DEBUG MapScene] Bot vs Bot/Neutral: Simulating Battle.")
		GameState.simulate_battle(turn_index, def_idx, province_name, city_val)
		return

	GameState.players = players
	GameState.province_owners = province_owners
	GameState.current_turn = turn_index
	GameState.game_phase = game_phase
	
	var defender_name: String
	if def_idx == -1:
		defender_name = "Neutral"
	else:
		defender_name = str(players[def_idx]["name"])
	
	_show_toast(tr("Bot Battle: %s vs %s") % [players[turn_index]["name"], defender_name])
	GameState.start_battle(turn_index, def_idx, province_name, city_val)

func _get_bot_target_province() -> String:
	var bot_army = players[turn_index].army
	
	var neighbors = []
	for child in get_children():
		if child is Area2D and _is_neighbor(child.name, turn_index):
			neighbors.append(child.name)
	
	if neighbors.is_empty(): return ""

	var neutral_targets = []
	var enemy_non_capitals = []
	var enemy_capitals = []

	for prov in neighbors:
		var owner_idx = province_owners.get(prov, -1)
		if owner_idx == -1:
			neutral_targets.append(prov)
		else:
			# robust capital check
			var cap_name = GameState.capitals.get(owner_idx, GameState.capitals.get(str(owner_idx), ""))
			var is_cap = (cap_name == prov)
			if is_cap: enemy_capitals.append(prov)
			else: enemy_non_capitals.append(prov)

	# PRIORITY 1: Neutral cities are the safest expansion
	if neutral_targets.size() > 0:
		# Pick the one with the smallest army for easiest expansion, or just pick random
		# Let's pick the "Best Neutral" (biggest one we can safely take)
		var best_neutral = ""
		var max_neutral_army = -1
		for prov in neutral_targets:
			var n_army = GameState.neutral_cities.get(prov, 10000)
			# If we can blitz it, that's top priority
			if n_army < bot_army * 0.6:
				return prov
			if n_army < bot_army and n_army > max_neutral_army:
				max_neutral_army = n_army
				best_neutral = prov
		
		if best_neutral != "":
			return best_neutral

	# PRIORITY 2: Weak Enemy Player Check (if no safe neutrals)
	var weak_enemy_provinces = []
	for prov in enemy_non_capitals:
		var owner_idx = province_owners[prov]
		if players[owner_idx].army < bot_army * 0.4: # Only if we can blitz
			return prov
		if players[owner_idx].army < bot_army:
			weak_enemy_provinces.append(prov)
	
	if weak_enemy_provinces.size() > 0:
		return weak_enemy_provinces.pick_random()

	# PRIORITY 3: Capital Attack (if army is massive and no other choice)
	if bot_army > 100000 and enemy_capitals.size() > 0:
		return enemy_capitals.pick_random()
			
	return ""

func _is_province_selectable(province_name: String) -> bool:
	if game_phase != "picking": return false
	if province_owners.has(province_name): return false
	var p = players[turn_index]
	var p_data = game_data.get(province_name, {})
	if p_data.is_empty(): return false
	var region_key = str(players.size())
	var p_region = p_data.get("regions", {}).get(region_key, "")
	var p_region_assigned = p.get("region", "Any")
	if p_region_assigned != "Any" and p_region != p_region_assigned: return false
	var adjacencies = p_data.get("adjacencies", [])
	for adj in adjacencies:
		if province_owners.has(adj) and province_owners[adj] != turn_index: return false
	return true

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, area: Area2D):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var p = players[turn_index]
		var bot_flag = p.get("is_bot", false)
		print("!!! [INPUT] Click on ", area.name, " | Current Turn: ", p.name, " | Index: ", turn_index, " | IsBot: ", bot_flag, " | BotActing: ", _is_bot_acting, " !!!")
		
		if bot_flag or _is_bot_acting:
			print("!!! [INPUT] BLOCKING CLICK - Not your turn commander! !!!")
			return
			
		var province_name = area.name
		
		if game_phase == "picking":
			if not _is_province_selectable(province_name): return
			
			province_owners[province_name] = turn_index
			if not GameState.capitals.has(turn_index):
				GameState.capitals[turn_index] = province_name

			GameState.players = players
			GameState.province_owners = province_owners
			GameState.next_turn()
			turn_index = GameState.current_turn
			
			if turn_index == 0:
				game_phase = "playing"
				GameState.game_phase = game_phase
				
			_update_ui()
			_update_colors()
			_save_session()
		elif game_phase == "playing":
			if province_owners.get(province_name, -1) == turn_index: return
			
			var p_data = game_data.get(province_name, {})
			if not _is_neighbor(province_name, turn_index):
				_show_toast(tr("MUST_ATTACK_ADJACENT"))
				return
				
			var city_val = int(p_data.get("initial_army", p_data.get("Initial_Army", 10000)))
			var defender_size_for_ratio = 0
			var def_idx = province_owners.get(province_name, -1)

			if def_idx == -1:
				defender_size_for_ratio = city_val
				GameState.neutral_cities[province_name] = city_val
			else:
				defender_size_for_ratio = int(players[def_idx].get("army", 0))

			var attacker_size = int(players[turn_index].get("army", 0))
			var ratio = float(defender_size_for_ratio) / float(attacker_size) if attacker_size > 0 else 999.0
			var is_blitz = false
			if def_idx == -1 and ratio < 0.85:
				is_blitz = true
			elif def_idx != -1 and ratio < 0.4:
				is_blitz = true

			if is_blitz:
				_instant_conquer(province_name, def_idx, city_val)
				return
			
			GameState.players = players
			GameState.province_owners = province_owners
			GameState.current_turn = turn_index
			GameState.game_phase = game_phase
			
			var defender_name: String
			if def_idx == -1:
				defender_name = "Neutral"
			else:
				defender_name = str(players[def_idx]["name"])
			_show_toast(tr("Battle: %s vs %s") % [players[turn_index]["name"], defender_name])
			GameState.start_battle(turn_index, def_idx, province_name, city_val)

func _instant_conquer(province_name: String, def_idx: int, city_val: int) -> void:
	var attacker_name = players[turn_index]["name"]
	_show_toast(tr("BLITZ! %s instantly conquers %s") % [attacker_name, province_name])
	
	province_owners[province_name] = turn_index
	var bonus = int(city_val * 0.1)
	players[turn_index]["army"] += bonus
	
	if def_idx != -1:
		players[def_idx]["army"] -= bonus
		if players[def_idx]["army"] < 0: players[def_idx]["army"] = 0

		var is_cap = (GameState.capitals.get(def_idx) == province_name)
		if is_cap:
			players[def_idx]["alive"] = false
			# Neutralize remaining lands
			var to_clear = []
			for p in province_owners:
				if province_owners[p] == def_idx and p != province_name:
					to_clear.append(p)
			for p in to_clear:
				province_owners.erase(p)

	GameState.players = players
	GameState.province_owners = province_owners
	_is_bot_acting = false # Reset flag before turn change
	GameState.next_turn()
	turn_index = GameState.current_turn
		
	_update_ui()
	_update_colors()
	_save_session()

func _is_neighbor(province_name: String, player_idx: int) -> bool:
	if int(province_owners.get(province_name, -1)) == player_idx: return false
	var p_data = game_data.get(province_name, {})
	var adjacencies = p_data.get("adjacencies", [])
	for adj in adjacencies:
		if int(province_owners.get(adj, -1)) == player_idx:
			return true
	return false

func _on_area_mouse_entered(area: Area2D):
	var province_name = area.name
	if game_phase == "playing" and not _is_neighbor(province_name, turn_index):
		return

	_hovered_area = area
	_update_colors()

	if game_data.has(province_name):
		var data = game_data[province_name]
		var tooltip_owner = "None"
		if province_owners.has(province_name):
			tooltip_owner = players[int(province_owners[province_name])]["name"]
		
		name_label.text = tr("Name: ") + province_name + " (" + tooltip_owner + ")"
		
		var strength_val = int(data.get("strength", data.get("Strength", 0)))
		var strength_info = get_strength_text_and_color(strength_val)
		strength_label.text = tr("Strength: ") + strength_info[0]
		strength_label.add_theme_color_override("font_color", strength_info[1])
		
		var army_val = int(data.get("initial_army", data.get("Initial_Army", 0)))
		army_label.text = tr("Army Size: ") + format_number(army_val)
	else:
		name_label.text = tr("Name: ") + province_name
		strength_label.text = tr("Strength: ") + "?"
		strength_label.add_theme_color_override("font_color", Color.WHITE)
		army_label.text = tr("Army Size: ") + "?"

	tooltip_panel.visible = true


func _setup_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.visible = false
	_toast_panel.layout_mode = 1
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 0.0
	_toast_panel.anchor_bottom = 0.0
	_toast_panel.offset_left = -320
	_toast_panel.offset_right = 320
	_toast_panel.offset_top = 14
	_toast_panel.offset_bottom = 54
	TWUIStyle.style_panel_container(_toast_panel)
	$UILayer.add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_toast_label.custom_minimum_size = Vector2(1, 1)
	_toast_panel.add_child(_toast_label)
	TWUIStyle.style_label(_toast_label, true)


func _show_toast(text: String) -> void:
	if _toast_panel == null or _toast_label == null:
		return

	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(1.25)
	tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func():
		_toast_panel.visible = false
	)

func _on_area_mouse_exited(area: Area2D):
	if _hovered_area == area:
		_hovered_area = null
		tooltip_panel.visible = false
	_update_colors()

func _update_army_labels():
	for province_id in province_labels:
		var label = province_labels[province_id]
		if not is_instance_valid(label):
			continue

		var army = game_data[province_id].initial_army
		label.text = str(int(army / 1000))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var owner_idx = province_owners.get(province_id, -1)
		if owner_idx != -1:
			var player_color = Color(players[owner_idx].color)
			label.add_theme_color_override("font_color", player_color.lerp(Color.BLACK, 0.5))

		else:
			label.add_theme_color_override("font_color", Color.BLACK)


func _update_colors():
	for child in get_children():
		if child is Area2D:
			var target_color = Color(0.7, 0.7, 0.7)

			if game_phase == "picking":
				var selectable = _is_province_selectable(child.name)
				if selectable:
					target_color = Color(0.85, 0.85, 0.5)
				else:
					target_color = Color(0.3, 0.3, 0.3)
				
				var is_owned = province_owners.has(child.name)
				if is_owned:
					var owner_idx = int(province_owners[child.name])
					var raw_col = players[owner_idx]["color"]
					if typeof(raw_col) == TYPE_STRING:
						target_color = Color(raw_col)
					else:
						target_color = raw_col

				if child == _hovered_area:
					target_color = target_color.lightened(0.3)
			else:
				var is_owned = province_owners.has(child.name)
				var owner_idx = int(province_owners.get(child.name, -1))
				var is_my_own = is_owned and owner_idx == turn_index
				var is_neighboring = _is_neighbor(child.name, turn_index)
				var is_capital = false
				
				if is_owned:
					# Robust capital lookup (handles JSON int/string key conversion)
					var cap_name = GameState.capitals.get(owner_idx, GameState.capitals.get(str(owner_idx), ""))
					is_capital = (cap_name == child.name)

					var raw_col = players[owner_idx]["color"]
					if typeof(raw_col) == TYPE_STRING:
						target_color = Color(raw_col)
					else:
						target_color = raw_col
						
					if is_capital:
						target_color = target_color.darkened(0.6)
				elif is_neighboring:
					target_color = Color.GRAY
				else:
					target_color = Color(0.9, 0.9, 0.9)

				if child == _hovered_area and is_neighboring and not is_my_own:
					target_color = Color.DARK_GRAY

			for node in child.get_children():
				if node is Polygon2D:
					node.color = target_color
	_update_army_labels()
