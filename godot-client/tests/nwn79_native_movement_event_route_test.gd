extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")
const Motion=preload("res://systems/network_motion.gd")

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../backups/animations/local-network-character-v5.json")))
	if not fixture is Dictionary:fail("Original object-update fixture unavailable");return
	var created: Dictionary={};var updated: Dictionary={}
	for message in fixture.transport.messages:
		if message.get("kind")!="object-updates":continue
		for record in message.get("records",[]):
			if int(record.get("objectType",0))!=5:continue
			if created.is_empty() and record.get("action")=="create":created=record
			elif not created.is_empty() and int(record.get("id",-1))==int(created.id) and record.get("action")=="update" and record.get("state",{}).has("path"):
				updated=record;break
		if not updated.is_empty():break
	if created.is_empty() or updated.is_empty():fail("Original creature create/path update unavailable");return
	var session=Session.new();root.add_child(session);session.world_state.area_id=9
	var id:=int(created.id)
	session.world_state.registry[id]={"id":id,"objectType":5,"areaId":9,"replicationRemoved":false,"replicated":created.state.duplicate(true)}
	var born: Array[Dictionary]=session.movement_from_update({"records":[created]})
	if born.size()!=1 or not born[0].created or born[0].id!=id or not born[0].changes.has("position") or not born[0].changes.has("animation") or born[0].changes.has("visualTransform"):fail("Original create movement fields/order were not projected");return
	var replicated: Dictionary=session.world_state.registry[id].replicated
	replicated.merge(updated.state,true)
	var path: Array[Dictionary]=session.movement_from_update({"records":[updated]})
	if path.size()!=1 or path[0].created or path[0].revision<=born[0].revision or not path[0].changes.has("path") or not path[0].changes.has("animation") or path[0].changes.has("hitPoints"):fail("Original update movement fields/order were not projected");return
	var local=Motion.new();var initial:={"position":[0.0,0.0,0.0],"orientation":[1.0,0.0,0.0],"animation":1,"walkRate":3000.0,"runRate":5000.0}
	local.observe(7,initial,true,initial)
	local.observe(7,{"position":[1.5,0.0,0.0]},false,initial)
	if int(local.objects[7].animation)!=1 or absf(local.objects[7].position.x-1.5)>0.0001 or int(local.objects[7].correction)!=512:fail("Position-only reply must correct pose without inventing a locomotion clip");return
	local.observe(7,{"animation":4,"path":[[1.5,0.0],[3.0,0.0]],"runRate":5000.0},false,initial)
	if int(local.objects[7].animation)!=4 or not bool(local.objects[7].active) or local.objects[7].path.size()!=2:fail("Authoritative path/animation did not select locomotion");return
	print("NWN79 original movement route PASS: create/update projection, position correction, explicit path animation")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 original movement route failed: "+reason)
	quit(1)
