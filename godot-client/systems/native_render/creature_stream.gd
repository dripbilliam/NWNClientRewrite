extends Node3D
const Timing=preload("res://systems/native_render/frame_profile.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Appearance=preload("res://systems/native_data/creature_appearance.gd")
const Items=preload("res://systems/native_data/item_appearance.gd")
const Lookup=preload("res://systems/native_data/animation_lookup.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Priority=preload("res://systems/native_render/stream_priority.gd")
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
var actors: Dictionary={}
var waiting: Array=[]
var plans: Array=[]
var done:=false
var use_skeleton:=false
var admission_parent: Node3D
var closed:=false
var stats:={"planned_creatures":0,"rendered_creatures":0,"planned_items":0,"rendered_items":0,"model_jobs":0,"skin_meshes":0,"skin_prepared_meshes":0,"skin_main_meshes":0,"meshes":0,"publication_ms":0.0,"max_publication_ms":0.0,"publications":[],"errors":[],"scope_errors":[],"object_failures":{},"warnings":[],"memory_hits":0,"worker_ms":0.0,"jobs":[]}
func object_failed(id: int,reason: String,model: String="",causes: Array=[]) -> void:
	var diagnostic:={"id":id,"reason":reason}
	if not model.is_empty(): diagnostic.model=model
	if not causes.is_empty(): diagnostic.causes=causes
	stats.errors.append(diagnostic); stats.object_failures[id]=diagnostic
func configure(source,shared_pool,snapshot: Array,area_id: int,cache_path: String,priority_id: int=-1) -> void:
	catalog=source; pool=shared_pool; controlled_priority=priority_id
	stats.configured_ms=Time.get_ticks_usec()/1000.0; stats.table_jobs=[]
	for object in snapshot:
		if int(object.get("areaId",-1))==area_id and not object.get("replicationRemoved",false) and int(object.get("objectType",0)) in [5,6]:
			if int(object.id)==priority_id: objects.push_front(object)
			else: objects.append(object)
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
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
func item_descriptors(item: Dictionary,anchor: String="",scale_value: float=1.0,equipment_slot: int=0,owner_id: int=-1) -> Array:
	var parser:=Items.new(); var plan:=parser.plan(item,tables)
	if plan.is_empty(): object_failed(owner_id,parser.failure); return []
	var selected:=parser.select(plan,catalog)
	if not parser.failure.is_empty(): object_failed(owner_id,parser.failure); return []
	var output: Array=[]
	for selection in selected:
		var piece:={"model":selection.name,"anchor":anchor,"scale":scale_value,"follow":false,"initial_clip":"default" if plan.defaultAnimation else "","nativeVisualScope":selection.selector}
		piece.equipmentSlot=equipment_slot
		if equipment_slot in [16,32]:
			var original:=row("baseitems",int(item.baseItem))
			piece.equipmentVisual={"baseItem":int(item.baseItem),"modelType":int(original.get("ModelType","0"))&255,"itemClass":str(original.get("ItemClass","")).left(10),"itemFlag2a8":int(item.get("field2a8",0))&255}
		if not anchor.is_empty(): piece.attachment="pq"
		if plan.palette!=null: piece.paletteColors=plan.palette
		output.append(piece)
	return output
func equipment(object: Dictionary,appearance_row: Dictionary,planner) -> Array:
	var output: Array=[]; var right: Dictionary=planner.equipped(object,16); var left: Dictionary=planner.equipped(object,32); var scale_value: float=planner.number(appearance_row.get("WEAPONSCALE","1"))
	if not right.is_empty():
		var special: bool=int(right.item.baseItem) in [8,11]
		output.append_array(item_descriptors(right.item,"lhand" if special else "rhand",scale_value,16,int(object.id)))
		if special: left={}
	if not left.is_empty(): output.append_array(item_descriptors(left.item,"lforearm" if int(left.item.baseItem) in [14,56,57] else "lhand",scale_value,32,int(object.id)))
	var helmet: Dictionary=planner.equipped(object,1)
	if not helmet.is_empty():
		var field:="HELMET_SCALE_F" if int(object.appearance.get("gender",0))==1 else "HELMET_SCALE_M"
		output.append_array(item_descriptors(helmet.item,"head_g",planner.number(appearance_row.get(field,"1")),0,int(object.id)))
	return output
func build_plans() -> void:
	for object in objects:
		var placement:=pose(object)
		if placement.is_empty(): continue # Equipped/non-world item registry rows.
		var pieces: Array=[]; var maps: Dictionary={}; var kind:=int(object.objectType)
		if kind==5:
			stats.planned_creatures+=1
			var planner:=Appearance.new(); var plan:=planner.plan(object,tables)
			if plan.is_empty(): object_failed(int(object.id),planner.failure); continue
			for warning in planner.warnings: stats.warnings.append({"id":object.id,"reason":warning})
			pieces.append({"model":plan.model,"fallbackModel":plan.get("fallbackModel",""),"anchor":"","follow":true})
			for part in plan.parts:
				var piece: Dictionary=part.duplicate(); piece.anchor=part.get("node","") if part.get("node")!=null else ""; piece.follow=int(part.get("partIndex",-1))==18
				pieces.append(piece)
			for part in plan.attachments:
				var piece: Dictionary=part.duplicate(); piece.anchor=part.node; piece.follow=true; pieces.append(piece)
			pieces.append_array(equipment(object,row("appearance",int(object.appearance.appearance)),planner))
			if stats.object_failures.has(int(object.id)): continue
			var lookup:=Lookup.new(); var context:=lookup.context(object,tables)
			if context.is_empty(): object_failed(int(object.id),lookup.failure); continue
			maps=lookup.maps(context)
			placement.animation_context=context
			placement.combat_actor=preload("res://systems/native_data/combat_actor.gd").project(object,tables)
			var original: Dictionary=row("appearance",int(object.appearance.appearance))
			placement.movement={"modelType":int(context.fieldDE),"walkDistance":Vector3(planner.number(original.get("WALKDIST","0"),0),0,0).x,"runDistance":Vector3(planner.number(original.get("RUNDIST","0"),0),0,0).x}
		else:
			stats.planned_items+=1; pieces=item_descriptors(object.get("item",object.get("replicated",{}).get("item",{})),"",1.0,0,int(object.id))
		if pieces.is_empty(): continue
		var valid:=true
		for piece in pieces:
			var name:=str(piece.model)
			if not catalog.has_resource(name,2002): name=str(piece.get("fallbackModel",""))
			if name.is_empty() or not catalog.has_resource(name,2002): object_failed(int(object.id),"Original actor model and fallback are absent",str(piece.model)); valid=false; break
			var options:={"plt_candidates":piece.get("pltCandidates",[]),"relevant_tracks":true}
			if piece.has("paletteColors"): options.palette_colors=piece.paletteColors
			var key:=JSON.stringify([name,options]); piece.key=key
			piece.source_model=name; piece.source_options=options
		if valid:
			for piece in pieces:
				if not model_specs.has(piece.key): model_specs[piece.key]={"name":piece.source_model,"options":piece.source_options}; waiting.append(piece.key)
				piece.erase("source_model"); piece.erase("source_options")
			placement.merge({"id":int(object.id),"kind":kind,"pieces":pieces,"maps":maps,"animation":int(object.get("replicated",{}).get("animation",0))}); plans.append(placement)
	objects.clear()
	priority_dirty=true
func prepared(id: int,result: Dictionary) -> void:
	if closed: return
	if table_jobs.has(id):
		var name: String=table_jobs[id]; table_jobs.erase(id)
		stats.table_jobs.append({"name":name,"requested_ms":result.get("requested_ms",0),"started_ms":result.get("started_ms",0),"received_ms":Time.get_ticks_usec()/1000.0,"worker_ms":result.worker_ms,"decode_timings":result.get("timings",{}),"phases":result.get("phases",{})})
		if not str(result.error).is_empty():
			var diagnostic:={"table":name,"reason":result.error}; stats.errors.append(diagnostic); stats.scope_errors.append(diagnostic)
		else: tables[name]=result.value
		if table_jobs.is_empty():
			if stats.scope_errors.is_empty(): build_plans()
			else: objects.clear()
			stats.plans_built_ms=Time.get_ticks_usec()/1000.0
		return
	if not model_jobs.has(id): return
	var key: String=model_jobs[id]; model_jobs.erase(id); bundles[key]=result
	if bool(result.get("memory_cache_hit",false)): stats.memory_hits+=1
	stats.worker_ms+=float(result.worker_ms)
	stats.jobs.append({"model":model_specs[key].name,"error":result.error,"memory_hit":bool(result.get("memory_cache_hit",false)),"read_ms":result.read_ms,"worker_ms":result.worker_ms,"phases":result.get("phases",{})})
	for dependency in result.get("dependencies",[]):
		if dependency.get("role")=="emitter" and dependency.get("missing",false): stats.warnings.append({"model":model_specs[key].name,"texture":dependency.name,"reason":"Original emitter bitmap is unavailable; geometry retained, no replacement bitmap supplied"})
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_creatures",began)
func _profile_process(_delta: float) -> void:
	if closed or done or not is_instance_valid(assets) or not table_jobs.is_empty(): return
	refresh_priority()
	while not waiting.is_empty() and assets.pending.size()+assets.running.size()<mini(assets.maximum_pending,assets.maximum_workers*2):
		var key:=str(waiting.pop_front()); var spec: Dictionary=model_specs[key]; var id: int=assets.request(spec.name,2002,"actor-model",spec.options)
		if id<0: bundles[key]={"error":assets.failure}
		else: model_jobs[id]=key; stats.model_jobs+=1
	# Each actor owns a complete hierarchy, including robe and equipment roots.
	# Publish one ready actor per frame; never attach a half-prepared skeleton.
	for index in plans.size():
		var plan: Dictionary=plans[index]; var ready:=true; var failures: Array=[]
		for piece in plan.pieces:
			if not bundles.has(piece.key): ready=false; continue
			if not str(bundles[piece.key].error).is_empty(): failures.append({"model":model_specs[piece.key].name,"reason":bundles[piece.key].error})
		if not failures.is_empty():
			object_failed(int(plan.id),str(failures[0].reason),str(failures[0].model),failures); plans.remove_at(index); break
		if not ready: continue
		if pool.has_method("can_publish") and not pool.can_publish(int(plan.id)==controlled_priority): break
		plans.remove_at(index)
		var began:=Time.get_ticks_usec()
		var pieces: Array=[]
		for source in plan.pieces:
			var piece: Dictionary=source.duplicate(); piece.bundle=bundles[source.key]; pieces.append(piece)
		var actor:=Actor.new();actor.actor_alpha_enabled=int(plan.kind)==5; actor.use_skeleton=use_skeleton; actor.position=plan.position; actor.rotation.y=plan.rotation
		if is_instance_valid(admission_parent): actor.hide(); admission_parent.add_child(actor)
		else: add_child(actor)
		if not actor.install(pieces,pool,int(plan.id),plan.maps,int(plan.animation),plan.get("animation_context",{})): object_failed(int(plan.id),actor.failure); actor.retire()
		else:
			if plan.has("combat_actor"): actor.set_meta("native_combat_actor",plan.combat_actor)
			actor.position=plan.position; actor.rotation.y=plan.rotation; actor.set_meta("world_object_id",plan.id); actors[plan.id]=actor
			for diagnostic in actor.unattached_equipment:
				var warning: Dictionary=diagnostic.duplicate(true); warning.id=plan.id; stats.warnings.append(warning)
			actor.set_meta("native_movement",plan.get("movement",{}))
			stats["rendered_creatures" if int(plan.kind)==5 else "rendered_items"]+=1; stats.skin_meshes+=int(actor.rigs.stats.skin_meshes); stats.meshes+=actor.meshes.size()
			stats.skin_prepared_meshes+=int(actor.rigs.stats.skin_prepared_meshes); stats.skin_main_meshes+=int(actor.rigs.stats.skin_main_meshes)
		var elapsed:=(Time.get_ticks_usec()-began)/1000.0
		if pool.has_method("publication_finished"): pool.publication_finished(began,int(plan.id)==controlled_priority)
		stats.publication_ms+=elapsed; stats.max_publication_ms=maxf(stats.max_publication_ms,elapsed); stats.publications.append({"id":plan.id,"ms":elapsed,"meshes":actor.meshes.size(),"success":actor.failure.is_empty()})
		break
	if waiting.is_empty() and model_jobs.is_empty() and plans.is_empty(): done=true
func snapshot() -> Dictionary:
	return stats.duplicate(true)
func detach_prepared_data() -> Dictionary:
	var payload:={"bundles":bundles,"model_specs":model_specs,"plans":plans,"objects":objects,"tables":tables}
	bundles={}; model_specs={}; plans=[]; objects=[]; tables={}
	return payload
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets): assets.close()
	for actor in actors.values():
		if is_instance_valid(actor): actor.retire()
	actors.clear(); plans.clear(); bundles.clear(); model_specs.clear(); model_jobs.clear(); table_jobs.clear(); waiting.clear(); objects.clear(); tables.clear(); catalog=null
func _exit_tree() -> void: close()
