extends SceneTree
const Directory=preload("res://systems/native_data/native_server_directory.gd")
var client: Node
var deadline:=0

func _initialize()->void:
	client=Directory.new();root.add_child(client)
	client.completed.connect(_completed)
	deadline=Time.get_ticks_msec()+25000
	client.refresh.call_deferred()

func _process(_delta: float)->bool:
	if Time.get_ticks_msec()>deadline:fail("Internet server list timed out")
	return false

func _completed(rows: Array[Dictionary],error: String)->void:
	if not error.is_empty() or rows.is_empty():fail("Godot Internet server list is unavailable: "+error);return
	if rows.any(func(row):return not row.get("allowed",false) or str(row.get("host","")).is_empty() or int(row.get("port",0))<1):fail("Internet list admitted an invalid endpoint");return
	print("NWN79 Godot Internet directory PASS: rows=",rows.size())
	client.close();quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot Internet directory failed: "+reason)
	if client!=null:client.close()
	quit(1)
