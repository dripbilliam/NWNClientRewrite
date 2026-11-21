extends Node3D
# One private ascending allocator for native effect/projectile/area hosts.
# Original c_dummy models and temporary AI expiry never enter server state.
const Fade=preload("res://systems/client_fade.gd")
const WorldTimer=preload("res://systems/native_data/world_timer.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const GameObjectArray=preload("res://systems/native_data/native_game_object_array.gd")
var manager
var object_array=GameObjectArray.new({"clientMode":true})
var entries: Dictionary={}
var next_id:=0
var registration_error:=""
var serial:=0
var previous_ticks:=0
var closed:=false
var visual_scene_reported:=false
var projectile_scene_reported:=false
var events: Array=[]
var stats:={"created":0,"registered":0,"destroyed":0,"expired":0,"retired":0,"aborted":0,"failed":0,"area_created":0,"area_retired":0,"projectile_created":0,"projectile_retired":0,"display_calls":0}
func event(record: Dictionary) -> void:
	events.append(record)
	if events.size()>64: events.pop_front()
func _native_position(point: Array) -> Array:
	return [PackedFloat32Array([float(point[0])])[0],PackedFloat32Array([float(point[1])])[0],PackedFloat32Array([float(point[2])])[0]]
func configure(owner) -> void:
	manager=owner; previous_ticks=Time.get_ticks_usec(); process_priority=47
func _world_time() -> Dictionary:
	var timer:Variant=manager.combat_timer
	if timer==null or not timer.has_method("time") or not WorldTimer.integer(timer.day_length): return {}
	var now:Dictionary=timer.time()
	if not bool(now.get("ready",false)): return {}
	return {"day":int(now.day),"time":int(now.time)}
func _fade_unavailable(cell: Dictionary,reason: String) -> void:
	if str(cell.get("reason","")).is_empty():cell.reason=reason
func _providers(snapshot: int,now: Dictionary={},failure: Dictionary={}) -> Dictionary:
	var current:Dictionary=now if not now.is_empty() else _world_time()
	var length:Variant=manager.combat_timer.day_length
	var unavailable:Dictionary=failure if not failure.is_empty() else {"reason":""}
	return {"worldTime":func():return current,"difference":func(a,b):
		var elapsed:Dictionary=WorldTimer.subtract_world_times(a,b,length)
		return {"day":int(elapsed.day),"time":int(elapsed.time)} if bool(elapsed.get("ready",false)) and bool(elapsed.get("outputsDefined",false)) else {"day":0,"time":0},
		"snapshotDifference":func():_fade_unavailable(unavailable,"Native dummy fade snapshot-time provider is unavailable");return snapshot,
		"modelHandle":func(state):return state.model,"mode":func():return 2,"controlledId":func():return manager.controlled_id,
		"display":func(state,offset):stats.display_calls+=1; event({"kind":"dummyDisplay","id":int(state.id),"offset":offset}),
		"targetAlpha":func(_state):_fade_unavailable(unavailable,"Native dummy target-alpha context is unavailable");return 1.0,
		"alpha":func(_s,_opacity,_part):_fade_unavailable(unavailable,"Native dummy model-alpha adapter is unavailable"),
		"handleScene":func(_s,_on):_fade_unavailable(unavailable,"Native dummy fade-completion scene adapter is unavailable")}
func _dummy_state() -> Dictionary:
	stats.created+=1
	return {"id":0x7f000000,"objectType":5,"nativeField28":0,"position":[0.0,0.0,0.0],"orientation":[0.0,0.0,0.0],"desiredPosition":[0.0,0.0,0.0],"model":null,"temporary":0,"blocked":0,"fadeState":1,"fadeTarget":1,"delayEnabled":0,"duration":0,"since":{"day":0,"time":0},"opacity":1.0,"visible":1,"destroyed":false}
func allocate(area: bool=false,object_type: int=5,existing_object: Dictionary={}) -> Dictionary:
	registration_error=""
	if closed or next_id>=0x7effffff: return {}
	var object:Dictionary=existing_object if not existing_object.is_empty() else (_dummy_state() if not area and object_type==5 else {"objectType":11 if area else object_type,"appearance":{"appearance":201}})
	var registered:Dictionary=object_array.add_internal_object(object)
	if int(registered.status)!=0:
		registration_error="Client internal object insertion failed (%d)"%int(registered.status)
		manager.diagnose("client.object-insertion-failed",registration_error,0)
		return {}
	var id:int=int(registered.id);next_id=int(object_array.next_object_id[0]);serial+=1
	object.privateToken=serial
	var row:={"id":id,"token":serial,"area":area,"model":null,"object":object,"ai":not area and object_type==5}
	entries[id]=row
	if area: stats.area_created+=1
	elif object_type==8: stats.projectile_created+=1
	return row
func create(role: String,position: Array,lifetime: int,prepared_object: Dictionary={},prepared_model: Variant=null,prepared_now: Dictionary={}) -> Variant:
	if closed: return null
	if role not in ["point","source","target"]: manager.diagnose("visual.object-dummy-create-failed","Unknown native visual dummy role",0,{"role":role,"position":position.duplicate(),"lifetime":lifetime}); stats.failed+=1; return null
	var now:Dictionary=prepared_now if not prepared_now.is_empty() else _world_time()
	if now.is_empty(): manager.diagnose("client.dummy-world-time-unavailable","Native world timer is unavailable for temporary dummy expiry",0); stats.failed+=1; return null
	var object:Dictionary=prepared_object if not prepared_object.is_empty() else _dummy_state()
	var model:Variant=prepared_model if prepared_model!=null else manager.create_model(0,"c_dummy")
	if model==null:
		manager.diagnose("visual.object-dummy-model-failed","Original c_dummy model could not be loaded",0)
		stats.failed+=1
		return null
	object.model=model
	object.resourceName="c_dummy"
	var row:=allocate(false,5,object)
	if row.is_empty():
		manager.release_model(model)
		if prepared_object.is_empty():
			stats.failed+=1
			manager.diagnose("visual.object-dummy-admission-failed","Native object-visual dummy did not enter the scene",0,{"role":role,"position":position.duplicate(),"lifetime":lifetime})
		return null
	row.model=model
	# The reviewed SOURCE branch aborts on successful status0 registration.
	# Preserve this quirk; its original source ID is not replaced by this host.
	if role=="source":
		stats.aborted+=1; stats.failed+=1; remove(int(row.id)); manager.diagnose("visual.object-dummy-source-native-abort","Original source-role registration status-zero abort retained",0); return null
	row.object.area=int(manager.world.area_id)
	stats.registered+=1
	var native_position: Array=_native_position(position)
	model.position=Vector3(native_position[0],native_position[2],-native_position[1])
	row.object.position=native_position; row.object.desiredPosition=native_position.duplicate(); row.object.model=model; row.object.appearance=201
	row.state=row.object
	Fade.set_fade(row.state,1,1,lifetime,_providers(0,now)); row.state.temporary=1
	if prepared_object.is_empty():
		event({"kind":"visualDummyReady","role":role,"id":int(row.id),"position":native_position.duplicate(),"duration":int(row.state.duration),"appearance":201})
		if not visual_scene_reported:
			visual_scene_reported=true
			manager.diagnose("visual.object-dummy-scene-adapter-incomplete","Object-visual dummy uses local scene/display mode 2",int(row.id))
	return row.object
func create_projectile_target(target_id: int,position: Array,travel: int) -> Dictionary:
	var requested:int=target_id&0xffffffff
	if requested==0x7f000000: return {"targetId":requested,"dummy":null,"registered":false,"aborted":false}
	if closed: return {}
	var now:Dictionary=_world_time()
	if now.is_empty(): manager.diagnose("client.dummy-world-time-unavailable","Native world timer is unavailable for temporary dummy expiry",0); stats.failed+=1; return {}
	var object:Dictionary=_dummy_state()
	var model:Variant=manager.create_model(0,"c_dummy")
	object.model=model
	if is_instance_valid(model): object.resourceName="c_dummy"; event({"kind":"dummyLoaded","resource":"c_dummy"})
	var player:Variant=manager.world.raw_object_lookup.call(int(manager.world.controlled_id)) if manager.world.raw_object_lookup.is_valid() else manager.world.desired.get(int(manager.world.controlled_id),{}).get("object")
	var player_present:bool=player!=null
	var area_present:bool=int(manager.world.area_id)>=0
	if model==null or not player_present or not area_present:
		if model==null: manager.diagnose("visual.projectile-dummy-model-failed","Original c_dummy model could not be loaded",0); stats.failed+=1
		Fade.set_fade(object,1,1,(travel+500)&0xffffffff,_providers(0,now)); object.temporary=1
		object.destroyed=true
		if is_instance_valid(model): manager.release_model(model)
		object.model=null
		manager.diagnose("visual.projectile-dummy-unregistered","Dummy model/player/area admission failed; projectile retains its requested target ID",requested)
		return {"targetId":requested,"dummy":null,"registered":false,"aborted":false}
	var dummy:Variant=create("target",position,(travel+500)&0xffffffff,object,model,now)
	if dummy==null:
		stats.failed+=1
		manager.diagnose("visual.projectile-dummy-registration-failed","Native client dummy allocation or registration failed",requested)
		return {}
	event({"kind":"dummyReady","id":int(dummy.id),"requestedTargetId":requested,"position":dummy.position.duplicate(),"duration":int(dummy.duration),"appearance":int(dummy.appearance)})
	if not projectile_scene_reported:
		projectile_scene_reported=true
		manager.diagnose("visual.projectile-dummy-scene-adapter-incomplete","Dummy uses local scene/display mode 2",int(dummy.id))
	return {"targetId":int(dummy.id),"dummy":dummy,"registered":true,"aborted":false}
func host(id: int,token: int) -> Node3D:
	return entries[id].model if has(id,token) and not entries[id].area else null
func anchor(id: int,token: int,part: String) -> Node3D:
	var model:=host(id,token)
	return model.node_for(0,part) if is_instance_valid(model) else null
func has(id: int,token: int) -> bool:
	return not closed and entries.has(id) and int(entries[id].token)==token and int(object_array.get_game_object(id).status)==0 and object_array.lookup(id)==entries[id].object
func descriptor(id: int,token: int) -> Dictionary:
	var model:=host(id,token)
	if model==null: return {}
	var parts: Array=[]; var rig: Dictionary=model.rigs.entities[0]
	for index in rig.model_parts[0]: parts.append(rig.authored_names[int(index)])
	return {"type":5,"privateToken":token,"parts":parts,"loadedName":"c_dummy"}
func remove(id: int) -> void:
	if not entries.has(id): return
	object_array.remove(id)
	var row: Dictionary=entries[id]; entries.erase(id)
	if row.area: stats.area_retired+=1
	elif int(row.object.objectType)==8:
		if is_instance_valid(row.model): manager.release_model(row.model)
		stats.projectile_retired+=1
	else:
		row.object.destroyed=true
		if row.has("state"): row.state.model=null
		if is_instance_valid(row.model): manager.release_model(row.model)
		stats.retired+=1; stats.destroyed+=1; event({"kind":"dummyDestroy","id":id})
func _process(_delta: float) -> void:
	var began:=Timing.begin(); advance(); Timing.finish("callback_dummies",began)
func advance() -> void:
	if closed: return
	var now:Dictionary=_world_time()
	if now.is_empty(): return
	var ticks:=Time.get_ticks_usec(); var fade_failure:={"reason":""}; var providers:=_providers(ticks-previous_ticks,now,fade_failure); previous_ticks=ticks
	for id in entries.keys():
		if not entries[id].has("state") or not bool(entries[id].ai): continue
		var state:Dictionary=entries[id].state
		if int(state.fadeState)==int(state.fadeTarget) and int(state.delayEnabled)!=0:
			var elapsed:Dictionary=WorldTimer.subtract_world_times(now,state.since,manager.combat_timer.day_length)
			if not bool(elapsed.get("ready",false)) or not bool(elapsed.get("outputsDefined",false)): continue
		fade_failure.reason=""
		var expired:int=Fade.update(entries[id].state,providers)
		if not str(fade_failure.reason).is_empty():
			stats.failed+=1
			manager.diagnose("visual.projectile-dummy-update-failed",str(fade_failure.reason),int(id))
			remove(int(id))
			continue
		if expired!=0:
			entries[id].ai=false
			var deleted:Dictionary=object_array.remove(int(id))
			if int(deleted.status)==0 and deleted.object!=null: remove(int(id)); stats.expired+=1
func sample() -> Dictionary: return {"active":entries.size(),"stats":stats.duplicate(),"next_id":next_id,"clock":"native world timer"}
func snapshot() -> Dictionary:
	var active: Array=[]
	for row in entries.values():
		if bool(row.area) or int(row.object.objectType)!=5: continue
		var state:Dictionary=row.object
		active.append({"id":int(state.id),"position":state.position.duplicate(),"appearance":state.get("appearance",null),"temporary":int(state.temporary),"duration":int(state.duration),"registered":bool(row.ai)})
	return {"created":int(stats.created),"registered":int(stats.registered),"destroyed":int(stats.destroyed),"failed":int(stats.failed),"active":active,"events":events.duplicate(true)}
func close() -> void:
	if closed: return
	closed=true
	for id in entries.keys(): remove(int(id))
	set_process(false)
func _exit_tree() -> void: close()
