extends RefCounted
# Original mode1 hit visuals. Private creature slots, never authoritative
# effects, damage, inventory, object IDs or interaction/highlight entities.
const Blood=preload("res://systems/native_data/blood_visual.gd")
const Query=preload("res://systems/native_data/visual_definition.gd")
const Motion=preload("res://systems/network_motion.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const HP=preload("res://systems/native_data/client_presentation_hp.gd")
var manager
var hp_defaults: Dictionary={}
var hp_gain_requested:=false
var hp_failure_reported:=false
var owners: Dictionary={}
var queue: Array=[]
var history: Array=[]
var combat
var closed:=false
var stats:={"received":0,"started":0,"destroyed":0,"reused":0,"full_slots":0,"suppressed":0,"stale":0,"failed":0,"overflow":0,"ranged":0}
func configure(owner) -> void:
	manager=owner; combat=manager.world.get("combat")
	for name in ["ruleset","racialtypes","classes"]:
		manager.jobs[manager.assets.request(name,2017,"2da")]={"kind":"table","name":name}
	if is_instance_valid(combat): combat.engine.presentation_event.connect(combat_event)
func prepare_hp_defaults() -> bool:
	if not hp_defaults.is_empty(): return true
	for name in ["ruleset","racialtypes","classes"]:
		if not manager.tables.has(name): return false
	var gain:=HP.gain_table(manager.tables)
	if not gain.is_empty() and not manager.tables.has(gain):
		if not hp_gain_requested:
			hp_gain_requested=true
			manager.jobs[manager.assets.request(gain,2017,"2da")]={"kind":"table","name":gain}
		return false
	hp_defaults=HP.constructor(manager.tables)
	if hp_defaults.is_empty() and not hp_failure_reported:
		hp_failure_reported=true; manager.diagnose("blood.invalid-hp-constructor","Active client ability modifier increment is zero",0)
	return not hp_defaults.is_empty()
func event(kind: String,detail: Dictionary) -> void:
	if history.size()>=128: history.pop_front()
	var row:={"kind":kind,"at":Time.get_ticks_msec()}; row.merge(detail); history.append(row)
func gore() -> int:
	var node: Node=manager.world
	while node!=null:
		if node.has_meta("native_gore"): return int(node.get_meta("native_gore"))
		node=node.get_parent()
	return 1 # Original game.gore registration default, not inferred from damage.
func combat_event(value: Dictionary) -> void:
	if closed or str(value.kind)!="impact": return
	var target: Variant=manager.projectiles.object_view(int(value.id)); var source: Variant=manager.projectiles.object_view(int(value.sourceId))
	if target==null or source==null: stats.stale+=1; return
	var direction:=M.subtract(source.position,target.position)
	receive(int(target.id),value.record,direction,"impact",false)
func receive(id: int,record: Dictionary,direction: Array,part: String,ranged: bool=false) -> void:
	if closed: return
	if queue.size()>=128: stats.overflow+=1; return
	var target: Variant=manager.object(id)
	if target==null or int(target.objectType)!=5: stats.stale+=1; return
	var host=manager.host(id); var facing: Vector3=Motion.facing(target.get("replicated",{}).get("orientation",[1,0,0]))
	var motion=manager.world.get("motion")
	if motion!=null and motion.objects.has(id): facing=motion.objects[id].orientation
	var animation:=int(target.get("replicated",{}).get("animation",0))
	if is_instance_valid(combat): animation=int(combat.engine.states.get(id,{}).get("visual",animation))
	queue.append({"id":id,"lifetime":int(target.get("nativeLifetime",0)),"binding":host.get_instance_id() if is_instance_valid(host) else 0,"record":record.duplicate(true),"direction":M.values(direction),"part":part if not part.is_empty() else "impact","facing":[M.f(facing.x),M.f(facing.y),M.f(facing.z)],"animation":animation,"received":Time.get_ticks_msec(),"ranged":ranged})
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
func admit(request: Dictionary,target: Dictionary,host: Node3D) -> void:
	var id:=int(request.id)
	var providers:={"kind":func(actor):return int(actor.get("nativeField28",0)),"violence":gore,
		"blood":func(actor):return Query.query(manager.tables.appearance,int(actor.get("appearance",{}).get("appearance",65535))&65535,"BLOODCOLR","string").value,
		"maximum":func(actor):return HP.stored(actor,"maximum",hp_defaults),
		"whiteOverride":func(actor):var overrides: Array=actor.get("nativeBloodOverrides18",[]); return not overrides.is_empty() and int(overrides.back())!=0,
		"lowViolence":func(row):return Query.query(manager.tables.visualeffects,int(row),"LowViolence","integer"),
		"modelName":func(row):return Query.query(manager.tables.visualeffects,int(row),"Imp_Impact_Node","string").value,
		"warning":func(reason):manager.diagnose("blood."+str(reason),"Original hit visual selector could not select a resource",id)}
	var name: Variant=Blood.select(target,request.record,providers)
	if name==null: stats.suppressed+=1; return
	if str(name).is_empty(): manager.diagnose("blood.model-unavailable","Original hit visual selection returned an empty model reference",id); stats.failed+=1; return
	if not owners.has(id):
		if owners.size()>=128: stats.overflow+=1; return
		owners[id]={"lifetime":int(request.lifetime),"binding":host.get_instance_id(),"slots":[null,null,null]}
	var owner: Dictionary=owners[id]
	var reused: Array=[false]
	var index:=Blood.slot(owner.slots,{"playInfo":play_info,"destroy":func(entry):reused[0]=true; destroy(entry)})
	if index<0: stats.full_slots+=1; return
	stats.reused+=int(reused[0])
	var q:=Blood.orientation(request.facing,request.direction,int(request.animation),weapon_type(target,int(request.record.weaponAttackType)))
	if not q.all(func(value):return is_finite(float(value))): manager.diagnose("blood.orientation-unavailable","Original hit pose produced non-finite values",id); stats.failed+=1; return
	owner.slots[index]={"id":id,"index":index,"resource":str(name).to_lower(),"part":str(request.part),"quaternion":q,"model":null,"removed":false,"received":request.received}
	manager.ensure_models({str(name).to_lower():true}); event("reserved",{"actor":id,"slot":index,"resource":str(name).to_lower(),"part":request.part,"ranged":request.ranged})
func pump() -> void:
	var started:=0
	for id in owners:
		var owner: Dictionary=owners[id]
		for index in 3:
			var entry: Variant=owner.slots[index]
			if entry==null or entry.removed or is_instance_valid(entry.model) or started>=2 or not manager.ensure_models({entry.resource:true}): continue
			if str(manager.bundles[entry.resource].get("error","")).is_empty(): entry.model=manager.create_model(int(id),entry.resource)
			var host=manager.host(int(id)); var node: Node3D=host.physical_part(entry.part) if is_instance_valid(host) and host.has_method("physical_part") else manager.anchor(int(id),0,entry.part)
			if not is_instance_valid(entry.model) or node==null or not entry.model.attach_to(node,3):
				manager.diagnose("blood.model-or-anchor-unavailable",str(entry.resource)+" / "+str(entry.part),int(id)); stats.failed+=1; destroy(entry); owner.slots[index]=null; continue
			var q: Array=entry.quaternion; entry.model.quaternion=Quaternion(q[1],q[3],-q[2],q[0])
			if not entry.model.play_effect_clip("impact",1,1,0):
				manager.diagnose("blood.impact-clip-unavailable",entry.resource,int(id)); stats.failed+=1; destroy(entry); owner.slots[index]=null; continue
			started+=1; stats.started+=1; event("started",{"actor":id,"slot":index,"resource":entry.resource,"part":entry.part,"quaternion":q})
func advance() -> void:
	if closed: return
	for id in owners.keys():
		var owner: Dictionary=owners[id]; var target: Variant=manager.object(int(id)); var host=manager.host(int(id))
		if target==null or int(target.get("nativeLifetime",0))!=int(owner.lifetime) or not is_instance_valid(host) or host.get_instance_id()!=int(owner.binding): forget(int(id)); stats.stale+=1
	if not manager.tables.has("appearance") or not manager.tables.has("visualeffects") or not manager.projectiles.ranged_tables.has("baseitems") or not prepare_hp_defaults(): return
	var waiting: Array=[]
	for request in queue:
		var target: Variant=manager.object(int(request.id)); var host=manager.host(int(request.id))
		if target==null or int(target.get("nativeLifetime",0))!=int(request.lifetime) or int(request.binding)!=0 and (not is_instance_valid(host) or host.get_instance_id()!=int(request.binding)): stats.stale+=1; continue
		if not is_instance_valid(host):
			if Time.get_ticks_msec()-int(request.received)<5000: waiting.append(request)
			else: stats.stale+=1
			continue
		admit(request,target,host)
	queue=waiting; pump()
func snapshot() -> Dictionary:
	var slots: Array=[]
	for id in owners:
		slots.append({"actor":id,"slots":owners[id].slots.map(func(entry):return null if entry==null else {"resource":entry.resource,"part":entry.part,"ready":is_instance_valid(entry.model),"time":play_info(entry),"quaternion":entry.quaternion,"emitter_failures":entry.model.find_children("*","Node",true,false).filter(func(node):return node.has_method("detonate") and not node.failure.is_empty()).map(func(node):return node.failure) if is_instance_valid(entry.model) else []})})
	return {"stats":stats.duplicate(),"pending":queue.size(),"owners":slots,"events":history.duplicate(true),"private_hp_constructor":hp_defaults.duplicate(),"scope":"Original mode1 blood selection/three-slot reuse and private constructor HP with native assets; render-override defaults, asynchronous preparation, shape/clock and complete mixed-client parity remain separate acceptance"}
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(combat) and combat.engine.presentation_event.is_connected(combat_event): combat.engine.presentation_event.disconnect(combat_event)
	for id in owners.keys(): forget(int(id))
	queue.clear(); combat=null; manager=null
