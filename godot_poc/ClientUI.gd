extends Control

const DEFAULT_URL: String = "http://localhost:8080"
const DEFAULT_PLAYER: String = "commander_fa26"

var post_req: HTTPRequest
var get_req: HTTPRequest

@onready var url_input: LineEdit = %TunnelUrlInput
@onready var player_input: LineEdit = %PlayerIdInput
@onready var kill_btn: Button = %KillEnemyButton
@onready var battle_btn: Button = %WinBattleButton
@onready var finish_btn: Button = %FinishGameButton
@onready var reset_btn: Button = %ResetButton
@onready var refresh_btn: Button = %FetchProfileButton
@onready var auto_refresh: CheckBox = %AutoRefreshCheck
@onready var status_label: Label = %WriteStatusLabel
@onready var stats_label: Label = %MetricsLabel
@onready var achievements_label: Label = %AchievementsLabel

func _ready() -> void:
	post_req = HTTPRequest.new()
	post_req.timeout = 5.0
	add_child(post_req)
	post_req.request_completed.connect(_on_post_done)

	get_req = HTTPRequest.new()
	get_req.timeout = 5.0
	add_child(get_req)
	get_req.request_completed.connect(_on_get_done)

	url_input.text = DEFAULT_URL
	player_input.text = DEFAULT_PLAYER

	kill_btn.pressed.connect(func() -> void: send_action("KILL_ENEMY"))
	battle_btn.pressed.connect(func() -> void: send_action("WIN_BATTLE"))
	finish_btn.pressed.connect(func() -> void: send_action("FINISH_GAME"))
	reset_btn.pressed.connect(func() -> void: send_action("RESET"))
	refresh_btn.pressed.connect(fetch_profile)

	# Initial connection check on launch
	status_label.text = "Status: Connection to database initializing..."
	fetch_profile()

func send_action(action_name: String) -> void:
	var base_url: String = url_input.text.strip_edges().trim_suffix("/")
	if base_url.is_empty():
		status_label.text = "Status: No server URL entered"
		return

	var body: Dictionary = {
		"player_id": player_input.text.strip_edges(),
		"action": action_name
	}
	var headers: PackedStringArray = ["Content-Type: application/json"]
	status_label.text = "Status: Sending %s..." % action_name
	post_req.cancel_request()
	var err: Error = post_req.request(base_url + "/profile", headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		status_label.text = "Status: Invalid URL or request failed"

func fetch_profile() -> void:
	var base_url: String = url_input.text.strip_edges().trim_suffix("/")
	if base_url.is_empty():
		status_label.text = "Status: No server URL entered"
		return

	var player_id: String = player_input.text.strip_edges().uri_encode()
	status_label.text = "Status: Connection to database initializing..."
	get_req.cancel_request()
	var err: Error = get_req.request(base_url + "/profile?player_id=" + player_id, [], HTTPClient.METHOD_GET)
	if err != OK:
		status_label.text = "Status: Invalid URL or request failed"

func _on_post_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status_label.text = get_connection_error(result, code)
		return

	status_label.text = "Status: Connected (Saved to DB)"
	if auto_refresh.button_pressed:
		fetch_profile()

func _on_get_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status_label.text = get_connection_error(result, code)
		return

	var text: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or parsed.has("error"):
		status_label.text = "Status: Database offline or profile not initialized"
		return

	status_label.text = "Status: Connected to database"
	update_ui(parsed)

# Detect whether Cloudflare, the Godot Server, or PostgreSQL is offline
func get_connection_error(result: int, code: int) -> String:
	var current_url: String = url_input.text.to_lower()
	var using_cloudflare: bool = current_url.contains("trycloudflare.com") or current_url.begins_with("https://")

	# Network-level failure (couldn't reach host or DNS failed)
	if result == HTTPRequest.RESULT_CANT_RESOLVE:
		return "Status: Cloudflare offline (tunnel link not active)" if using_cloudflare else "Status: Server offline (cannot resolve host)"
	if result == HTTPRequest.RESULT_CANT_CONNECT or result == HTTPRequest.RESULT_CONNECTION_ERROR or result == HTTPRequest.RESULT_TIMEOUT:
		return "Status: Cloudflare offline (cannot reach tunnel)" if using_cloudflare else "Status: Server offline (port 8080 not running)"

	# HTTP error codes returned by Cloudflare or the Server
	if code == 530 or code == 1033:
		return "Status: Cloudflare offline (cloudflared tunnel stopped)"
	if code == 502 or code == 504:
		return "Status: Server offline (Cloudflare is up, but Server on 8080 is off)"
	if code == 503:
		return "Status: Database offline (Server is up, but PostgreSQL is off)"

	return "Status: Server offline (HTTP %d)" % code

func update_ui(data: Dictionary) -> void:
	stats_label.text = (
		"Player: %s\n" % str(data.get("player_id", DEFAULT_PLAYER)) +
		"Enemies Killed: %d\n" % int(data.get("enemies_killed", 0)) +
		"Battles Won: %d\n" % int(data.get("battles_won", 0)) +
		"Games Finished: %d" % int(data.get("games_finished", 0))
	)

	var first_battle: bool = bool(data.get("flag_first_battle", false))
	var ten_battles: bool = bool(data.get("flag_ten_battles", false))
	var game_done: bool = bool(data.get("flag_game_finished", false))

	achievements_label.text = (
		"[%s] First Battle (Win 1 battle)\n" % ("x" if first_battle else " ") +
		"[%s] Battle Veteran (Win 10 battles)\n" % ("x" if ten_battles else " ") +
		"[%s] Game Finisher (Finish 1 game)" % ("x" if game_done else " ")
	)
