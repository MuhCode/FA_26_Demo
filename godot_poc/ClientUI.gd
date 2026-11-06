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
	# Set up two HTTP nodes: one for sending updates (POST) and one for reading profile (GET)
	post_req = HTTPRequest.new()
	add_child(post_req)
	post_req.request_completed.connect(_on_post_done)

	get_req = HTTPRequest.new()
	add_child(get_req)
	get_req.request_completed.connect(_on_get_done)

	url_input.text = DEFAULT_URL
	player_input.text = DEFAULT_PLAYER

	kill_btn.pressed.connect(func() -> void: send_action("KILL_ENEMY"))
	battle_btn.pressed.connect(func() -> void: send_action("WIN_BATTLE"))
	finish_btn.pressed.connect(func() -> void: send_action("FINISH_GAME"))
	reset_btn.pressed.connect(func() -> void: send_action("RESET"))
	refresh_btn.pressed.connect(fetch_profile)

	# Pull current stats from Postgres on launch
	fetch_profile()

func send_action(action_name: String) -> void:
	var base_url: String = url_input.text.strip_edges().trim_suffix("/")
	var body: Dictionary = {
		"player_id": player_input.text.strip_edges(),
		"action": action_name
	}
	var headers: PackedStringArray = ["Content-Type: application/json"]
	status_label.text = "Status: Sending %s..." % action_name
	post_req.cancel_request()
	post_req.request(base_url + "/profile", headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func fetch_profile() -> void:
	var base_url: String = url_input.text.strip_edges().trim_suffix("/")
	var player_id: String = player_input.text.strip_edges().uri_encode()
	status_label.text = "Status: Loading profile..."
	get_req.cancel_request()
	get_req.request(base_url + "/profile?player_id=" + player_id, [], HTTPClient.METHOD_GET)

func _on_post_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code == 200:
		status_label.text = "Status: Saved to DB"
	else:
		status_label.text = "Status: Error (%d) %s" % [code, body.get_string_from_utf8()]

	if auto_refresh.button_pressed:
		fetch_profile()

func _on_get_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var text: String = body.get_string_from_utf8()
	if code != 200:
		status_label.text = "Status: Failed to load (%d)" % code
		return

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or parsed.has("error"):
		status_label.text = "Status: DB error"
		return

	status_label.text = "Status: Profile synced"
	update_ui(parsed)

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
