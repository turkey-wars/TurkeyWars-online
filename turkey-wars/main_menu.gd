extends Control

@onready var main_menu_page: VBoxContainer = $CenterContainer/MainMenuPage
@onready var new_session_page: VBoxContainer = $CenterContainer/NewSessionPage
@onready var new_local_session_page: VBoxContainer = $CenterContainer/NewLocalSessionPage
@onready var new_online_session_page: VBoxContainer = $CenterContainer/NewOnlineSessionPage
@onready var load_session_page: VBoxContainer = $CenterContainer/LoadSessionPage
@onready var settings_page: VBoxContainer = $CenterContainer/SettingsPage
@onready var players_container: VBoxContainer = $CenterContainer/NewLocalSessionPage/PlayersContainer
@onready var add_player_button: Button = $CenterContainer/NewLocalSessionPage/AddPlayerButton
@onready var world_name_input: LineEdit = $CenterContainer/NewLocalSessionPage/WorldNameInput

const MIN_PLAYERS := 2
const MAX_PLAYERS := 5
const LOCAL_SESSION_SAVE_PATH := "user://local_session.json"


func _ready() -> void:
	$CenterContainer/MainMenuPage/NewSessionButton.pressed.connect(_on_new_session_pressed)
	$CenterContainer/MainMenuPage/LoadSessionButton.pressed.connect(_on_load_session_pressed)
	$CenterContainer/MainMenuPage/SettingsButton.pressed.connect(_on_settings_pressed)

	$CenterContainer/NewSessionPage/NewLocalSessionButton.pressed.connect(_on_new_local_session_pressed)
	$CenterContainer/NewSessionPage/NewOnlineSessionButton.pressed.connect(_on_new_online_session_pressed)
	$CenterContainer/NewSessionPage/BackButton.pressed.connect(_on_new_session_back_pressed)

	$CenterContainer/NewLocalSessionPage/AddPlayerButton.pressed.connect(_on_add_player_pressed)
	$CenterContainer/NewLocalSessionPage/CreateWorldButton.pressed.connect(_on_create_world_pressed)
	$CenterContainer/NewLocalSessionPage/BackButton.pressed.connect(_on_new_local_session_back_pressed)
	$CenterContainer/NewOnlineSessionPage/BackButton.pressed.connect(_on_new_online_session_back_pressed)

	$CenterContainer/LoadSessionPage/BackButton.pressed.connect(_on_load_session_back_pressed)
	$CenterContainer/SettingsPage/BackButton.pressed.connect(_on_settings_back_pressed)

	_update_add_player_button_state()
	_show_page(main_menu_page)


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
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_player_pressed.bind(player_row))

	player_row.add_child(player_input)
	player_row.add_child(remove_button)
	players_container.add_child(player_row)
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

