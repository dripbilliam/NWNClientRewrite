extends Node3D
# One private ascending allocator for native effect/projectile/area hosts.
# Original c_dummy models and temporary AI expiry never enter server state.
const Fade=preload("res://systems/client_fade.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var manager
var entries: Dictionary={}
var next_id:=0
var serial:=0
var previous_ticks:=0
var closed:=false
var stats:={"created":0,"expired":0,"retired":0,"aborted":0,"failed":0,"area_created":0,"area_retired":0,"projectile_created":0,"projectile_retired":0,"display_calls":0}
func configure(owner) -> void:
	manager=owner; previous_ticks=Time.get_ticks_usec(); process_priority=40
func _world_time() -> Dictionary:
	# Client presentation projection; authoritative pause/clock synchronization
	# remains separate from native subtraction and local temporary-object expiry.
	var length:=maxi(1,int(manager.world.minutes_per_hour)&255)*1440000
	var ticks:=Time.get_ticks_msec()
	return {"day":(ticks/length)&0xffffffff,"time":ticks%length,"length":length}
func _providers(snapshot: int) -> Dictionary:
	return {"worldTime":_world_time,"difference":func(a,b):
		var day: int=(int(a.day)-int(b.day))&0xffffffff; var time: int=(int(a.time)-int(b.time))&0xffffffff
		if time>=int(a.length): day=(day-1)&0xffffffff; time=(time+int(a.length))&0xffffffff
		return {"day":day,"time":time},
		"snapshotDifference":func():return snapshot,"modelHandle":func(state):return state.model,"mode":func():return 2,"controlledId":func():return manager.controlled_id,
		"display":func(_state,_offset):stats.display_calls+=1,"targetAlpha":func(_state):return 1.0,"alpha":func(_s,_opacity,_part):pass,"handleScene":func(_s,_on):pass}
func allocate(area: bool=false,object_type: int=5) -> Dictionary:
	if closed or entries.size()>=512 or next_id>=0x7effffff: return {}
	var id:=next_id; next_id+=1; serial+=1
	var row:={"id":id,"token":serial,"area":area,"model":null,"object":{"id":id,"objectType":11 if area else object_type,"privateToken":serial,"appearance":{"appearance":201}}}
	entries[id]=row
	if area: stats.area_created+=1
	elif object_type==8: stats.projectile_created+=1
	return row
func create(role: String,position: Array,lifetime: int) -> Variant:
	if closed or role not in ["point","source","target"]: return null
	var row:=allocate()
	if row.is_empty(): return null
	var model=manager.create_model(0,"c_dummy")
	if model==null: entries.erase(row.id); stats.failed+=1; return null
	row.model=model
	# The reviewed SOURCE branch aborts on successful status0 registration.
	# Preserve this quirk; its original source ID is not replaced by this host.
	if role=="source":
		stats.aborted+=1; remove(int(row.id)); manager.diagnose("visual.object-dummy-source-native-abort","Original source-role registration status-zero abort retained",0); return null
	model.position=Vector3(position[0],position[2],-position[1])
	row.object.position=position.duplicate()
	row.state={"id":row.id,"temporary":0,"blocked":0,"fadeTarget":1,"fadeState":1,"delayEnabled":0,"duration":0,"since":{"day":0,"time":0},"opacity":1.0,"visible":1,"model":model}
	Fade.set_fade(row.state,1,1,lifetime,_providers(0)); row.state.temporary=1; stats.created+=1
	return row.object
func host(id: int,token: int) -> Node3D:
	return entries[id].model if not closed and entries.has(id) and int(entries[id].token)==token and not entries[id].area else null
func anchor(id: int,token: int,part: String) -> Node3D:
	var model:=host(id,token)
	return model.node_for(0,part) if is_instance_valid(model) else null
func has(id: int,token: int) -> bool: return not closed and entries.has(id) and int(entries[id].token)==token
func descriptor(id: int,token: int) -> Dictionary:
	var model:=host(id,token)
	if model==null: return {}
	var parts: Array=[]; var rig: Dictionary=model.rigs.entities[0]
	for index in rig.model_parts[0]: parts.append(rig.authored_names[int(index)])
	return {"type":5,"privateToken":token,"parts":parts,"loadedName":"c_dummy"}
func remove(id: int) -> void:
	if not entries.has(id): return
	var row: Dictionary=entries[id]; entries.erase(id)
	if row.area: stats.area_retired+=1
	elif int(row.object.objectType)==8:
		if is_instance_valid(row.model): manager.release_model(row.model)
		stats.projectile_retired+=1
	else:
		if row.has("state"): row.state.model=null
		if is_instance_valid(row.model): manager.release_model(row.model)
		stats.retired+=1
func _process(_delta: float) -> void:
	var began:=Timing.begin(); advance(); Timing.finish("callback_dummies",began)
func advance() -> void:
	if closed: return
	var ticks:=Time.get_ticks_usec(); var providers:=_providers(ticks-previous_ticks); previous_ticks=ticks
	for id in entries.keys():
		if not entries[id].has("state"): continue
		if Fade.update(entries[id].state,providers)!=0: remove(int(id)); stats.expired+=1
func sample() -> Dictionary: return {"active":entries.size(),"stats":stats.duplicate(),"next_id":next_id,"clock":"local monotonic projection; authoritative pause/time synchronization remains open"}
func close() -> void:
	if closed: return
	for id in entries.keys(): remove(int(id))
	closed=true; set_process(false)
func _exit_tree() -> void: close()
