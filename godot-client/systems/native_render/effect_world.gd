extends "res://systems/visual_world.gd"
# Direct-native resources and event lifetime owner. The retained phase/selection
# logic operates on private original models, without staged JSON/GLB assets.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Definition=preload("res://systems/native_data/visual_definition.gd")
const NativeModel=preload("res://systems/native_render/effect_model.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const Routing=preload("res://systems/native_data/object_visual_route.gd")
const AreaDefinition=preload("res://systems/native_data/area_visual_definition.gd")
const PresentationLifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
var reuse_selection_inputs:=not OS.get_cmdline_user_args().has("--effect-inputs=reference")
var selection_owner_projections:=0
var selection_presentation_projections:=0
var world
var assets
var tables: Dictionary={}
var jobs: Dictionary={}
var bundles: Dictionary={}
var requested: Dictionary={}
var records: Dictionary={}
var queue: Array=[]
var last_serial:=-1
var known: Dictionary={}
var controlled_id:=-1
var removed_states: Dictionary={}
var world_scope: Dictionary={}
var pivots: Dictionary={}
var owner_scene: Dictionary={}
var world_audio
var client_dummies
var projectiles
var casts
var blood
var parries
var special_attacks
var equipped_attacks
var creature_voices
var script_sounds
var history: Array=[]
var delivery:={"received":0,"stale":0,"overflow":0,"prepared":0}
var perception_visuals
func _selection_view_gate() -> bool:
	var reference: WeakRef=world.get_meta("native_focus_light_owner") if world.has_meta("native_focus_light_owner") else null
	var owner=reference.get_ref() if reference!=null else null
	if not is_instance_valid(owner): diagnose("visual.native-view-light-sample-unavailable","Missing native scene focus owner",0); return false
	owner.set_controlled(host(world.controlled_id))
	return owner.view_gate()
func tables_ready() -> bool:
	# Blood/voice controllers may add rules tables to this shared cache. Their
	# arrival must not stop ordinary effects that already have their dependencies.
	return ["visualeffects","progfx","appearance"].all(func(name):return tables.has(name))
func configure(owner) -> void:
	world=owner; client=self; world_scope={"ticket":world.generation}; process_priority=45
	perception_visuals=preload("res://systems/native_render/perception_visuals.gd").new();perception_visuals.configure(world,_apply_perception_visual,_remove_perception_visual)
	assets=Assets.new(); add_child(assets); assets.configure(world.catalog); assets.cache_directory=world.cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	for name in ["visualeffects","progfx","appearance"]: jobs[assets.request(name,2017,"2da") ]={"kind":"table","name":name}
	world_audio=preload("res://systems/native_render/effect_audio.gd").new(); add_child(world_audio); world_audio.configure(self)
	client_dummies=preload("res://systems/native_render/client_dummies.gd").new(); add_child(client_dummies); client_dummies.configure(self)
	projectiles=preload("res://systems/native_render/projectile_world.gd").new(); add_child(projectiles); projectiles.configure(self)
	casts=preload("res://systems/native_render/cast_visual_world.gd").new(); casts.configure(self)
	blood=preload("res://systems/native_render/blood_world.gd").new(); blood.configure(self)
	parries=preload("res://systems/native_render/parry_world.gd").new(); parries.configure(self)
	special_attacks=preload("res://systems/native_render/special_attack_world.gd").new(); special_attacks.configure(self)
	equipped_attacks=preload("res://systems/native_render/equipped_attack_world.gd").new(); equipped_attacks.configure(self)
	creature_voices=preload("res://systems/native_render/creature_voice_world.gd").new(); creature_voices.configure(self)
	script_sounds=preload("res://systems/native_render/script_sound_world.gd").new(); script_sounds.configure(self)
func command(value: Dictionary) -> void:
	if closed: return
	if value.kind=="world-audio-resource":
		var job: int=assets.request(str(value.name),4,"wave-native-v1")
		if job<0: world_audio.resource_ready(int(value.resourceId),{"error":assets.failure}); return
		jobs[job]={"kind":"audio","id":int(value.resourceId)}; return
	if history.size()>=128: history.pop_front()
	history.append(value.duplicate(true))
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var job: Dictionary=jobs[id]; jobs.erase(id)
	if job.kind=="projectile-table":
		if str(result.get("error","")).is_empty(): projectiles.accept_table(str(job.get("name","spells")),result.value)
		else: diagnose("projectile.table-unavailable",str(result.error),0)
		return
	if job.kind=="audio": world_audio.resource_ready(int(job.id),result); return
	if job.kind=="table":
		if str(result.get("error","")).is_empty(): tables[job.name]=result.value
		else: diagnose("visual.table-unavailable",str(job.name)+": "+str(result.error),0)
	else: bundles[job.name]=result
func receive_raw(message: Dictionary) -> void:
	if closed: return
	var serial:=int(message.get("serial",-1))
	if serial<=last_serial: delivery.stale+=1; return
	last_serial=serial
	for event in message.get("events",[]):
		if event.kind=="projectile": projectiles.receive(event); delivery.received+=1; continue
		if queue.size()>=512: delivery.overflow+=1; continue
		queue.append(event.duplicate(true)); delivery.received+=1
func host(id: int,_token: int=0) -> Node3D:
	if _token!=0: return client_dummies.host(id,_token) if is_instance_valid(client_dummies) else null
	return world.instances.get(id) if world.desired.has(id) else null
func observe_perception(objects: Array,controlled: int) -> void:
	if not closed and perception_visuals!=null:perception_visuals.receive(objects,controlled)
func begin_received_perception(objects: Array,controlled: int) -> void:
	if not closed and perception_visuals!=null:perception_visuals.begin_received(objects,controlled)
func received_perception_step() -> bool:
	return true if closed or perception_visuals==null else perception_visuals.received_step()
func cancel_received_perception() -> void:
	if perception_visuals!=null:perception_visuals.cancel_received()
func _apply_perception_visual(id: int,lifetime: int,visual: int) -> int:
	var before:=next_effect
	reserve(id,lifetime,{"visualId":visual,"sourceId":0x7f000000,"bodyPart":0,"delivery":{"instant":0,"sourcePart":0,"targetPart":0,"point":[0,0,0]}},false)
	return next_effect if next_effect>before else 0
func _remove_perception_visual(id: int,effect_id: int) -> void:
	# The handler owns this exact instance; a server-sent visual6 is independent.
	if entries.has(effect_id):super.receive({"kind":"visual-remove","actorId":id,"visualId":6,"effectId":effect_id})
func alpha_commands(effect_id: int,actor_id: int,token: int,commands: Array) -> Dictionary:
	if closed or not entries.has(effect_id) or not _bound(entries[effect_id]):return {"available":false,"reason":"Effect lifetime retired"}
	var effect_entry: Dictionary=entries[effect_id]
	if int(effect_entry.actor)!=actor_id or int(effect_entry.privateToken)!=token:return {"available":false,"reason":"Alpha target does not match owning effect"}
	var instance:=host(actor_id,token)
	if not is_instance_valid(instance) or token!=0 or not world.desired.has(actor_id) or str(world.installed.get(actor_id,""))!=str(world.desired[actor_id].key):return {"available":false,"reason":"Current target model is not admitted"}
	var model_indices: Array=instance.call("renderer_alpha_model_indices") if instance.has_method("renderer_alpha_model_indices") else [0]
	for command in commands:
		if closed or not entries.has(effect_id) or not is_same(entries[effect_id],effect_entry) or not _bound(effect_entry) or host(actor_id,token)!=instance or instance.get("retired")==true or not world.desired.has(actor_id) or str(world.installed.get(actor_id,""))!=str(world.desired[actor_id].key):return {"available":false,"reason":"Target changed during alpha publication"}
		var accepted:=true
		match str(command.kind):
			"set_alpha":accepted=instance.has_method("set_renderer_alpha") and instance.call("set_renderer_alpha",preload("res://tools/native_parity/visibility/alpha_program.gd").scalar(int(command.alpha_word)),model_indices)
			"set_vector_channel":
				var vector: Array=[]
				for bits in command.vector_words:vector.append(preload("res://tools/native_parity/visibility/alpha_program.gd").scalar(int(bits)))
				accepted=instance.has_method("set_renderer_vector") and instance.call("set_renderer_vector",int(command.channel),vector,model_indices)
			"clear_vector_channel":accepted=instance.has_method("set_renderer_vector") and instance.call("set_renderer_vector",int(command.channel),null,model_indices)
			"set_visible":accepted=instance.has_method("set_presentation_draw_enabled") and instance.call("set_presentation_draw_enabled",bool(command.value),model_indices)
			"set_blocked":instance.set_meta("native_fade_blocked",bool(command.value))
			"refresh_visibility":pass # The mesh gate above retains root/selection membership.
			_:accepted=false
		if not accepted:return {"available":false,"reason":"Unsupported native alpha command: "+str(command.kind)}
	return {"available":true,"attachment_scope":"base model; child propagation remains explicit","scene_detach_parity":false}
func _bound(entry: Dictionary) -> bool:
	if int(entry.privateToken)!=0: return is_instance_valid(client_dummies) and client_dummies.has(int(entry.actor),int(entry.privateToken))
	if not world.desired.has(int(entry.actor)) or not records.has(int(entry.id)):return false
	var source: Dictionary=world.desired[int(entry.actor)].object;var record: Dictionary=records[int(entry.id)]
	if int(source.get("nativeLifetime",0))!=int(record.lifetime):return false
	return not record.has("presentation_lifetime") or record.presentation_lifetime==preload("res://systems/native_data/entity_presentation_lifetime.gd").token(source)
func _selection_entries(actor: int,token: int) -> Array:
	# The canonical filter has no authored hooks. Project the shared owner's
	# current lifetime once for this invocation, before any runtime state getter
	# or selector callback. Nothing survives a phase, selection or nested call.
	# Custom owners keep their imperative _bound calls and observable ordering.
	if not reuse_selection_inputs or get_script().resource_path!="res://systems/native_render/effect_world.gd":return super._selection_entries(actor,token)
	if token!=0 and is_instance_valid(client_dummies) and (not client_dummies.get_script() is GDScript or client_dummies.get_script().resource_path!="res://systems/native_render/client_dummies.gd"):return super._selection_entries(actor,token)
	var members:=_member_entries(actor,token)
	var selected: Array=[]
	if members.is_empty():return selected
	selection_owner_projections+=1
	var source: Dictionary={}
	var lifetime:=0
	if token!=0:
		if not is_instance_valid(client_dummies) or not client_dummies.has(actor,token):return selected
	else:
		if not world.desired.has(actor):return selected
		source=world.desired[actor].object;lifetime=int(source.get("nativeLifetime",0))
	var presentation: Array=[]
	var presentation_ready:=false
	for entry in members:
		if entry.areaVisual or entry.actor!=actor or entry.privateToken!=token or entry.runtime==null:continue
		if token==0:
			if not records.has(int(entry.id)):continue
			var record: Dictionary=records[int(entry.id)]
			if int(record.lifetime)!=lifetime:continue
			if record.has("presentation_lifetime"):
				if not presentation_ready:
					presentation=PresentationLifetime.token(source);presentation_ready=true;selection_presentation_projections+=1
				if record.presentation_lifetime!=presentation:continue
		selected.append(entry)
	return selected
func _competing_entries(current: Dictionary) -> Array:
	if not reuse_selection_inputs or get_script().resource_path!="res://systems/native_render/effect_world.gd":return super._competing_entries(current)
	if int(current.privateToken)!=0 and is_instance_valid(client_dummies) and (not client_dummies.get_script() is GDScript or client_dummies.get_script().resource_path!="res://systems/native_render/client_dummies.gd"):return super._competing_entries(current)
	# No bound callbacks occur in the canonical projection. The same ordered
	# fresh input walk is valid for competing removal as for normal selection.
	return _selection_entries(int(current.actor),int(current.privateToken))
func _selection_snapshot(actor: int,token: int) -> Dictionary:
	# This private schema has no custom bound/property providers. Subclasses
	# keep the general path so overridden lifetime hooks cannot be bypassed.
	if get_script().resource_path!="res://systems/native_render/effect_world.gd": return {}
	compiled_snapshot_calls+=1
	if not compiled_snapshot_available: return {"error":"Native visual snapshot is unavailable"}
	var live_dummies:=is_instance_valid(client_dummies)
	return ClassDB.class_call_static("NwnParticleKernel","visual_snapshot",_member_entries(actor,token),actor,token,world.desired,records,client_dummies.entries if live_dummies else {},not live_dummies or client_dummies.closed)
func anchor(id: int,_token: int,part: String) -> Node3D:
	if _token!=0: return client_dummies.anchor(id,_token,part) if is_instance_valid(client_dummies) else null
	var instance:=host(id)
	if not is_instance_valid(instance): return null
	if instance.get("rigs")!=null: return instance.rigs.node_for(id,0,part)
	for node in instance.get("parts") if instance.get("parts") is Array else []:
		if str(node.get_meta("native_part_name","")).to_lower()==part.to_lower(): return node
	return instance if part=="root" else null
func descriptor(id: int,token: int=0) -> Dictionary:
	if token!=0: return client_dummies.descriptor(id,token) if is_instance_valid(client_dummies) else {}
	var instance:=host(id)
	if instance==null or str(world.installed.get(id,""))!=str(world.desired[id].key): return {}
	var object: Dictionary=world.desired[id].object; var parts: Array=[]; var name:=""
	if instance.get("rigs")!=null:
		var rig: Dictionary=instance.rigs.entities[id]
		for index in rig.model_parts[0]: parts.append(rig.authored_names[int(index)])
		name=str(instance.model_names[0])
	else:
		for node in instance.get("parts") if instance.get("parts") is Array else []: parts.append(str(node.get_meta("native_part_name","")))
		name=str(instance.get_meta("native_model_name",""))
	return {"type":int(object.objectType),"parts":parts,"loadedName":name}
func reserve(actor_id: int,lifetime: int,record: Dictionary,transient: bool,token: int=0) -> void:
	if entries.size()>=512: delivery.overflow+=1; diagnose("visual.capacity","Native physical effect list reached its admission bound",0); return
	next_effect+=1
	super.receive({"kind":"visual-reserve","effectId":next_effect,"actorId":actor_id,"privateToken":token,"visualId":record.visualId,"transient":transient})
	records[next_effect]={"actor":actor_id,"lifetime":lifetime,"privateToken":token,"area":false,"record":record,"definition":{}}
	if token==0 and world.desired.has(actor_id):records[next_effect].presentation_lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd").token(world.desired[actor_id].object)
var next_effect:=0
func object(id: int) -> Variant: return world.desired[id].object if world.desired.has(id) else null
func ensure_models(resources: Dictionary) -> bool:
	for name in resources:
		if not requested.has(name):
			var job: int=assets.request(name,2002,"actor-model")
			if job>=0: requested[name]=true; jobs[job]={"kind":"model","name":name}
	return resources.keys().all(func(name):return bundles.has(name))
func route(event: Dictionary) -> bool:
	if event.kind=="loop":
		for change in event.changes:
			if change.action=="A": reserve(int(event.id),int(event.lifetime),{"visualId":change.visualId,"sourceId":change.get("target",0x7f000000),"bodyPart":0,"networkTransform":change.get("visualTransform"),"delivery":{"instant":0,"sourcePart":change.get("field8",0),"targetPart":0,"point":[0,0,0]}},false)
			elif change.action=="D": super.receive({"kind":"visual-remove","actorId":event.id,"visualId":change.visualId})
	elif event.kind=="instant":
		var packet: Dictionary=event.message; var visual:=int(packet.visualId)&65535; var target:=int(packet.targetId); var source:=int(packet.get("sourceId",0x7f000000))
		var type:=Routing.type_name(str(Definition.query(tables.visualeffects,visual,"Type_FD","string").value)); var special:=type in ["P","B"] or visual==999
		if special and int(event.get("sourceLifetime",0))>0 and not world.desired.has(source): return false
		if special and int(event.get("sourceLifetime",0))>0 and int(world.desired[source].object.get("nativeLifetime",0))!=int(event.sourceLifetime): delivery.stale+=1; return true
		var needs_dummy: bool=(not special and target==0x7f000000) or special and (not Routing.valid(object(source)) or not Routing.valid(object(target)))
		if needs_dummy and not ensure_models({"c_dummy":true}): return false
		Routing.deliver(packet,{"visualType":func(id):return Definition.query(tables.visualeffects,id,"Type_FD","string"),"object":object,"renderObject":func(actor):return actor,"createDummy":client_dummies.create,
			"add":func(actor,record):reserve(int(actor.id),int(event.lifetime),record,true,int(actor.get("privateToken",0)))})
	elif event.kind=="area":
		create_area_visual(event.message)
	return true
func create_area_visual(message: Dictionary) -> int:
	if closed or not tables.has("visualeffects"): return 0
	if entries.size()>=512: delivery.overflow+=1; return 0
	var loader:=AreaDefinition.new(); var definition:=loader.prepare(message,tables.visualeffects)
	if definition.is_empty(): diagnose("visual.native-area-definition-unavailable",loader.failure,0); return 0
	var allocation: Dictionary=client_dummies.allocate(true)
	if allocation.is_empty(): return 0
	next_effect+=1
	super.receive({"kind":"visual-reserve","effectId":next_effect,"actorId":allocation.id,"privateToken":allocation.token,"areaVisual":true,"visualId":message.visualId,"transient":true})
	records[next_effect]={"actor":allocation.id,"privateToken":allocation.token,"lifetime":0,"area":true,"definition":definition,"record":{}}
	return next_effect
func _process(delta: float) -> void:
	var began:=Timing.begin(); advance(delta); Timing.finish("callback_effects",began)
func observe_source(id: int) -> void:
	if world.desired.has(id):
		known[id]=int(world.desired[id].object.get("nativeLifetime",0)); removed_states.erase(id)
	elif known.has(id): removed_states[id]=true
func advance(delta: float) -> void:
	if closed: return
	casts.advance()
	blood.advance()
	parries.advance()
	special_attacks.advance(delta)
	equipped_attacks.advance()
	creature_voices.advance()
	controlled_id=world.controlled_id; pivots=world.instances; owner_scene.camera=get_viewport().get_camera_3d()
	# Only actors referenced by pending/active effects participate. Static scenery
	# and unrelated creatures never acquire an extra per-frame registry scan.
	var sources: Dictionary={}
	for event in queue:
		if event.kind!="area" and int(event.id)!=0x7f000000: sources[int(event.id)]=true
	for record in records.values():
		if int(record.privateToken)==0: sources[int(record.actor)]=true
	for id in sources: observe_source(int(id))
	var visual_tables_ready:=tables_ready()
	if visual_tables_ready:
		var waiting: Array=[]
		for event in queue:
			var id:=int(event.id); var lifetime:=int(event.lifetime)
			if event.kind=="area" or event.kind=="instant" and (id==0x7f000000 or lifetime==0):
				if not route(event): waiting.append(event)
				continue
			if not known.has(id) or int(known[id])<lifetime: waiting.append(event); continue
			if removed_states.get(id,false) or int(known[id])!=lifetime: delivery.stale+=1; continue
			if not route(event): waiting.append(event)
		queue=waiting
	var started:=0
	for effect_id in records.keys():
		if not entries.has(effect_id): records.erase(effect_id); continue
		var row: Dictionary=records[effect_id]; var entry: Dictionary=entries[effect_id]
		if int(row.privateToken)==0 and row.has("presentation_lifetime") and world.desired.has(int(row.actor)) and row.presentation_lifetime!=preload("res://systems/native_data/entity_presentation_lifetime.gd").token(world.desired[int(row.actor)].object):_forget(effect_id,"retired");continue
		if int(row.privateToken)==0 and (removed_states.get(row.actor,false) or known.has(row.actor) and int(known[row.actor])!=int(row.lifetime)): _forget(effect_id,"retired"); continue
		if int(row.privateToken)!=0 and not client_dummies.has(int(row.actor),int(row.privateToken)): _forget(effect_id,"retired"); continue
		if entry.runtime!=null and not row.area and host(int(row.actor),int(row.privateToken))==null: entry.runtime.detach_models()
		if not entry.definition.is_empty() or (not row.area and host(row.actor,int(row.privateToken))==null) or not visual_tables_ready: continue
		if row.definition.is_empty():
			var hosts: Dictionary={}
			for actor_id in [int(row.actor),int(row.record.sourceId)]:
				var data:=descriptor(actor_id,int(row.privateToken) if actor_id==int(row.actor) else 0)
				if not data.is_empty(): hosts[actor_id]=data
			if not hosts.has(int(row.actor)): continue
			var actor: Dictionary=client_dummies.entries[row.actor].object if int(row.privateToken)!=0 else world.desired[row.actor].object
			var loader:=Definition.new(); row.definition=loader.prepare(actor,row.record,tables,hosts)
			if row.definition.is_empty(): diagnose("visual.native-definition-unavailable",loader.failure,effect_id); _forget(effect_id,"failed"); continue
		if not ensure_models(row.definition.resources): continue
		if started>=2: continue
		if row.area:
			var model: Variant=row.definition.state.model
			if model!=null and not str(bundles[model.resource].get("error","")).is_empty(): diagnose("visual.area-model-unavailable",str(bundles[model.resource].error),effect_id); _forget(effect_id,"failed"); continue
		else:
			for index in 3:
				var model: Variant=row.definition.state.models88[index]
				if model!=null and not str(bundles[model.resource].get("error","")).is_empty(): row.definition.state.models88[index]=null; row.definition.state.retiredDc[index]=1
		entry.definition=row.definition; delivery.prepared+=1; started+=1
	super._process(delta)
func _forget(id: int,reason: String) -> void:
	if entries.has(id) and reason=="failed": stats.failed+=1
	if records.has(id) and records[id].area and is_instance_valid(client_dummies): client_dummies.remove(int(records[id].actor))
	records.erase(id); super._forget(id,reason)
func create_model(effect_id: int,resource: String):
	if not bundles.has(resource): return null
	var began:=Timing.begin(); Timing.count("count_effect_models_created",1)
	var instance:=NativeModel.new(); add_child(instance)
	if not instance.load_model(bundles[resource],world.pool):
		diagnose("visual.native-model-failed",instance.failure,effect_id); instance.retire(); Timing.finish("effect_model_create",began); return null
	next_model+=1; instance.set_meta("visual_model_id",next_model); models[next_model]={"model":instance,"effect":effect_id}
	Timing.finish("effect_model_create",began)
	return instance
func release_model(model) -> void:
	models.erase(int(model.get_meta("visual_model_id",-1))); model.retire()
func sample() -> Dictionary:
	return {"stats":stats.duplicate(true),"delivery":delivery.duplicate(),"entries":entries.size(),"models":models.size(),"pending":queue.size(),"jobs":jobs.size(),"resources":bundles.keys(),"history":history.duplicate(true),"diagnostics":diagnostics.keys(),"dummies":client_dummies.sample() if is_instance_valid(client_dummies) else {},"projectiles":projectiles.snapshot() if is_instance_valid(projectiles) else {},"casts":casts.snapshot() if casts!=null else {},"blood":blood.snapshot() if blood!=null else {},"parries":parries.snapshot() if parries!=null else {},"special_attacks":special_attacks.snapshot() if special_attacks!=null else {},"equipped_attacks":equipped_attacks.snapshot() if equipped_attacks!=null else {},"creature_voices":creature_voices.snapshot() if creature_voices!=null else {},"script_sounds":script_sounds.snapshot() if script_sounds!=null else {},"audio":world_audio.snapshot() if is_instance_valid(world_audio) else {}}
func detach_prepared_data() -> Dictionary:
	# Worker outputs/rule tables contain only decoded data. Definitions, live
	# effect records, physical models and audio/scene owners stay on this thread.
	# Child controllers may clear their aliases of these top-level maps during
	# close. A shallow retained container protects the immutable child graphs.
	var payload:={"bundles":bundles.duplicate(),"tables":tables.duplicate()}
	if is_instance_valid(projectiles): payload.projectiles=projectiles.detach_prepared_data()
	if creature_voices!=null: payload.creature_voices=creature_voices.detach_prepared_data()
	bundles={}; tables={}; return payload
func close_controller(owner,phase: String) -> void:
	if not is_instance_valid(owner): return
	var began:=Timing.begin(); owner.close(); Timing.finish("retirement_effect_"+phase,began)
func close() -> void:
	if closed: return
	if perception_visuals!=null:perception_visuals.close()
	close_controller(projectiles,"projectiles"); close_controller(casts,"casts")
	close_controller(blood,"blood"); close_controller(parries,"parries")
	close_controller(special_attacks,"special_attacks"); close_controller(equipped_attacks,"equipped_attacks")
	close_controller(creature_voices,"voices"); close_controller(script_sounds,"script_sounds")
	var began:=Timing.begin(); super.close(); Timing.finish("retirement_effect_models",began)
	close_controller(client_dummies,"dummies"); close_controller(world_audio,"audio"); close_controller(assets,"assets")
	records.clear(); queue.clear(); bundles.clear(); tables.clear(); jobs.clear(); pivots={}; known.clear()
