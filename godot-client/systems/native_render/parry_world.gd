extends RefCounted
# Local original hit callback -> original area visual; never a server effect
# packet, damage result, canonical entity or fallback attack-record target.
const Parry=preload("res://systems/native_data/parry_visual.gd")
const Query=preload("res://systems/native_data/visual_definition.gd")
const Motion=preload("res://systems/network_motion.gd")
var manager
var combat
var closed:=false
var queue: Array=[]
var history: Array=[]
var stats:={"received":0,"spawned":0,"suppressed":0,"stale":0,"failed":0,"overflow":0}
func configure(owner) -> void:
	manager=owner; combat=manager.world.get("combat")
	if is_instance_valid(combat): combat.engine.presentation_event.connect(combat_event)
func combat_event(value: Dictionary) -> void:
	if not closed and str(value.kind)=="parry": receive(int(value.id))
func warn(reason: String,id: int) -> void:
	manager.diagnose("parry."+reason,"Original parry visual placement boundary: "+reason,id)
func receive(id: int) -> int:
	if closed: return 0
	stats.received+=1
	if queue.size()>=128: stats.overflow+=1; return 0
	var source: Variant=manager.projectiles.object_view(id)
	if source==null: stats.stale+=1; return 0
	var target_id:=int(source.get("replicated",{}).get("facingTarget",0x7f000000)); var target: Variant=manager.projectiles.object_view(target_id)
	if target==null or int(target.objectType)!=5: stats.suppressed+=1; return 0
	var host=manager.host(id); var position: Array=[0.0,0.0,0.0]; var q: Array=[1.0,0.0,0.0,0.0]
	if not is_instance_valid(host) or manager.projectiles.node_pose(host,"impact",position,q)==0: warn("missing-impact",id); stats.failed+=1; return 0
	var motion=manager.world.get("motion"); var facing: Vector3
	if motion!=null and motion.objects.has(id): facing=motion.objects[id].orientation
	elif source.get("replicated",{}).has("orientation"): facing=Motion.facing(source.replicated.orientation)
	else: warn("facing-unavailable",id); stats.failed+=1; return 0
	queue.append({"source":source,"target":target,"facing":[facing.x,facing.y,facing.z],"impact":position,"binding":host.get_instance_id(),"received":Time.get_ticks_msec()})
	return 1
func advance() -> void:
	if closed or not manager.tables.has("appearance") or not manager.tables.has("visualeffects"): return
	for request in queue:
		var source: Dictionary=request.source; var target: Dictionary=request.target; var id:=int(source.id); var current: Variant=manager.object(id); var current_target: Variant=manager.object(int(target.id)); var host=manager.host(id)
		if current==null or current_target==null or int(current.get("nativeLifetime",0))!=int(source.get("nativeLifetime",0)) or int(current_target.get("nativeLifetime",0))!=int(target.get("nativeLifetime",0)) or not is_instance_valid(host) or host.get_instance_id()!=int(request.binding): stats.stale+=1; continue
		var space:=Query.query(manager.tables.appearance,int(target.get("appearance",{}).get("appearance",65535))&65535,"CREPERSPACE","float")
		if not space.found: warn("creature-space-unavailable",id); stats.failed+=1; continue
		var effect: Array=[0]; var outcome:=Parry.place(source,{"targetId":func(_actor):return int(target.id),"object":func(_id):return target,"creatureSpace":func(_target):return space.value,
			"impactPose":func(_actor):return request.impact,"position":func(actor):return actor.position,"orientation":func(_actor):return request.facing,"warning":func(reason):warn(str(reason),id),
			"areaVisual":func(_actor,visual,point):effect[0]=manager.create_area_visual({"visualId":visual,"position":point}); return 1 if effect[0]>0 else 0})
		if outcome==0: stats.failed+=1; continue
		stats.spawned+=1
		if history.size()>=128: history.pop_front()
		history.append({"source":id,"target":int(target.id),"effect":effect[0],"at":Time.get_ticks_msec(),"sourcePosition":source.position,"targetPosition":target.position,"impact":request.impact,"orientation":request.facing,"space":space.value,"position":manager.records[effect[0]].definition.state.position})
	queue.clear()
func snapshot() -> Dictionary: return {"stats":stats.duplicate(),"pending":queue.size(),"events":history.duplicate(true),"scope":"Original mode0 spark placement from facing target into private type11 area visual; full weapon/shield/audio/clock and paired-client parity remain open"}
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(combat) and combat.engine.presentation_event.is_connected(combat_event): combat.engine.presentation_event.disconnect(combat_event)
	queue.clear(); combat=null; manager=null
