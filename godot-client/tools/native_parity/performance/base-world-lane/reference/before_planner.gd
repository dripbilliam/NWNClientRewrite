extends RefCounted
var closed:=false
var retiring:=false
var stats:={"errors":[]}
var controlled_id:=1
var area_id:=1
var desired: Dictionary={}
var installed: Dictionary={}
var failed_objects: Dictionary={}
var instances: Dictionary={}
var batches: Array=[]
var control_ready:=false
var terrain_ready:=false
var has_priority_origin:=true
var priority_origin:=Vector3.ZERO
var entry_prefetch_enabled:=true
var entry_prefetch_limit:=8
var entry_prefetch_radius:=20.
var maximum_static_batch:=64
var maximum_actor_batch:=32
var maximum_stream_wave:=64
func ready_for_control() -> bool:return control_ready
func ready_for_admission() -> bool:return terrain_ready
func object_pose(object: Dictionary) -> Dictionary:
	var value: Variant=object.get("replicated",{}).get("position",object.get("staticState",{}).get("position"))
	if not value is Array or value.size()!=3:return {}
	for part in value:
		if not (part is int or part is float) or not is_finite(float(part)):return {}
	return {"position":Vector3(value[0],value[2],-value[1])}
func pending_plan(inflight: Dictionary) -> Dictionary:
	var plan:={"actors":[],"statics":[]}
	if closed or retiring or not stats.errors.is_empty(): return plan
	# Terrain and the complete controlled actor (including equipment) own the
	# first preparation window. Area-ready still releases original server player
	# replication; waiting for that player before the protocol ack would deadlock.
	if desired.has(controlled_id) and installed.get(controlled_id,"")!=desired[controlled_id].key and not inflight.has(controlled_id):
		plan.actors.append(desired[controlled_id].object); return plan
	var before_control:=not ready_for_control()
	if batches.size()>=2: return plan
	var origin:=Vector3.ZERO
	if before_control:
		# The exclusive player request has already started and terrain owns its
		# admission gate. At most one nearby scenery owner can overlap that job;
		# remote actor/supermodel work cannot consume this initial window.
		if not entry_prefetch_enabled or int(stats.get("entry_prefetch_batches",0))>0 or not ready_for_admission() or not inflight.has(controlled_id) or not desired.has(controlled_id): return plan
		var controlled_pose:=object_pose(desired[controlled_id].object)
		if controlled_pose.is_empty(): return plan
		origin=controlled_pose.position
	else: origin=instances[controlled_id].position
	var candidates: Array=[]
	for id in desired:
		var wanted: Dictionary=desired[id]
		if before_control and int(wanted.object.objectType) not in [9,10]: continue
		if str(installed.get(id,""))==str(wanted.key): continue
		# Keep failure distinct from hidden or installed. An appearance change,
		# removal/recreation or new world scope may try again; snapshots alone do not.
		if failed_objects.has(id) and str(failed_objects[id].key)==str(wanted.key): continue
		if inflight.has(id): continue
		var placement:=object_pose(wanted.object)
		if placement.is_empty(): continue
		var distance:=origin.distance_squared_to(placement.position)
		if before_control and distance>entry_prefetch_radius*entry_prefetch_radius: continue
		var entry:={"object":wanted.object,"distance":distance}
		candidates.append(entry)
	var nearer:=func(a,b):return a.distance<b.distance or (a.distance==b.distance and int(a.object.id)<int(b.object.id))
	candidates.sort_custom(nearer)
	var owner_slots:=1 if before_control else 2-batches.size()
	# One shared distance wave: far-away actors cannot jump ahead merely because
	# their category still has room. Completed work never waits on a slow model.
	for entry in candidates.slice(0,mini(maximum_stream_wave,entry_prefetch_limit) if before_control else maximum_stream_wave):
		var group: Array=plan.actors if int(entry.object.objectType) in [5,6] else plan.statics
		var limit:=maximum_actor_batch if int(entry.object.objectType) in [5,6] else maximum_static_batch
		if group.size()>=limit or group.is_empty() and owner_slots<=0: continue
		if group.is_empty(): owner_slots-=1
		group.append(entry.object)
	# Keep at most two background owners; reserve the third slot for a changed
	# controlled appearance even while scenery and other actors are streaming.
	return plan
