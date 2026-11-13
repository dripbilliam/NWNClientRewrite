extends "res://systems/native_render/actor_instance.gd"
# Private animated physical Parts for received door state. No optimistic open
# state or local rule result is written back into the authoritative object.
const Names=preload("res://systems/native_data/object_animation.gd")
var _door_regions=preload("res://tools/native_parity/doors/door_pick_regions.gd").new()
var received_state:=-1
var received_animation:=-1
var pending_rest:=-1
var remaining:=0.0
var _transition_hover_active:=false
var transition_hover_unavailable:=""
var door_stats:={"updates":0,"transitions":0,"missing_clips":[]}
func install_door(bundle: Dictionary,shared_pool,id: int,state: Dictionary) -> bool:
	actor_alpha_enabled=true
	var map: Dictionary={}
	for code in [0,14,22,50,51,72,77,99,100,213,214,215,216,300,301,302,303,304]: map[str(code)]=Names.name(10,code,int(state.get("destroyedModel",0)))
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
func play_door(code: int,loop: bool) -> float:
	var length: float=rigs.clip_length(object_id,code)
	if length<=0:
		var clip:=Names.name(10,code)
		if not door_stats.missing_clips.has(clip): door_stats.missing_clips.append(clip)
		return 0
	if rigs.entities.has(object_id) and rigs.entities[object_id].models[0].has("native_owner"):
		# Once auxiliary Trans uses native Runs, the same existing owner must
		# receive future ordinary clips; its _update bypasses AnimationPlayer.
		if not rigs.play_native(object_id,0,rigs.clip_name(object_id,code),1.0,0 if loop else 1,0.0): return 0
	else: rigs.set_playback(object_id,code,1.0,loop,true)
	return length
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
	var next:=Names.door_state(state); var animation:=int(state.get("animation",-1))
	if next==received_state and animation==received_animation: return
	var previous:=received_state; received_state=next; received_animation=animation; door_stats.updates+=1
	if animation in [300,301,302,303,304]:
		pending_rest={300:50,301:51,302:22,303:22,304:72}[animation]; remaining=play_door(animation,false); return
	if next<0: return
	var rest: int={0:22,1:50,2:51,3:72}[next]
	if previous>=0 and previous!=next and next in [0,1,2] and previous in [0,1,2]:
		var transition: int=(303 if previous==2 else 302) if next==0 else (301 if next==2 else 300)
		remaining=play_door(transition,false); pending_rest=rest; door_stats.transitions+=1
		if remaining>0: return
	pending_rest=-1; play_door(rest,true)
func _process(delta: float) -> void:
	if retired or pending_rest<0: return
	remaining-=delta
	if remaining<=0:
		var rest:=pending_rest; pending_rest=-1; play_door(rest,true)
