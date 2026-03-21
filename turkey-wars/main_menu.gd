extends Control

@onready var main_menu_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/MainMenuPage
@onready var new_session_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/NewSessionPage
@onready var new_local_session_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage
@onready var new_online_session_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/NewOnlineSessionPage
@onready var load_session_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/LoadSessionPage
@onready var settings_page: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/SettingsPage
@onready var players_container: VBoxContainer = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/PlayersContainer
@onready var add_player_button: Button = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/AddPlayerButton
@onready var world_name_input: LineEdit = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/WorldNameInput

@onready var main_menu_card: PanelContainer = $CenterContainer/MainMenuCard

const MIN_PLAYERS := 2
const MAX_PLAYERS := 5
const LOCAL_SESSION_SAVE_PATH := "user://local_session.json"


func _ready() -> void:
	$CenterContainer/MainMenuCard/CardContent/MainMenuPage/NewSessionButton.pressed.connect(_on_new_session_pressed)
	$CenterContainer/MainMenuCard/CardContent/MainMenuPage/LoadSessionButton.pressed.connect(_on_load_session_pressed)
	$CenterContainer/MainMenuCard/CardContent/MainMenuPage/SettingsButton.pressed.connect(_on_settings_pressed)

	$CenterContainer/MainMenuCard/CardContent/NewSessionPage/NewLocalSessionButton.pressed.connect(_on_new_local_session_pressed)
	$CenterContainer/MainMenuCard/CardContent/NewSessionPage/NewOnlineSessionButton.pressed.connect(_on_new_online_session_pressed)
	$CenterContainer/MainMenuCard/CardContent/NewSessionPage/BackButton.pressed.connect(_on_new_session_back_pressed)

	$CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/AddPlayerButton.pressed.connect(_on_add_player_pressed)
	$CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/CreateWorldButton.pressed.connect(_on_create_world_pressed)
	$CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/BackButton.pressed.connect(_on_new_local_session_back_pressed)
	$CenterContainer/MainMenuCard/CardContent/NewOnlineSessionPage/BackButton.pressed.connect(_on_new_online_session_back_pressed)

	$CenterContainer/MainMenuCard/CardContent/LoadSessionPage/BackButton.pressed.connect(_on_load_session_back_pressed)
	$CenterContainer/MainMenuCard/CardContent/SettingsPage/BackButton.pressed.connect(_on_settings_back_pressed)

	_update_add_player_button_state()
	_show_page(main_menu_page)
	_connect_initial_remove_buttons()
	_apply_shared_style()


func _show_page(target_page: VBoxContainer) -> void:
	var pages: Array[VBoxContainer] = [
		main_menu_page,
		new_session_page,
		new_local_session_page,
		new_online_session_page,
		load_session_page,
		settings_page,
	]

	for page in pages:
		page.visible = page == target_page


func _on_new_session_pressed() -> void:
	_show_page(new_session_page)


func _on_load_session_pressed() -> void:
	if FileAccess.file_exists(LOCAL_SESSION_SAVE_PATH):
		get_tree().change_scene_to_file("res://map_scene.tscn")
	else:
		push_error("No save file found!")


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
	remove_button.text = "Remove"
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

	var session_data := {
		"world_name": world_name_input.text,
		"players": players,
	}

	var save_file := FileAccess.open(LOCAL_SESSION_SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("Failed to save session data to %s" % LOCAL_SESSION_SAVE_PATH)
		return

	save_file.store_string(JSON.stringify(session_data, "\t"))
	save_file.close()
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
		$CenterContainer/MainMenuCard/CardContent/NewSessionPage/TitleLabel,
		$CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/TitleLabel,
		$CenterContainer/MainMenuCard/CardContent/NewOnlineSessionPage/TitleLabel,
		$CenterContainer/MainMenuCard/CardContent/LoadSessionPage/TitleLabel,
		$CenterContainer/MainMenuCard/CardContent/SettingsPage/TitleLabel,
	]:
		if lbl:
			TWUIStyle.style_label_muted(lbl)
			lbl.text = lbl.text.to_upper()

	# Navigation buttons — uppercase text, taller hit area, gold hover bar.
	for btn in [
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
			btn.text = btn.text.to_upper()

	# Back buttons — dimmer presence, same hover mechanic.
	for btn in [
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
			btn.text = "← BACK"

	# Primary action button — gold accent, prominent.
	var create_btn = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/CreateWorldButton
	if create_btn:
		TWUIStyle.style_button_accent(create_btn)
		create_btn.custom_minimum_size = Vector2(0, 50)
		create_btn.text = "DEPLOY WORLD"

	# Small form labels.
	var world_lbl = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/WorldNameLabel
	if world_lbl:
		TWUIStyle.style_label_muted(world_lbl)
		world_lbl.text = "WORLD NAME"

	var players_lbl = $CenterContainer/MainMenuCard/CardContent/NewLocalSessionPage/PlayersLabel
	if players_lbl:
		TWUIStyle.style_label_muted(players_lbl)
		players_lbl.text = "COMMANDERS"

	# WorldName LineEdit.
	if world_name_input:
		TWUIStyle.style_line_edit(world_name_input)

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
	title_lbl.text = "TURKEY WARS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TWUIStyle.style_game_title(title_lbl)
	header.add_child(title_lbl)

	# Subtitle.
	var sub_lbl := Label.new()
	sub_lbl.text = "GRAND STRATEGY"
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
