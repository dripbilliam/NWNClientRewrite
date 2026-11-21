extends Node3D
const Timing=preload("res://systems/native_render/frame_profile.gd")
const JoinDiagnostics=preload("res://systems/native_render/join_publication_diagnostics.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Appearance=preload("res://systems/native_data/creature_appearance.gd")
const Items=preload("res://systems/native_data/item_appearance.gd")
const MovementRate=preload("res://systems/native_data/native_movement_rate.gd")
const Lookup=preload("res://systems/native_data/animation_lookup.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Priority=preload("res://systems/native_render/stream_priority.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const SourcePrefetch=preload("res://systems/native_data/resource_prefetch.gd")
var source_prefetch
var prefetch_waiting: Dictionary={}
var foreground_keys: Dictionary={}
var _planning_active:=false
var _planning_cursor:=0
var _actor_pending: Dictionary={}
var reference_admissions: Dictionary={}
func reference_token(plan: Dictionary,piece: Dictionary) -> String:
	return "creature:"+str(get_instance_id())+":"+str(plan.id)+":"+str(piece.key)
func release_reference_token(token: String) -> void:
	if not reference_admissions.has(token):return
	var hub=admission_parent.get_meta("native_reference_hub") if is_instance_valid(admission_parent) and admission_parent.has_meta("native_reference_hub") else null
	if is_instance_valid(hub):hub.release_admission(str(reference_admissions[token]),token)
	reference_admissions.erase(token)
func release_reference_plan(plan: Dictionary) -> void:
	for piece in plan.pieces:release_reference_token(reference_token(plan,piece))
func discard_failed_held(plan: Dictionary,failed: Dictionary) -> void:
	var previous: Dictionary=plan.get("failedHeld",{})
	for item_id in failed:
		if previous.has(item_id):continue
		var row: Dictionary=failed[item_id]
		stats.warnings.append({"id":plan.id,"itemId":item_id,"code":"network.scene-equipment-model-failed","model":row.get("model",""),"reason":row.reason})
		previous[item_id]=row
	var retained: Array=[]
	for piece in plan.pieces:
		if previous.has(int(piece.get("equipmentItemId",-1))):release_reference_token(reference_token(plan,piece))
		else:retained.append(piece)
	plan.pieces=retained;plan.failedHeld=previous
func recover_failed_optional_install(plan: Dictionary,actor) -> bool:
	if int(plan.kind)!=5:return false
	var source_index:=int(actor.failed_piece_source_index)
	var item_id:=int(actor.failed_equipment_item_id)
	var optional_rows: Array=[];var held:=false;var model:=""
	if source_index>=0 and source_index<plan.pieces.size():
		var piece: Dictionary=plan.pieces[source_index]
		if source_index<=plan.partBatchKeys.size():return false
		item_id=int(piece.get("equipmentItemId",-1))
		model=str(piece.get("model",""))
		held=int(piece.get("equipmentSlot",0)) in [16,32]
		optional_rows.append({"piece":piece,"reason":actor.failure})
	elif item_id>=0:
		for piece in plan.pieces:
			if int(piece.get("equipmentItemId",-1))!=item_id:continue
			model=str(piece.get("model",""))
			if int(piece.get("equipmentSlot",0)) in [16,32]:held=true
			else:optional_rows.append({"piece":piece,"reason":actor.failure})
	else:return false
	if model.is_empty() or held and plan.get("failedHeld",{}).has(item_id):return false
	if held:
		discard_failed_held(plan,{item_id:{"model":model,"reason":actor.failure}})
		for piece in plan.get("suppressedHeld",[]):
			if int(piece.get("suppressedByRightItemId",-1))==item_id:plan.pieces.append(piece)
		plan.erase("suppressedHeld")
	else:discard_optional_pieces(plan,optional_rows)
	plans.push_front(plan)
	return true
var publication_keys: Dictionary={}
func publication_current(id: int) -> bool:
	if publication_keys.is_empty():return true
	return is_instance_valid(admission_parent) and not admission_parent.closed and not admission_parent.retiring and admission_parent.desired.has(id) and str(admission_parent.desired[id].key)==str(publication_keys.get(id,""))
func cancel_actor_publication() -> void:
	if _actor_pending.is_empty():return
	var actor=_actor_pending.actor;release_reference_plan(_actor_pending.plan);_actor_pending={}
	if is_instance_valid(actor):actor.cancel_install();actor.retire()
func resume_actor_publication() -> void:
	var began:=Time.get_ticks_usec();var attempts:=0;var callback_budget:=Template.callback_budget(pool)
	while not _actor_pending.is_empty():
		var state: Dictionary=_actor_pending;var plan: Dictionary=state.plan;var priority:=int(plan.id)==controlled_priority
		if not publication_current(int(plan.id)):cancel_actor_publication();stats.stale_publications=int(stats.get("stale_publications",0))+1;return
		if attempts>0 and Time.get_ticks_usec()-began>=callback_budget:
			if JoinDiagnostics.enabled:JoinDiagnostics.blocked(get_instance_id(),"actor-local-time")
			return
		if pool.has_method("can_publish") and not pool.can_publish(priority):
			if JoinDiagnostics.enabled:JoinDiagnostics.blocked(get_instance_id(),"actor-install-shared-budget")
			return
		var unit_began:=Time.get_ticks_usec();var actor=state.actor;var budget_owner=pool
		var progress: Dictionary=actor.install_step(32,Template.step_budget(budget_owner));attempts+=1
		Timing.finish("creature_publication_install_step_ms",unit_began)
		Timing.count("count_creature_publication_install_steps",1)
		if Timing.enabled:Timing.count("count_creature_publication_install_units",int(progress.get("units",0)))
		# A helper's _ready() can retire this scope, cancel it, or replace it.
		# Charge that work to its original ledger without publishing stale state.
		if closed or not is_same(_actor_pending,state) or not publication_current(int(plan.id)):
			if is_same(_actor_pending,state):cancel_actor_publication()
			if budget_owner.has_method("construction_finished"):budget_owner.construction_finished(unit_began)
			elif budget_owner.has_method("publication_finished"):budget_owner.publication_finished(unit_began,priority)
			return
		if progress.status=="pending":
			var elapsed:=(Time.get_ticks_usec()-unit_began)/1000.0;stats.publication_ms+=elapsed;stats.max_publication_ms=maxf(stats.max_publication_ms,elapsed);state.cpu_ms+=elapsed;state.max_step_ms=maxf(state.max_step_ms,elapsed)
			if pool.has_method("construction_finished"):pool.construction_finished(unit_began)
			elif pool.has_method("publication_finished"):pool.publication_finished(unit_began,priority)
			continue
		if progress.status=="failed":
			if recover_failed_optional_install(plan,actor):
				actor.retire();_actor_pending={}
				if pool.has_method("publication_finished"):pool.publication_finished(unit_began,priority)
				return
			object_failed(int(plan.id),actor.failure);actor.retire();release_reference_plan(plan)
		else:
			var finish_began:=Timing.begin()
			if not _finish_actor(plan,actor):progress.status="failed"
			Timing.finish("creature_publication_ready_finish_ms",finish_began)
			Timing.count("count_creature_publication_ready_finishes",1)
		var elapsed:=(Time.get_ticks_usec()-unit_began)/1000.0;stats.publication_ms+=elapsed;stats.max_publication_ms=maxf(stats.max_publication_ms,elapsed);state.cpu_ms+=elapsed;state.max_step_ms=maxf(state.max_step_ms,elapsed)
		stats.publications.append({"id":plan.id,"ms":state.cpu_ms,"latency_ms":(Time.get_ticks_usec()-int(state.began))/1000.0,"max_step_ms":state.max_step_ms,"meshes":actor.meshes.size(),"success":progress.status=="ready","staged":true})
		_actor_pending={}
		if pool.has_method("publication_finished"):pool.publication_finished(unit_began,priority)
func _publish_actor_references(hub,actor) -> Dictionary:
	var began:=Timing.begin()
	var result: Dictionary=hub.publish_prefetched_tree(actor)
	Timing.finish("creature_publication_references_ms",began)
	Timing.count("count_creature_publication_reference_publishes",1)
	return result

func _finish_actor(plan: Dictionary,actor) -> bool:
	var hub=admission_parent.get_meta("native_reference_hub") if is_instance_valid(admission_parent) and admission_parent.has_meta("native_reference_hub") else null
	if is_instance_valid(hub):
		var constructed:=_publish_actor_references(hub,actor)
		if constructed.status=="failed":
			actor.failure=str(constructed.reason)
			actor.failed_equipment_item_id=int(constructed.get("equipmentItemId",-1))
			actor.failed_piece_source_index=int(constructed.get("sourcePieceIndex",-1))
			if recover_failed_optional_install(plan,actor):actor.retire();return false
			object_failed(int(plan.id),actor.failure);actor.retire();release_reference_plan(plan);return false
	if not prepare_actor_graphics(plan,actor):
		object_failed(int(plan.id),actor.failure);actor.retire();release_reference_plan(plan);return false
	var began:=Timing.begin()
	release_reference_plan(plan)
	if plan.has("combat_actor"):actor.set_meta("native_combat_actor",plan.combat_actor)
	actor.position=plan.position;actor.rotation.y=plan.rotation;actor.set_meta("world_object_id",plan.id);actors[plan.id]=actor
	for diagnostic in actor.unattached_equipment:
		var warning: Dictionary=diagnostic.duplicate(true);warning.id=plan.id;stats.warnings.append(warning)
	actor.set_meta("native_movement",plan.get("movement",{}))
	stats["rendered_creatures" if int(plan.kind)==5 else "rendered_items"]+=1;stats.skin_meshes+=int(actor.rigs.stats.skin_meshes);stats.meshes+=actor.meshes.size()
	stats.skin_prepared_meshes+=int(actor.rigs.stats.skin_prepared_meshes);stats.skin_main_meshes+=int(actor.rigs.stats.skin_main_meshes)
	if JoinDiagnostics.enabled:JoinDiagnostics.stage(get_instance_id(),int(plan.id),"built",actor)
	Timing.finish("creature_publication_finalize_ms",began)
	Timing.count("count_creature_publication_finalized",1)
	return true
func prepare_actor_graphics(plan: Dictionary,actor) -> bool:
	var graphics=admission_parent.get_meta("native_area_graphics_owner") if is_instance_valid(admission_parent) and admission_parent.has_meta("native_area_graphics_owner") else null
	if graphics==null:return true
	var began:=Timing.begin()
	var ready:=_prepare_actor_graphics(plan,actor,graphics)
	Timing.finish("creature_publication_graphics_ms",began)
	Timing.count("count_creature_publication_graphics_calls",1)
	return ready

func _actor_graphics_entries(plan: Dictionary,actor,part_count: int) -> Array:
	var unique_source_keys: Dictionary={}
	for piece in plan.pieces:
		if not bundles.has(piece.key):continue
		var bundle: Dictionary=bundles[piece.key]
		var name:=str(bundle.get("resource_name",bundle.value.name))
		# The old key is shared only when exactly one piece matched this name.
		unique_source_keys[name]=null if unique_source_keys.has(name) else str(piece.key)
	var entries: Array=[]
	for model_index in actor.model_resource_names.size():
		var key: Variant
		if model_index>0 and model_index<=part_count:key=str(plan.partBatchKeys[model_index-1])
		else:
			key=unique_source_keys.get(str(actor.model_resource_names[model_index]))
			if key==null:key=str(actor.get_instance_id())+":"+str(model_index)
		entries.append({"root":actor,"key":"creature:"+str(key),"model_index":model_index})
	return entries

func _prepare_actor_graphics(plan: Dictionary,actor,graphics) -> bool:
	# The main model is prepared first, required body parts as one batch, and
	# equipment individually. Cache identities keep original source ownership.
	var part_count: int=int(plan.get("partBatchKeys",[]).size()) if int(plan.kind)==5 else 0
	if part_count>=actor.model_resource_names.size() and part_count>0:
		actor.failure="Required creature part was not installed before graphics preparation"
		return false
	var began:=Timing.begin()
	var entries:=_actor_graphics_entries(plan,actor,part_count)
	Timing.finish("creature_publication_graphics_keys_ms",began)
	if Timing.enabled:Timing.count("count_creature_publication_graphics_model_entries",entries.size())
	var area_owner:=admission_parent
	var graphics_current: Callable=func() -> bool:
		return not closed and is_instance_valid(actor) and is_instance_valid(area_owner) and admission_parent==area_owner and not area_owner.closed and not area_owner.retiring and area_owner.get_meta("native_area_graphics_owner",null)==graphics and publication_current(int(plan.id))
	for entry_index in entries.size():
		if entry_index>0 and entry_index<=part_count:continue
		if not graphics_current.call():actor.failure="Model preparation was retired before admission";return false
		var entry: Dictionary=entries[entry_index]
		var result: Dictionary=graphics.prepare_model(actor,str(entry.key),int(entry.model_index))
		if not bool(result.get("ready",false)):
			actor.failure=str(result.get("error","Model preparation was retired before admission"))
			return false
		if entry_index==0 and part_count>0:
			var part_entries: Array=entries.slice(1,mini(entries.size(),part_count+1))
			result=graphics.prepare_model_batch(part_entries,graphics_current)
			if result.has("error"):
				# NetworkScene.prepareModels isolates a failed group with its
				# existing per-part path before reporting the first ordered failure.
				for part_entry in part_entries:
					if not graphics_current.call():actor.failure="Model preparation was retired before admission";return false
					result=graphics.prepare_model(actor,str(part_entry.key),int(part_entry.model_index))
					if not bool(result.get("ready",false)):break
			if not bool(result.get("ready",false)):
				actor.failure=str(result.get("error","Model preparation was retired before admission"))
				return false
	var has_references:=false
	for candidate in actor.find_children("*","GeometryInstance3D",true,false):
		if not candidate.has_meta("native_source_model_index"):
			has_references=true
			break
	if has_references:
		var reference_key:="creature:reference:"+str(actor.get_instance_id())
		var reference_result: Dictionary=graphics.prepare_model(actor,reference_key,-2)
		if reference_result.has("error"):
			actor.failure=str(reference_result.error)
			return false
	return true
func begin_planning() -> void:
	_planning_active=true;_planning_cursor=0
func planning_step() -> bool:
	if not _planning_active:return true
	var began:=Time.get_ticks_usec();var units:=0
	while _planning_cursor<objects.size() and units<32:
		if units>0 and Time.get_ticks_usec()-began>=1500:break
		if pool!=null and pool.has_method("can_publish") and not pool.can_publish(_planning_cursor==0 and int(objects[_planning_cursor].id)==controlled_priority):break
		var unit_began:=Time.get_ticks_usec();_plan_object(objects[_planning_cursor]);_planning_cursor+=1;units+=1
		if pool!=null and pool.has_method("construction_finished"):pool.construction_finished(unit_began)
	if _planning_cursor<objects.size():return false
	_planning_active=false;_planning_cursor=0;objects.clear();priority_dirty=true;stats.plans_built_ms=Time.get_ticks_usec()/1000.0;return true
var priority_origin:=Vector3.ZERO
var has_priority_origin:=false
var priority_dirty:=false
var controlled_priority:=-1
func set_priority_origin(value: Vector3) -> void:
	if not value.is_finite() or has_priority_origin and priority_origin.distance_squared_to(value)<4.0: return
	priority_origin=value; has_priority_origin=true; priority_dirty=true
func refresh_priority() -> void:
	if not priority_dirty or not has_priority_origin: return
	priority_dirty=false
	Priority.sort_rows(plans,priority_origin)
	for index in plans.size():
		if int(plans[index].id)==controlled_priority: plans.push_front(plans.pop_at(index)); break
	var names: Array=[]
	for plan in plans:
		for piece in plan.pieces:
			if not names.has(piece.key): names.append(piece.key)
	var ranks: Dictionary={}
	for index in names.size(): ranks[names[index]]=index
	waiting.sort_custom(func(a,b):return int(ranks.get(a,2147483647))<int(ranks.get(b,2147483647)))
	assets.prioritize(Priority.request_order(model_jobs,names))
var assets
var catalog
var pool
var objects: Array=[]
var tables: Dictionary={}
var table_jobs: Dictionary={}
var model_jobs: Dictionary={}
var model_specs: Dictionary={}
var bundles: Dictionary={}
var scheduled_models: Dictionary={}
var actors: Dictionary={}
var waiting: Array=[]
var plans: Array=[]
func schedule_model(key: String)->void:
	if scheduled_models.has(key) or bundles.has(key):return
	scheduled_models[key]=true
	waiting.append(key)
	priority_dirty=true
func later_creature_groups(object: Dictionary,pieces: Array,part_count: int)->Array:
	var groups: Array=[];var seen_items: Dictionary={}
	for equipment_row in object.get("appearance",{}).get("equipment",[]):
		if int(equipment_row.get("slot",0)) not in [16,32]:continue
		var item_id:=int(equipment_row.get("id",-1))
		if seen_items.has(item_id):continue
		seen_items[item_id]=true
		var keys: Array=[]
		for piece in pieces:
			if int(piece.get("equipmentSlot",0)) in [16,32] and int(piece.get("equipmentItemId",-1))==item_id:keys.append(str(piece.key))
		if not keys.is_empty():groups.append(keys)
	var helmet_keys: Array=[]
	for piece in pieces:
		if piece.has("equipmentItemId") and int(piece.get("equipmentSlot",0)) not in [16,32]:helmet_keys.append(str(piece.key))
	if not helmet_keys.is_empty():groups.append(helmet_keys)
	# The old NetworkScene requests tail then wings after the helmet. Its
	# cloak row only affects their hide flags; the retained native cloak model
	# is a separate current-client attachment and follows those two requests.
	for scope in [253,252]:
		for index in range(1+part_count,pieces.size()):
			if not pieces[index].has("equipmentItemId") and int(pieces[index].get("nativeVisualScope",-1))==scope:groups.append([str(pieces[index].key)])
	for index in range(1+part_count,pieces.size()):
		if not pieces[index].has("equipmentItemId") and int(pieces[index].get("nativeVisualScope",-1)) not in [253,252]:groups.append([str(pieces[index].key)])
	return groups
func admit_creature_stages()->void:
	for plan in plans:
		if int(plan.kind)!=5:continue
		var main_key:=str(plan.get("mainKey",""))
		if not bundles.has(main_key) or not str(bundles[main_key].get("error","")).is_empty():continue
		var part_keys: Array=plan.get("partBatchKeys",[])
		if not bool(plan.get("partBatchQueued",false)):
			for key in part_keys:schedule_model(str(key))
			plan.partBatchQueued=true
		var settled:=true
		for key in part_keys:
			if not bundles.has(str(key)) or not str(bundles[str(key)].get("error","")).is_empty():settled=false;break
		if not settled or bool(plan.get("laterQueued",false)):continue
		# The old scene awaits each held item, then helmet, then each optional
		# attachment. A failed optional group still advances to the next group.
		var groups: Array=plan.get("laterGroups",[])
		var group_index:=int(plan.get("laterGroupIndex",0))
		while group_index<groups.size():
			var group: Array=groups[group_index]
			for key in group:schedule_model(str(key))
			var group_settled:=true
			for key in group:
				if not bundles.has(str(key)):group_settled=false;break
			if not group_settled:break
			group_index+=1
		plan.laterGroupIndex=group_index
		plan.laterQueued=group_index==groups.size()
var done:=false
var use_skeleton:=false
var creation_preview:=false
var admission_parent: Node3D
var closed:=false
var stats:={"planned_creatures":0,"rendered_creatures":0,"planned_items":0,"rendered_items":0,"model_jobs":0,"skin_meshes":0,"skin_prepared_meshes":0,"skin_main_meshes":0,"meshes":0,"publication_ms":0.0,"max_publication_ms":0.0,"publications":[],"errors":[],"scope_errors":[],"object_failures":{},"warnings":[],"memory_hits":0,"worker_ms":0.0,"jobs":[]}
func object_failed(id: int,reason: String,model: String="",causes: Array=[]) -> void:
	var diagnostic:={"id":id,"reason":reason}
	if not model.is_empty(): diagnostic.model=model
	if not causes.is_empty(): diagnostic.causes=causes
	stats.errors.append(diagnostic); stats.object_failures[id]=diagnostic
func optional_piece_failed(id: int,piece: Dictionary,reason: String)->void:
	var code:="network.scene-creature-attachment-failed"
	if piece.has("equipmentItemId"):
		code="network.scene-equipment-model-failed" if int(piece.get("equipmentSlot",0)) in [16,32] else "network.scene-helmet-model-failed"
	stats.warnings.append({"id":id,"itemId":piece.get("equipmentItemId",null),"code":code,"model":str(piece.get("model","")),"reason":reason})
func discard_optional_pieces(plan: Dictionary,failed_rows: Array)->void:
	var retained: Array=[]
	for piece in plan.pieces:
		var failed_reason: String=""
		for failed in failed_rows:
			if is_same(failed.piece,piece):failed_reason=str(failed.reason);break
		if failed_reason.is_empty():retained.append(piece)
		else:optional_piece_failed(int(plan.id),piece,failed_reason);release_reference_token(reference_token(plan,piece))
	plan.pieces=retained
func configure(source,shared_pool,snapshot: Array,area_id: int,cache_path: String,priority_id: int=-1,for_creation_preview: bool=false) -> void:
	catalog=source; pool=shared_pool; controlled_priority=priority_id;creation_preview=for_creation_preview
	stats.configured_ms=Time.get_ticks_usec()/1000.0; stats.table_jobs=[]
	for object in snapshot:
		if int(object.get("areaId",-1))==area_id and not object.get("replicationRemoved",false) and int(object.get("objectType",0)) in [5,6]:
			if int(object.id)==priority_id: objects.push_front(object)
			else: objects.append(object)
	if JoinDiagnostics.enabled:JoinDiagnostics.wave(pool,get_instance_id(),"actor",objects)
	assets=Assets.new(); add_child(assets);assets.configure(catalog);assets.completion_pool=pool; assets.cache_directory=cache_path; assets.completed.connect(prepared)
	source_prefetch=admission_parent.get("source_prefetch") if is_instance_valid(admission_parent) else null
	if is_instance_valid(source_prefetch):source_prefetch.finished.connect(_prefetch_ready)
	assets.high_priority=objects.any(func(object):return int(object.id)==controlled_priority)
	for name in ["appearance","racialtypes","gender","phenotype","capart","parts_robe","tailmodel","wingmodel","cloakmodel","baseitems","parts_chest"]: table_jobs[assets.request(name,2017,"2da",{"immutable_source":true})]=name
static func pose(object: Dictionary) -> Dictionary:
	var state: Dictionary=object.get("replicated",{}); var position: Variant=state.get("position")
	if not position is Array or position.size()<3: return {}
	var orientation: Variant=state.get("orientation"); var vector: Variant=orientation.get("vector") if orientation is Dictionary else orientation; var rotation:=0.0
	if vector is Array and vector.size()>=2: rotation=-atan2(float(vector[0]),float(vector[1]))
	elif orientation is Dictionary: rotation=deg_to_rad(float(orientation.get("yaw",0)))
	return {"position":Vector3(position[0],position[2],-position[1]),"rotation":rotation}
func row(name: String,index: int) -> Dictionary:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
func item_descriptors(item: Dictionary,anchor: String="",scale_value: float=1.0,equipment_slot: int=0,owner_id: int=-1,required: bool=true,item_id: int=-1) -> Array:
	var parser:=Items.new(); var plan:=parser.plan(item,tables)
	if plan.is_empty():
		if required:object_failed(owner_id,parser.failure)
		else:stats.warnings.append({"id":owner_id,"itemId":item_id,"slot":equipment_slot,"code":"network.scene-equipment-model-failed","reason":parser.failure})
		return []
	var selected:=parser.select(plan,catalog)
	if not parser.failure.is_empty():
		if required:object_failed(owner_id,parser.failure)
		else:stats.warnings.append({"id":owner_id,"itemId":item_id,"slot":equipment_slot,"code":"network.scene-equipment-model-failed","reason":parser.failure})
		return []
	var output: Array=[]
	for selection in selected:
		var piece:={"model":selection.name,"anchor":anchor,"scale":scale_value,"follow":false,"initial_clip":"default" if plan.defaultAnimation else "","nativeVisualScope":selection.selector}
		piece.equipmentSlot=equipment_slot
		if item_id>=0:piece.equipmentItemId=item_id
		if equipment_slot in [16,32]:
			piece.heldRight=1 if equipment_slot==16 and anchor=="rhand" else 0
			piece.nativeLightPriority=2 if owner_id==controlled_priority else 4
			var original:=row("baseitems",int(item.baseItem))
			piece.equipmentVisual={"baseItem":int(item.baseItem),"modelType":int(original.get("ModelType","0"))&255,"itemClass":str(original.get("ItemClass","")).left(10),"itemFlag2a8":int(item.get("field2a8",0))&255}
		if not anchor.is_empty(): piece.attachment="pq"
		if plan.palette!=null: piece.paletteColors=plan.palette
		output.append(piece)
	return output
func equipment(object: Dictionary,planner) -> Array:
	var scale_entry: Dictionary=MovementRate.native_float_entry(tables.get("appearance"),int(object.appearance.appearance),"WEAPONSCALE")
	var scale_value: float=float(scale_entry.get("value",1.0)) if bool(scale_entry.get("found",false)) else 1.0
	var output: Array=[]; var right: Dictionary=planner.equipped(object,16); var left: Dictionary=planner.equipped(object,32)
	var special_right_id:=-1
	if not right.is_empty():
		var special: bool=int(right.item.baseItem) in [8,11]
		var right_pieces:=item_descriptors(right.item,"lhand" if special else "rhand",scale_value,16,int(object.id),false,int(right.id))
		output.append_array(right_pieces)
		if special and not right_pieces.is_empty():special_right_id=int(right.id)
	if not left.is_empty():
		var left_pieces:=item_descriptors(left.item,"lforearm" if int(left.item.baseItem) in [14,56,57] else "lhand",scale_value,32,int(object.id),false,int(left.id))
		if special_right_id<0 and not right.is_empty() and int(right.id)==int(left.id) and not left_pieces.is_empty():
			# The old caller reuses one candidate by item ID. Its second attach
			# moves that root to the left anchor instead of drawing it twice.
			output=output.filter(func(piece):return int(piece.get("equipmentSlot",0))!=16 or int(piece.get("equipmentItemId",-1))!=int(left.id))
		# The old scene prepares both candidate models, then SwitchWeaponEvent
		# skips left only when the special right model loaded successfully.
		if special_right_id>=0:
			for piece in left_pieces:piece.suppressedByRightItemId=special_right_id
		output.append_array(left_pieces)
	var helmet: Dictionary=planner.equipped(object,1)
	if not helmet.is_empty():
		var field:="HELMET_SCALE_F" if int(object.appearance.get("gender",0))==1 else "HELMET_SCALE_M"
		var helmet_entry: Dictionary=MovementRate.native_float_entry(tables.get("appearance"),int(object.appearance.appearance),field)
		var helmet_scale: float=float(helmet_entry.get("value",1.0)) if bool(helmet_entry.get("found",false)) else 1.0
		output.append_array(item_descriptors(helmet.item,"head_g",helmet_scale,0,int(object.id),false,int(helmet.id)))
	return output
func build_plans() -> void:
	for object in objects:_plan_object(object)
	objects.clear();priority_dirty=true
func _plan_object(object: Dictionary) -> void:
	var placement:=pose(object)
	if placement.is_empty(): return # Equipped/non-world item registry rows.
	var pieces: Array=[]; var maps: Dictionary={}; var kind:=int(object.objectType);var required_part_count:=0
	if kind==5:
		stats.planned_creatures+=1
		var planner:=Appearance.new(); var plan:=planner.plan(object,tables,creation_preview)
		if plan.is_empty(): object_failed(int(object.id),planner.failure); return
		for warning in planner.warnings: stats.warnings.append({"id":object.id,"reason":warning})
		pieces.append({"model":plan.model,"fallbackModel":plan.get("fallbackModel",""),"anchor":"","follow":true})
		required_part_count=plan.parts.size()
		for part in plan.parts:
			var piece: Dictionary=part.duplicate(); piece.anchor=part.get("node","") if part.get("node")!=null else ""; piece.follow=int(part.get("partIndex",-1))==18
			pieces.append(piece)
		for part in plan.attachments:
			var scope:=int(part.get("nativeVisualScope",-1))
			# The worn cloak contains a skinned copy of the body pose nodes. Its
			# inherited clip advances with the creature even though it is root-mounted.
			var piece: Dictionary=part.duplicate(); piece.anchor=part.node; piece.follow=scope in [243,252,253]
			if scope==243 and not catalog.has_resource(str(piece.model),2002) and not catalog.has_resource(str(piece.get("fallbackModel","")),2002):
				stats.warnings.append({"id":object.id,"reason":"Original worn-cloak model is unavailable: "+str(piece.model)})
				continue
			pieces.append(piece)
		pieces.append_array(equipment(object,planner))
		if stats.object_failures.has(int(object.id)): return
		var lookup:=Lookup.new(); var context:=lookup.context(object,tables)
		if context.is_empty(): object_failed(int(object.id),lookup.failure); return
		maps=lookup.maps(context)
		placement.animation_context=context
		placement.combat_actor=preload("res://systems/native_data/combat_actor.gd").project(object,tables)
		var original: Dictionary=row("appearance",int(object.appearance.appearance))
		placement.movement={"modelType":int(context.fieldDE),"walkDistance":Vector3(planner.number(original.get("WALKDIST","0"),0),0,0).x,"runDistance":Vector3(planner.number(original.get("RUNDIST","0"),0),0,0).x}
	else:
		stats.planned_items+=1; pieces=item_descriptors(object.get("item",object.get("replicated",{}).get("item",{})),"",1.0,0,int(object.id))
	if pieces.is_empty(): return
	var valid:=true;var accepted_pieces: Array=[]
	for index in pieces.size():
		var piece: Dictionary=pieces[index]
		var name:=str(piece.model)
		var fallback:=str(piece.get("fallbackModel",""))
		if not catalog.has_resource(name,2002):name=fallback;fallback=""
		if name.is_empty() or not catalog.has_resource(name,2002):
			if kind==5 and index>=1+required_part_count:
				optional_piece_failed(int(object.id),piece,"Original actor model and fallback are absent")
				continue
			object_failed(int(object.id),"Original actor model and fallback are absent",str(piece.model));valid=false;break
		var options:={"plt_candidates":piece.get("pltCandidates",[]),"relevant_tracks":true}
		if piece.has("paletteColors"): options.palette_colors=piece.paletteColors
		if fallback==name:fallback=""
		var key:=JSON.stringify([name,options,fallback]); piece.key=key
		piece.source_model=name; piece.source_options=options;piece.source_fallback=fallback
		accepted_pieces.append(piece)
	if valid:
		pieces=accepted_pieces
		var part_batch_keys: Array=[]
		if kind==5:
			for index in range(1,1+required_part_count):part_batch_keys.append(str(pieces[index].key))
		for piece in pieces:
			if not model_specs.has(piece.key):model_specs[piece.key]={"name":piece.source_model,"options":piece.source_options,"fallback":piece.source_fallback}
			piece.erase("source_model");piece.erase("source_options");piece.erase("source_fallback")
		placement.merge({"id":int(object.id),"kind":kind,"pieces":pieces,"maps":maps,"animation":int(object.get("replicated",{}).get("animation",0))})
		if kind==5:
			placement.mainKey=str(pieces[0].key);placement.partBatchKeys=part_batch_keys
			placement.laterGroups=later_creature_groups(object,pieces,required_part_count)
			schedule_model(str(pieces[0].key))
		else:
			for piece in pieces:schedule_model(str(piece.key))
		plans.append(placement)
func prepared(id: int,result: Dictionary) -> void:
	if closed: return
	if table_jobs.has(id):
		var name: String=table_jobs[id]; table_jobs.erase(id)
		stats.table_jobs.append({"name":name,"requested_ms":result.get("requested_ms",0),"started_ms":result.get("started_ms",0),"received_ms":Time.get_ticks_usec()/1000.0,"worker_ms":result.worker_ms,"decode_timings":result.get("timings",{}),"phases":result.get("phases",{})})
		if not str(result.error).is_empty():
			var diagnostic:={"table":name,"reason":result.error}; stats.errors.append(diagnostic); stats.scope_errors.append(diagnostic)
		else: tables[name]=result.value
		if table_jobs.is_empty():
			if stats.scope_errors.is_empty():
				if is_instance_valid(source_prefetch) and not creation_preview:source_prefetch.set_creature_tables(tables)
				if Template.cooperative(pool):begin_planning()
				else:build_plans()
			else: objects.clear()
			stats.plans_built_ms=Time.get_ticks_usec()/1000.0
		return
	if not model_jobs.has(id): return
	var key: String=model_jobs[id]; model_jobs.erase(id)
	var source_key:=str(foreground_keys.get(id,""));foreground_keys.erase(id)
	if JoinDiagnostics.enabled:JoinDiagnostics.model_job(pool,"actors",result)
	_model_ready(key,result)
	if not source_key.is_empty() and is_instance_valid(source_prefetch):source_prefetch.foreground_done(source_key,result)
func _prefetch_ready(source_key: String,result: Dictionary)->void:
	if closed or not prefetch_waiting.has(source_key):return
	var began:=Timing.begin()
	var keys: Array=prefetch_waiting[source_key];prefetch_waiting.erase(source_key)
	# Actor construction creates private scene nodes and animation state from
	# immutable prepared data. Each key owns its result envelope only.
	for key in keys:
		if model_specs.has(key):_model_ready(str(key),result.duplicate())
	Timing.finish("creature_source_prefetch_delivery_ms",began)
func _model_ready(key: String,result: Dictionary)->void:
	if bool(result.get("memory_cache_hit",false)): stats.memory_hits+=1
	stats.worker_ms+=float(result.get("worker_ms",0.0))
	stats.jobs.append({"model":model_specs[key].name,"error":result.get("error",""),"memory_hit":bool(result.get("memory_cache_hit",false)),"read_ms":result.get("read_ms",0.0),"worker_ms":result.get("worker_ms",0.0),"phases":result.get("phases",{})})
	# NetworkScene.prepareModels catches a failed primary source load and tries
	# its authored fallback, including decode failures after a successful lookup.
	var fallback:=str(model_specs[key].get("fallback",""))
	if not str(result.get("error","")).is_empty() and not fallback.is_empty():
		model_specs[key].name=fallback;model_specs[key].fallback="";waiting.append(key)
		return
	bundles[key]=result
	for dependency in result.get("dependencies",[]):
		if dependency.get("role")=="emitter" and dependency.get("missing",false): stats.warnings.append({"model":model_specs[key].name,"texture":dependency.name,"reason":"Original emitter bitmap is unavailable; geometry retained, no replacement bitmap supplied"})
	if creation_preview:
		for name in result.get("missing_textures",[]):stats.warnings.append({"model":model_specs[key].name,"texture":name,"code":"character.preview-texture-unavailable","reason":"Character preview texture "+str(name)+" is unavailable"})
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_creatures",began)
func _profile_process(_delta: float) -> void:
	if closed or done or not is_instance_valid(assets) or not table_jobs.is_empty(): return
	if not planning_step():return
	admit_creature_stages()
	refresh_priority()
	while not waiting.is_empty() and assets.pending.size()+assets.running.size()<mini(assets.maximum_pending,mini(4,assets.maximum_workers)):
		var key:=str(waiting.pop_front()); var spec: Dictionary=model_specs[key]
		var source_key: String=""
		if is_instance_valid(source_prefetch):
			source_key=SourcePrefetch.key(str(spec.name),"actor-model",spec.options)
			var claim_began:=Timing.begin()
			var shared: Dictionary=source_prefetch.claim(source_key,true)
			Timing.finish("creature_source_prefetch_claim_ms",claim_began)
			if shared.get("status")=="ready":_model_ready(key,shared.result);continue
			if shared.get("status")=="running":
				if not prefetch_waiting.has(source_key):prefetch_waiting[source_key]=[]
				prefetch_waiting[source_key].append(key);continue
			if not source_key.is_empty():source_prefetch.foreground_begin(source_key)
		var id: int=assets.request(spec.name,2002,"actor-model",spec.options)
		if id<0:
			var failed_result: Dictionary={"error":assets.failure}
			_model_ready(key,failed_result)
			if not source_key.is_empty() and is_instance_valid(source_prefetch):source_prefetch.foreground_done(source_key,failed_result)
		else:
			model_jobs[id]=key;stats.model_jobs+=1
			if not source_key.is_empty():foreground_keys[id]=source_key
	if not _actor_pending.is_empty():
		resume_actor_publication()
		if waiting.is_empty() and model_jobs.is_empty() and prefetch_waiting.is_empty() and plans.is_empty() and _actor_pending.is_empty():done=true
		return
	# Each actor owns a complete hierarchy, including robe and equipment roots.
	# Publish one ready actor per frame; never attach a half-prepared skeleton.
	for index in plans.size():
		var plan: Dictionary=plans[index]; var ready:=true; var failures: Array=[]; var failed_held: Dictionary={};var failed_optional: Array=[]
		if int(plan.kind)==5:
			var main_key:=str(plan.get("mainKey",""))
			if not bundles.has(main_key):continue
			if not str(bundles[main_key].get("error","")).is_empty():
				object_failed(int(plan.id),str(bundles[main_key].error),str(model_specs[main_key].name))
				plans.remove_at(index);break
			# The old prepareModels call settles every indexed body-part result
			# before preparedModel attaches or reports the first failed part.
			var part_batch_ready:=true
			for key in plan.get("partBatchKeys",[]):
				if not bundles.has(str(key)):part_batch_ready=false;break
			if not part_batch_ready:continue
			var failed_part:=false
			for key in plan.get("partBatchKeys",[]):
				if not str(bundles[str(key)].get("error","")).is_empty():
					object_failed(int(plan.id),str(bundles[str(key)].error),str(model_specs[str(key)].name))
					plans.remove_at(index);failed_part=true;break
			if failed_part:break
		for piece_index in plan.pieces.size():
			var piece: Dictionary=plan.pieces[piece_index]
			if not bundles.has(piece.key): ready=false; continue
			if not str(bundles[piece.key].error).is_empty():
				var failure:={"model":model_specs[piece.key].name,"reason":bundles[piece.key].error}
				if int(plan.kind)==5 and int(piece.get("equipmentSlot",0)) in [16,32]:failed_held[int(piece.get("equipmentItemId",-1))]=failure
				elif int(plan.kind)==5 and piece_index>plan.partBatchKeys.size():failed_optional.append({"piece":piece,"reason":str(failure.reason)})
				else:failures.append(failure)
		if not failures.is_empty():
			object_failed(int(plan.id),str(failures[0].reason),str(failures[0].model),failures); plans.remove_at(index); break
		if not ready: continue
		if JoinDiagnostics.enabled:JoinDiagnostics.stage(get_instance_id(),int(plan.id),"assetsReady")
		if not failed_held.is_empty():discard_failed_held(plan,failed_held)
		if not failed_optional.is_empty():discard_optional_pieces(plan,failed_optional)
		# The old scene loader awaited every referenced model and its resources
		# before constructing the owning actor.
		var reference_hub=admission_parent.get_meta("native_reference_hub") if is_instance_valid(admission_parent) and admission_parent.has_meta("native_reference_hub") else null
		var reference_pending:=false
		var reference_failure:=""
		var failed_references: Dictionary={};var failed_optional_references: Array=[]
		for piece_index in plan.pieces.size():
			var piece: Dictionary=plan.pieces[piece_index]
			var piece_bundle: Dictionary=bundles[piece.key]
			if not piece_bundle.value.nodes.any(func(row):return row.has("reference")):continue
			if not is_instance_valid(reference_hub):reference_failure="Native reference preparation scope is unavailable";break
			var token:=reference_token(plan,piece);reference_admissions[token]=str(model_specs[piece.key].name)
			var tree: Dictionary=reference_hub.prefetch_tree(str(model_specs[piece.key].name),piece_bundle,null,token)
			if tree.status=="failed":
				if int(plan.kind)==5 and int(piece.get("equipmentSlot",0)) in [16,32]:failed_references[int(piece.get("equipmentItemId",-1))]={"model":model_specs[piece.key].name,"reason":str(tree.reason)};continue
				if int(plan.kind)==5 and piece_index>plan.partBatchKeys.size():failed_optional_references.append({"piece":piece,"reason":str(tree.reason)});continue
				reference_failure=str(tree.reason);break
			if tree.status!="ready":reference_pending=true
		if not reference_failure.is_empty():object_failed(int(plan.id),reference_failure);release_reference_plan(plan);plans.remove_at(index);break
		if not failed_references.is_empty():discard_failed_held(plan,failed_references);continue
		if not failed_optional_references.is_empty():discard_optional_pieces(plan,failed_optional_references);continue
		if reference_pending:
			if JoinDiagnostics.enabled:JoinDiagnostics.blocked(get_instance_id(),"actor-reference")
			continue
		if plan.pieces.any(func(piece):return piece.has("suppressedByRightItemId")):
			var visible: Array=[];var suppressed: Array=[]
			var failed_ids: Dictionary=plan.get("failedHeld",{})
			for piece in plan.pieces:
				if piece.has("suppressedByRightItemId") and not failed_ids.has(int(piece.suppressedByRightItemId)):suppressed.append(piece);release_reference_token(reference_token(plan,piece))
				else:visible.append(piece)
			plan.pieces=visible
			plan.suppressedHeld=suppressed
		if JoinDiagnostics.enabled:JoinDiagnostics.stage(get_instance_id(),int(plan.id),"eligible")
		if pool.has_method("can_publish") and not pool.can_publish(int(plan.id)==controlled_priority):
			if JoinDiagnostics.enabled:JoinDiagnostics.blocked(get_instance_id(),"actor-eligible-shared-budget")
			break
		plans.remove_at(index)
		var began:=Time.get_ticks_usec()
		var pieces: Array=[]
		for source_index in plan.pieces.size():
			var source: Dictionary=plan.pieces[source_index]
			var piece: Dictionary=source.duplicate();piece.bundle=bundles[source.key];piece.sourcePieceIndex=source_index;pieces.append(piece)
		var actor=Actor.new();actor.actor_alpha_enabled=int(plan.kind)==5; actor.use_skeleton=use_skeleton; actor.position=plan.position; actor.rotation.y=plan.rotation
		if is_instance_valid(admission_parent): actor.hide(); admission_parent.add_child(actor)
		else: add_child(actor)
		if Template.cooperative(pool):
			if not actor.begin_install(pieces,pool,int(plan.id),plan.maps,int(plan.animation),plan.get("animation_context",{})):object_failed(int(plan.id),actor.failure);actor.retire();release_reference_plan(plan)
			else:
				var initial_ms:=(Time.get_ticks_usec()-began)/1000.0
				stats.publication_ms+=initial_ms;stats.max_publication_ms=maxf(stats.max_publication_ms,initial_ms)
				_actor_pending={"actor":actor,"plan":plan,"began":began,"cpu_ms":initial_ms,"max_step_ms":initial_ms}
				if pool.has_method("construction_finished"):pool.construction_finished(began)
				resume_actor_publication()
			break
		var install_began:=Timing.begin()
		var actor_ready: bool=actor.install(pieces,pool,int(plan.id),plan.maps,int(plan.animation),plan.get("animation_context",{}))
		Timing.finish("creature_publication_install_sync_ms",install_began)
		Timing.count("count_creature_publication_install_sync_calls",1)
		if actor_ready and is_instance_valid(reference_hub):
			var constructed:=_publish_actor_references(reference_hub,actor)
			if constructed.status=="failed":actor.failure=str(constructed.reason);actor.failed_equipment_item_id=int(constructed.get("equipmentItemId",-1));actor.failed_piece_source_index=int(constructed.get("sourcePieceIndex",-1));actor_ready=false
		if actor_ready and not prepare_actor_graphics(plan,actor):actor_ready=false
		var recovered:=false
		if not actor_ready:
			recovered=recover_failed_optional_install(plan,actor)
			if not recovered:object_failed(int(plan.id),actor.failure)
			actor.retire()
		else:
			if plan.has("combat_actor"): actor.set_meta("native_combat_actor",plan.combat_actor)
			actor.position=plan.position; actor.rotation.y=plan.rotation; actor.set_meta("world_object_id",plan.id); actors[plan.id]=actor
			for diagnostic in actor.unattached_equipment:
				var warning: Dictionary=diagnostic.duplicate(true); warning.id=plan.id; stats.warnings.append(warning)
			actor.set_meta("native_movement",plan.get("movement",{}))
			stats["rendered_creatures" if int(plan.kind)==5 else "rendered_items"]+=1; stats.skin_meshes+=int(actor.rigs.stats.skin_meshes); stats.meshes+=actor.meshes.size()
			stats.skin_prepared_meshes+=int(actor.rigs.stats.skin_prepared_meshes); stats.skin_main_meshes+=int(actor.rigs.stats.skin_main_meshes)
			if JoinDiagnostics.enabled:JoinDiagnostics.stage(get_instance_id(),int(plan.id),"built",actor)
		if not recovered:release_reference_plan(plan)
		var elapsed:=(Time.get_ticks_usec()-began)/1000.0
		if pool.has_method("publication_finished"): pool.publication_finished(began,int(plan.id)==controlled_priority)
		stats.publication_ms+=elapsed; stats.max_publication_ms=maxf(stats.max_publication_ms,elapsed); stats.publications.append({"id":plan.id,"ms":elapsed,"meshes":actor.meshes.size(),"success":actor.failure.is_empty()})
		break
	if waiting.is_empty() and model_jobs.is_empty() and prefetch_waiting.is_empty() and plans.is_empty() and _actor_pending.is_empty(): done=true
func snapshot() -> Dictionary:
	return stats.duplicate(true)
func detach_prepared_data() -> Dictionary:
	_planning_active=false;_planning_cursor=0
	cancel_actor_publication()
	for token in reference_admissions.keys():release_reference_token(str(token))
	var payload:={"bundles":bundles,"model_specs":model_specs,"plans":plans,"objects":objects,"tables":tables}
	bundles={}; model_specs={}; scheduled_models={}; plans=[]; objects=[]; tables={}
	return payload
func close() -> void:
	if closed: return
	_planning_active=false;_planning_cursor=0
	cancel_actor_publication();publication_keys.clear()
	for token in reference_admissions.keys():release_reference_token(str(token))
	closed=true
	if is_instance_valid(source_prefetch):
		for source_key in foreground_keys.values():source_prefetch.foreground_cancel(str(source_key))
	if is_instance_valid(assets): assets.close()
	for actor in actors.values():
		if is_instance_valid(actor): actor.retire()
	actors.clear(); plans.clear(); bundles.clear(); model_specs.clear(); scheduled_models.clear(); model_jobs.clear(); prefetch_waiting.clear(); foreground_keys.clear(); table_jobs.clear(); waiting.clear(); objects.clear(); tables.clear(); catalog=null
func _exit_tree() -> void: close()
