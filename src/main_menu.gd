extends Control

@onready var main_menu_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/MainMenuPage
@onready var single_player_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/SinglePlayerPage
@onready var new_session_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/NewSessionPage
@onready var new_local_session_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage
@onready var new_online_session_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/NewOnlineSessionPage
@onready var load_session_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/LoadSessionPage
@onready var settings_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/SettingsPage
@onready var resolution_option: OptionButton = $CenterContainer/MainMenuCard/CardContent/SettingsPage/ResolutionOption
@onready var fullscreen_check: CheckButton = $CenterContainer/MainMenuCard/CardContent/SettingsPage/FullscreenCheck
@onready var players_container: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/PlayersContainer
@onready var add_player_button: Button = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/AddPlayerButton
@onready var world_name_input: LineEdit = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/WorldNameInput

@onready var commander_name_input: LineEdit = $CenterContainer/MainMenuCard/CardContent/SinglePlayerPage/PlayerNameInput
@onready var bot_count_slider: HSlider = $CenterContainer/MainMenuCard/CardContent/SinglePlayerPage/BotCountSlider
@onready var bot_count_label: Label = $CenterContainer/MainMenuCard/CardContent/SinglePlayerPage/BotCountLabel

@onready var main_menu_card: PanelContainer = $CenterContainer/MainMenuCard

const MIN_PLAYERS := 2
const MAX_PLAYERS := 5
const SAVES_DIR := "user://saves/"

const HISTORICAL_GENERALS = [
	"Napoleon Bonaparte", "Alexander the Great", "Julius Caesar", "Hannibal Barca", 
	"Genghis Khan", "Sun Tzu", "Gustavus Adolphus", "George S. Patton", 
	"Erwin Rommel", "Khalid ibn al-Walid", "Subutai", "Duke of Wellington"
]

const RESOLUTIONS = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_absolute(SAVES_DIR)
		
	$CenterContainer/MainMenuCard/CardContent/MainMenuPage/SinglePlayerButton.pressed.connect(_on_single_player_pressed)
	$CenterContainer/MainMenuCard/CardContent/MainMenuPage/NewSessionButton.pressed.connect(_on_new_session_pressed)
	$CenterContainer/MainMenuCard/CardContent/MainMenuPage/LoadSessionButton.pressed.connect(_on_load_session_pressed)
	$CenterContainer/MainMenuCard/CardContent/MainMenuPage/SettingsButton.pressed.connect(_on_settings_pressed)

	$CenterContainer/MainMenuCard/CardContent/SinglePlayerPage/StartSinglePlayerButton.pressed.connect(_on_start_single_player_pressed)
	$CenterContainer/MainMenuCard/CardContent/SinglePlayerPage/BackButton.pressed.connect(_on_single_player_back_pressed)
	bot_count_slider.value_changed.connect(_on_bot_count_changed)
	_on_bot_count_changed(bot_count_slider.value)

	$CenterContainer/MainMenuCard/CardContent/NewSessionPage/NewLocalSessionButton.pressed.connect(_on_new_local_session_pressed)
	$CenterContainer/MainMenuCard/CardContent/NewSessionPage/NewOnlineSessionButton.pressed.connect(_on_new_online_session_pressed)
	$CenterContainer/MainMenuCard/CardContent/NewSessionPage/BackButton.pressed.connect(_on_new_session_back_pressed)

	$CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/AddPlayerButton.pressed.connect(_on_add_player_pressed)
	$CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/CreateWorldButton.pressed.connect(_on_create_world_pressed)
	$CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/BackButton.pressed.connect(_on_new_local_session_back_pressed)
	$CenterContainer/MainMenuCard/CardContent/NewOnlineSessionPage/BackButton.pressed.connect(_on_new_online_session_back_pressed)

	$CenterContainer/MainMenuCard/CardContent/LoadSessionPage/BackButton.pressed.connect(_on_load_session_back_pressed)
	$CenterContainer/MainMenuCard/CardContent/SettingsPage/BackButton.pressed.connect(_on_settings_back_pressed)

	_setup_settings_page()
	_update_add_player_button_state()
	_show_page(main_menu_page)
	_connect_initial_remove_buttons()
	_apply_shared_style()


func _show_page(target_page: VBoxContainer) -> void:
	var pages: Array[VBoxContainer] = [
		main_menu_page,
		single_player_page,
		new_session_page,
		new_local_session_page,
		new_online_session_page,
		load_session_page,
		settings_page,
	]

	for page in pages:
		page.visible = page == target_page


func _on_single_player_pressed() -> void:
	_show_page(single_player_page)

func _on_single_player_back_pressed() -> void:
	_show_page(main_menu_page)

func _on_bot_count_changed(val: float) -> void:
	bot_count_label.text = tr("Number of Bots (%d)") % int(val)

func _on_start_single_player_pressed() -> void:
	var human_name = commander_name_input.text.strip_edges()
	if human_name == "": human_name = "Commander"
	
	var bot_count = int(bot_count_slider.value)
	var player_names: Array[String] = [human_name]
	var bots: Array[String] = []
	
	var available_bots = HISTORICAL_GENERALS.duplicate()
	available_bots.shuffle()
	
	for i in range(bot_count):
		bots.append(available_bots.pop_back())
	
	# Create session data with bot info
	var world_name = "SinglePlayer_World"
	var safe_name = world_name.validate_filename()
	var save_path = SAVES_DIR + safe_name + ".json"

	# We'll use a special structure for session data to indicate bots
	# For now, let's just pass the names and we'll handle bot assignment in map_scene
	var session_players = []
	session_players.append({"name": human_name, "is_bot": false})
	for b_name in bots:
		session_players.append({"name": b_name, "is_bot": true})

	var session_data := {
		"world_name": world_name,
		"players_info": session_players, # New field for detailed player info
		"players": [human_name] + bots, # Compatibility with existing code
	}

	var save_file := FileAccess.open(save_path, FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(session_data, "\t"))
		save_file.close()
	
	GameState.last_save_path = save_path
	get_tree().change_scene_to_file("res://map_scene.tscn")


func _on_new_session_pressed() -> void:
	_show_page(new_session_page)


func _on_load_session_pressed() -> void:
	_refresh_load_session_page()
	_show_page(load_session_page)


func _refresh_load_session_page() -> void:
	# Clear previous list
	for child in load_session_page.get_children():
		if child is Button and child.text != "← BACK":
			child.queue_free()
		elif child is ScrollContainer:
			child.queue_free()
			
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 200
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	load_session_page.add_child(scroll)
	load_session_page.move_child(scroll, 1) # Put between title and back button
	
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	
	var dir = DirAccess.open(SAVES_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var btn := Button.new()
				btn.text = file_name.replace(".json", "")
				TWUIStyle.style_button(btn)
				btn.pressed.connect(_on_save_selected.bind(SAVES_DIR + file_name))
				list.add_child(btn)
			file_name = dir.get_next()
	else:
		var lbl := Label.new()
		lbl.text = tr("No saves found")
		TWUIStyle.style_label_muted(lbl)
		list.add_child(lbl)

func _on_save_selected(path: String) -> void:
	GameState.last_save_path = path
	get_tree().change_scene_to_file("res://map_scene.tscn")

func _setup_settings_page() -> void:
	print("[DEBUG MainMenu] Setting up Settings Page...")
	# Populate resolutions
	resolution_option.clear()
	for res in RESOLUTIONS:
		resolution_option.add_item("%dx%d" % [res.x, res.y])
	
	# Select current resolution if it matches one in the list
	var current_res = get_window().size
	var found_match = false
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == current_res:
			resolution_option.selected = i
			found_match = true
			break
	
	if not found_match:
		# Default to something sensible if current size isn't in list
		resolution_option.selected = 0
		print("[DEBUG MainMenu] Current resolution not in list, defaulting to index 0")
	
	# Set fullscreen state
	var current_mode = DisplayServer.window_get_mode()
	fullscreen_check.button_pressed = (current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	# Connect signals
	if not resolution_option.item_selected.is_connected(_on_resolution_selected):
		resolution_option.item_selected.connect(_on_resolution_selected)
	if not fullscreen_check.toggled.is_connected(_on_fullscreen_toggled):
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)

func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size(): return
	var res = RESOLUTIONS[index]
	print("[DEBUG MainMenu] Changing resolution to: ", res)
	
	var win = get_window()
	# Update the content scale size - this changes how the game internally renders 
	# and is safe even if the OS window itself can't be resized (e.g. in-editor)
	win.content_scale_size = res
	
	# Only attempt OS window resizing if we're not embedded in the editor
	if not win.is_embedded():
		win.size = res
		# Center the window
		var screen_id = win.current_screen
		var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
		win.position = screen_rect.position + (screen_rect.size - Vector2i(res)) / 2
	else:
		print("[DEBUG MainMenu] Window is embedded (likely running in Editor), skipping OS window resize.")

func _on_fullscreen_toggled(is_pressed: bool) -> void:
	print("[DEBUG MainMenu] Fullscreen toggled: ", is_pressed)
	var win = get_window()
	
	if is_pressed:
		win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		win.mode = Window.MODE_WINDOWED
		# Re-apply resolution to ensure it's correct after leaving fullscreen
		_on_resolution_selected(resolution_option.selected)

func _on_settings_pressed() -> void:
	_show_page(settings_page)


func _on_new_local_session_pressed() -> void:
	_show_page(new_local_session_page)
	_update_add_player_button_state()


func _on_new_online_session_pressed() -> void:
	_show_page(new_online_session_page)


func _on_new_session_back_pressed() -> void:
	_show_page(main_menu_page)


func _on_new_local_session_back_pressed() -> void:
	_show_page(new_session_page)


func _on_add_player_pressed() -> void:
	var current_players := _get_player_count()
	if current_players >= MAX_PLAYERS:
		_update_add_player_button_state()
		return

	var player_row := HBoxContainer.new()
	var player_input := LineEdit.new()
	player_input.name = "PlayerInput"
	player_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_input.text = "Player%d" % [current_players + 1]

	var remove_button := Button.new()
	remove_button.name = "RemoveButton"
	remove_button.text = tr("Remove")
	remove_button.pressed.connect(_on_remove_player_pressed.bind(player_row))

	player_row.add_child(player_input)
	player_row.add_child(remove_button)
	players_container.add_child(player_row)
	TWUIStyle.style_line_edit(player_input)
	TWUIStyle.style_button(remove_button)
	_update_add_player_button_state()


func _on_create_world_pressed() -> void:
	var players: Array[String] = []
	for player_entry in players_container.get_children():
		if player_entry is LineEdit:
			players.append((player_entry as LineEdit).text)
		elif player_entry is HBoxContainer:
			var player_input := (player_entry as HBoxContainer).get_node_or_null("PlayerInput") as LineEdit
			if player_input != null:
				players.append(player_input.text)

	var world_name = world_name_input.text.strip_edges()
	if world_name == "":
		world_name = "unnamed_world"
		
	var safe_name = world_name.validate_filename()
	var save_path = SAVES_DIR + safe_name + ".json"

	var session_data := {
		"world_name": world_name,
		"players": players,
	}

	var save_file := FileAccess.open(save_path, FileAccess.WRITE)
	if save_file == null:
		push_error("Failed to save session data to %s" % save_path)
		return

	save_file.store_string(JSON.stringify(session_data, "\t"))
	save_file.close()
	
	GameState.last_save_path = save_path
	get_tree().change_scene_to_file("res://map_scene.tscn")


func _on_remove_player_pressed(player_row: HBoxContainer) -> void:
	if _get_player_count() <= MIN_PLAYERS:
		_update_add_player_button_state()
		return

	if player_row.get_parent() == players_container:
		players_container.remove_child(player_row)
		player_row.queue_free()

	_update_add_player_button_state()


func _connect_initial_remove_buttons() -> void:
	# The initial player rows are authored in `main_menu.tscn`.
	# Their remove buttons need connections like the dynamically added ones.
	for child in players_container.get_children():
		if child is HBoxContainer:
			var row := child as HBoxContainer
			var remove_btn := row.get_node_or_null("RemoveButton") as Button
			if remove_btn:
				remove_btn.pressed.connect(_on_remove_player_pressed.bind(row))


func _apply_shared_style() -> void:
	# Gold left-accent card replaces generic rounded box.
	TWUIStyle.style_panel_container_accent(main_menu_card)

	# Build game title header at the top of CardContent.
	_build_game_header()

	# Hide the redundant "Main Menu" title — TURKEY WARS header replaces it.
	var main_title_lbl = $CenterContainer/MainMenuCard/CardContent/MainMenuPage/TitleLabel
	if main_title_lbl:
		main_title_lbl.visible = false

	# Sub-page titles → small all-caps section headers.
	for lbl in [
		$CenterContainer/MainMenuCard/CardContent/SinglePlayerPage/TitleLabel,
		$CenterContainer/MainMenuCard/CardContent/NewSessionPage/TitleLabel,
		$CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/TitleLabel,
		$CenterContainer/MainMenuCard/CardContent/NewOnlineSessionPage/TitleLabel,
		$CenterContainer/MainMenuCard/CardContent/LoadSessionPage/TitleLabel,
		$CenterContainer/MainMenuCard/CardContent/SettingsPage/TitleLabel,
		$CenterContainer/MainMenuCard/CardContent/SettingsPage/ResolutionLabel,
		$CenterContainer/MainMenuCard/CardContent/SettingsPage/FullscreenLabel,
	]:
		if lbl:
			TWUIStyle.style_label_muted(lbl)
			lbl.text = tr(lbl.text).to_upper()

	# Navigation buttons — uppercase text, taller hit area, gold hover bar.
	for btn in [
		$CenterContainer/MainMenuCard/CardContent/MainMenuPage/SinglePlayerButton,
		$CenterContainer/MainMenuCard/CardContent/MainMenuPage/NewSessionButton,
		$CenterContainer/MainMenuCard/CardContent/MainMenuPage/LoadSessionButton,
		$CenterContainer/MainMenuCard/CardContent/MainMenuPage/SettingsButton,
		$CenterContainer/MainMenuCard/CardContent/NewSessionPage/NewLocalSessionButton,
		$CenterContainer/MainMenuCard/CardContent/NewSessionPage/NewOnlineSessionButton,
		$CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/AddPlayerButton,
	]:
		if btn:
			TWUIStyle.style_button(btn)
			btn.custom_minimum_size = Vector2(0, 46)
			btn.text = tr(btn.text).to_upper()

	# Back buttons — dimmer presence, same hover mechanic.
	for btn in [
		$CenterContainer/MainMenuCard/CardContent/SinglePlayerPage/BackButton,
		$CenterContainer/MainMenuCard/CardContent/NewSessionPage/BackButton,
		$CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/BackButton,
		$CenterContainer/MainMenuCard/CardContent/NewOnlineSessionPage/BackButton,
		$CenterContainer/MainMenuCard/CardContent/LoadSessionPage/BackButton,
		$CenterContainer/MainMenuCard/CardContent/SettingsPage/BackButton,
	]:
		if btn:
			TWUIStyle.style_button(btn)
			btn.custom_minimum_size = Vector2(0, 38)
			btn.modulate.a = 0.6
			btn.text = tr("← BACK")

	# Primary action button — gold accent, prominent.
	var deploy_btn = $CenterContainer/MainMenuCard/CardContent/SinglePlayerPage/StartSinglePlayerButton
	if deploy_btn:
		TWUIStyle.style_button_accent(deploy_btn)
		deploy_btn.custom_minimum_size = Vector2(0, 50)
		deploy_btn.text = tr("DEPLOY TO WAR")

	var create_btn = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/CreateWorldButton
	if create_btn:
		TWUIStyle.style_button_accent(create_btn)
		create_btn.custom_minimum_size = Vector2(0, 50)
		create_btn.text = tr("DEPLOY WORLD")

	# Small form labels.
	for lbl in [
		$CenterContainer/MainMenuCard/CardContent/SinglePlayerPage/PlayerNameLabel,
		$CenterContainer/MainMenuCard/CardContent/SinglePlayerPage/BotCountLabel
	]:
		if lbl:
			TWUIStyle.style_label_muted(lbl)
			lbl.text = tr(lbl.text).to_upper()

	var world_lbl = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/WorldNameLabel
	if world_lbl:
		TWUIStyle.style_label_muted(world_lbl)
		world_lbl.text = tr("WORLD NAME")

	var players_lbl = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/PlayersLabel
	if players_lbl:
		TWUIStyle.style_label_muted(players_lbl)
		players_lbl.text = tr("COMMANDERS")

	# WorldName LineEdit.
	if world_name_input:
		TWUIStyle.style_line_edit(world_name_input)

	# Style OptionButton and CheckButton
	if resolution_option:
		resolution_option.add_theme_stylebox_override("normal", TWUIStyle.make_surface_stylebox())
		resolution_option.add_theme_stylebox_override("hover", TWUIStyle.make_button_hover())
		resolution_option.add_theme_stylebox_override("pressed", TWUIStyle.make_button_pressed())
		resolution_option.add_theme_color_override("font_color", TWUIStyle.COLOR_TEXT)

	if fullscreen_check:
		fullscreen_check.add_theme_color_override("font_color", TWUIStyle.COLOR_TEXT)
		fullscreen_check.add_theme_color_override("font_pressed_color", TWUIStyle.COLOR_GOLD)

	# Initial player-row LineEdits and remove buttons.
	for child in players_container.get_children():
		if child is HBoxContainer:
			var row := child as HBoxContainer
			var li := row.get_node_or_null("PlayerInput") as LineEdit
			var rb := row.get_node_or_null("RemoveButton") as Button
			if li:
				TWUIStyle.style_line_edit(li)
			if rb:
				TWUIStyle.style_button(rb)
				rb.custom_minimum_size = Vector2(36, 36)


func _build_game_header() -> void:
	var card_content := $CenterContainer/MainMenuCard/CardContent
	if card_content.get_node_or_null("GameHeader"):
		return  # Already inserted — guard against double-calls.

	var header := VBoxContainer.new()
	header.name = "GameHeader"
	header.add_theme_constant_override("separation", 5)
	card_content.add_child(header)
	card_content.move_child(header, 0)

	# "TURKEY WARS" game title.
	var title_lbl := Label.new()
	title_lbl.text = tr("TURKEY WARS")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TWUIStyle.style_game_title(title_lbl)
	header.add_child(title_lbl)

	# Subtitle.
	var sub_lbl := Label.new()
	sub_lbl.text = tr("GRAND STRATEGY")
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TWUIStyle.style_label_muted(sub_lbl)
	header.add_child(sub_lbl)

	# Thin gold separator line.
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", TWUIStyle.make_gold_separator_stylebox())
	sep.add_theme_constant_override("separation", 2)
	header.add_child(sep)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	header.add_child(spacer)


func _get_player_count() -> int:
	return players_container.get_child_count()


func _update_add_player_button_state() -> void:
	add_player_button.disabled = _get_player_count() >= MAX_PLAYERS


func _on_new_online_session_back_pressed() -> void:
	_show_page(new_session_page)


func _on_load_session_back_pressed() -> void:
	_show_page(main_menu_page)


func _on_settings_back_pressed() -> void:
	_show_page(main_menu_page)
