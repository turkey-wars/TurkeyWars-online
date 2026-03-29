extends Node

# ─────────────────────────────────────────────────────────────────────────────
#  NetworkManager  —  WebSocket relay-based turn-passing multiplayer
#
#  Architecture:
#    • All peers connect to a shared Deno relay server via WebSocket.
#    • Host (peer_id 1) is always player_index 0 and drives all game logic.
#    • Clients push their actions to the host; host applies + re-broadcasts
#      the full serialized GameState to every peer.
#    • Scene transitions are coordinated via relay messages so all peers
#      change scene together.
# ─────────────────────────────────────────────────────────────────────────────

## URL of the deployed Deno relay.  Update this after deploying relay/main.ts.
const RELAY_URL: String     = "wss://turkeywars.turkey-wars.deno.net"
const DEFAULT_PORT: int     = 7777   # unused; kept so call-sites don't break
const MAX_PEERS: int        = 4

var is_online:        bool   = false
var is_host:          bool   = false
var my_player_index:  int    = 0
var room_code:        String = ""

## Array of {name, peer_id, player_index} — same shape as before.
var lobby_players: Array = []

signal lobby_changed()
signal game_started()
signal state_applied()
signal connection_failed(reason: String)
signal peer_disconnected_in_game()
signal room_created(code: String)   # emitted on host once room is ready

var _ws: WebSocketPeer     = null
var _peer_id: int          = 0       # our relay peer-id (host = 1)
var _pending_name: String  = ""
var _on_open_cb: Callable  = Callable()
var _ws_was_open: bool     = false


# ── Godot lifecycle ───────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _ws_was_open:
				_ws_was_open = true
				if _on_open_cb.is_valid():
					var cb := _on_open_cb
					_on_open_cb = Callable()
					cb.call()
			while _ws.get_available_packet_count() > 0:
				_handle_message(_ws.get_packet().get_string_from_utf8())

		WebSocketPeer.STATE_CLOSED:
			if _ws_was_open:
				_on_unexpected_close()
			elif not _ws_was_open and _ws != null:
				# Never opened — relay is unreachable
				_cleanup()
				connection_failed.emit("Cannot reach relay server. Check your internet connection.")


# ── Public API (same shape as the old ENet version) ──────────────────────────

func host_game(player_name: String, _port: int = DEFAULT_PORT) -> void:
	_pending_name = player_name
	_connect_relay(func(): _send({"type": "host"}))


## `room` is a 6-character room code (e.g. "ABC123").
func join_game(room: String, player_name: String, _port: int = DEFAULT_PORT) -> void:
	_pending_name = player_name
	_connect_relay(func(): _send({"type": "join", "room": room.to_upper().strip_edges()}))


func disconnect_game() -> void:
	_cleanup()


func is_my_turn() -> bool:
	if not is_online:
		return true
	return GameState.current_turn == my_player_index


## Returns the room code (used in main_menu to display "share this code").
func get_local_ip() -> String:
	return room_code


# ── Sync helpers (called from GameState / scene code) ────────────────────────

## Sync full state to all peers.
func net_sync(state: Dictionary) -> void:
	if is_host:
		_relay_broadcast({"type": "sync_state", "state": state})
		# Host applies locally so its own state_applied listeners fire too.
		GameState.apply_state(state)
		state_applied.emit()
	else:
		# Client sends to host; host will apply + re-broadcast.
		_relay_to(1, {"type": "push_state", "state": state})


## Sync full state and transition every peer to `scene_path`.
func net_sync_and_change_scene(state: Dictionary, scene_path: String) -> void:
	if is_host:
		_relay_broadcast({"type": "sync_and_scene", "state": state, "scene": scene_path})
		GameState.apply_state(state)
		state_applied.emit()
		get_tree().change_scene_to_file(scene_path)
	else:
		_relay_to(1, {"type": "push_state_and_scene", "state": state, "scene": scene_path})


## Change scene on all peers without a state sync (host only).
func broadcast_scene_change(scene_path: String) -> void:
	if is_host:
		_relay_broadcast({"type": "change_scene", "scene": scene_path})
		get_tree().change_scene_to_file(scene_path)


# ── Internal helpers ──────────────────────────────────────────────────────────

func _connect_relay(on_open: Callable) -> void:
	_cleanup()
	_ws         = WebSocketPeer.new()
	_ws_was_open = false
	_on_open_cb  = on_open
	var err := _ws.connect_to_url(RELAY_URL)
	if err != OK:
		_cleanup()
		connection_failed.emit("Cannot reach relay server.")


func _send(msg: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))


func _relay_broadcast(data: Dictionary) -> void:
	_send({"type": "relay", "target": 0, "data": data})


func _relay_to(target_peer_id: int, data: Dictionary) -> void:
	_send({"type": "relay", "target": target_peer_id, "data": data})


func _cleanup() -> void:
	if _ws:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_ws.close()
		_ws = null
	_ws_was_open    = false
	_on_open_cb     = Callable()
	is_online       = false
	is_host         = false
	my_player_index = 0
	room_code       = ""
	_peer_id        = 0
	lobby_players.clear()


func _on_unexpected_close() -> void:
	var was_in_game: bool = (GameState.game_phase == "playing")
	_cleanup()
	if was_in_game:
		peer_disconnected_in_game.emit()
	else:
		connection_failed.emit("Lost connection to relay server.")


# ── Incoming message dispatch ─────────────────────────────────────────────────

func _handle_message(raw: String) -> void:
	var msg = JSON.parse_string(raw)
	if not msg is Dictionary:
		return

	match msg.get("type", ""):
		"room_created":
			room_code       = msg.get("room", "")
			_peer_id        = int(msg.get("peer_id", 1))
			is_online       = true
			is_host         = true
			my_player_index = 0
			lobby_players   = [{"name": _pending_name, "peer_id": 1, "player_index": 0}]
			room_created.emit(room_code)
			lobby_changed.emit()

		"joined":
			_peer_id  = int(msg.get("peer_id", 0))
			is_online = true
			is_host   = false
			# Ask the host for current lobby state.
			_relay_to(1, {"type": "request_lobby", "name": _pending_name, "peer_id": _peer_id})

		"peer_connected":
			pass  # Host handles lobby roster via request_lobby

		"peer_disconnected":
			var pid := int(msg.get("peer_id", 0))
			for i in range(lobby_players.size()):
				if int(lobby_players[i].get("peer_id", 0)) == pid:
					lobby_players.remove_at(i)
					break
			if is_online and GameState.game_phase == "playing":
				peer_disconnected_in_game.emit()
			lobby_changed.emit()

		"relay":
			_handle_relay_data(int(msg.get("from", 0)), msg.get("data", {}))

		"error":
			connection_failed.emit(msg.get("message", "Relay error."))


func _handle_relay_data(from_peer: int, data: Dictionary) -> void:
	match data.get("type", ""):

		# ── Lobby management ──────────────────────────────────────────────────

		"request_lobby":
			if not is_host:
				return
			var joiner_name: String = data.get("name", "Player")
			var joiner_peer: int    = int(data.get("peer_id", 0))
			var player_idx: int     = lobby_players.size()
			lobby_players.append({"name": joiner_name, "peer_id": joiner_peer, "player_index": player_idx})
			var lobby_msg := {"type": "lobby_update", "lobby": lobby_players}
			_relay_broadcast(lobby_msg)
			_apply_lobby_update(lobby_players)  # apply on host too

		"lobby_update":
			_apply_lobby_update(data.get("lobby", []))

		# ── State / scene sync ────────────────────────────────────────────────

		"sync_state":
			GameState.apply_state(data.get("state", {}))
			state_applied.emit()

		"change_scene":
			get_tree().change_scene_to_file(data.get("scene", ""))

		"sync_and_scene":
			GameState.apply_state(data.get("state", {}))
			state_applied.emit()
			get_tree().change_scene_to_file(data.get("scene", ""))

		# ── Client → Host pushes ──────────────────────────────────────────────

		"push_state":
			if not is_host:
				return
			GameState.apply_state(data.get("state", {}))
			net_sync(GameState.serialize())

		"push_state_and_scene":
			if not is_host:
				return
			GameState.apply_state(data.get("state", {}))
			net_sync_and_change_scene(GameState.serialize(), data.get("scene", ""))


# ── Helpers ───────────────────────────────────────────────────────────────────

func _apply_lobby_update(lobby: Array) -> void:
	lobby_players = lobby.duplicate(true)
	for entry in lobby_players:
		if int(entry.get("peer_id", 0)) == _peer_id:
			my_player_index = int(entry.get("player_index", 0))
			break
	lobby_changed.emit()
