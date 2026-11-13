extends SceneTree
const Probe=preload("res://tests/native_direct_handoff_probe.gd")
func _initialize()->void:
	var failures: Array=[]
	var checks:=0
	var catalog:=RefCounted.new()
	var world:=Node.new()
	var ui:=Control.new()
	var objects:={"catalogInstance":catalog,"worldInstance":world,"gameplayInstance":ui}
	var record:={"objectId":4294967294,"connection":1}
	for key in objects:record[key]=Probe.instance_id_token(objects[key])
	var decoded: Dictionary=JSON.parse_string(JSON.stringify(record))
	for key in objects:
		checks+=1
		if not decoded[key] is String:failures.append(key+" must remain a string")
		checks+=1
		if decoded[key]!=str(objects[key].get_instance_id()):failures.append(key+" loses native int64 digits")
		checks+=1
		if decoded[key].to_int()!=objects[key].get_instance_id():failures.append(key+" cannot round trip exact native ID")
	var limits: Dictionary=JSON.parse_string(JSON.stringify({"min":"-9223372036854775808","max":"9223372036854775807"}))
	checks+=1
	if limits.min!="-9223372036854775808":failures.append("signed64 minimum string changed")
	checks+=1
	if limits.max!="9223372036854775807":failures.append("signed64 maximum string changed")
	checks+=1
	if decoded.objectId is String or decoded.objectId!=4294967294:failures.append("server object ID must remain numeric")
	world.free();ui.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"actual":decoded,"scope":"Actual RefCounted/Node/Control instance IDs through the probe formatter and Godot JSON; no session, assets or network."}
	var target:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--result="):target=arg.trim_prefix("--result=")
	if not target.is_empty():
		var file:=FileAccess.open(target,FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"));file.close()
	print("NATIVE_DIRECT_INSTANCE_IDS ",JSON.stringify(result))
	quit(0 if result.success else 1)
