extends RefCounted
# Local original hit callback -> original area visual; never a server effect
# packet, damage result, canonical entity or fallback attack-record target.
const Parry=preload("res://systems/native_data/parry_visual.gd")
const MovementRate=preload("res://systems/native_data/native_movement_rate.gd")
const M=preload("res://systems/native_render/particle_math.gd")
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
	var message: String="Native parry actor has no impact node" if reason=="missing-impact" else "Native parry impact height exceeds five metres"
	if is_instance_valid(combat):combat.engine.failure(id,message,"network.scene-parry-warning")
	else:manager.diagnose("network.scene-parry-warning",message,id)
func failure(id: int,reason: String) -> void:
	if is_instance_valid(combat):combat.engine.failure(id,reason,"network.scene-combat-effect-unhandled")
	else:manager.diagnose("network.scene-combat-effect-unhandled",reason,id)
static func displayed_position(host: Node3D) -> Array:
	return [M.f(host.position.x),M.f(-host.position.z),M.f(host.position.y)]
func receive(id: int) -> int:
	if closed: return 0
	stats.received+=1
	if queue.size()>=128: stats.overflow+=1; return 0
	var source: Variant=manager.projectiles.object_view(id)
	if source==null: stats.stale+=1; return 0
	var target_id:=int(source.get("replicated",{}).get("facingTarget",0x7f000000)); var target: Variant=manager.projectiles.object_view(target_id)
	if target==null or int(target.objectType)!=5: stats.suppressed+=1; return 0
	var host=manager.host(id); var position: Array=[0.0,0.0,0.0]; var q: Array=[1.0,0.0,0.0,0.0]
	if not is_instance_valid(host):warn("missing-impact",id);stats.failed+=1;return 0
	var pose_result:=int(manager.projectiles.node_pose(host,"impact",position,q))
	if pose_result<0:failure(id,manager.projectiles.take_part_query_failure());stats.failed+=1;return 0
	if pose_result==0:warn("missing-impact",id);stats.failed+=1;return 0
	var target_host=manager.host(target_id)
	if not is_instance_valid(target_host):failure(id,"Native parry source/target displayed position is unavailable");stats.failed+=1;return 0
	var motion=manager.world.get("motion")
	if motion==null or not motion.objects.has(id):failure(id,"Native parry displayed facing is unavailable");stats.failed+=1;return 0
	var facing:Vector3=motion.objects[id].orientation
	queue.append({"source":source,"target":target,"facing":[facing.x,facing.y,facing.z],"impact":position,"sourcePosition":displayed_position(host),"targetPosition":displayed_position(target_host),"binding":host.get_instance_id(),"targetBinding":target_host.get_instance_id(),"received":Time.get_ticks_msec()})
	if manager.tables.has("appearance") and manager.tables.has("visualeffects"):advance()
	return 1
func advance() -> void:
	if closed or not manager.tables.has("appearance") or not manager.tables.has("visualeffects"): return
	for request in queue:
		var source: Dictionary=request.source; var target: Dictionary=request.target; var id:=int(source.id); var current: Variant=manager.object(id); var current_target: Variant=manager.object(int(target.id)); var host=manager.host(id); var target_host=manager.host(int(target.id))
		if current==null or current_target==null or int(current.get("nativeLifetime",0))!=int(source.get("nativeLifetime",0)) or int(current_target.get("nativeLifetime",0))!=int(target.get("nativeLifetime",0)) or not is_instance_valid(host) or host.get_instance_id()!=int(request.binding) or not is_instance_valid(target_host) or target_host.get_instance_id()!=int(request.targetBinding): stats.stale+=1; continue
		var space:=MovementRate.native_float_entry(manager.tables.appearance,int(target.get("appearance",{}).get("appearance",65535))&65535,"CREPERSPACE")
		var effect: Array=[0]; var point_out: Array=[]
		var outcome:=Parry.place(source,{"targetId":func(_actor):return int(target.id),"object":func(_id):return target,"creatureSpace":func(_target):return space.value,
			"impactPose":func(_actor):return request.impact,"position":func(actor):return request.sourcePosition if int(actor.id)==id else request.targetPosition,"orientation":func(_actor):return request.facing,"warning":func(reason):warn(str(reason),id),
			"areaVisual":func(_actor,visual,point):
				if manager.closed:return 0
				point_out.assign(point)
				effect[0]=manager.create_area_visual({"visualId":visual,"position":point})
				if is_instance_valid(combat):combat.engine.event("parry-visual",id,{"visualId":visual,"position":point.duplicate()})
				return 1})
		if outcome==0: stats.failed+=1; continue
		stats.spawned+=1
		if history.size()>=128: history.pop_front()
		history.append({"source":id,"target":int(target.id),"effect":effect[0],"at":Time.get_ticks_msec(),"sourcePosition":request.sourcePosition,"targetPosition":request.targetPosition,"impact":request.impact,"orientation":request.facing,"space":space.value,"position":point_out.duplicate()})
	queue.clear()
func snapshot() -> Dictionary: return {"stats":stats.duplicate(),"pending":queue.size(),"events":history.duplicate(true),"scope":"Original mode0 spark placement from facing target into private type11 area visual; full weapon/shield/audio/clock and paired-client parity remain open"}
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(combat) and combat.engine.presentation_event.is_connected(combat_event): combat.engine.presentation_event.disconnect(combat_event)
	queue.clear(); combat=null; manager=null
