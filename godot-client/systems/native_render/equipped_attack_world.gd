extends RefCounted
# Original equipped7fd6b0 slotFB, driven by the same body model events as
# unarmed specials. Models are private presentation owners, not registry Gobs.
const State=preload("res://systems/native_data/equipped_attack_visual.gd")
var manager
var combat
var closed:=false
var records: Dictionary={}
var warm: Dictionary={}
var history: Array=[]
var stats:={"events":0,"created":0,"destroyed":0,"stale":0,"deferred":0,"failed":0,"colours":0,"expired_pending":0}
func configure(owner) -> void:
	manager=owner; combat=manager.world.get("combat")
	if is_instance_valid(combat): combat.engine.presentation_event.connect(combat_event)
func detail(object: Dictionary,host) -> Dictionary:
	for entry in object.get("appearance",{}).get("equipment",[]):
		if int(entry.get("slot",0))!=16 or entry.get("item",{}).is_empty(): continue
		var definitions: Variant=host.get("equipment_visuals"); var definition: Dictionary=definitions.get(16,{}) if definitions is Dictionary else {}
		if definition.is_empty(): return {"pending":true}
		return {"pending":false,"definition":definition,"signature":[int(entry.get("id",-1)),int(definition.baseItem),str(definition.itemClass),int(definition.itemFlag2a8)]}
	return {}
func ready(id: int,object: Variant,host) -> bool:
	return object is Dictionary and is_instance_valid(host) and not host.retired and manager.world.desired.has(id) and str(manager.world.installed.get(id,""))==str(manager.world.desired[id].key)
func valid(record: Dictionary) -> bool:
	var object: Variant=manager.object(int(record.id)); var host=manager.host(int(record.id))
	if not ready(int(record.id),object,host) or int(object.get("nativeLifetime",0))!=int(record.lifetime) or host.get_instance_id()!=int(record.binding): return false
	var next:=detail(object,host)
	return not next.is_empty() and not next.get("pending",false) and next.signature==record.signature
func observe(object: Dictionary) -> void:
	if closed: return
	var id:=int(object.id); var host=manager.host(id)
	if not ready(id,object,host): return
	var info:=detail(object,host)
	if info.is_empty() or info.get("pending",false):
		if records.has(id): forget(id)
		warm.erase(id); return
	var signature: Array=[int(object.get("nativeLifetime",0)),host.get_instance_id(),info.signature]
	if warm.get(id,[])==signature: return
	warm[id]=signature
	if records.has(id) and not valid(records[id]): forget(id)
	if int(info.definition.modelType)==2:
		var resource:=State.resource(str(info.definition.itemClass))
		if not resource.is_empty() and manager.world.catalog.has_resource(resource,2002): manager.ensure_models({resource:true})
func event(kind: String,id: int,extra: Dictionary={}) -> void:
	if history.size()>=128: history.pop_front()
	var value:={"kind":kind,"actor":id}; value.merge(extra); history.append(value)
func combat_event(value: Dictionary) -> void:
	if closed or value.kind not in ["weapon-start","weapon-end"]: return
	var id:=int(value.id); var object: Variant=manager.object(id); var host=manager.host(id)
	if not ready(id,object,host): stats.stale+=1; return
	var info:=detail(object,host)
	if info.is_empty():
		if records.has(id): forget(id)
		return
	stats.events+=1
	if info.get("pending",false): stats.deferred+=1; manager.diagnose("weapon.equipped-definition-unavailable","Native held-model base-item metadata is not ready",id); return
	if records.has(id) and not valid(records[id]): forget(id); stats.stale+=1
	if not records.has(id): records[id]={"id":id,"lifetime":int(object.get("nativeLifetime",0)),"binding":host.get_instance_id(),"host":weakref(host),"signature":info.signature.duplicate(true),"definition":info.definition.duplicate(true),"state":{"enabled":0,"attackType":0},"wanted":false,"pending":false,"model":null}
	var record: Dictionary=records[id]
	if not record.has("colour_listener"):
		record.colour_listener=func(slot,scope,rgb):
			if slot==16 and is_instance_valid(record.model):
				if not record.model.rigs.set_model_colour_scope(0,0,scope,rgb): stats.failed+=1
		host.equipment_colour_changed.connect(record.colour_listener)
	record.state.attackType=int(value.get("attackType",0))&65535; record.wanted=value.kind=="weapon-start"
	if not record.wanted:
		if record.pending: stats.expired_pending+=1
		record.pending=false
	State.transition(record.state,1 if record.wanted else 0,record.definition,providers(record))
func providers(record: Dictionary) -> Dictionary:
	return {"exists":func(resource):return manager.world.catalog.has_resource(resource,2002),"load":func(resource,_slot,_flags):return load_model(record,resource),
		"configure":func(slot,a,b):
			if is_instance_valid(record.model): record.model.set_meta("native_weapon_slot_configuration",[slot,a,b]),
		"colour":func(rgb,scope,_flags):apply_colour(record,scope,rgb),"remove":func(_slot):remove_model(record),"clear_colour":func(scope):apply_colour(record,scope,null)}
func load_model(record: Dictionary,resource: String) -> bool:
	if not valid(record) or not record.wanted: return false
	if not manager.ensure_models({resource:true}): record.pending=true; stats.deferred+=1; return false
	record.pending=false
	if not str(manager.bundles[resource].get("error","")).is_empty(): stats.failed+=1; manager.diagnose("weapon.equipped-model-unavailable",resource,int(record.id)); return false
	var host: Object=record.host.get_ref(); var part: Node3D=host.equipment_part(16,"root")
	if part==null: stats.failed+=1; manager.diagnose("weapon.equipped-root-unavailable",resource,int(record.id)); return false
	var model=manager.create_model(int(record.id),resource)
	if not is_instance_valid(model): stats.failed+=1; return false
	if not model.attach_to(part,0,true): manager.release_model(model); stats.failed+=1; return false
	record.model=model
	var colours: Dictionary=host.equipment_colour_state(16)
	for scope in 5:
		if colours.active[scope] and not model.rigs.set_model_colour_scope(0,0,scope,colours.colours[scope]): stats.failed+=1
	stats.created+=1; event("load",int(record.id),{"resource":resource,"slot":251}); return true
func apply_colour(record: Dictionary,scope: int,rgb: Variant) -> void:
	var host: Object=record.host.get_ref()
	if is_instance_valid(host) and not host.retired and not host.equipment_colour_scope(16,scope,rgb): stats.failed+=1; manager.diagnose("weapon.equipped-colour-unavailable","Held model colour scope",int(record.id))
	if rgb!=null: stats.colours+=1
	event("colour" if rgb!=null else "clear-colour",int(record.id),{"scope":scope,"rgb":rgb})
func remove_model(record: Dictionary) -> void:
	if is_instance_valid(record.model): manager.release_model(record.model); stats.destroyed+=1; event("remove",int(record.id),{"slot":251})
	record.model=null
func forget(id: int) -> void:
	if not records.has(id): return
	var record: Dictionary=records[id]; record.pending=false; record.wanted=false
	remove_model(record); apply_colour(record,4,null); records.erase(id)
	var host: Object=record.host.get_ref()
	if is_instance_valid(host) and record.has("colour_listener") and host.equipment_colour_changed.is_connected(record.colour_listener): host.equipment_colour_changed.disconnect(record.colour_listener)
	# The listener captures this record. Disconnecting the signal alone leaves
	# a record -> Callable -> record cycle; break its retained binding too.
	record.erase("colour_listener")
func advance() -> void:
	if closed: return
	for id in records.keys():
		var record: Dictionary=records[id]
		if not valid(record): forget(int(id)); stats.stale+=1; continue
		if record.pending and record.wanted: State.transition(record.state,1,record.definition,providers(record))
	for id in warm.keys():
		if manager.object(int(id))==null: warm.erase(id)
func snapshot() -> Dictionary:
	return {"owners":records.size(),"models":records.values().filter(func(record):return is_instance_valid(record.model)).size(),"stats":stats.duplicate(),"events":history.duplicate(true),"scope":"Original equipped slotFB transition and colour-scope selection; native held-root/model lifecycle. Complete original shader/outer-clock and mixed-client visual acceptance remain open."}
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(combat) and combat.engine.presentation_event.is_connected(combat_event): combat.engine.presentation_event.disconnect(combat_event)
	for id in records.keys(): forget(int(id))
	warm.clear(); combat=null; manager=null
