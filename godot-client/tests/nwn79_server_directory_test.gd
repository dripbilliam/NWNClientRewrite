extends SceneTree
const Directory=preload("res://systems/native_data/native_server_directory.gd")

func _initialize()->void:
	var rows: Array=[{"host":"127.0.0.1","port":5121,"session_name":"Private Prelude","module_name":"Prelude","servervault":false,"passworded":true,"current_players":1,"max_players":2},{"host":"","port":5121},{"host":"example.invalid","port":70000},{"host":"example.invalid","port":5122.5}]
	var parsed: Dictionary=Directory.parse_rows(JSON.stringify(rows).to_utf8_buffer())
	if parsed.has("error") or parsed.rows.size()!=1 or parsed.rows[0].host!="127.0.0.1" or parsed.rows[0].port!=5121 or parsed.rows[0].serverName!="Private Prelude" or not parsed.rows[0].allowLocalVaultCharacters or not parsed.rows[0].passwordRequired or not parsed.rows[0].allowed:fail("Godot directory changed the original server-list schema or endpoint admission");return
	if not Directory.parse_rows("{}".to_utf8_buffer()).has("error"):fail("Godot directory accepted a non-list response");return
	print("NWN79 Godot server directory PASS: valid_rows=1 invalid_rows=3")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot server directory failed: "+reason)
	quit(1)
