extends "res://systems/visual_world.gd"
# Direct-native resources and event lifetime owner. The retained phase/selection
# logic operates on private original models, without staged JSON/GLB assets.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Definition=preload("res://systems/native_data/visual_definition.gd")
const SpellMetadata=preload("res://systems/native_data/spell_metadata.gd")
const VisualType10=preload("res://systems/native_data/visual_type10.gd")
const NativeModel=preload("res://systems/native_render/effect_model.gd")
const ModelTemplate=preload("res://systems/native_render/model_template.gd")
const ModelPointLight=preload("res://systems/native_render/model_point_light.gd")
const ModelReference=preload("res://systems/native_render/model_reference.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const Routing=preload("res://systems/native_data/object_visual_route.gd")
const AreaDefinition=preload("res://systems/native_data/area_visual_definition.gd")
const PresentationLifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
class VisualPhase extends Node:
	var manager
	func _process(delta: float) -> void:
		if is_instance_valid(manager): manager.advance_visual_phase(delta)
var reuse_selection_inputs:=not OS.get_cmdline_user_args().has("--effect-inputs=reference")
var selection_owner_projections:=0
var selection_presentation_projections:=0
var world
var visual_phase
var combat_timer: Variant=null
var assets
var tables: Dictionary={}
var jobs: Dictionary={}
var bundles: Dictionary={}
var graphics_sources: Dictionary={}
var requested: Dictionary={}
var records: Dictionary={}
var area_visual_received:=0
var area_visual_failed:=0
var queue: Array=[]
var last_serial:=-1
var known: Dictionary={}
var controlled_id:=-1
var removed_states: Dictionary={}
var world_scope: Dictionary={}
var pivots: Dictionary={}
var last_render_positions: Dictionary={}
var cached_render_views: Dictionary={}
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
signal instant_receipt_completed(receipt_id: int)
var instant_receipts: Dictionary={}
var next_instant_receipt:=0

func create_instant_receipt() -> int:
	if closed:return 0
	next_instant_receipt+=1
	instant_receipts[next_instant_receipt]={"done":false,"outcome":"","effects":[]}
	return next_instant_receipt

func _complete_instant_receipt(receipt_id: int,outcome: String,effects: Array=[]) -> void:
	if not instant_receipts.has(receipt_id) or bool(instant_receipts[receipt_id].done):return
	instant_receipts[receipt_id]={"done":true,"outcome":outcome,"effects":effects}
	instant_receipt_completed.emit(receipt_id)

func finish_instant_receipt(receipt_id: int,outcome: String) -> void:
	_complete_instant_receipt(receipt_id,outcome)

func wait_instant_receipt(receipt_id: int) -> Dictionary:
	if receipt_id<=0:return {"outcome":"unavailable","effects":[]}
	while instant_receipts.has(receipt_id) and not bool(instant_receipts[receipt_id].done) and not closed:await instant_receipt_completed
	var result: Dictionary=instant_receipts.get(receipt_id,{"done":true,"outcome":"closed","effects":[]}).duplicate(true)
	instant_receipts.erase(receipt_id)
	return result

func _finish_instant_receipt(receipt_id: int,effect_ids: Array,delivered: bool,dummy_failed: bool=false) -> void:
	var outcomes: Array=[]
	for effect_id in effect_ids:outcomes.append(await wait_effect_outcome(int(effect_id)))
	_complete_instant_receipt(receipt_id,"routed" if delivered else "dummy-unavailable" if dummy_failed else "unavailable",outcomes)
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
	# Old projectile update advances cast visuals, then dummies and projectiles,
	# before the separate visual phase. Keep these as two scoped process stages.
	# Cast controller commands precede this world's effect-model binding (10)
	# and rig (12), then dummy (47), projectile (50) and visual (54) phases.
	world=owner; client=self; world_scope={"ticket":world.generation}; process_priority=9
	world.instance_removed.connect(_capture_last_render_position)
	world.instance_ready.connect(_clear_last_render_position)
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
	visual_phase=VisualPhase.new();visual_phase.manager=self;visual_phase.process_priority=54;add_child(visual_phase)
func bind_combat_timer(timer: Variant) -> void:
	# The old network scene shares its combat timer with projectiles, cast
	# visuals and temporary client dummies. Bind that one owner after the
	# combat presentation has constructed it.
	combat_timer=timer
	if casts!=null: casts.configure(self)
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
	if closed:
		for event in message.get("events",[]):_complete_instant_receipt(int(event.get("receiptId",0)),"closed")
		return
	var serial:=int(message.get("serial",-1))
	if serial<=last_serial:
		delivery.stale+=1
		for event in message.get("events",[]):_complete_instant_receipt(int(event.get("receiptId",0)),"stale")
		return
	last_serial=serial
	for event in message.get("events",[]):
		if event.kind=="projectile": projectiles.receive(event); delivery.received+=1; continue
		if queue.size()>=512: delivery.overflow+=1; _complete_instant_receipt(int(event.get("receiptId",0)),"overflow"); continue
		queue.append(event.duplicate(true)); delivery.received+=1
func host(id: int,_token: int=0) -> Node3D:
	if _token!=0: return client_dummies.host(id,_token) if is_instance_valid(client_dummies) else null
	return world.instances.get(id) if world.desired.has(id) else null
func _render_scope(id: int) -> Dictionary:
	if not world.desired.has(id):return {}
	return {"canonical":world.raw_object_lookup.call(id) if world.raw_object_lookup.is_valid() else world.desired[id].object,"lifetime":PresentationLifetime.token(world.desired[id].object),"areaId":world.area_id,"generation":world.generation}
func _render_scope_matches(id: int,scope: Dictionary) -> bool:
	if scope.is_empty() or not world.desired.has(id):return false
	var current: Dictionary=_render_scope(id)
	return int(scope.areaId)==int(current.areaId) and int(scope.generation)==int(current.generation) and scope.lifetime==current.lifetime and (scope.canonical==null or is_same(scope.canonical,current.canonical))
func _note_current_render_view(id: int) -> void:
	var instance:=host(id)
	if not is_instance_valid(instance):return
	var scope:=_render_scope(id)
	if scope.is_empty():return
	scope.wrapperId=instance.get_instance_id()
	cached_render_views[id]=scope
func _descriptor_from_instance(id: int,instance: Node3D) -> Dictionary:
	if not is_instance_valid(instance) or not world.desired.has(id):return {}
	var object: Dictionary=world.desired[id].object; var parts: Array=[]; var name:=""
	if instance.get("rigs")!=null:
		var rig: Dictionary=instance.rigs.entities[id]
		for index in rig.model_parts[0]: parts.append(rig.authored_names[int(index)])
		name=str(instance.model_resource_names[0])
	else:
		for node in instance.get("parts") if instance.get("parts") is Array else []: parts.append(str(node.get_meta("native_part_name","")))
		name=str(instance.get_meta("native_model_name",""))
	return {"type":int(object.objectType),"parts":parts,"loadedName":name}
func _capture_last_render_position(id: int) -> void:
	# NetworkVisualPresentation.render remembers the last current wrapper even
	# after its last effect ends. The world emits before retiring that Node3D.
	# Its authored roots are removed during retirement; only view metadata and
	# position remain available to a new visual in this replacement interval.
	if closed or not world.desired.has(id) or world.failed_objects.has(id):return
	var instance: Variant=world.instances.get(id)
	if not is_instance_valid(instance):return
	var scope: Dictionary=cached_render_views.get(id,{})
	if not _render_scope_matches(id,scope) or int(scope.get("wrapperId",0))!=instance.get_instance_id():return
	var old_descriptor: Dictionary=_descriptor_from_instance(id,instance)
	if old_descriptor.is_empty():return
	old_descriptor.parts=[] # NetworkScene.destroyModels removes the physical graph.
	var retained: Dictionary=_render_scope(id)
	retained.position=instance.global_position
	retained.wrapperId=instance.get_instance_id()
	retained.descriptor=old_descriptor
	last_render_positions[id]=retained
func _clear_last_render_position(id: int,_source: Dictionary,_instance: Variant) -> void:
	last_render_positions.erase(id)
	if cached_render_views.has(id):_note_current_render_view(id)
func last_render_position(id: int) -> Variant:
	if closed or world.instances.has(id) or world.failed_objects.has(id) or not world.desired.has(id) or removed_states.get(id,false):return null
	var retained: Dictionary=last_render_positions.get(id,{})
	if not _render_scope_matches(id,retained):return null
	return retained.position
func _render_wrapper_id(id: int) -> int:
	var instance:=host(id)
	if is_instance_valid(instance):return instance.get_instance_id()
	return int(last_render_positions.get(id,{}).get("wrapperId",0)) if last_render_position(id) is Vector3 else 0
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
	if record.has("view_scope") and not _render_scope_matches(int(entry.actor),record.view_scope):return false
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
	if instance==null:
		if last_render_position(id) is Vector3:return last_render_positions[id].get("descriptor",{}).duplicate(true)
		return {}
	if str(world.installed.get(id,""))!=str(world.desired[id].key):return {}
	var result: Dictionary=_descriptor_from_instance(id,instance)
	_note_current_render_view(id)
	return result
func _reset_physical_visual(effect_id: int,wrapper_id: int,outcome: String="replaced") -> void:
	if not records.has(effect_id) or not entries.has(effect_id):return
	var row: Dictionary=records[effect_id]
	var entry: Dictionary=entries[effect_id]
	var unadopted: Array=[]
	for model in row.get("prepared_models",{}).values():
		if is_instance_valid(model) and (entry.runtime==null or not entry.runtime.models.has(model.get_instance_id())):unadopted.append(model)
	if entry.runtime!=null:
		entry.runtime.close()
		entry.runtime=null
	for model in unadopted:
		if is_instance_valid(model):release_model(model)
	entry.binding=null
	entry.definition={}
	entry.signature=""
	entry.erase("part_query_failed")
	entry.erase("beginning")
	row.definition={}
	for key in ["visual_resource_steps","visual_resource_cursor","prepared_models","visual_references_ready","visual_asset_failures","type10_authored","type10_resource_error","type10_prepared","type10_prepare_failures"]:row.erase(key)
	row.render_wrapper_id=wrapper_id
	row.physical_failed=outcome=="failed"
	row.view_waiting=outcome=="render-unavailable"
	_complete_effect(effect_id,outcome)
func fail_physical_visual(effect_id: int) -> void:
	if not records.has(effect_id) or not entries.has(effect_id):return
	if bool(records[effect_id].get("area",false)) or int(records[effect_id].get("privateToken",0))!=0 or bool(entries[effect_id].transient) or bool(entries[effect_id].removed):_forget(effect_id,"failed");return
	stats.failed+=1
	_reset_physical_visual(effect_id,int(records[effect_id].get("render_wrapper_id",0)),"failed")
func _refresh_loop_bindings_for_add() -> void:
	# NetworkVisualPresentation.add calls loops.update(0) before its normal
	# update prepass. That update visits every cached view, not just the actor
	# receiving this add, and can invalidate another actor's old wrapper.
	for actor_id in cached_render_views.keys():
		if is_instance_valid(host(int(actor_id))):_note_current_render_view(int(actor_id))
	for effect_id in records.keys().duplicate():
		if not records.has(effect_id) or not entries.has(effect_id):continue
		var row: Dictionary=records[effect_id]
		if bool(row.area) or int(row.privateToken)!=0:continue
		var actor_id:=int(row.actor)
		var entry: Dictionary=entries[effect_id]
		if not _render_scope_matches(actor_id,row.get("view_scope",{})):_forget(int(effect_id),"retired");continue
		var wrapper_id:=_render_wrapper_id(actor_id)
		if wrapper_id==0:
			if bool(entry.transient) or bool(entry.removed):_forget(int(effect_id),"retired")
			elif not bool(row.get("view_waiting",false)):_reset_physical_visual(int(effect_id),0,"render-unavailable")
			continue
		if int(row.get("render_wrapper_id",0))==0 or int(row.render_wrapper_id)==wrapper_id:continue
		if bool(entry.transient) or bool(entry.removed):_forget(int(effect_id),"retired")
		else:_reset_physical_visual(int(effect_id),wrapper_id)
func immediate_visual_scope_current(scope: Dictionary) -> bool:
	return not closed and is_instance_valid(world) and not world.closed and not world.retiring and int(scope.get("generation",-1))==int(world.generation) and int(scope.get("areaId",-1))==int(world.area_id) and int(scope.get("ticket",-1))==int(world_scope.ticket)
func immediate_visual_before_step(scope: Dictionary) -> void:
	if immediate_visual_scope_current(scope):_refresh_loop_bindings_for_add()
func immediate_visual_entry_current(entry: Dictionary) -> bool:
	if not _bound(entry) or not records.has(int(entry.id)):return false
	if int(entry.privateToken)!=0:return true
	var row: Dictionary=records[int(entry.id)]
	return not bool(row.get("view_waiting",false)) and not bool(row.get("physical_failed",false)) and int(row.get("render_wrapper_id",0))>0 and int(row.render_wrapper_id)==_render_wrapper_id(int(row.actor))
func reserve(actor_id: int,lifetime: int,record: Dictionary,transient: bool,token: int=0,watch_receipt: bool=false) -> int:
	if entries.size()>=512: delivery.overflow+=1; diagnose("visual.capacity","Native physical effect list reached its admission bound",0); return 0
	var wrapper_id:=0
	if token==0:
		wrapper_id=_render_wrapper_id(actor_id)
		if wrapper_id==0:return 0
		_note_current_render_view(actor_id)
	# One-shot presentation owns a snapshot independent of the decoded packet.
	var stored_record: Dictionary=record.duplicate(true) if transient else record
	next_effect+=1
	var effect_id:=next_effect
	if watch_receipt:watch_effect(effect_id)
	super.receive({"kind":"visual-reserve","effectId":effect_id,"actorId":actor_id,"privateToken":token,"visualId":stored_record.visualId,"transient":transient})
	records[effect_id]={"actor":actor_id,"lifetime":lifetime,"privateToken":token,"area":false,"record":stored_record,"definition":{},"render_wrapper_id":wrapper_id}
	if token==0 and world.desired.has(actor_id):
		records[effect_id].presentation_lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd").token(world.desired[actor_id].object)
		records[effect_id].view_scope=_render_scope(actor_id)
	if token==0 and not transient:super.immediate_loop_zero_update({"generation":world.generation,"areaId":world.area_id,"ticket":world_scope.ticket})
	return effect_id
var next_effect:=0
func object(id: int) -> Variant: return world.desired[id].object if world.desired.has(id) else null
func _type10_resource(value: Variant) -> Dictionary:
	return VisualType10.object_template_resref(str(value))
func _type10_identity(id: int) -> Variant:
	var source: Variant=world.raw_object_lookup.call(id) if world.raw_object_lookup.is_valid() else object(id)
	var private_token:=0
	if source==null and client_dummies.entries.has(id):
		source=client_dummies.entries[id].object
		private_token=int(client_dummies.entries[id].token)
	if not source is Dictionary:return null
	return [PresentationLifetime.token(source),private_token]
func _type10_prepare(row: Dictionary) -> void:
	var definition: Dictionary=row.definition
	var authored: Dictionary={}
	var prepared: Dictionary={}
	for key in definition.programs:
		var program: Dictionary=definition.programs[key]
		if int(program.get("type",{}).get("value",0))&255!=10:continue
		var resource:=_type10_resource(program.get("string",{}).get("param1",{}).get("value",""))
		if resource.has("error"):row.type10_resource_error=str(resource.error);continue
		authored[str(key)]=str(resource.value)
		var path:=int(program.get("integer",{}).get("param4",{}).get("value",0))
		prepared[str(key)]={"main":false,"auxiliary":false,"path":path}
	row.type10_authored=authored
	row.type10_prepared=prepared
	row.type10_prepare_failures={}
func start_type10(effect_id: int,effect: Dictionary,program_id: int,program: Dictionary) -> void:
	if closed or not records.has(effect_id):return
	var row: Dictionary=records[effect_id]
	var prepared: Dictionary=row.get("type10_prepared",{}).get(str(program_id),{})
	if prepared.is_empty():diagnose("visual.procedural-projectile-resource-unavailable","Native procedural projectile assets were not prepared",effect_id);return
	var expected: Dictionary=prepared.get("identity",{})
	if expected.get("source")!=_type10_identity(int(effect.source58)) or expected.get("target")!=_type10_identity(int(effect.target54)):
		diagnose("visual.procedural-projectile-stale","Procedural projectile source/target changed during resource loading",effect_id)
		return
	var resource:=_type10_resource(program.get("string",{}).get("param1",{}).get("value",""))
	if resource.has("error"):diagnose("visual.procedural-projectile-resource-unavailable",str(resource.error),effect_id);return
	if str(row.get("type10_authored",{}).get(str(program_id),""))!=str(resource.value):diagnose("visual.procedural-projectile-stale","Procedural projectile resource changed during loading",effect_id);return
	projectiles.start_procedural(effect,program_id,program,prepared)
func ensure_models(resources: Dictionary) -> bool:
	for name in resources:
		if not requested.has(name):
			var job: int=assets.request(name,2002,"actor-model")
			if job>=0: requested[name]=true; jobs[job]={"kind":"model","name":name}
	return resources.keys().all(func(name):return bundles.has(name))
func visual_resource_steps(row: Dictionary) -> Array:
	# The old loader yields ground, impact and head in slot order, then the
	# distinct program IDs in programsD0 order. Repeated names share bytes but
	# each ordinary slot still gets its own model instance.
	var steps: Array=[]
	var state: Dictionary=row.definition.state
	for index in 3:
		var model: Variant=state.models88[index]
		if model is Dictionary:steps.append({"kind":"model","index":index,"name":str(model.resource)})
	var seen_programs: Dictionary={}
	for value in state.programsD0:
		var id:=int(value)
		if id==65535 or seen_programs.has(id):continue
		seen_programs[id]=true
		var program: Dictionary=row.definition.programs.get(str(id),{})
		var name:=str(program.get("resource",""))
		if not name.is_empty():steps.append({"kind":"program","name":name})
		if int(program.get("type",{}).get("value",0))&255==10:
			var resource:=_type10_resource(program.get("string",{}).get("param1",{}).get("value",""))
			if resource.has("error"):steps.append({"kind":"type10-error","error":str(resource.error)});continue
			name=str(resource.value).to_lower()
			steps.append({"kind":"type10","name":name,"programId":str(id),"role":"main"})
			var path:=int(program.get("integer",{}).get("param4",{}).get("value",0))
			if path in [7,10]:steps.append({"kind":"type10","name":"ref","programId":str(id),"role":"auxiliary"})
	return steps
func _visual_asset_failure(row: Dictionary,effect_id: int,name: String,reason: String) -> void:
	name=name.to_lower()
	if row.visual_asset_failures.has(name):return
	# createVisualSceneRuntime.getAsset caches the rejected per-name Promise as
	# null for this effect. The scene's parsed bundle remains available to other
	# owners, while this effect does not retry its failed reference closure.
	row.visual_asset_failures[name]=reason
	diagnose("visual.model-load-failed",reason,effect_id,{"model":name})
func _type10_prefetch_failure(row: Dictionary,effect_id: int,step: Dictionary,reason: String) -> void:
	var program_id:=str(step.programId)
	var prepared: Dictionary=row.type10_prepared.get(program_id,{})
	if prepared.is_empty() or prepared.get("prefetch_failed",false):return
	prepared.prefetch_failed=true
	var resource:=str(row.type10_authored.get(program_id,""))
	diagnose("visual.procedural-projectile-prefetch-failed",reason,effect_id,{"resource":resource,"path":int(prepared.path)})
func ensure_visual_resources(row: Dictionary,effect_id: int) -> Dictionary:
	if not row.has("visual_resource_steps"):
		row.visual_resource_steps=visual_resource_steps(row)
		row.visual_resource_cursor=0
		row.prepared_models={}
		row.visual_references_ready={}
		row.visual_asset_failures={}
	var steps: Array=row.visual_resource_steps
	while int(row.visual_resource_cursor)<steps.size():
		var step: Dictionary=steps[int(row.visual_resource_cursor)]
		if str(step.kind)=="type10-error":return {"status":"failed","kind":"type10","reason":str(step.error)}
		var name:=str(step.name).to_lower()
		var type10:=str(step.kind)=="type10"
		var prepared: Dictionary=row.type10_prepared.get(str(step.get("programId","")),{}) if type10 else {}
		if type10 and str(step.role)=="main" and not prepared.has("identity"):
			var effect_state: Dictionary=row.definition.state
			prepared.identity={"source":_type10_identity(int(effect_state.source58)),"target":_type10_identity(int(effect_state.target54))}
		if type10 and str(step.role)=="auxiliary" and not bool(prepared.get("main",false)):
			row.visual_resource_cursor=int(row.visual_resource_cursor)+1
			continue
		if type10 and name.is_empty():
			_type10_prefetch_failure(row,effect_id,step,"Referenced model name is unavailable")
			row.visual_resource_cursor=int(row.visual_resource_cursor)+1
			continue
		if not bundles.has(name):
			if not requested.has(name):
				var job: int=assets.request(name,2002,"actor-model")
				if job>=0:
					requested[name]=true
					jobs[job]={"kind":"model","name":name}
			if not bundles.has(name):return {"status":"pending"}
		var bundle: Dictionary=bundles[name]
		if type10:
			# prepareProcedural awaits the main factory first and catches either
			# factory failure without aborting its enclosing visual. A successful
			# main remains available when the optional endpoint preparation fails.
			var reason:=str(row.type10_prepare_failures.get(name,row.visual_asset_failures.get(name,bundle.get("error",""))))
			if reason.is_empty() and not row.visual_references_ready.has(name):
				var reference_state: Dictionary=ensure_reference_trees({name:true},true)
				if str(reference_state.get("status",""))=="pending":return reference_state
				if str(reference_state.get("status",""))!="ready":reason=str(reference_state.get("reason","Native visual resource is unavailable"))
				else:row.visual_references_ready[name]=true
			if not reason.is_empty():
				row.type10_prepare_failures[name]=reason
				_type10_prefetch_failure(row,effect_id,step,reason)
			else:prepared[str(step.role)]=true
			row.visual_resource_cursor=int(row.visual_resource_cursor)+1
			continue
		var asset_step:=str(step.kind) in ["model","program"]
		if asset_step and row.type10_prepare_failures.has(name):_visual_asset_failure(row,effect_id,name,str(row.type10_prepare_failures[name]))
		if asset_step and not str(bundle.get("error","")).is_empty():_visual_asset_failure(row,effect_id,name,str(bundle.error))
		if str(bundle.get("error","")).is_empty() and not row.visual_asset_failures.has(name) and not row.visual_references_ready.has(name):
			var one_resource: Dictionary={}
			one_resource[name]=true
			var reference_state: Dictionary=ensure_reference_trees(one_resource,true)
			if str(reference_state.get("status",""))!="ready":
				if str(reference_state.get("status",""))=="pending":return reference_state
				if not asset_step:reference_state.kind="reference";return reference_state
				_visual_asset_failure(row,effect_id,name,str(reference_state.get("reason","Native visual resource is unavailable")))
			else:row.visual_references_ready[name]=true
		if str(step.kind)=="model":
			var index:=int(step.index)
			var model: Variant=null
			if not row.visual_asset_failures.has(name):model=create_model(effect_id,name)
			if is_instance_valid(model):
				model.visible=false
				for light in model.find_children("*","OmniLight3D",true,false):light.set_meta("native_light_priority",3)
				row.prepared_models[index]=model
			else:
				diagnose("visual.native-model-warning","CNWCVisualEffectOnObject::LoadVisualEffect: Failed to load %s node visual." % ["ground","impact","head"][index],effect_id,{"line":574+15*index})
				row.definition.state.models88[index]=null
				row.definition.state.retiredDc[index]=1
		row.visual_resource_cursor=int(row.visual_resource_cursor)+1
	return {"status":"ready"}
func ensure_reference_trees(resources: Dictionary,strict_failure: bool=false) -> Dictionary:
	for name in resources:
		var key:=str(name).to_lower()
		var bundle: Dictionary=bundles.get(key,{})
		# The old visual loader treats each failed model load independently.
		# Leave its null/retired warning decision to the three model slots.
		if not str(bundle.get("error","")).is_empty():
			if strict_failure:return {"status":"failed","reason":str(bundle.error)}
			continue
		var model: Dictionary=bundle.get("value",{})
		if not model.get("nodes",[]).any(func(row):return row.has("reference") and (not row.has("type") or str(row.type)=="reference")):continue
		if not is_instance_valid(world.references):return {"status":"failed","reason":"Native reference catalog scope is unavailable"}
		var state: Dictionary=world.references.prefetch_tree(key,bundle,self)
		if str(state.get("status",""))=="pending":return state
		if str(state.get("status",""))!="ready":
			if strict_failure:return state
			continue
	return {"status":"ready"}
func _remove_loop_visual(actor_id: int,visual_id: int) -> void:
	# NetworkVisualPresentation.remove reaches LoopingVisualPresentation.bound
	# before the next periodic render rewrite. A changed wrapper retires only
	# the selected old physical entry, without running its cessation callback.
	var current_id:=_render_wrapper_id(actor_id)
	for entry in _member_entries(actor_id,0):
		if bool(entry.areaVisual) or int(entry.privateToken)!=0 or int(entry.visual)!=visual_id or bool(entry.removed):continue
		if entry.runtime!=null and (bool(entry.runtime.state.finishedF4) or entry.runtime.phase.has_cessation()):continue
		if not records.has(int(entry.id)) or not _render_scope_matches(actor_id,records[int(entry.id)].get("view_scope",{})):continue
		if bool(records[int(entry.id)].get("view_waiting",false)):continue
		var old_id:=int(records[int(entry.id)].get("render_wrapper_id",0))
		if old_id>0 and old_id!=current_id:
			entry.removed=true
			stats.removed+=1
			_forget(int(entry.id),"retired")
			return
		super.receive({"kind":"visual-remove","actorId":actor_id,"visualId":visual_id,"effectId":int(entry.id)})
		return
func route(event: Dictionary) -> bool:
	if event.kind=="loop":
		for change in event.changes:
			if change.action=="A": reserve(int(event.id),int(event.lifetime),{"visualId":change.visualId,"sourceId":change.get("target",0x7f000000),"bodyPart":0,"networkTransform":change.get("visualTransform"),"delivery":{"instant":0,"sourcePart":change.get("field8",0),"targetPart":0,"point":[0,0,0]}},false)
			elif change.action=="D": _remove_loop_visual(int(event.id),int(change.visualId))
	elif event.kind=="instant":
		var receipt_id:=int(event.get("receiptId",0))
		var reserved: Array=[]
		var dummy_state:={"failed":false}
		var packet: Dictionary=event.message; var visual:=int(packet.visualId)&65535; var target:=int(packet.targetId); var source:=int(packet.get("sourceId",0x7f000000))
		var type:=Routing.type_name(str(SpellMetadata.native_string_entry(tables.visualeffects,visual,"Type_FD").value)); var special:=type in ["P","B"] or visual==999
		if special and int(event.get("sourceLifetime",0))>0 and not world.desired.has(source): return false
		if special and int(event.get("sourceLifetime",0))>0 and int(world.desired[source].object.get("nativeLifetime",0))!=int(event.sourceLifetime): delivery.stale+=1; _complete_instant_receipt(receipt_id,"stale"); return true
		var needs_dummy: bool=(not special and target==0x7f000000) or special and (not Routing.valid(object(source)) or not Routing.valid(object(target)))
		if needs_dummy and not ensure_models({"c_dummy":true}): return false
		var make_dummy:=func(role,position,lifetime):
			var created=client_dummies.create(role,position,lifetime)
			if created==null:dummy_state.failed=true
			return created
		var delivered: int=Routing.deliver(packet,{"visualType":func(id):return SpellMetadata.native_string_entry(tables.visualeffects,id,"Type_FD"),"object":object,"renderObject":func(actor):return actor,"createDummy":make_dummy,
			"add":func(actor,record):
				var effect_id:=reserve(int(actor.id),int(event.lifetime),record,true,int(actor.get("privateToken",0)),receipt_id>0)
				if effect_id>0:reserved.append(effect_id)
				return 1 if effect_id>0 else 0})
		if receipt_id>0:_finish_instant_receipt(receipt_id,reserved,delivered==1,bool(dummy_state.failed))
	elif event.kind=="area":
		create_area_visual(event.message)
	return true
func create_area_visual(message: Dictionary) -> int:
	if closed:return 0
	area_visual_received+=1
	if not tables.has("visualeffects"): return 0
	if entries.size()>=512: delivery.overflow+=1; return 0
	var loader:=AreaDefinition.new(); var definition:=loader.prepare(message,tables.visualeffects)
	if definition.is_empty(): diagnose("visual.native-area-definition-unavailable",loader.failure,0); return 0
	var allocation: Dictionary=client_dummies.allocate(true)
	if allocation.is_empty(): return 0
	next_effect+=1
	super.receive({"kind":"visual-reserve","effectId":next_effect,"actorId":allocation.id,"privateToken":allocation.token,"areaVisual":true,"visualId":message.visualId,"transient":true})
	records[next_effect]={"actor":allocation.id,"privateToken":allocation.token,"lifetime":0,"area":true,"definition":definition,"record":{}}
	return next_effect
func _process(_delta: float) -> void:
	if closed or casts==null:return
	var began:=Timing.begin();casts.advance();Timing.finish("callback_casts",began)
func advance_visual_phase(delta: float) -> void:
	var began:=Timing.begin(); advance(delta); Timing.finish("callback_effects",began)
func observe_source(id: int) -> void:
	if world.desired.has(id):
		known[id]=int(world.desired[id].object.get("nativeLifetime",0)); removed_states.erase(id)
	elif known.has(id): removed_states[id]=true
func advance(delta: float) -> void:
	if closed: return
	for id in cached_render_views.keys():
		if _render_scope_matches(int(id),cached_render_views[id]):continue
		if is_instance_valid(host(int(id))):_note_current_render_view(int(id))
		else:cached_render_views.erase(id)
	for id in last_render_positions.keys():
		if not (last_render_position(int(id)) is Vector3):last_render_positions.erase(id)
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
			if removed_states.get(id,false) or int(known[id])!=lifetime: delivery.stale+=1; _complete_instant_receipt(int(event.get("receiptId",0)),"stale"); continue
			if not route(event): waiting.append(event)
		queue=waiting
	var started:=0
	for effect_id in records.keys():
		if not entries.has(effect_id): records.erase(effect_id); continue
		var row: Dictionary=records[effect_id]; var entry: Dictionary=entries[effect_id]
		if int(row.privateToken)==0 and row.has("view_scope") and not _render_scope_matches(int(row.actor),row.view_scope):_forget(effect_id,"retired");continue
		if int(row.privateToken)==0 and row.has("presentation_lifetime") and world.desired.has(int(row.actor)) and row.presentation_lifetime!=preload("res://systems/native_data/entity_presentation_lifetime.gd").token(world.desired[int(row.actor)].object):_forget(effect_id,"retired");continue
		if int(row.privateToken)==0 and (removed_states.get(row.actor,false) or known.has(row.actor) and int(known[row.actor])!=int(row.lifetime)): _forget(effect_id,"retired"); continue
		if int(row.privateToken)!=0 and not client_dummies.has(int(row.actor),int(row.privateToken)): _forget(effect_id,"retired"); continue
		if int(row.privateToken)==0 and host(int(row.actor))==null and not (last_render_position(int(row.actor)) is Vector3):
			if bool(entry.transient) or bool(entry.removed):_forget(effect_id,"retired")
			elif not bool(row.get("view_waiting",false)):_reset_physical_visual(int(effect_id),0,"render-unavailable")
			continue
		if bool(row.get("view_waiting",false)):
			row.view_waiting=false
			row.render_wrapper_id=_render_wrapper_id(int(row.actor))
		if bool(row.get("physical_failed",false)):continue
		if entry.runtime!=null and not row.area and host(int(row.actor),int(row.privateToken))==null: entry.runtime.detach_models()
		if not entry.definition.is_empty() or (not row.area and host(row.actor,int(row.privateToken))==null and (int(row.privateToken)!=0 or not (last_render_position(int(row.actor)) is Vector3))) or not visual_tables_ready: continue
		if row.definition.is_empty():
			var hosts: Dictionary={}
			for actor_id in [int(row.actor),int(row.record.sourceId)]:
				var data:=descriptor(actor_id,int(row.privateToken) if actor_id==int(row.actor) else 0)
				if not data.is_empty(): hosts[actor_id]=data
			if not hosts.has(int(row.actor)): continue
			var actor: Dictionary=client_dummies.entries[row.actor].object if int(row.privateToken)!=0 else world.desired[row.actor].object
			var loader:=Definition.new(); row.definition=loader.prepare(actor,row.record,tables,hosts)
			if row.definition.is_empty(): diagnose("visual.native-definition-unavailable",loader.failure,effect_id); _forget(effect_id,"failed"); continue
			_type10_prepare(row)
		if row.area:
			if not ensure_models(row.definition.resources):continue
			var reference_state: Dictionary=ensure_reference_trees(row.definition.resources)
			if reference_state.status=="pending":continue
			if reference_state.status!="ready":diagnose("visual.reference-preparation-failed",str(reference_state.get("reason","")),effect_id);_forget(effect_id,"failed");continue
		else:
			var resource_state: Dictionary=ensure_visual_resources(row,int(effect_id))
			if str(resource_state.get("status",""))=="pending":continue
			if str(resource_state.get("status",""))!="ready":diagnose("visual.procedural-projectile-resource-unavailable" if str(resource_state.get("kind",""))=="type10" else "visual.reference-preparation-failed",str(resource_state.get("reason","")),effect_id);_forget(effect_id,"failed");continue
		if started>=2: continue
		if row.area:
			var model: Variant=row.definition.state.model
			if model!=null and not str(bundles[model.resource].get("error","")).is_empty(): diagnose("visual.area-model-unavailable",str(bundles[model.resource].error),effect_id); _forget(effect_id,"failed"); continue
		else:row.definition.prepared_models=row.prepared_models;row.definition.asset_failures=row.visual_asset_failures.duplicate()
		entry.definition=row.definition; delivery.prepared+=1; started+=1
	# NetworkVisualPresentation.update first rewrites an existing entry's render
	# to the current wrapper before loops.update can invoke any callbacks. A
	# queued add above ran first and may have replaced the old physical entry.
	for effect_id in records.keys():
		if not records.has(effect_id) or not entries.has(effect_id):continue
		var row: Dictionary=records[effect_id]
		if bool(row.area) or int(row.privateToken)!=0 or not _render_scope_matches(int(row.actor),row.get("view_scope",{})):continue
		var current_id:=_render_wrapper_id(int(row.actor))
		if current_id>0:row.render_wrapper_id=current_id
	super._process(delta)
func _forget(id: int,reason: String) -> void:
	if entries.has(id) and reason=="failed": stats.failed+=1
	if records.has(id) and bool(records[id].get("area",false)) and reason=="failed":area_visual_failed+=1
	if reason=="failed" and records.has(id) and entries.has(id) and not bool(records[id].get("area",false)) and int(records[id].get("privateToken",0))==0 and not bool(entries[id].transient) and not bool(entries[id].removed):
		# The old load catch releases the physical instance but leaves the
		# authoritative looping record in the view until a later render change.
		_reset_physical_visual(id,int(records[id].get("render_wrapper_id",0)),"failed")
		return
	if records.has(id) and records[id].area and is_instance_valid(client_dummies): client_dummies.remove(int(records[id].actor))
	# Models created at the old sequential loader boundary have not yet been
	# handed to VisualRuntime when a pending effect is canceled or retired.
	if records.has(id) and (not entries.has(id) or entries[id].runtime==null):
		for model in records[id].get("prepared_models",{}).values():
			if is_instance_valid(model):release_model(model)
	records.erase(id); super._forget(id,reason)
func _schedule_visual_references(root: Node3D) -> void:
	# The old visual adapter advances the owned animator, then each level's
	# referenced animator/attachment before the phase clock. The published
	# prefetched tree is complete here; projectile owners override 51/52 later.
	for reference in root.find_children("native_reference","Node3D",true,false):
		if reference.get_script()!=ModelReference:continue
		var depth:=1;var ancestor: Node=reference.get_parent()
		while ancestor!=null and ancestor!=root:
			if ancestor.get_script()==ModelReference:depth+=1
			ancestor=ancestor.get_parent()
		var referenced: Variant=reference.get("model68")
		if is_instance_valid(referenced) and is_instance_valid(referenced.get("rigs")):
			referenced.rigs.process_priority=11+2*depth
		reference.process_priority=12+2*depth
func create_model(effect_id: int,resource: String,publish_scene: bool=true):
	if not bundles.has(resource) or closed or not is_instance_valid(world) or world.closed or world.retiring or int(world.generation)!=int(world_scope.ticket):return null
	var began:=Timing.begin(); Timing.count("count_effect_models_created",1)
	# The projectile receiver loads and poses its model before setScene(1).
	# Ordinary effect callers keep their original add-before-load ordering.
	var instance:=NativeModel.new(); instance.bind_reference_scene_root(self)
	if publish_scene:add_child(instance)
	if not instance.load_model(bundles[resource],world.pool):
		diagnose("visual.native-model-failed",instance.failure,effect_id);instance.retire();Timing.finish("effect_model_create",began);return null
	if publish_scene:
		if not _finalize_scene_model(instance,effect_id,resource):
			instance.retire();Timing.finish("effect_model_create",began);return null
	next_model+=1
	instance.set_meta("visual_model_id",next_model)
	instance.set_meta("native_visual_resource",resource)
	instance.set_meta("native_scene_published",publish_scene)
	models[next_model]={"model":instance,"effect":effect_id}
	Timing.finish("effect_model_create",began)
	return instance
func publish_projectile_model(instance: Node3D,parent: Node) -> bool:
	if closed or not is_instance_valid(world) or world.closed or world.retiring or int(world.generation)!=int(world_scope.ticket) or not is_instance_valid(instance) or bool(instance.get("retired")) or not is_instance_valid(parent):return false
	var model_id:=int(instance.get_meta("visual_model_id",-1))
	if not models.has(model_id) or not is_same(models[model_id].model,instance):return false
	if bool(instance.get_meta("native_scene_published",false)):return instance.get_parent()==parent
	# EffectModel's reference scene owner is this exact root. A different parent
	# would make subsequent reference attachment fail its original owner guard.
	if parent!=self or instance.get_parent()!=null:return false
	parent.add_child(instance)
	if not is_instance_valid(instance) or not models.has(model_id) or not is_same(models[model_id].model,instance):return false
	if closed or world.closed or world.retiring or int(world.generation)!=int(world_scope.ticket):
		if instance.get_parent()==parent:parent.remove_child(instance)
		return false
	var effect_id:=int(models[model_id].effect)
	var resource:=str(instance.get_meta("native_visual_resource",""))
	if not bundles.has(resource):
		parent.remove_child(instance)
		return false
	if not _finalize_scene_model(instance,effect_id,resource):
		if is_instance_valid(instance) and instance.get_parent()==parent:parent.remove_child(instance)
		return false
	instance.set_meta("native_scene_published",true)
	return true
func _finalize_scene_model(instance: Node3D,effect_id: int,resource: String) -> bool:
	if not instance.is_inside_tree() or not bundles.has(resource):return false
	if bundles[resource].get("value",{}).get("nodes",[]).any(func(row):return row.has("reference") and (not row.has("type") or str(row.type)=="reference")):
		var published: Dictionary=world.references.publish_prefetched_tree(instance) if is_instance_valid(world.references) else {"status":"failed","reason":"Native reference catalog scope is unavailable"}
		if published.status!="ready":
			diagnose("visual.reference-publication-failed",str(published.get("reason","")),effect_id)
			return false
	# Retain the shared material variant lease through area retirement. This is
	# the same finalization used by default effect models after scene insertion.
	var graphics=world.get_meta("native_area_graphics_owner",null)
	if graphics!=null:
		if not graphics_sources.has(resource):graphics_sources[resource]=ModelTemplate.identity(bundles[resource],world.pool)
		var preparation_key:="visual:"+str(graphics_sources[resource])
		var prepared: Dictionary=graphics.prepare_model(instance,preparation_key)
		if not bool(prepared.get("ready",false)):
			diagnose("visual.native-model-preparation-failed",str(prepared.get("error","Material preparation failed")),effect_id)
			return false
		instance.set_meta("native_graphics_preparation_key",preparation_key)
	if records.has(effect_id):_schedule_visual_references(instance)
	if bool(records.get(effect_id,{}).get("area",false)):
		for light in instance.find_children("*","OmniLight3D",true,false):
			if light.get_script()==ModelPointLight:light.set_meta("native_light_priority",11)
	return true
func type4_shadowing(model,enabled: bool)->void:
	if not is_instance_valid(model):return
	for light in model.find_children("*","OmniLight3D",true,false):
		if light.get_script()==ModelPointLight:light.set_native_shadowing(enabled)
func release_model(model) -> void:
	# NetworkScene retains each parsed asset/preparation record across individual
	# effect endings. Keep its shared variants until the area asset cache closes.
	models.erase(int(model.get_meta("visual_model_id",-1))); model.retire()
func area_visual_snapshot() -> Dictionary:
	var active: Array[Dictionary]=[]
	for effect_id in records:
		var row: Dictionary=records[effect_id]
		if not bool(row.get("area",false)) or not entries.has(effect_id):continue
		var entry: Dictionary=entries[effect_id]
		var runtime: Variant=entry.get("runtime")
		var state: Dictionary=runtime.state if is_instance_valid(runtime) else row.get("definition",{}).get("state",{})
		var model: Variant=state.get("model")
		var authored: Variant=row.get("definition",{}).get("state",{}).get("model")
		active.append({"id":int(row.actor),"visualId":int(entry.visual),"ready":model is Node and is_instance_valid(model),"model":authored.get("resource") if authored is Dictionary else null,"phase":int(state.get("phase184",0)),"remaining":int(state.get("remaining17c",0)),"retiring":int(state.get("retiring188",0)),"retireRemaining":int(state.get("retire178",0)),"position":state.get("position",[])})
	return {"received":area_visual_received,"failed":area_visual_failed,"active":active}
func sample() -> Dictionary:
	return {"stats":stats.duplicate(true),"area_visuals":area_visual_snapshot(),"delivery":delivery.duplicate(),"entries":entries.size(),"models":models.size(),"pending":queue.size(),"jobs":jobs.size(),"resources":bundles.keys(),"history":history.duplicate(true),"diagnostics":diagnostics.keys(),"dummies":client_dummies.sample() if is_instance_valid(client_dummies) else {},"projectiles":projectiles.snapshot() if is_instance_valid(projectiles) else {},"client_projectiles":projectiles.client_snapshot() if is_instance_valid(projectiles) else {},"casts":casts.snapshot() if casts!=null else {},"blood":blood.snapshot() if blood!=null else {},"client_blood":blood.client_snapshot() if blood!=null else [],"parries":parries.snapshot() if parries!=null else {},"special_attacks":special_attacks.snapshot() if special_attacks!=null else {},"equipped_attacks":equipped_attacks.snapshot() if equipped_attacks!=null else {},"creature_voices":creature_voices.snapshot() if creature_voices!=null else {},"script_sounds":script_sounds.snapshot() if script_sounds!=null else {},"audio":world_audio.snapshot() if is_instance_valid(world_audio) else {}}
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
	for receipt_id in instant_receipts.keys():_complete_instant_receipt(int(receipt_id),"closed")
	if perception_visuals!=null:perception_visuals.close()
	close_controller(projectiles,"projectiles"); close_controller(casts,"casts")
	close_controller(blood,"blood"); close_controller(parries,"parries")
	close_controller(special_attacks,"special_attacks"); close_controller(equipped_attacks,"equipped_attacks")
	close_controller(creature_voices,"voices"); close_controller(script_sounds,"script_sounds")
	var began:=Timing.begin(); super.close(); Timing.finish("retirement_effect_models",began)
	close_controller(client_dummies,"dummies"); close_controller(world_audio,"audio"); close_controller(assets,"assets")
	var graphics=world.get_meta("native_area_graphics_owner",null) if is_instance_valid(world) else null
	if graphics!=null:
		for identity in graphics_sources.values():graphics.release_model("visual:"+str(identity))
	graphics_sources.clear()
	records.clear(); queue.clear(); bundles.clear(); tables.clear(); jobs.clear(); pivots={}; last_render_positions.clear(); cached_render_views.clear(); known.clear()
	combat_timer=null
