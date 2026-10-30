extends RefCounted
# Private original conjure/release models. The unchanged server discloses cast
# IDs, silent flags and animation; no spells, damage or effects execute here.
const State=preload("res://systems/native_data/cast_visual_controller.gd")
const Spell=preload("res://systems/native_data/projectile_spell.gd")
var manager
var records: Dictionary={}
var handles: Dictionary={}
var releases: Array=[]
var cast_states: Dictionary={}
var serial:=0
var history: Array=[]
var closed:=false
var stats:={"created":0,"loaded":0,"destroyed":0,"failed":0,"stale":0,"overflow":0,"releases":0,"callbacks":0,"rebound":0}
func configure(owner) -> void: manager=owner
func event(kind: String,detail: Dictionary) -> void:
	if history.size()>=128: history.pop_front()
	var row:={"kind":kind,"at":Time.get_ticks_msec()}; row.merge(detail); history.append(row)
func record(object: Dictionary) -> Dictionary:
	var id:=int(object.id); var lifetime:=int(object.get("nativeLifetime",0))
	if records.has(id) and int(records[id].lifetime)!=lifetime:
		var latest: Dictionary=cast_states.get(id,{})
		forget(id); stats.stale+=1
		if not latest.is_empty() and int(latest.lifetime)==lifetime: cast_states[id]=latest
	if not records.has(id):
		records[id]={"id":id,"lifetime":lifetime,"source":{},"visuals":State.create(),"animation":0,"spellId":-1,"previousCasting":0,"suppressSound":0,"race":-1,"gender":255,"last":Time.get_ticks_msec()}
	return records[id]
func refresh(r: Dictionary,object: Dictionary,animation: int) -> void:
	var immediate: Dictionary=cast_states.get(int(object.id),{})
	if not immediate.is_empty() and int(immediate.lifetime)==int(object.get("nativeLifetime",0)): animation=int(immediate.animation)
	r.source={"id":int(object.id),"position":manager.projectiles.object_view(int(object.id)).position}; r.animation=animation
	var replicated: Dictionary=object.get("replicated",{})
	if ((animation-15)&65535)<6 or (animation&65535)==61:
		var cast: Dictionary=immediate.cast if not immediate.is_empty() and int(immediate.lifetime)==int(r.lifetime) else replicated.get("cast",{})
		if cast.has("spell"): r.spellId=int(cast.spell); r.suppressSound=int(cast.get("silent",0))
	r.race=int(replicated.get("stats",{}).get("racialType",-1)); r.gender=int(object.get("appearance",{}).get("gender",255)) if manager.host(int(object.id))!=null else 255
func observe(object: Dictionary,animation: int) -> void:
	if closed or int(object.objectType)!=5: return
	var id:=int(object.id)
	if cast_states.has(id) and int(cast_states[id].lifetime)==int(object.get("nativeLifetime",0)): animation=int(cast_states[id].animation)
	if not State.casting(animation) and not records.has(id): return
	refresh(record(object),object,animation)
func receive(row: Dictionary) -> void:
	if closed: return
	var id:=int(row.id); var animation:=int(row.animation)
	var object: Variant=manager.object(id)
	if object!=null and int(object.get("nativeLifetime",0))>int(row.lifetime): stats.stale+=1; return
	if cast_states.has(id) and int(cast_states[id].lifetime)>int(row.lifetime): stats.stale+=1; return
	if not State.casting(animation) and not records.has(id): cast_states.erase(id); return
	if not cast_states.has(id) and cast_states.size()>=128: stats.overflow+=1; return
	cast_states[id]={"lifetime":int(row.lifetime),"animation":animation,"cast":row.get("cast",{}).duplicate(true),"received":Time.get_ticks_msec()}
	if object!=null and int(object.get("nativeLifetime",0))==int(row.lifetime): refresh(record(object),object,animation)
func release(object: Dictionary,refs: Array,received: int) -> void:
	if closed: return
	if releases.size()>=128: stats.overflow+=1; return
	releases.append({"id":int(object.id),"lifetime":int(object.get("nativeLifetime",0)),"refs":refs.duplicate(),"received":received}); stats.releases+=1
func providers(r: Dictionary) -> Dictionary:
	return {"spell":func(id):return Spell.casting(manager.projectiles.table,int(id)),
		"create":func(resource,category):return create_handle(r,resource,category),
		"sourceModel":func(source,_part,_flags):return manager.host(int(source.id)),
		"nodePose":manager.projectiles.node_pose,
		"attach":func(handle,parent,part,flags):command(handle,{"kind":"attach","attached":parent!=null,"part":part,"flags":flags}),
		"play":func(handle,clip,speed,flags,time):command(handle,{"kind":"play","clip":clip,"speed":speed,"flags":flags,"time":time}),
		"listen":func(handle,_name,_callback,_context):handle.listen=true,
		"destroy":destroy_handle,
		"oneShot":func(resource,position,priority,height):
			event("sound",{"sourceId":r.id,"resource":resource}); manager.world_audio.one_shot(resource,position,height,priority)}
func create_handle(r: Dictionary,resource: String,category: String) -> Variant:
	if handles.size()>=256: stats.overflow+=1; return null
	serial+=1
	var h:={"id":serial,"actor":int(r.id),"lifetime":int(r.lifetime),"resource":resource.to_lower(),"category":category,"model":null,"commands":[],"listen":false,"attached":false,"part":"","host":0,"destroyed":false}
	handles[serial]=h; stats.created+=1; event("create",{"sourceId":r.id,"resource":resource,"category":category}); manager.ensure_models({h.resource:true}); return h
func command(h: Dictionary,c: Dictionary) -> void:
	if h.destroyed: return
	if is_instance_valid(h.model): apply(h,c)
	else: h.commands.append(c)
func bind(h: Dictionary) -> void:
	if not is_instance_valid(h.model) or not h.attached: return
	var host=manager.host(int(h.actor)); var identity: int=host.get_instance_id() if is_instance_valid(host) else 0
	if identity==int(h.host): return
	var node: Node3D=manager.anchor(int(h.actor),0,str(h.part))
	if node==null: h.model.detach(); h.host=0; return
	if h.model.attach_to(node): h.host=identity; stats.rebound+=1
func apply(h: Dictionary,c: Dictionary) -> void:
	if c.kind=="attach":
		h.attached=bool(c.attached); h.part=c.part; h.host=0
		if h.attached: bind(h)
		else: h.model.detach()
	else:
		var played: bool=h.model.play_effect_clip(c.clip,float(c.speed),int(c.flags),float(c.time))
		event("play",{"sourceId":h.actor,"resource":h.resource,"clip":c.clip,"played":played})
		if not played: manager.diagnose("cast.clip-unavailable",str(h.resource)+" / "+str(c.clip),int(h.actor))
func model_event(handle_id: int,name: String) -> void:
	if name.to_lower()!="donefade" or not handles.has(handle_id): return
	var h: Dictionary=handles[handle_id]
	if h.listen and records.has(int(h.actor)) and int(records[int(h.actor)].lifetime)==int(h.lifetime):
		State.done_fade(h,records[int(h.actor)].visuals); stats.callbacks+=1; event("donefade",{"sourceId":h.actor,"resource":h.resource})
func destroy_handle(h: Dictionary) -> void:
	if h.destroyed: return
	h.destroyed=true; handles.erase(int(h.id)); h.commands.clear()
	if is_instance_valid(h.model): manager.release_model(h.model)
	h.model=null; stats.destroyed+=1; event("destroy",{"sourceId":h.actor,"resource":h.resource})
func forget(id: int) -> void:
	if not records.has(id): return
	var r: Dictionary=records[id]; var p:=providers(r)
	State.clear(r.visuals,"conjure",p); State.clear(r.visuals,"cast",p)
	# Repeated release may overwrite a physical slot; scope teardown owns all
	# private handles, including any no-longer-slotted pending allocation.
	for h in handles.values().duplicate():
		if int(h.actor)==id: destroy_handle(h)
	records.erase(id)
	cast_states.erase(id)
func pump() -> void:
	var installed:=0
	for h in handles.values().duplicate():
		if not is_instance_valid(h.model):
			if installed>=2 or not manager.ensure_models({h.resource:true}): continue
			var bundle: Dictionary=manager.bundles[h.resource]
			if str(bundle.get("error","")).is_empty(): h.model=manager.create_model(int(h.actor),h.resource)
			if not is_instance_valid(h.model):
				stats.failed+=1; manager.diagnose("cast.model-unavailable",str(h.resource),int(h.actor))
				if records.has(int(h.actor)):
					for group in [records[int(h.actor)].visuals.conjure,records[int(h.actor)].visuals.cast]:
						for i in 3:
							if is_same(group[i],h): group[i]=null
				destroy_handle(h); continue
			installed+=1; stats.loaded+=1
			var handle_id:=int(h.id)
			h.model.rigs.model_event.connect(func(_actor,_index,name,_play_serial):model_event(handle_id,name))
			event("loaded",{"sourceId":h.actor,"resource":h.resource})
			for c in h.commands: apply(h,c)
			h.commands.clear()
		bind(h)
func advance() -> void:
	if closed or manager.projectiles.table.is_empty(): return
	var now:=Time.get_ticks_msec(); var waiting: Array=[]
	for id in cast_states.keys():
		var state: Dictionary=cast_states[id]; var object: Variant=manager.object(int(id))
		if object==null or int(object.get("nativeLifetime",0))!=int(state.lifetime):
			if now-int(state.received)>5000 or object!=null and int(object.get("nativeLifetime",0))>int(state.lifetime):
				cast_states.erase(id)
				if not records.has(id): stats.stale+=1
			continue
		if not records.has(id) and manager.host(int(id))!=null: refresh(record(object),object,int(state.animation))
	for entry in releases:
		var object: Variant=manager.object(int(entry.id))
		if object==null or int(object.get("nativeLifetime",0))!=int(entry.lifetime): stats.stale+=1; continue
		if manager.host(int(entry.id))==null:
			if now-int(entry.received)<5000: waiting.append(entry)
			else: stats.stale+=1
			continue
		var r:=record(object); var animation:=int(object.get("replicated",{}).get("animation",0)); refresh(r,object,animation)
		var p:=providers(r); State.drive(r,0,p); State.release(r.visuals,entry.refs,r.source,p); r.visuals.released=1
		event("release",{"sourceId":entry.id,"refs":entry.refs})
	releases=waiting
	for id in records.keys():
		var r: Dictionary=records[id]; var object: Variant=manager.object(int(id))
		if object==null or int(object.get("nativeLifetime",0))!=int(r.lifetime): forget(id); stats.stale+=1; continue
		State.drive(r,(now-int(r.last))&0xffffffff,providers(r)); r.last=now
		if not State.casting(int(r.animation)) and int(r.visuals.released)==0 and (r.visuals.conjure+r.visuals.cast).all(func(h):return h==null): forget(id)
	pump()
func snapshot() -> Dictionary:
	return {"stats":stats.duplicate(),"controllers":records.size(),"models":handles.size(),"pending_releases":releases.size(),"events":history.duplicate(true),"scope":"Original cast visual state with native assets/audio; monotonic clock, async model preparation and broader original-client comparison remain separate acceptance"}
func close() -> void:
	if closed: return
	closed=true
	for id in records.keys(): forget(int(id))
	for h in handles.values().duplicate(): destroy_handle(h)
	releases.clear(); cast_states.clear(); manager=null
