extends SceneTree
const Query=preload("res://systems/native_data/native_server_query.gd")
var owner

func _initialize()->void:
	call_deferred("start")

func start()->void:
	owner=Query.new();root.add_child(owner)
	owner.completed.connect(done)
	owner.query("127.0.0.1",5121)

func done(row: Dictionary,error: String)->void:
	if not error.is_empty() or row.get("host")!="127.0.0.1" or int(row.get("port",0))!=5121 or str(row.get("moduleName","")).is_empty():
		printerr("NWN79 Godot server info failed: "+error+" module="+str(row.get("moduleName","")))
		quit(1);return
	print("NWN79 Godot server info PASS: "+JSON.stringify({"module":row.moduleName,"name":row.serverName,"extended":row.extendedReceived}))
	quit(0)
