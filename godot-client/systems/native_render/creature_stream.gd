extends Node3D
const Assets=preload("res://systems/native_data/asset_service.gd")
const Appearance=preload("res://systems/native_data/creature_appearance.gd")
const Items=preload("res://systems/native_data/item_appearance.gd")
const Lookup=preload("res://systems/native_data/animation_lookup.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
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
var closed:=false
var stats:={"planned_creatures":0,"rendered_creatures":0,"planned_items":0,"rendered_items":0,"model_jobs":0,"skin_meshes":0,"meshes":0,"errors":[],"warnings":[]}
func configure(source,shared_pool,snapshot: Array,area_id: int,cache_path: String) -> void:
	catalog=source; pool=shared_pool
	for object in snapshot:
		if int(object.get("areaId",-1))==area_id and not object.get("replicationRemoved",false) and int(object.get("objectType",0)) in [5,6]: objects.append(object)
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	for name in ["appearance","racialtypes","gender","phenotype","capart","parts_robe","tailmodel","wingmodel","cloakmodel","baseitems","parts_chest"]: table_jobs[assets.request(name,2017,"2da")]=name
func pose(object: Dictionary) -> Dictionary:
	var state: Dictionary=object.get("replicated",{}); var position: Variant=state.get("position")
	if not position is Array or position.size()<3: return {}
	var orientation: Variant=state.get("orientation"); var vector: Variant=orientation.get("vector") if orientation is Dictionary else orientation; var rotation:=0.0
	if vector is Array and vector.size()>=2: rotation=-atan2(float(vector[0]),float(vector[1]))
	elif orientation is Dictionary: rotation=deg_to_rad(float(orientation.get("yaw",0)))
	return {"position":Vector3(position[0],position[2],-position[1]),"rotation":rotation}
func row(name: String,index: int) -> Dictionary:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
func item_descriptors(item: Dictionary,anchor: String="",scale_value: float=1.0) -> Array:
	var parser:=Items.new(); var plan:=parser.plan(item,tables)
	if plan.is_empty(): stats.errors.append({"item":item.get("baseItem"),"reason":parser.failure}); return []
	var selected:=parser.select(plan,catalog)
	if not parser.failure.is_empty(): stats.errors.append({"item":item.get("baseItem"),"reason":parser.failure}); return []
	var output: Array=[]
	for selection in selected:
		var piece:={"model":selection.name,"anchor":anchor,"scale":scale_value,"follow":false,"initial_clip":"default" if plan.defaultAnimation else "","nativeVisualScope":selection.selector}
		if not anchor.is_empty(): piece.attachment="pq"
		if plan.palette!=null: piece.paletteColors=plan.palette
		output.append(piece)
	return output
func equipment(object: Dictionary,appearance_row: Dictionary,planner) -> Array:
	var output: Array=[]; var right: Dictionary=planner.equipped(object,16); var left: Dictionary=planner.equipped(object,32); var scale_value: float=planner.number(appearance_row.get("WEAPONSCALE","1"))
	if not right.is_empty():
		var special: bool=int(right.item.baseItem) in [8,11]
		output.append_array(item_descriptors(right.item,"lhand" if special else "rhand",scale_value))
		if special: left={}
	if not left.is_empty(): output.append_array(item_descriptors(left.item,"lforearm" if int(left.item.baseItem) in [14,56,57] else "lhand",scale_value))
	var helmet: Dictionary=planner.equipped(object,1)
	if not helmet.is_empty():
		var field:="HELMET_SCALE_F" if int(object.appearance.get("gender",0))==1 else "HELMET_SCALE_M"
		output.append_array(item_descriptors(helmet.item,"head_g",planner.number(appearance_row.get(field,"1"))))
	return output
func build_plans() -> void:
	for object in objects:
		var placement:=pose(object)
		if placement.is_empty(): continue # Equipped/non-world item registry rows.
		var pieces: Array=[]; var maps: Dictionary={}; var kind:=int(object.objectType)
		if kind==5:
			stats.planned_creatures+=1
			var planner:=Appearance.new(); var plan:=planner.plan(object,tables)
			if plan.is_empty(): stats.errors.append({"id":object.id,"reason":planner.failure}); continue
			for warning in planner.warnings: stats.warnings.append({"id":object.id,"reason":warning})
			pieces.append({"model":plan.model,"fallbackModel":plan.get("fallbackModel",""),"anchor":"","follow":true})
			for part in plan.parts:
				var piece: Dictionary=part.duplicate(); piece.anchor=part.get("node","") if part.get("node")!=null else ""; piece.follow=int(part.get("partIndex",-1))==18
				pieces.append(piece)
			for part in plan.attachments:
				var piece: Dictionary=part.duplicate(); piece.anchor=part.node; piece.follow=true; pieces.append(piece)
			pieces.append_array(equipment(object,row("appearance",int(object.appearance.appearance)),planner))
			var lookup:=Lookup.new(); var context:=lookup.context(object,tables)
			if context.is_empty(): stats.errors.append({"id":object.id,"reason":lookup.failure}); continue
			maps=lookup.maps(context)
		else:
			stats.planned_items+=1; pieces=item_descriptors(object.get("item",object.get("replicated",{}).get("item",{})))
		if pieces.is_empty(): continue
		var valid:=true
		for piece in pieces:
			var name:=str(piece.model)
			if not catalog.has_resource(name,2002): name=str(piece.get("fallbackModel",""))
			if name.is_empty() or not catalog.has_resource(name,2002): stats.errors.append({"id":object.id,"model":piece.model,"reason":"Original actor model and fallback are absent"}); valid=false; break
			var options:={"plt_candidates":piece.get("pltCandidates",[])}
			if piece.has("paletteColors"): options.palette_colors=piece.paletteColors
			var key:=JSON.stringify([name,options]); piece.key=key
			if not model_specs.has(key): model_specs[key]={"name":name,"options":options}; waiting.append(key)
		if valid: placement.merge({"id":int(object.id),"kind":kind,"pieces":pieces,"maps":maps,"animation":int(object.get("replicated",{}).get("animation",0))}); plans.append(placement)
	objects.clear()
func prepared(id: int,result: Dictionary) -> void:
	if closed: return
	if table_jobs.has(id):
		var name: String=table_jobs[id]; table_jobs.erase(id)
		if not str(result.error).is_empty(): stats.errors.append({"table":name,"reason":result.error})
		else: tables[name]=result.value
		if table_jobs.is_empty(): build_plans()
		return
	if not model_jobs.has(id): return
	var key: String=model_jobs[id]; model_jobs.erase(id); bundles[key]=result
	if not str(result.error).is_empty(): stats.errors.append({"model":model_specs[key].name,"reason":result.error})
func _process(_delta: float) -> void:
	if closed or done or not is_instance_valid(assets) or not table_jobs.is_empty(): return
	while not waiting.is_empty() and assets.pending.size()+assets.running.size()<assets.maximum_pending:
		var key:=str(waiting.pop_front()); var spec: Dictionary=model_specs[key]; var id: int=assets.request(spec.name,2002,"actor-model",spec.options)
		if id<0: stats.errors.append({"model":spec.name,"reason":assets.failure}); bundles[key]={"error":assets.failure}
		else: model_jobs[id]=key; stats.model_jobs+=1
	# Each actor owns a complete hierarchy, including robe and equipment roots.
	# Publish one ready actor per frame; never attach a half-prepared skeleton.
	for index in plans.size():
		var plan: Dictionary=plans[index]; var ready:=true; var failed:=false
		for piece in plan.pieces:
			if not bundles.has(piece.key): ready=false; break
			if not str(bundles[piece.key].error).is_empty(): failed=true
		if not ready: continue
		plans.remove_at(index)
		if not failed:
			var pieces: Array=[]
			for source in plan.pieces:
				var piece: Dictionary=source.duplicate(); piece.bundle=bundles[source.key]; pieces.append(piece)
			var actor:=Actor.new(); add_child(actor)
			if not actor.install(pieces,pool,int(plan.id),plan.maps,int(plan.animation)): stats.errors.append({"id":plan.id,"reason":actor.failure}); actor.retire()
			else:
				actor.position=plan.position; actor.rotation.y=plan.rotation; actor.set_meta("world_object_id",plan.id); actors[plan.id]=actor
				stats["rendered_creatures" if int(plan.kind)==5 else "rendered_items"]+=1; stats.skin_meshes+=int(actor.rigs.stats.skin_meshes); stats.meshes+=actor.meshes.size()
		break
	if waiting.is_empty() and model_jobs.is_empty() and plans.is_empty(): done=true
func snapshot() -> Dictionary:
	return stats.duplicate(true)
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets): assets.close()
	for actor in actors.values():
		if is_instance_valid(actor): actor.retire()
	actors.clear(); plans.clear(); bundles.clear(); model_specs.clear(); model_jobs.clear(); table_jobs.clear(); waiting.clear(); objects.clear(); tables.clear(); catalog=null
func _exit_tree() -> void: close()
