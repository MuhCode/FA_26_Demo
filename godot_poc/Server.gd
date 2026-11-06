extends Node

# Local HTTP server on port 8080 so cloudflared can forward requests to Postgres
const PORT: int = 8080
const HOST: String = "127.0.0.1"
const DB_USER: String = "postgres"
const DB_NAME: String = "aomf_poc"
const DEFAULT_PLAYER: String = "commander_fa26"

@export var db_password: String = "postgres"

var psql_path: String = "psql"
var server: TCPServer = TCPServer.new()
var clients: Array[StreamPeerTCP] = []
var running: bool = false

func _ready() -> void:
	if not db_password.is_empty() and not OS.has_environment("PGPASSWORD"):
		OS.set_environment("PGPASSWORD", db_password)

	find_psql_path()
	init_db()

	var err: Error = server.listen(PORT, HOST)
	if err != OK:
		print("Port %d already in use (err %d)" % [PORT, err])
		return

	running = true
	print("Server listening on http://%s:%d" % [HOST, PORT])

# Find psql.exe if the Windows installer hasn't added it to PATH yet
func find_psql_path() -> void:
	for ver in ["17", "16", "15", "14"]:
		var path: String = "C:/Program Files/PostgreSQL/%s/bin/psql.exe" % ver
		if FileAccess.file_exists(path):
			psql_path = path
			return
	var local_path: String = OS.get_environment("LOCALAPPDATA").path_join("Programs/PostgreSQL/pgsql/bin/psql.exe")
	if FileAccess.file_exists(local_path):
		psql_path = local_path

# Make sure the database and player_profile table exist on startup
func init_db() -> void:
	var out: Array = []
	OS.execute(psql_path, ["-U", DB_USER, "-tc", "CREATE DATABASE %s;" % DB_NAME], out, true)
	var table_sql: String = (
		"CREATE TABLE IF NOT EXISTS player_profile (" +
		"player_id VARCHAR(50) PRIMARY KEY, " +
		"display_name VARCHAR(100) NOT NULL DEFAULT 'commander_fa26', " +
		"enemies_killed INT NOT NULL DEFAULT 0, " +
		"battles_won INT NOT NULL DEFAULT 0, " +
		"games_finished INT NOT NULL DEFAULT 0, " +
		"flag_first_battle BOOLEAN NOT NULL DEFAULT FALSE, " +
		"flag_ten_battles BOOLEAN NOT NULL DEFAULT FALSE, " +
		"flag_game_finished BOOLEAN NOT NULL DEFAULT FALSE, " +
		"last_action VARCHAR(50) DEFAULT 'INIT', " +
		"updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP);"
	)
	run_query(table_sql)

func _process(_delta: float) -> void:
	if not running:
		return
	accept_connections()
	poll_clients()

func accept_connections() -> void:
	while server.is_connection_available():
		var client: StreamPeerTCP = server.take_connection()
		if client != null:
			clients.append(client)

func poll_clients() -> void:
	for i in range(clients.size() - 1, -1, -1):
		var client: StreamPeerTCP = clients[i]
		client.poll()
		var status: StreamPeerTCP.Status = client.get_status()
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			clients.remove_at(i)
			continue
		if status == StreamPeerTCP.STATUS_CONNECTED and client.get_available_bytes() > 0:
			var raw: String = client.get_utf8_string(client.get_available_bytes())
			handle_request(client, raw)
			clients.remove_at(i)

func handle_request(client: StreamPeerTCP, raw: String) -> void:
	var lines: PackedStringArray = raw.split("\r\n")
	if lines.is_empty():
		client.disconnect_from_host()
		return
	var parts: PackedStringArray = lines[0].split(" ")
	if parts.size() < 2:
		client.disconnect_from_host()
		return

	var method: String = parts[0]
	var path: String = parts[1]
	print("Request: %s %s" % [method, path])

	var body_start: int = raw.find("\r\n\r\n")
	var body: String = raw.substr(body_start + 4).strip_edges() if body_start != -1 else ""

	if method == "GET" and path.begins_with("/profile"):
		var player_id: String = get_query_param(path, "player_id", DEFAULT_PLAYER)
		send_response(client, "200 OK", get_profile(player_id))
		return
	if method == "POST" and path.begins_with("/profile"):
		send_response(client, "200 OK", update_profile(body))
		return
	send_response(client, "404 Not Found", "{\"error\":\"Not found\"}")

# Grab query parameter like ?player_id=commander_fa26
func get_query_param(path: String, key: String, default_val: String) -> String:
	var q_idx: int = path.find("?")
	if q_idx == -1:
		return default_val
	for pair in path.substr(q_idx + 1).split("&"):
		var kv: PackedStringArray = pair.split("=")
		if kv.size() == 2 and kv[0] == key:
			return kv[1].uri_decode()
	return default_val

func clean_sql(text: String) -> String:
	return text.replace("'", "''")

func get_profile(player_id: String) -> String:
	var safe_id: String = clean_sql(player_id)
	# Make sure player row exists before reading
	var seed_sql: String = (
		"INSERT INTO player_profile (player_id, display_name) " +
		"VALUES ('%s', '%s') ON CONFLICT (player_id) DO NOTHING;" % [safe_id, safe_id]
	)
	run_query(seed_sql)
	var select_sql: String = (
		"SELECT row_to_json(t) FROM " +
		"(SELECT * FROM player_profile WHERE player_id = '%s') t;" % safe_id
	)
	return run_query(select_sql)

func update_profile(json_body: String) -> String:
	var parsed: Variant = JSON.parse_string(json_body)
	if typeof(parsed) != TYPE_DICTIONARY:
		return "{\"error\":\"Bad JSON\"}"
	var data: Dictionary = parsed
	var player_id: String = clean_sql(str(data.get("player_id", DEFAULT_PLAYER)))
	var action: String = clean_sql(str(data.get("action", "NONE")))

	var sql: String = get_action_sql(player_id, action)
	if sql.is_empty():
		return "{\"error\":\"Unknown action\"}"

	var res: String = run_query(sql)
	if res.begins_with("{\"error\""):
		return res
	return "{\"ok\":true,\"action\":\"%s\"}" % action

# Build SQL update for each button press and check achievement thresholds
func get_action_sql(player_id: String, action: String) -> String:
	match action:
		"KILL_ENEMY":
			return (
				"UPDATE player_profile SET enemies_killed = enemies_killed + 1, " +
				"last_action = 'KILL_ENEMY', updated_at = CURRENT_TIMESTAMP " +
				"WHERE player_id = '%s' RETURNING row_to_json(player_profile.*);" % player_id
			)
		"WIN_BATTLE":
			return (
				"UPDATE player_profile SET battles_won = battles_won + 1, " +
				"flag_first_battle = flag_first_battle OR (battles_won + 1 >= 1), " +
				"flag_ten_battles = flag_ten_battles OR (battles_won + 1 >= 10), " +
				"last_action = 'WIN_BATTLE', updated_at = CURRENT_TIMESTAMP " +
				"WHERE player_id = '%s' RETURNING row_to_json(player_profile.*);" % player_id
			)
		"FINISH_GAME":
			return (
				"UPDATE player_profile SET games_finished = games_finished + 1, " +
				"flag_game_finished = flag_game_finished OR (games_finished + 1 >= 1), " +
				"last_action = 'FINISH_GAME', updated_at = CURRENT_TIMESTAMP " +
				"WHERE player_id = '%s' RETURNING row_to_json(player_profile.*);" % player_id
			)
		"RESET":
			return (
				"UPDATE player_profile SET enemies_killed = 0, battles_won = 0, games_finished = 0, " +
				"flag_first_battle = FALSE, flag_ten_battles = FALSE, flag_game_finished = FALSE, " +
				"last_action = 'RESET', updated_at = CURRENT_TIMESTAMP " +
				"WHERE player_id = '%s' RETURNING row_to_json(player_profile.*);" % player_id
			)
	return ""

func run_query(sql: String) -> String:
	var output: Array = []
	var args: PackedStringArray = ["-U", DB_USER, "-d", DB_NAME, "-t", "-A", "-c", sql]
	var code: int = OS.execute(psql_path, args, output, true)
	if code != 0 or output.is_empty():
		var msg: String = str(output[0]).strip_edges() if not output.is_empty() else "psql error"
		return "{\"error\":%s}" % JSON.stringify(msg)
	var text: String = str(output[0]).strip_edges()
	return text if not text.is_empty() else "{}"

func send_response(client: StreamPeerTCP, status: String, body: String) -> void:
	var bytes: PackedByteArray = body.to_utf8_buffer()
	var headers: String = (
		"HTTP/1.1 %s\r\n" % status +
		"Content-Type: application/json\r\n" +
		"Access-Control-Allow-Origin: *\r\n" +
		"Content-Length: %d\r\n" % bytes.size() +
		"Connection: close\r\n\r\n"
	)
	client.put_data(headers.to_utf8_buffer() + bytes)
	client.disconnect_from_host()
