extends "res://systems/native_render/actor_instance.gd"
# Private animated physical Parts for received door state. No optimistic open
# state or local rule result is written back into the authoritative object.
const Names=preload("res://systems/native_data/object_animation.gd")
const NetworkDoor=preload("res://systems/native_data/native_network_door.gd")
var _door_regions=preload("res://tools/native_parity/doors/door_pick_regions.gd").new()
var received_state:=-1
var received_animation:=-1
var pending_rest:=-1
var remaining:=0.0
var _transition_hover_active:=false
var transition_hover_unavailable:=""
var door_stats:={"updates":0,"transitions":0,"missing_clips":[]}
var animation_warning: Callable
var legacy_dwk_points: Array[Vector3]=[]
func configure_legacy_dwk(surface: Dictionary) -> void:
	legacy_dwk_points.clear()
	if surface.has("pick_points"):
		for point in surface.pick_points:
			if point is Array and point.size()>=3:legacy_dwk_points.append(Vector3(float(point[0]),float(point[1]),float(point[2])))
		return
	var states: Array=surface.get("states",[])
	if states.is_empty():return
	var closed: Dictionary=states[0]
	var vertices: Array=closed.get("vertices",[])
	for face in closed.get("faces",[]):
		for index in face:
			if int(index)<0 or int(index)>=vertices.size():continue
			var point: Vector3=vertices[int(index)]
			legacy_dwk_points.append(Vector3(point.x,point.z,-point.y))
func legacy_dwk_pick(origin: Vector3,end: Vector3) -> Dictionary:
	if retired or not is_inside_tree() or not is_visible_in_tree() or legacy_dwk_points.is_empty():return {}
	var low:=Vector3(INF,INF,INF)
	var high:=Vector3(-INF,-INF,-INF)
	for point in legacy_dwk_points:
		var world_point: Vector3=global_transform*point
		low=low.min(world_point);high=high.max(world_point)
	low-=Vector3.ONE*0.04;high+=Vector3.ONE*0.04
	var direction:=end-origin
	var enter: float=-INF
	var leave: float=INF
	for axis in 3:
		var position: float=origin[axis]
		var velocity: float=direction[axis]
		if absf(velocity)<0.0000001:
			if position<low[axis] or position>high[axis]:return {}
			continue
		var first: float=(low[axis]-position)/velocity
		var second: float=(high[axis]-position)/velocity
		enter=maxf(enter,minf(first,second));leave=minf(leave,maxf(first,second))
		if enter>leave:return {}
	var distance_fraction: float=enter if enter>=0 else leave
	if distance_fraction<0 or distance_fraction>1:return {}
	var point:=origin+direction*distance_fraction
	return {"position":point,"distance":origin.distance_to(point)}
func begin_install_door(bundle: Dictionary,shared_pool,id: int,state: Dictionary) -> bool:
	actor_alpha_enabled=true
	var map: Dictionary={}
	for code in [0,14,22,50,51,72,77,99,100,213,214,215,216,300,301,302,303,304]:map[str(code)]=Names.name(10,code,int(state.get("destroyedModel",0)))
	map["72"]="dead";map["305"]="opening3"
	var initial:=int(state.get("animation",{0:22,1:50,2:51,3:72}.get(Names.door_state(state),22)))
	return begin_install([{"bundle":bundle,"anchor":"","follow":true}],shared_pool,id,{"0":map},initial)
func finish_install_door(bundle: Dictionary,state: Dictionary) -> void:
	_door_regions.configure(self,bundle,rigs,object_id)
	observe_door(state)
func install_door(bundle: Dictionary,shared_pool,id: int,state: Dictionary) -> bool:
	actor_alpha_enabled=true
	var map: Dictionary={}
	for code in [0,14,22,50,51,72,77,99,100,213,214,215,216,300,301,302,303,304]: map[str(code)]=Names.name(10,code,int(state.get("destroyedModel",0)))
	map["72"]="dead";map["305"]="opening3"
	var initial:=int(state.get("animation",{0:22,1:50,2:51,3:72}.get(Names.door_state(state),22)))
	if not install([{"bundle":bundle,"anchor":"","follow":true}],shared_pool,id,{"0":map},initial): return false
	_door_regions.configure(self,bundle,rigs,id)
	observe_door(state); return true
func native_door_pick(origin: Vector3,end: Vector3) -> Dictionary:return _door_regions.pick(origin,end)
func native_door_pick_snapshot() -> Dictionary:return _door_regions.snapshot()
func retire() -> void:
	_transition_hover_active=false # Actor retirement closes all native runs.
	_door_regions.retire()
	super.retire()
func door_clip_available(code: int) -> bool:
	if rigs==null or not rigs.entities.has(object_id):return false
	var name: String=rigs.clip_name(object_id,code)
	if name.is_empty():return false
	for model in rigs.entities[object_id].models:
		if model.get("follow",false) and (model.get("names",{}).has(name) or not rigs._deferred_clip(model,name).is_empty()):return true
	return false
func door_clip_length(code: int) -> float:
	if rigs==null or not rigs.entities.has(object_id):return 0.0
	var name: String=rigs.clip_name(object_id,code)
	for model in rigs.entities[object_id].models:
		if not model.get("follow",false):continue
		var deferred: Dictionary=rigs._deferred_clip(model,name)
		if not deferred.is_empty():return float(deferred.length)
		if model.get("names",{}).has(name):return float(model.player.get_animation(model.names[name]).length)
	return 0.0
func warn_animation(code: String,animation: int) -> void:
	if animation_warning.is_valid():animation_warning.call(code,animation)
func play_door(code: int,loop: bool) -> float:
	var available:=door_clip_available(code)
	var length: float=door_clip_length(code)
	if not available:
		var clip: String=str(rigs.clip_name(object_id,code))
		if not door_stats.missing_clips.has(clip): door_stats.missing_clips.append(clip)
		return 0
	if rigs.entities.has(object_id) and rigs.entities[object_id].models[0].has("native_owner"):
		# Once auxiliary Trans uses native Runs, the same existing owner must
		# receive future ordinary clips; its _update bypasses AnimationPlayer.
		if not rigs.play_native(object_id,0,rigs.clip_name(object_id,code),1.0,0 if loop else 1,0.0): return 0
	else: rigs.set_playback(object_id,code,1.0,loop,true)
	return length
func pose_door(code: int) -> bool:
	if not door_clip_available(code):return false
	var length: float=door_clip_length(code)
	var model: Dictionary=rigs.entities[object_id].models[0]
	if model.has("native_owner"):
		if not rigs.play_native(object_id,0,rigs.clip_name(object_id,code),0.0,1,length):return false
		rigs._update(0.0)
	else:
		rigs.set_playback(object_id,code,0.0,false,true)
		if model.player!=null:
			model.player.seek(length,true)
			model.player.stop(true)
	return true
func begin_transition_hover() -> bool:
	if retired or rigs==null or not rigs.entities.has(object_id) or received_state not in [1,2,3]: return false
	if _transition_hover_active: return true
	var model: Dictionary=rigs.entities[object_id].models[0]
	transition_hover_unavailable=""
	# Never hand an otherwise working AnimationPlayer to an empty native owner
	# when ASCII/inherited controller storage is explicitly unavailable.
	if not _native_hover_clip_ready(model,"trans"):return false
	if not model.has("native_owner"):
		# play_native starts a new run owner, not a copy of AnimationPlayer's
		# current state. Seed the actual ordinary clip/clock before adding Trans.
		var clip:=str(model.get("clip",""))
		if not _native_hover_clip_ready(model,clip):return false
		var at:=float(model.get("last_time",0.0))
		if model.player!=null and model.player.is_playing() and not model.player.current_animation.is_empty(): at=model.player.current_animation_position
		# This run was already playing. Flag2 retains full initial weight instead
		# of inventing another transition from the static pose during handoff.
		if clip.is_empty() or not rigs.play_native(object_id,0,clip,float(model.get("speed",1.0)),2 if model.get("loop",false) else 3,at): return false
	if retired or not rigs.entities.has(object_id): return false
	if not rigs.play_native(object_id,0,"Trans",1.0,8,0.0):
		if not door_stats.missing_clips.has("trans"): door_stats.missing_clips.append("trans")
		return false
	if retired or not rigs.entities.has(object_id): return false
	_transition_hover_active=true
	# NativePose initialization writes authored static fields. Publish the seeded
	# current run now, not one frame of that default pose before ordinary _update.
	rigs._update(0.0)
	return true
func _native_hover_clip_ready(model: Dictionary,clip: String) -> bool:
	var native: Variant=model.get("asset_source",{}).get("nativeAnimation")
	var descriptor: Variant=native.get("clips",{}).get(clip.to_lower()) if native is Dictionary else null
	if descriptor is Dictionary and descriptor.get("root") is Dictionary:return true
	transition_hover_unavailable=str(descriptor.get("unavailable","Native clip/controller storage unavailable")) if descriptor is Dictionary else "Native clip/controller storage unavailable: "+clip
	return false
func end_transition_hover() -> bool:
	if not _transition_hover_active: return true
	_transition_hover_active=false
	if retired or rigs==null or not rigs.entities.has(object_id): return false
	var removed: bool=rigs.play_native(object_id,0,"Trans",0.0,128,0.0)
	if retired or not rigs.entities.has(object_id): return false
	# Native area7e7540 restores CURRENT open state, not the pre-hover state or
	# an old pending opening/closing completion.
	var rest: int={0:22,1:50,2:51,3:72}.get(received_state,-1)
	if rest<0: return false
	pending_rest=-1
	remaining=0.0
	return play_door(rest,true)>0 and removed
func snapshot_transition_hover() -> Dictionary:
	var runs: Array=[]
	if not retired and rigs!=null and rigs.entities.has(object_id):
		var model: Dictionary=rigs.entities[object_id].models[0]
		if model.has("native_owner"):
			for run in model.native_owner.gob.runsE0:
				runs.append({"clip":str(run.clip0.name),"flags":int(run.flagsC),"time":float(run.time14),"weight":float(run.weight18)})
	return {"active":_transition_hover_active,"retired":retired,"object_id":object_id,"received_state":received_state,"received_animation":received_animation,"pending_rest":pending_rest,"runs":runs,"unavailable":transition_hover_unavailable}
func observe_door(state: Dictionary) -> void:
	if retired or rigs==null: return
	var visual_state:Variant=NetworkDoor.state(state.get("animation"))
	var next:int=int(visual_state) if visual_state!=null else -1
	var animation:=int(state.get("animation",-1))
	if next==received_state and animation==received_animation: return
	var previous:=received_state; received_state=next; received_animation=animation; door_stats.updates+=1
	if next<0:
		warn_animation("network.scene-object-animation-unhandled",animation)
		return
	var rest: int={0:22,1:50,2:51,3:72}[next]
	if not door_clip_available(rest):
		warn_animation("network.scene-animation-unavailable",animation)
		return
	if previous>=0:
		var transition: int=(303 if previous==2 else 302) if next==0 else (305 if next==3 else (301 if next==2 else 300))
		remaining=play_door(transition,false); pending_rest=rest; door_stats.transitions+=1
		if remaining>0: return
	pending_rest=-1; pose_door(rest)
func _process(delta: float) -> void:
	if retired or pending_rest<0: return
	remaining-=delta
	if remaining<=0:
		var rest:=pending_rest; pending_rest=-1; pose_door(rest)
