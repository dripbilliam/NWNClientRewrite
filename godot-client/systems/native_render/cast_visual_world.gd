extends RefCounted
# Private original conjure/release models. The unchanged server discloses cast
# IDs, silent flags and animation; no spells, damage or effects execute here.
const State=preload("res://systems/native_data/cast_visual_controller.gd")
const Spell=preload("res://systems/native_data/projectile_spell.gd")
const WorldTimer=preload("res://systems/native_data/world_timer.gd")
var manager
var last_world_time: Dictionary={}
var records: Dictionary={}
var handles: Dictionary={}
var releases: Array=[]
var cast_states: Dictionary={}
var serial:=0
var history: Array=[]
var client_events: Array=[]
var closed:=false
var stats:={"created":0,"loaded":0,"destroyed":0,"failed":0,"stale":0,"overflow":0,"releases":0,"callbacks":0,"rebound":0}
func configure(owner) -> void:
	manager=owner
	var timer:Variant=manager.combat_timer
	if timer!=null:
		var now:Dictionary=timer.time()
		if bool(now.get("ready",false)):last_world_time={"day":int(now.day),"time":int(now.time)}
func elapsed_world_time() -> int:
	var timer:Variant=manager.combat_timer
	if timer==null:return 0
	var now:Dictionary=timer.time()
	if not bool(now.get("ready",false)):return 0
	var current:Dictionary={"day":int(now.day),"time":int(now.time)}
	if last_world_time.is_empty():last_world_time=current;return 0
	var difference:Dictionary=WorldTimer.subtract_world_times(current,last_world_time,timer.day_length)
	last_world_time=current
	return int(difference.time)&0xffffffff if bool(difference.get("ready",false)) and bool(difference.get("outputsDefined",false)) else 0
func event(kind: String,detail: Dictionary) -> void:
	if history.size()>=128: history.pop_front()
	var row:={"kind":kind,"at":Time.get_ticks_msec()}; row.merge(detail); history.append(row)
	if kind!="release":
		var client_row:Dictionary=row.duplicate(true);client_row.erase("at")
		if kind=="callback":client_row.erase("sourceId")
		client_events.append(client_row)
		if client_events.size()>48:client_events.pop_front()
func record(object: Dictionary) -> Dictionary:
	var id:=int(object.id); var lifetime:=int(object.get("nativeLifetime",0))
	if records.has(id) and int(records[id].lifetime)!=lifetime:
		var latest: Dictionary=cast_states.get(id,{})
		forget(id); stats.stale+=1
		if not latest.is_empty() and int(latest.lifetime)==lifetime: cast_states[id]=latest
	if not records.has(id):
		records[id]={"id":id,"lifetime":lifetime,"source":{},"visuals":State.create(),"animation":0,"spellId":-1,"previousCasting":0,"suppressSound":0,"race":-1,"gender":255}
	return records[id]
func refresh(r: Dictionary,object: Dictionary,animation: int) -> bool:
	var source: Variant=manager.projectiles.object_view(int(object.id))
	if source==null:return false
	var immediate: Dictionary=cast_states.get(int(object.id),{})
	if not immediate.is_empty() and int(immediate.lifetime)==int(object.get("nativeLifetime",0)): animation=int(immediate.animation)
	r.source={"id":int(object.id),"position":source.position}; r.animation=animation
	var replicated: Dictionary=object.get("replicated",{})
	r.castFieldUnavailable=false
	if ((animation-15)&65535)<6 or (animation&65535)==61:
		var immediate_cast:bool=not immediate.is_empty() and int(immediate.lifetime)==int(r.lifetime) and immediate.has("cast")
		if not immediate_cast and not replicated.has("cast"):
			r.castFieldUnavailable=true
			manager.diagnose("visual.cast-controller-failed","Replicated cast fields are unavailable",int(r.id))
			State.clear(r.visuals,"conjure",providers(r));State.clear(r.visuals,"cast",providers(r))
			return true
		var cast: Dictionary=immediate.cast if immediate_cast else replicated.get("cast",{})
		# network_projectile_presentation's dword/object/bool field reader is
		# inlined here: native_object_updates already supplies these three typed
		# replicated cells in that order and rejects a truncated packet first.
		var bits:int=int(cast.get("spell",0))&0xffffffff
		r.spellId=bits-0x100000000 if bits>=0x80000000 else bits
		r.spellItemId=int(cast.get("casterTarget",0))&0xffffffff; r.suppressSound=int(cast.get("silent",0))
	if State.casting(animation):
		var stats_state: Dictionary=replicated.get("stats",{}) if replicated.get("stats",{}) is Dictionary else {}
		var race: Variant=stats_state.get("racialType",null)
		if race==null:race=stats_state.get("fieldD20",-1)
		r.race=int(race)
		var appearance: Dictionary=object.get("appearance",{}) if object.get("appearance",{}) is Dictionary else {}
		var gender: Variant=appearance.get("gender",null)
		# The old network bridge installs appearance gender only after the source
		# model exists; an uncreated model keeps the client constructor's 255.
		if manager.host(int(r.id))!=null:r.gender=int(gender) if gender!=null else 255
	return true
func observe(object: Dictionary,animation: int) -> void:
	if closed or int(object.objectType)!=5: return
	var id:=int(object.id)
	if cast_states.has(id) and int(cast_states[id].lifetime)==int(object.get("nativeLifetime",0)): animation=int(cast_states[id].animation)
	# A matching immediate cast or an existing controller still needs the
	# canonical pose. Ordinary idle creatures have no controller to refresh.
	if not State.casting(animation) and not records.has(id): return
	var canonical: Variant=manager.projectiles.canonical_for_id(id)
	if canonical==null or int(canonical.get("nativeLifetime",0))!=int(object.get("nativeLifetime",0)):return
	if not refresh(record(object),object,animation):forget(id)
func receive(row: Dictionary) -> void:
	if closed: return
	var id:=int(row.id); var animation:=int(row.animation)
	var object: Variant=manager.projectiles.canonical_for_id(id)
	if object!=null and int(object.get("nativeLifetime",0))>int(row.lifetime): stats.stale+=1; return
	if cast_states.has(id) and int(cast_states[id].lifetime)>int(row.lifetime): stats.stale+=1; return
	if not State.casting(animation) and not records.has(id): cast_states.erase(id); return
	cast_states[id]={"lifetime":int(row.lifetime),"animation":animation,"cast":row.get("cast",{}).duplicate(true),"received":Time.get_ticks_msec()}
	if object!=null and int(object.get("nativeLifetime",0))==int(row.lifetime) and not refresh(record(object),object,animation):forget(id)
func release(object: Dictionary,refs: Array,received: int) -> void:
	if closed: return
	var canonical:Variant=manager.projectiles.canonical_for_id(int(object.id))
	if canonical!=null and int(canonical.get("nativeLifetime",0))==int(object.get("nativeLifetime",0)):
		var active:=record(canonical)
		if refresh(active,canonical,int(canonical.get("replicated",{}).get("animation",0))) and not bool(active.get("castFieldUnavailable",false)):
			var owner:=providers(active)
			State.drive(active,0,owner)
			if _part_query_failed(active,owner):return
			State.release(active.visuals,refs,active.source,owner);active.visuals.released=1
			event("release",{"sourceId":int(object.id),"refs":refs.duplicate()});stats.releases+=1
		return
	releases.append({"id":int(object.id),"lifetime":int(object.get("nativeLifetime",0)),"refs":refs.duplicate(),"received":received}); stats.releases+=1
func providers(r: Dictionary) -> Dictionary:
	return {"spell":func(id):return Spell.casting(manager.projectiles.table,int(id)),
		"create":func(resource,category):return create_handle(r,resource,category),
		"sourceModel":func(source,_part,_flags):return manager.host(int(source.id)),
		"nodePose":manager.projectiles.node_pose,
		"partQueryFailure":manager.projectiles.take_part_query_failure,
		"attach":func(handle,parent,part,flags):command(handle,{"kind":"attach","attached":parent!=null,"part":part,"flags":flags}),
		"play":func(handle,clip,speed,flags,time):command(handle,{"kind":"play","clip":clip,"speed":speed,"flags":flags,"time":time}),
		"listen":func(handle,name,callback,context):command(handle,{"kind":"listen","event":str(name),"callback":callback,"context":context}),
		"destroy":destroy_handle,
		"oneShot":func(resource,position,priority,height):
			event("sound",{"sourceId":r.id,"resource":resource}); manager.world_audio.one_shot(resource,position,height,priority,0,0,0,0x7f000000,"conjure")}
func _part_query_failed(r: Dictionary,p: Dictionary) -> bool:
	var reason:=str(r.visuals.get("partQueryError",""))
	if reason.is_empty():return false
	r.visuals.erase("partQueryError")
	manager.diagnose("visual.cast-controller-failed",reason,int(r.id))
	State.clear(r.visuals,"conjure",p)
	State.clear(r.visuals,"cast",p)
	return true
func create_handle(r: Dictionary,resource: String,category: String) -> Variant:
	serial+=1
	var h:={"id":serial,"actor":int(r.id),"lifetime":int(r.lifetime),"resource":resource.to_lower(),"authoredResource":resource,"category":category,"model":null,"commands":[],"listeners":[],"attached":false,"part":"","host":0,"anchor_reported":false,"destroyed":false}
	handles[serial]=h; stats.created+=1; event("create",{"sourceId":r.id,"resource":resource,"category":category}); manager.ensure_models({h.resource:true}); return h
func command(h: Dictionary,c: Dictionary) -> void:
	if h.destroyed: return
	if is_instance_valid(h.model): apply(h,c)
	else: h.commands.append(c)
func bind(h: Dictionary) -> void:
	if not is_instance_valid(h.model) or not h.attached: return
	var host=manager.host(int(h.actor)); var identity: int=host.get_instance_id() if is_instance_valid(host) else 0
	if identity==int(h.host): return
	if is_instance_valid(host) and not bool(h.get("partQueried",false)):
		h.partQueried=true
		if not manager.projectiles._part_query(host):
			stats.failed+=1
			manager.diagnose("visual.cast-model-failed",manager.projectiles.take_part_query_failure(),int(h.actor))
			if records.has(int(h.actor)):
				for group in [records[int(h.actor)].visuals.conjure,records[int(h.actor)].visuals.cast]:
					for i in 3:
						if is_same(group[i],h):group[i]=null
			destroy_handle(h)
			return
	var node: Node3D=manager.anchor(int(h.actor),0,str(h.part))
	if node==null:
		h.model.detach(); h.host=0
		if not h.anchor_reported:
			manager.diagnose("visual.cast-anchor-unavailable","Cast visual attachment part is unavailable: "+str(h.authoredResource)+" / "+str(h.part),int(h.actor))
			h.anchor_reported=true
		return
	if h.model.attach_to(node): h.host=identity; h.anchor_reported=false; stats.rebound+=1
	elif not h.anchor_reported:
		manager.diagnose("visual.cast-anchor-unavailable","Cast visual attachment part is unavailable: "+str(h.authoredResource)+" / "+str(h.part),int(h.actor))
		h.anchor_reported=true
func apply(h: Dictionary,c: Dictionary) -> void:
	if c.kind=="attach":
		h.attached=bool(c.attached); h.part=c.part; h.host=0; h.anchor_reported=false
		if h.attached: bind(h)
		else: h.model.detach()
	elif c.kind=="listen":
		var callback:=func(_owner: Variant,name: String,_data: Variant):
			if h.destroyed:return
			stats.callbacks+=1
			self.event("callback",{"sourceId":h.actor,"resource":h.authoredResource,"event":str(c.event)})
			c.callback.call(h,c.context)
		var record: Dictionary=h.model.rigs.add_model_event_listener(0,0,str(c.event),callback)
		if record.is_empty():manager.diagnose("visual.cast-event-unavailable","Cast visual model has no animation event dispatcher",int(h.actor),{"resource":str(h.authoredResource),"event":str(c.event)})
		else:h.listeners.append({"index":0,"record":record})
	else:
		var played: bool=h.model.play_effect_clip(c.clip,float(c.speed),int(c.flags),float(c.time))
		event("play",{"sourceId":h.actor,"resource":h.authoredResource,"clip":c.clip,"flags":int(c.flags),"played":played})
		if not played:manager.diagnose("visual.cast-clip-unavailable","Authored cast visual animation cannot play",int(h.actor),{"sourceId":int(h.actor),"resource":str(h.authoredResource),"clip":str(c.clip)})
func destroy_handle(h: Dictionary) -> void:
	if h.destroyed: return
	h.destroyed=true; handles.erase(int(h.id)); h.commands.clear()
	if is_instance_valid(h.model) and is_instance_valid(h.model.rigs):
		for listener in h.listeners:h.model.rigs.remove_model_event_listener(0,int(listener.index),listener.record)
	h.listeners.clear()
	if is_instance_valid(h.model): manager.release_model(h.model)
	h.model=null; stats.destroyed+=1; event("destroy",{"sourceId":h.actor,"resource":h.authoredResource})
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
func _load_current(h: Dictionary) -> bool:
	if closed or not is_instance_valid(manager) or bool(h.destroyed) or not handles.has(int(h.id)) or not is_same(handles[int(h.id)],h):return false
	if not records.has(int(h.actor)) or int(records[int(h.actor)].lifetime)!=int(h.lifetime):return false
	var canonical: Variant=manager.projectiles.canonical_for_id(int(h.actor))
	return canonical!=null and int(canonical.get("nativeLifetime",0))==int(h.lifetime)
func _load_failed(h: Dictionary,reason: String) -> void:
	# A newer cast can occupy the same slot while this model is loading.
	if records.has(int(h.actor)):
		for group in [records[int(h.actor)].visuals.conjure,records[int(h.actor)].visuals.cast]:
			for i in 3:
				if is_same(group[i],h):group[i]=null
	stats.failed+=1
	if is_instance_valid(manager):manager.diagnose("visual.cast-model-failed",reason,int(h.actor),{"sourceId":int(h.actor),"resource":str(h.authoredResource)})
	destroy_handle(h)
func pump() -> void:
	for h in handles.values().duplicate():
		if closed or bool(h.destroyed) or not handles.has(int(h.id)) or not is_same(handles[int(h.id)],h):continue
		if not is_instance_valid(h.model):
			if not manager.ensure_models({h.resource:true}): continue
			# The old async load refreshes the client object mirror immediately
			# before publishing its model. Desired render bindings can lag the raw
			# canonical source during a remove/recreate of the same server ID.
			if not _load_current(h):
				stats.stale+=1;destroy_handle(h);continue
			var bundle: Dictionary=manager.bundles[h.resource]
			if not str(bundle.get("error","")).is_empty():
				_load_failed(h,str(bundle.error));continue
			var owner: Variant=manager
			var candidate: Variant=owner.create_model(int(h.actor),h.resource)
			if not is_instance_valid(candidate):
				if not bool(h.destroyed):_load_failed(h,"Native cast model could not be created: "+str(h.authoredResource))
				continue
			# The old load continuation calls objects.sync before publishing the
			# handle. Read the authoritative canonical source again after scene
			# construction and discard a late result without touching a new slot.
			if not _load_current(h):
				stats.stale+=1
				if is_instance_valid(owner):owner.release_model(candidate)
				if not bool(h.destroyed):destroy_handle(h)
				continue
			h.model=candidate
			# Cast animator/events advance in this model's rig at priority 12.
			# The old bridge then syncs attachments once, after that update.
			# Keep the EffectModel's existing binding pass, just order this
			# cast-owned instance after its rig (other effect models stay at 10).
			h.model.process_priority=13
			stats.loaded+=1
			var clips: Array=[]
			if h.model.rigs.entities.has(0):
				for clip in h.model.rigs.entities[0].get("asset_source",{}).get("clips",[]):
					if clip is Dictionary:clips.append(str(clip.get("name","")))
			event("loaded",{"sourceId":h.actor,"resource":h.authoredResource,"clips":clips})
			var pending_commands: Array=h.commands.duplicate()
			h.commands.clear()
			for c in pending_commands:
				if h.destroyed:break
				apply(h,c)
			if not h.destroyed:bind(h)
func advance() -> void:
	if closed or manager.projectiles.table.is_empty(): return
	var now:=Time.get_ticks_msec(); var elapsed:=elapsed_world_time(); var waiting: Array=[]
	# The old client projects cast fields for every canonical creature mirror,
	# including one whose body has not yet been published into the scene.
	for id in manager.world.desired:
		if manager.world.instances.has(id):continue
		var object:Dictionary=manager.world.desired[id].object
		if int(object.get("objectType",0))==5:
			observe(object,int(object.get("replicated",{}).get("animation",0)))
	for id in cast_states.keys():
		var state: Dictionary=cast_states[id]; var object: Variant=manager.projectiles.canonical_for_id(int(id))
		if object==null or int(object.get("nativeLifetime",0))!=int(state.lifetime):
			if now-int(state.received)>5000 or object!=null and int(object.get("nativeLifetime",0))>int(state.lifetime):
				cast_states.erase(id)
				if not records.has(id): stats.stale+=1
			continue
		if not records.has(id) and manager.host(int(id))!=null and not refresh(record(object),object,int(state.animation)):forget(int(id))
	for entry in releases:
		var object: Variant=manager.projectiles.canonical_for_id(int(entry.id))
		if object==null or int(object.get("nativeLifetime",0))!=int(entry.lifetime): stats.stale+=1; continue
		var r:=record(object); var animation:=int(object.get("replicated",{}).get("animation",0))
		if not refresh(r,object,animation):forget(int(entry.id));stats.stale+=1;continue
		if bool(r.get("castFieldUnavailable",false)):continue
		var p:=providers(r); State.drive(r,0,p)
		if _part_query_failed(r,p):continue
		State.release(r.visuals,entry.refs,r.source,p); r.visuals.released=1
		event("release",{"sourceId":entry.id,"refs":entry.refs})
	releases=waiting
	for id in records.keys():
		var r: Dictionary=records[id]; var object: Variant=manager.projectiles.canonical_for_id(int(id))
		if object==null or int(object.get("nativeLifetime",0))!=int(r.lifetime):
			var latest: Dictionary=cast_states.get(id,{})
			forget(id)
			if not latest.is_empty() and int(latest.lifetime)>int(r.lifetime):cast_states[id]=latest
			stats.stale+=1;continue
		if bool(r.get("castFieldUnavailable",false)):continue
		var p:=providers(r)
		State.drive(r,elapsed,p)
		if _part_query_failed(r,p):continue
		if not State.casting(int(r.animation)) and int(r.visuals.released)==0 and (r.visuals.conjure+r.visuals.cast).all(func(h):return h==null): forget(id)
	pump()
func snapshot() -> Dictionary:
	return {"stats":stats.duplicate(),"controllers":records.size(),"models":handles.size(),"pending_releases":releases.size(),"events":history.duplicate(true),"scope":"Original cast visual state with native assets/audio; monotonic clock, async model preparation and broader original-client comparison remain separate acceptance"}
func client_snapshot() -> Dictionary:
	var active: Array=[]
	for h in handles.values():active.append({"sourceId":int(h.actor),"resource":str(h.authoredResource),"category":str(h.category),"loaded":is_instance_valid(h.model)})
	var controllers: Array=[]
	for r in records.values():
		var visuals:Dictionary=r.visuals
		if int(r.previousCasting)==0 and int(visuals.released)==0 and (visuals.conjure+visuals.cast).all(func(h):return h==null):continue
		var row:Dictionary={"sourceId":int(r.id),"spellId":int(r.spellId),"suppressSound":int(r.suppressSound),"race":int(r.race),"gender":int(r.gender),"animation":int(r.animation),"conjureTime":int(visuals.conjureTime),"castTime":int(visuals.castTime),"released":int(visuals.released)}
		if r.has("spellItemId"):row.spellItemId=int(r.spellItemId)
		controllers.append(row)
	return {"active":active,"controllers":controllers,"events":client_events.duplicate(true)}
func close() -> void:
	if closed: return
	closed=true
	for id in records.keys(): forget(int(id))
	for h in handles.values().duplicate(): destroy_handle(h)
	releases.clear(); cast_states.clear(); manager=null
