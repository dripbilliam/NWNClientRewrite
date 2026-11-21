extends RefCounted
# Original mode1 hit visuals. Private creature slots, never authoritative
# effects, damage, inventory, object IDs or interaction/highlight entities.
const Blood=preload("res://systems/native_data/blood_visual.gd")
const Query=preload("res://systems/native_data/visual_definition.gd")
const SpellMetadata=preload("res://systems/native_data/spell_metadata.gd")
const M=preload("res://systems/native_render/particle_math.gd")
var manager
var owners: Dictionary={}
var queue: Array=[]
var history: Array=[]
var combat
var closed:=false
var stats:={"received":0,"started":0,"destroyed":0,"reused":0,"full_slots":0,"suppressed":0,"stale":0,"failed":0,"overflow":0,"ranged":0}
func configure(owner) -> void:
	manager=owner; combat=manager.world.get("combat")
	if is_instance_valid(combat): combat.engine.presentation_event.connect(combat_event)
func event(kind: String,detail: Dictionary) -> void:
	if history.size()>=128: history.pop_front()
	var row:={"kind":kind,"at":Time.get_ticks_msec()}; row.merge(detail); history.append(row)
func failure(id: int,reason: String,code: String="network.scene-blood-failed") -> void:
	if is_instance_valid(combat): combat.engine.failure(id,reason,code)
	else: manager.diagnose(code,reason,id)
func gore() -> int:
	var node: Node=manager.world
	while node!=null:
		if node.has_meta("native_gore"): return int(node.get_meta("native_gore"))
		node=node.get_parent()
	return 1 # Original game.gore registration default, not inferred from damage.
func combat_event(value: Dictionary) -> void:
	if closed or str(value.kind)!="impact": return
	var target: Variant=manager.object(int(value.id))
	var target_host: Node3D=manager.host(int(value.id))
	if target==null or not is_instance_valid(target_host): stats.stale+=1; return
	receive(int(target.id),value.record,[],"impact",false,int(value.sourceId))
func receive(id: int,record: Dictionary,direction: Array,part: String,ranged: bool=false,source_id: int=-1) -> void:
	if closed: return
	var target: Variant=manager.object(id)
	if target==null or int(target.objectType)!=5: stats.stale+=1; return
	var host=manager.host(id)
	if not is_instance_valid(host): stats.stale+=1; return
	queue.append({"id":id,"lifetime":int(target.get("nativeLifetime",0)),"binding":host.get_instance_id(),"record":record.duplicate(true),"direction":M.values(direction),"sourceId":source_id,"part":part if not part.is_empty() else "impact","received":Time.get_ticks_msec(),"ranged":ranged})
	stats.received+=1; stats.ranged+=int(ranged)
func destroy(entry: Dictionary) -> void:
	if entry.removed: return
	entry.removed=true
	if is_instance_valid(entry.model): manager.release_model(entry.model)
	entry.model=null; stats.destroyed+=1
func forget(id: int) -> void:
	if not owners.has(id): return
	for entry in owners[id].slots:
		if entry!=null: destroy(entry)
	owners.erase(id)
func play_info(entry: Dictionary,_clip: String="impact") -> float:
	if not is_instance_valid(entry.model): return 0.0 # Pending load owns its slot.
	var model: Dictionary=entry.model.rigs.entities[0].models[0]
	return Blood.play_info(model.native_owner.gob.runsE0,"impact") if model.has("native_owner") else -1.0
func weapon_type(object: Dictionary,kind: int) -> Variant:
	var slot:=int({1:16,2:32,3:16384,4:32768,5:65536,6:16}.get(kind,-1))
	for entry in object.get("appearance",{}).get("equipment",[]):
		if int(entry.slot)==slot: return int(Query.query(manager.projectiles.ranged_tables.baseitems,int(entry.item.baseItem),"WeaponType","integer").value)
	return null
func replicated_maximum(actor: Dictionary,missing: Array) -> int:
	var value: Variant=actor.get("replicated",{}).get("hitPoints",{}).get("maximum")
	if not (value is int or value is float and is_finite(value) and value==floor(value)):
		missing[0]=true
		return 0
	return int(value)
func admit(request: Dictionary,target: Dictionary,host: Node3D) -> void:
	var id:=int(request.id)
	var maximum_missing: Array=[false]
	var providers:={"kind":func(_actor):return 0,"violence":gore,
		"blood":func(actor):return SpellMetadata.native_string_entry(manager.tables.appearance,int(actor.get("appearance",{}).get("appearance",65535))&65535,"BLOODCOLR").value,
		"maximum":func(actor):return replicated_maximum(actor,maximum_missing),
		"whiteOverride":func(_actor):return false,
		"lowViolence":func(row):return Query.query(manager.tables.visualeffects,int(row),"LowViolence","integer"),
		"modelName":func(row):return SpellMetadata.native_string_entry(manager.tables.visualeffects,int(row),"Imp_Impact_Node").value,
		"warning":func(reason):failure(id,"Native appearance has no blood type" if reason=="missing-blood" else "Native blood violence setting is unknown","network.scene-blood-warning")}
	var name: Variant=Blood.select(target,request.record,providers)
	if maximum_missing[0]: failure(id,"Native maximum HP for blood selection is unavailable"); stats.failed+=1; return
	if name==null: stats.suppressed+=1; return
	if str(name).is_empty(): failure(id,"Native blood model reference is empty"); stats.failed+=1; return
	if owners.has(id) and (int(owners[id].lifetime)!=int(request.lifetime) or int(owners[id].binding)!=host.get_instance_id()): forget(id)
	if not owners.has(id):
		owners[id]={"lifetime":int(request.lifetime),"binding":host.get_instance_id(),"slots":[null,null,null]}
	var owner: Dictionary=owners[id]
	var reused: Array=[false]
	var index:=Blood.slot(owner.slots,{"playInfo":play_info,"destroy":func(entry):reused[0]=true; destroy(entry)})
	if index<0: stats.full_slots+=1; return
	stats.reused+=int(reused[0])
	var direction: Array=request.direction
	if int(request.sourceId)>=0:
		var source_host: Node3D=manager.host(int(request.sourceId))
		if not is_instance_valid(source_host): failure(id,"Native blood direction source pose is unavailable"); stats.failed+=1; return
		# Both old positions come from the displayed binding wrappers, not the replicated pose.
		var from: Vector3=source_host.position; var to: Vector3=host.position
		direction=[M.f(from.x-to.x),M.f(to.z-from.z),M.f(from.y-to.y)]
	var motion=manager.world.get("motion")
	if motion==null or not motion.objects.has(id): failure(id,"Native blood defender facing is unavailable"); stats.failed+=1; return
	var facing: Vector3=motion.objects[id].orientation
	var animation:=int(target.get("replicated",{}).get("animation",0))
	if is_instance_valid(combat): animation=int(combat.engine.states.get(id,{}).get("visual",animation))
	var q:=Blood.orientation([M.f(facing.x),M.f(facing.y),M.f(facing.z)],direction,animation,weapon_type(target,int(request.record.weaponAttackType)))
	if not q.all(func(value):return is_finite(float(value))): failure(id,"Native blood orientation produced nonfinite coordinates"); stats.failed+=1; return
	owner.slots[index]={"id":id,"index":index,"resource":str(name).to_lower(),"modelName":str(name),"part":str(request.part),"quaternion":q,"model":null,"removed":false,"received":request.received}
	manager.ensure_models({str(name).to_lower():true}); event("reserved",{"actor":id,"slot":index,"resource":str(name),"part":request.part,"ranged":request.ranged})
func pump() -> void:
	for id in owners:
		var owner: Dictionary=owners[id]
		for index in 3:
			var entry: Variant=owner.slots[index]
			if entry==null or entry.removed or is_instance_valid(entry.model) or not manager.ensure_models({entry.resource:true}): continue
			if str(manager.bundles[entry.resource].get("error","")).is_empty(): entry.model=manager.create_model(int(id),entry.resource)
			var host=manager.host(int(id)); var node: Node3D=host.physical_part(entry.part) if is_instance_valid(host) and host.has_method("physical_part") else manager.anchor(int(id),0,entry.part)
			if not is_instance_valid(entry.model) or node==null or not entry.model.attach_to(node,3):
				failure(int(id),"Native blood impact attachment node is unavailable"); stats.failed+=1; destroy(entry); owner.slots[index]=null; continue
			var q: Array=entry.quaternion; entry.model.quaternion=Quaternion(q[1],q[3],-q[2],q[0])
			if not entry.model.play_effect_clip("impact",1,1,0):
				failure(int(id),"Native blood impact clip is unavailable"); stats.failed+=1; destroy(entry); owner.slots[index]=null; continue
			stats.started+=1; event("started",{"actor":id,"slot":index,"resource":entry.modelName,"part":entry.part,"quaternion":q})
			if is_instance_valid(combat): combat.engine.event("blood-visual",int(id),{"model":entry.modelName,"slot":index,"quaternion":q})
func advance() -> void:
	if closed: return
	for id in owners.keys():
		var owner: Dictionary=owners[id]; var target: Variant=manager.object(int(id)); var host=manager.host(int(id))
		if target==null or bool(target.get("replicationRemoved",false)) or int(target.get("areaId",-1))!=int(manager.world.area_id) or int(target.get("nativeLifetime",0))!=int(owner.lifetime) or not is_instance_valid(host) or host.get_instance_id()!=int(owner.binding): forget(int(id)); stats.stale+=1
	if not manager.tables.has("appearance") or not manager.tables.has("visualeffects") or not manager.projectiles.ranged_tables.has("baseitems"): return
	for request in queue:
		var target: Variant=manager.object(int(request.id)); var host=manager.host(int(request.id))
		if target==null or bool(target.get("replicationRemoved",false)) or int(target.get("areaId",-1))!=int(manager.world.area_id) or int(target.get("nativeLifetime",0))!=int(request.lifetime) or not is_instance_valid(host) or host.get_instance_id()!=int(request.binding): stats.stale+=1; continue
		admit(request,target,host)
	queue.clear(); pump()
func client_snapshot() -> Array:
	var result: Array=[]
	for id in owners:
		var slots: Array=[]
		for entry in owners[id].slots:
			slots.append(null if entry==null else {"model":entry.modelName,"ready":is_instance_valid(entry.model),"time":play_info(entry) if is_instance_valid(entry.model) else null,"quaternion":entry.quaternion})
		result.append({"id":int(id),"slots":slots})
	return result
func snapshot() -> Dictionary:
	var slots: Array=[]
	for id in owners:
		slots.append({"actor":id,"slots":owners[id].slots.map(func(entry):return null if entry==null else {"resource":entry.resource,"part":entry.part,"ready":is_instance_valid(entry.model),"time":play_info(entry),"quaternion":entry.quaternion,"emitter_failures":entry.model.find_children("*","Node",true,false).filter(func(node):return node.has_method("detonate") and not node.failure.is_empty()).map(func(node):return node.failure) if is_instance_valid(entry.model) else []})})
	return {"stats":stats.duplicate(),"pending":queue.size(),"owners":slots,"events":history.duplicate(true),"scope":"Original mode1 blood selection and three-slot reuse with native assets"}
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(combat) and combat.engine.presentation_event.is_connected(combat_event): combat.engine.presentation_event.disconnect(combat_event)
	for id in owners.keys(): forget(int(id))
	queue.clear(); combat=null; manager=null
