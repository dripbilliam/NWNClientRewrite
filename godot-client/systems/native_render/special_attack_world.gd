extends RefCounted
# Original unarmed special-attack slots, driven by original body model events.
# Equipped weapon modelFB/colour is owned by equipped_attack_world.gd.
const State=preload("res://systems/native_data/special_attack_visual.gd")
const Init=preload("res://systems/native_data/special_initialization.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
var manager
var combat
var records: Dictionary={}
var handles: Dictionary={}
var serial:=0
var closed:=false
var warm_signature: Array=[]
var history: Array=[]
var stats:={"events":0,"created":0,"loaded":0,"destroyed":0,"failed":0,"stale":0,"overflow":0,"equipped_events":0,"initializations":0,"eye_updates":0,"missing_clip_requests":0}
func configure(owner) -> void:
	manager=owner; combat=manager.world.get("combat")
	if is_instance_valid(combat): combat.engine.presentation_event.connect(combat_event)
func observe(object: Dictionary) -> void:
	if closed: return
	var id:=int(object.get("id",-1)); var host=manager.host(id)
	if records.has(id) and not valid(records[id]): forget(id); stats.stale+=1
	if is_instance_valid(host) and not host.retired and manager.world.desired.has(id) and str(manager.world.installed.get(id,""))==str(manager.world.desired[id].key):
		var feats:=Rules.collect_feats(object); var classes: Array=object.get("replicated",{}).get("stats",{}).get("classes",[])
		if records.has(id) or State.gate(classes,[feats],0)==1 or State.gate(classes,[feats],1)==1:
			if not records.has(id): records[id]=new_record(object,host)
			var r: Dictionary=records[id]; r.source=object
			var context: Dictionary=host.rigs.entities.get(id,{}).get("context",{})
			var signature: Array=[classes,feats,object.get("appearance",{}).get("appearance",-1),object.get("appearance",{}).get("gender",0),object.get("appearance",{}).get("phenotype",0),object.get("replicated",{}).get("stats",{}).get("fieldDE4"),context.get("fieldDD",0),manager.tables.has("appearance")]
			if r.initial_signature!=signature and initialize_record(r): r.initial_signature=signature.duplicate(true); r.initialize_elapsed=0.0
	if id!=int(manager.world.controlled_id): return
	var feats:=Rules.collect_feats(object); var signature: Array=[int(object.id),int(object.get("nativeLifetime",0)),feats.has(213),feats.has(39),feats.has(296)]
	if signature==warm_signature: return
	warm_signature=signature
	# Warm immutable resources for disclosed owned abilities, without creating
	# scene instances or withholding control. A short first blur window must
	# not expire while its first-ever original model is still being decoded.
	var resources: Dictionary={}
	if signature[2]: resources.vcm_monkki=true
	if signature[3]: resources.vcm_monkstun=true
	if signature[4]: resources.vcm_monkquiv=true
	if not resources.is_empty(): manager.ensure_models(resources)
func event(kind: String,detail: Dictionary) -> void:
	if history.size()>=128: history.pop_front()
	var row:={"kind":kind,"at":Time.get_ticks_msec()}; row.merge(detail); history.append(row)
func valid(r: Dictionary) -> bool:
	var object: Variant=manager.object(int(r.id)); var host=manager.host(int(r.id))
	return object!=null and int(object.get("nativeLifetime",0))==int(r.lifetime) and is_instance_valid(host) and not host.retired and host.get_instance_id()==int(r.binding) and str(manager.world.desired[int(r.id)].key)==str(r.appearance_key) and str(manager.world.installed.get(int(r.id),""))==str(r.appearance_key)
func new_record(object: Dictionary,host) -> Dictionary:
	var id:=int(object.id)
	return {"id":id,"lifetime":int(object.get("nativeLifetime",0)),"binding":host.get_instance_id(),"appearance_key":str(manager.world.desired[id].key),"state":State.create(),"eye":Init.create_eye(),"eye_deferred":false,"animation":0,"source":object,"initial_signature":[],"initialize_elapsed":0.0}
func initialize_record(r: Dictionary) -> bool:
	if not valid(r): return false
	# Missing eye-specific data must neither invent its model nor block the
	# independent paired-ki initialization. Changed metadata retries the eyes.
	r.eye_deferred=not manager.tables.has("appearance") or not r.source.get("replicated",{}).get("stats",{}).has("fieldDE4")
	var host=manager.host(int(r.id)); r.animation=int(host.rigs.entities.get(int(r.id),{}).get("animation",0))
	Init.initialize(r.state,providers(r)); stats.initializations+=1
	return true
func eye(r: Dictionary) -> void:
	if r.eye_deferred: return
	var appearance: Dictionary=r.source.get("appearance",{}); var raw:=int(r.source.replicated.stats.fieldDE4)&65535
	var alignment:=clampi(raw-65536 if raw>=32768 else raw,0,100)
	Init.eye(r.eye,alignment,int(appearance.get("appearance",65535)),int(appearance.get("gender",0)),int(appearance.get("phenotype",0)),providers(r)); stats.eye_updates+=1
func combat_event(value: Dictionary) -> void:
	if closed or value.kind not in ["weapon-start","weapon-end"]: return
	stats.events+=1; var id:=int(value.id); var object: Variant=manager.object(id); var host=manager.host(id)
	if object==null or not is_instance_valid(host) or host.retired: stats.stale+=1; return
	if records.has(id) and not valid(records[id]): forget(id); stats.stale+=1
	if not manager.world.desired.has(id) or str(manager.world.installed.get(id,""))!=str(manager.world.desired[id].key): stats.stale+=1; return
	if not records.has(id): records[id]=new_record(object,host)
	var r: Dictionary=records[id]; var state: Dictionary=combat.engine.states.get(id,{}) if is_instance_valid(combat) else {}
	r.source=object; r.animation=int(value.get("animation",state.get("visual",0))); r.state.attackType=int(value.get("attackType",state.get("attackType",0)))&65535
	var right: Array=object.get("appearance",{}).get("equipment",[]).filter(func(item):return int(item.get("slot",0))==16 and not item.get("item",{}).is_empty())
	if not right.is_empty():
		stats.equipped_events+=1; return # Separate equipped7fd6b0 owner consumes the same original event.
	State.unarmed(r.state,1 if value.kind=="weapon-start" else 0,providers(r))
func providers(r: Dictionary) -> Dictionary:
	return {"animation":func():return int(r.animation),"modelPart":func(slot):return int(manager.host(int(r.id)).body_model_scopes.has(int(slot))),"sourceModel":func(_slot,_flags):return manager.host(int(r.id)),
		"gate":func(mode):return State.gate(r.source.get("replicated",{}).get("stats",{}).get("classes",[]),[Rules.collect_feats(r.source)],int(mode)),
		"present":func():return is_instance_valid(manager.host(int(r.id))),"style":func():return int(manager.host(int(r.id)).rigs.entities.get(int(r.id),{}).get("context",{}).get("fieldDD",0)),"eyes":func():eye(r),
		"create":func(resource,name):return create_handle(r,resource,name),
		"attach":func(handle,_source,part,flags):command(handle,{"kind":"attach","part":part,"flags":flags}),
		"scale_entry":scale_entry,"scale":func(handle,value,flags):command(handle,{"kind":"scale","value":value,"flags":flags}),
		"play":func(handle,clip,speed,flags,time):command(handle,{"kind":"play","clip":clip,"speed":speed,"flags":flags,"time":time}),
		"warning":func(reason):manager.diagnose("weapon.special-attack-boundary",str(reason),int(r.id)),"destroy":destroy_handle}
func scale_entry(index: int,column: String) -> Dictionary:
	var rows: Array=manager.tables.get("appearance",{}).get("orderedRows",[])
	var value:=str(rows[index].get(column,"")) if index>=0 and index<rows.size() else ""
	return {"found":value.is_valid_float(),"value":float(value) if value.is_valid_float() else 1.0}
func create_handle(r: Dictionary,resource: String,name: String) -> Variant:
	if handles.size()>=256: stats.overflow+=1; return null
	serial+=1; var h:={"id":serial,"actor":int(r.id),"resource":resource,"name":name,"model":null,"commands":[],"part":"","destroyed":false}
	handles[serial]=h; stats.created+=1
	# NewCAurObject is synchronous on the original blur callback. When native
	# data is already warm, attach/play in that callback too: delaying until
	# priority45 can let a short blur_end overtake the first particle update.
	if manager.ensure_models({resource:true}) and str(manager.bundles[resource].get("error","")).is_empty():
		h.model=manager.create_model(int(r.id),resource)
		if is_instance_valid(h.model): stats.loaded+=1
	event("create",{"actor":r.id,"resource":resource,"name":name}); return h
func command(h: Dictionary,c: Dictionary) -> void:
	if h.destroyed: return
	if is_instance_valid(h.model): apply(h,c)
	else: h.commands.append(c)
func apply(h: Dictionary,c: Dictionary) -> void:
	if c.kind=="attach":
		h.part=str(c.part); var node: Node3D=manager.anchor(int(h.actor),0,h.part)
		if node==null or not h.model.attach_to(node,int(c.flags)): stats.failed+=1; manager.diagnose("weapon.special-attack-part-unavailable",str(h.part),int(h.actor))
		event("attach",{"actor":h.actor,"resource":h.resource,"part":h.part,"flags":c.flags})
	elif c.kind=="scale":
		h.model.anchor_scale=Vector3.ONE*float(c.value); h.model.scale=h.model.anchor_scale
		event("scale",{"actor":h.actor,"resource":h.resource,"value":c.value,"flags":c.flags})
	else:
		var played: bool=h.model.play_effect_clip(c.clip,float(c.speed),int(c.flags),float(c.time))
		var available: bool=h.model.bundle_data.value.rig_asset.clips.any(func(clip):return str(clip.name).to_lower()==str(c.clip).to_lower())
		# Original8033c0 ignores the Gob request's return. Stock eye models have
		# no clips; Gob052580 returns0 for that impact request.
		# Keep that static model and record the absent clip, without inventing one.
		if not played:
			if not available: stats.missing_clip_requests+=1
			else: stats.failed+=1; manager.diagnose("weapon.special-attack-clip-unavailable",str(h.resource)+" / "+str(c.clip),int(h.actor))
		event("play",{"actor":h.actor,"resource":h.resource,"clip":c.clip,"played":played,"available":available})
func destroy_handle(h: Dictionary) -> void:
	if h.destroyed: return
	h.destroyed=true; handles.erase(int(h.id)); h.commands.clear()
	if is_instance_valid(h.model): manager.release_model(h.model)
	h.model=null; stats.destroyed+=1
func forget(id: int) -> void:
	if not records.has(id): return
	var r: Dictionary=records[id]
	State.clear(r.state,providers(r))
	if r.eye.model!=null: destroy_handle(r.eye.model); r.eye.model=null
	records.erase(id)
func advance(delta: float=0.0) -> void:
	if closed: return
	for id in records.keys():
		if not valid(records[id]): forget(int(id)); stats.stale+=1
		else:
			var r: Dictionary=records[id]; r.initialize_elapsed+=maxf(0.0,delta)*1000.0
			if r.initialize_elapsed>=6000.0:
				r.source=manager.object(int(id)); initialize_record(r); r.initialize_elapsed=0.0
	var installed:=0
	for h in handles.values().duplicate():
		if is_instance_valid(h.model): continue
		if installed>=2 or not manager.ensure_models({h.resource:true}): continue
		if str(manager.bundles[h.resource].get("error","")).is_empty(): h.model=manager.create_model(int(h.actor),str(h.resource))
		if not is_instance_valid(h.model):
			stats.failed+=1
			if records.has(int(h.actor)):
				if is_same(records[int(h.actor)].eye.model,h): records[int(h.actor)].eye.model=null
				for index in 4:
					if is_same(records[int(h.actor)].state.slots[index],h): records[int(h.actor)].state.slots[index]=null
			destroy_handle(h); continue
		installed+=1; stats.loaded+=1
		for c in h.commands: apply(h,c)
		h.commands.clear()
func snapshot() -> Dictionary:
	return {"stats":stats.duplicate(),"owners":records.size(),"models":handles.size(),"events":history.duplicate(true),"scope":"Original unarmed special slots, body blur/completion, initialization and level20 eye-effect owners with native original models. Equipped slotFB/colour has a separate owner; full original clocks/shaders and paired-client/server acceptance remain open."}
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(combat) and combat.engine.presentation_event.is_connected(combat_event): combat.engine.presentation_event.disconnect(combat_event)
	for id in records.keys(): forget(int(id))
	for h in handles.values().duplicate(): destroy_handle(h)
	warm_signature.clear(); combat=null; manager=null
