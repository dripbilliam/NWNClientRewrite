extends RefCounted
# Prepare a native PackedScene once; repeat instances clone in engine code.
# Private physical nodes and shared immutable resources are both preserved.
const Instance=preload("res://systems/native_render/model_instance.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const ReferenceGraph=preload("res://systems/native_render/reference_graph.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const StaticDrawInvalidation=preload("res://systems/native_render/static_draw_invalidation.gd")
const Recipe=preload("res://systems/native_render/native_model_recipe.gd")
static var _construction_counts: Dictionary={"templates_built":0,"recipe_capture_attempts":0,"recipe_templates_built":0,"recipe_capture_fallbacks":0,"recipe_clones":0,"packed_templates_built":0,"packed_clones":0,"first_root_reuses":0}
static var _recipe_fallback_reasons: Dictionary={}
static func configured_recipe() -> bool:return OS.get_cmdline_user_args().has("--model-template=recipe")
static func construction_totals() -> Dictionary:
	var value:=_construction_counts.duplicate();value.recipe_fallback_reasons=_recipe_fallback_reasons.duplicate();value.scope="Process-cumulative actual native template build/create boundaries; no live owner references";return value
var scene: PackedScene
var recipe
var recipe_capture_attempts:=0
var recipe_capture_successes:=0
var recipe_instance_creations:=0
var recipe_fallback_reason:=""
var packed_template_creations:=0
# Detached never-admitted construction tree serves only the first placement.
var _first_root: Node3D
var first_instance_reuses:=0
var packed_instance_creations:=0
var limitations: Array=[]
var failure:=""
var reference_rows: Array=[]
var source_model_name:=""
var static_draw_proof: Dictionary={}
var preparation_timings: Dictionary={}
var _build_progress: Dictionary={}
var staged_steps:=0
var staged_max_step_us:=0
static func scene_surface_bounds(source,node) -> Dictionary:
	var result:={"valid":false,"bounds":AABB()};var data=null
	if node is MeshInstance3D:data=node.mesh.get_meta("native_scene_geometry",null)
	elif node.has_meta("native_pick_geometry"):data=node.get_meta("native_pick_geometry").get_meta("native_scene_geometry",null)
	if data==null or data.indices.is_empty():return result
	var box: AABB=data.bounds;var local:=AABB(Vector3(box.position.x,box.position.z,-box.end.y),Vector3(box.size.x,box.size.z,box.size.y));var pose:=Transform3D.IDENTITY;var parent: Node=node
	while parent!=source and parent!=null:
		if parent is Node3D:pose=parent.transform*pose
		parent=parent.get_parent()
	result.bounds=pose*local;result.valid=true;return result
static func scene_bounds(source) -> Dictionary:
	var result:={"valid":false,"bounds":AABB()};var surfaces: Array=source.meshes.duplicate();surfaces.append_array(source.pick_surfaces)
	for node in surfaces:
		var current:=scene_surface_bounds(source,node)
		if not current.valid:continue
		result.bounds=result.bounds.merge(current.bounds) if result.valid else current.bounds;result.valid=true
	return result
class Placement:
	extends Node3D
	var parts: Array=[]
	var meshes: Array=[]
	var pick_surfaces: Array=[]
	var limitations: Array=[]
	var static_draw_proof: Dictionary={}
	var renderer_alpha
	func _ensure_renderer_alpha() -> bool:
		if retired:return false
		if renderer_alpha!=null:return true
		StaticDrawInvalidation.withdraw(self,"alpha-owner-enrollment")
		# Nonanimated template clones have private MeshInstances and no native
		# pose owner caching their materials. Enroll only on first alpha command.
		var owner:=preload("res://tools/native_parity/ui/actor-alpha-owner.gd").new();owner.begin_model(0)
		for mesh in meshes:
			if not owner.enroll(mesh,0):owner.close();return false
		renderer_alpha=owner;return true
	func renderer_alpha_model_indices() -> Array[int]:return [0] if not retired else []
	func set_renderer_alpha(value: float,indices: Array=[0]) -> bool:
		StaticDrawInvalidation.withdraw(self,"renderer-alpha");return _ensure_renderer_alpha() and renderer_alpha.set_alpha(value,indices)
	func set_renderer_vector(channel: int,value: Variant,indices: Array=[0]) -> bool:
		StaticDrawInvalidation.withdraw(self,"renderer-vector");return _ensure_renderer_alpha() and renderer_alpha.set_vector(channel,value,indices)
	func set_presentation_draw_enabled(value: bool,indices: Array=[0]) -> bool:
		StaticDrawInvalidation.withdraw(self,"presentation-draw");return _ensure_renderer_alpha() and renderer_alpha.set_presentation_draw_enabled(value,indices)
	var retired:=false
	var reference_graph
	var random_part_model: Dictionary={}
	func physical_part(part_name: String) -> Node3D:
		for part in parts:
			if str(part.get_meta("native_part_name","")).to_lower()==part_name.to_lower(): return part
		return null
	func impact_model() -> Dictionary:
		if random_part_model.is_empty():
			var rows: Array=[]
			for part in parts: rows.append({"index":part.get_meta("native_part_index"),"parent":part.get_meta("native_part_parent"),"name":part.get_meta("native_part_name"),"area":part.get_meta("native_part_area") if part.has_meta("native_part_area") else null})
			random_part_model=preload("res://systems/native_data/model_random_part.gd").graph(rows)
		return random_part_model
	func reattach_references(target: Node3D) -> bool:
		StaticDrawInvalidation.withdraw(self,"reference-reattachment")
		return not retired and (reference_graph==null or reference_graph.reattach(target))
	func retire() -> void:
		if retired: return
		StaticDrawInvalidation.withdraw(self,"placement-retirement")
		retired=true
		if renderer_alpha!=null:renderer_alpha.close();renderer_alpha=null
		for child in get_children(): child.free()
		parts.clear(); meshes.clear(); pick_surfaces.clear(); reference_graph=null; random_part_model.clear(); queue_free()
static func identity(bundle: Dictionary, pool) -> String:
	var textures: Array=[]; var names: Array=bundle.get("textures",{}).keys(); names.sort()
	for name in names: textures.append([name,bundle.textures[name].get("sha256","recorded-missing")])
	var emitter_names: Array=bundle.get("emitter_textures",{}).keys(); emitter_names.sort()
	for name in emitter_names: textures.append(["emitter:"+str(name),bundle.emitter_textures[name].get("sha256","recorded-missing")])
	var reference_origin:=str(bundle.get("resource_name",bundle.value.name)) if bundle.value.nodes.any(func(row):return row.has("reference") or row.has("emitter")) else ""
	var policy: Array=[bundle.sha256,textures,bundle.get("animation_sources",[]),reference_origin,pool.unshaded,pool.texture_filter,pool.picking]
	if pool.compact_static_parts: policy.append("compact-leaf-parts-v1")
	if pool.native_lighting: policy.append("native-enhanced-lighting-v1")
	if pool.native_standard: policy.append("native-standard-retail-v1")
	if pool.native_surface_output: policy.append("native-surface-gamma-v1")
	if OS.get_cmdline_user_args().has("--base-scenery-draw=merged"):policy.append("base-static-draw-proof-v1")
	if configured_recipe():policy.append(Recipe.REVISION)
	return Cache.digest(var_to_bytes(policy))
func build(bundle: Dictionary, pool) -> bool:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id(): failure="Native scene publication requires main thread"; return false
	if scene!=null or recipe!=null or is_instance_valid(_first_root) or not _build_progress.is_empty(): failure="Native template already prepared"; return false
	var began:=Timing.begin(); var phase_began:=began
	var source:=Instance.new()
	if not source.install(bundle,pool): failure=source.failure; source.free(); return false
	source_model_name=str(source.get_meta("native_model_name",""))
	if OS.get_cmdline_user_args().has("--base-scenery-draw=merged") and bundle.get("static_draw_proof") is Dictionary:static_draw_proof=bundle.static_draw_proof.duplicate(true)
	if began>0: preparation_timings.source_install_ms=(Time.get_ticks_usec()-phase_began)/1000.0; preparation_timings.install=source.install_timings.duplicate(); phase_began=Time.get_ticks_usec()
	var collision_bounds:=scene_bounds(source)
	if began>0: preparation_timings.bounds_ms=(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
	limitations=source.limitations.duplicate()
	if bundle.value.nodes.any(func(row):return row.has("reference")):
		for row in bundle.value.nodes: reference_rows.append({"name":row.name,"parent":row.parent})
	var root_node:=Node3D.new()
	if collision_bounds.valid: root_node.set_meta("native_scene_bounds",collision_bounds.bounds)
	for part in source.parts:
		if part.get_parent()==source: part.reparent(root_node,false)
	for node in root_node.find_children("*","",true,false): node.owner=root_node
	if began>0: preparation_timings.owners_ms=(Time.get_ticks_usec()-phase_began)/1000.0; preparation_timings.parts=source.parts.size(); preparation_timings.meshes=source.meshes.size(); phase_began=Time.get_ticks_usec()
	source.parts.clear(); source.meshes.clear(); source.pick_surfaces.clear(); source.free()
	if began>0: preparation_timings.source_dispose_ms=(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
	var result:=OK
	if configured_recipe():
		recipe_capture_attempts+=1;_construction_counts.recipe_capture_attempts+=1
		var candidate:=Recipe.new()
		if candidate.capture(root_node):recipe=candidate;recipe_capture_successes+=1
		else:
			recipe_fallback_reason=candidate.failure;_construction_counts.recipe_capture_fallbacks+=1
			var reason:=recipe_fallback_reason if _recipe_fallback_reasons.has(recipe_fallback_reason) or _recipe_fallback_reasons.size()<16 else "other-unsupported-graph"
			_recipe_fallback_reasons[reason]=int(_recipe_fallback_reasons.get(reason,0))+1
		if began>0:preparation_timings.recipe_capture_ms=(Time.get_ticks_usec()-phase_began)/1000.0;phase_began=Time.get_ticks_usec()
	if recipe==null:
		scene=PackedScene.new();result=scene.pack(root_node)
		if result==OK:packed_template_creations+=1;_construction_counts.packed_templates_built+=1
		if began>0:preparation_timings.pack_ms=(Time.get_ticks_usec()-phase_began)/1000.0;phase_began=Time.get_ticks_usec()
	else:
		_construction_counts.recipe_templates_built+=1
		if began>0:preparation_timings.pack_ms=0.0
	if result==OK: _first_root=root_node
	else: root_node.free()
	if began>0: preparation_timings.root_dispose_ms=(Time.get_ticks_usec()-phase_began)/1000.0; preparation_timings.total_ms=(Time.get_ticks_usec()-began)/1000.0
	if result!=OK: failure="Native model template pack failed"; scene=null; return false
	_construction_counts.templates_built+=1
	if began>0:
		preparation_timings.template_mode="known-node-recipe" if recipe!=null else "packed-scene"
		preparation_timings.recipe_capture_attempts=recipe_capture_attempts;preparation_timings.recipe_capture_successes=recipe_capture_successes;preparation_timings.recipe_fallback_reason=recipe_fallback_reason
	return true
func create() -> Placement:
	var began:=Timing.begin(); var result:=prepare_instance()
	Timing.finish("publication_clone_cpu_ms",began); return result
func prepare_instance() -> Placement:
	if not _build_progress.is_empty() or scene==null and recipe==null or OS.get_thread_caller_id()!=OS.get_main_thread_id(): return null
	var root_node: Node
	if is_instance_valid(_first_root):
		root_node=_first_root; _first_root=null; first_instance_reuses+=1;_construction_counts.first_root_reuses+=1
	elif recipe!=null:
		root_node=recipe.create()
		if root_node!=null:recipe_instance_creations+=1;_construction_counts.recipe_clones+=1
		else:failure="Native model recipe creation failed: "+recipe.failure
	else:
		root_node=scene.instantiate(); packed_instance_creations+=1;_construction_counts.packed_clones+=1
	if root_node==null:return null
	return _placement_from_root(root_node)
func _placement_from_root(root_node: Node) -> Placement:
	var placement:=Placement.new()
	placement.set_meta("native_model_name",source_model_name)
	placement.static_draw_proof=static_draw_proof
	placement.add_child(root_node)
	if root_node.has_meta("native_scene_bounds"): placement.set_meta("native_scene_bounds",root_node.get_meta("native_scene_bounds"))
	placement.parts=root_node.find_children("part_*","Node3D",true,false)
	placement.parts.sort_custom(func(a,b):return int(a.get_meta("native_part_index"))<int(b.get_meta("native_part_index")))
	placement.meshes=root_node.find_children("*","MeshInstance3D",true,false)
	placement.pick_surfaces=placement.parts.filter(func(part):return not part is MeshInstance3D and part.has_meta("native_pick_geometry"))
	placement.limitations=limitations.duplicate()
	if not reference_rows.is_empty():
		placement.reference_graph=ReferenceGraph.new()
		if not placement.reference_graph.configure(placement,reference_rows,placement.parts): placement.free(); return null
	return placement

func construction_snapshot() -> Dictionary:
	return {"mode":"known-node-recipe" if recipe!=null else "packed-scene","requested_recipe":configured_recipe(),"ready":_build_progress.is_empty() and (scene!=null or recipe!=null),"staged_pending":not _build_progress.is_empty(),"staged_steps":staged_steps,"staged_max_step_us":staged_max_step_us,"recipe_capture_attempts":recipe_capture_attempts,"recipe_capture_successes":recipe_capture_successes,"recipe_instance_creations":recipe_instance_creations,"recipe_fallback_reason":recipe_fallback_reason,"packed_template_creations":packed_template_creations,"packed_instance_creations":packed_instance_creations,"first_instance_reuses":first_instance_reuses,"recipe":recipe.snapshot() if recipe!=null else {}}

# Cooperative preparation is selected only by the existing recipe mode. The
# packed synchronous API remains available; no partial model enters a SceneTree.
func begin_staged_build(bundle: Dictionary,pool) -> bool:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():failure="Native scene publication requires main thread";return false
	if not configured_recipe():failure="Staged native templates require recipe mode";return false
	if scene!=null or recipe!=null or is_instance_valid(_first_root) or not _build_progress.is_empty():failure="Native template already prepared";return false
	var source:=Instance.new()
	if not source.begin_install(bundle,pool):failure=source.failure;source.free();return false
	_build_progress={"phase":"install","bundle":bundle,"pool":pool,"source":source,"root":null,"surfaces":[],"index":0,"bounds":{"valid":false,"bounds":AABB()},"reference_rows":[],"has_references":false,"owners":[],"candidate":null,"cpu_us":0}
	return true
func cancel_staged_build() -> void:
	if _build_progress.is_empty():return
	var state: Dictionary=_build_progress;_build_progress={}
	if is_instance_valid(state.source):state.source.cancel_install();state.source.free()
	if is_instance_valid(state.root):state.root.free()
	if state.candidate!=null:state.candidate.cancel_capture()
	scene=null;recipe=null
func _staged_failure(reason: String) -> Dictionary:
	failure=reason;cancel_staged_build();return {"status":"failed","reason":failure,"units":0}
func staged_build_step(maximum_units: int=8,budget_us: int=1500) -> Dictionary:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():return {"status":"failed","reason":"Native scene publication requires main thread","units":0}
	if _build_progress.is_empty():return {"status":"ready" if scene!=null or recipe!=null else "failed","reason":failure,"units":0}
	var began:=Time.get_ticks_usec();var units:=0;var result: Dictionary={"status":"pending"}
	while not _build_progress.is_empty() and units<maxi(1,maximum_units):
		if units>0 and budget_us>0 and Time.get_ticks_usec()-began>=budget_us:break
		var state: Dictionary=_build_progress;var source=state.source;var index:=int(state.index)
		match str(state.phase):
			"install":
				var phase_began:=Time.get_ticks_usec()
				result=source.install_step(maxi(1,maximum_units-units),maxi(1,budget_us-(Time.get_ticks_usec()-began)) if budget_us>0 else 0)
				if Timing.enabled:preparation_timings.source_install_ms=float(preparation_timings.get("source_install_ms",0.0))+(Time.get_ticks_usec()-phase_began)/1000.0
				if result.status=="failed":return _staged_failure(str(result.reason))
				units+=int(result.units)
				if result.status=="pending":break
				source_model_name=str(source.get_meta("native_model_name",""));limitations=source.limitations.duplicate()
				if OS.get_cmdline_user_args().has("--base-scenery-draw=merged") and state.bundle.get("static_draw_proof") is Dictionary:static_draw_proof=state.bundle.static_draw_proof.duplicate(true)
				if Timing.enabled:preparation_timings.install=source.install_timings.duplicate()
				state.surfaces=source.meshes.duplicate();state.surfaces.append_array(source.pick_surfaces);state.phase="bounds";state.index=0
			"bounds":
				if index>=state.surfaces.size():state.phase="references";state.index=0;continue
				var current:=scene_surface_bounds(source,state.surfaces[index])
				if current.valid:
					state.bounds.bounds=state.bounds.bounds.merge(current.bounds) if state.bounds.valid else current.bounds;state.bounds.valid=true
				state.index=index+1;units+=1
			"references":
				if index>=state.bundle.value.nodes.size():
					reference_rows=state.reference_rows if state.has_references else []
					state.root=Node3D.new()
					if state.bounds.valid:state.root.set_meta("native_scene_bounds",state.bounds.bounds)
					state.phase="move";state.index=0;continue
				var row: Dictionary=state.bundle.value.nodes[index];state.has_references=state.has_references or row.has("reference")
				state.reference_rows.append({"name":row.name,"parent":row.parent});state.index=index+1;units+=1
			"move":
				if index>=source.parts.size():state.owners=state.root.get_children();state.phase="owners";continue
				var part: Node=source.parts[index]
				if part.get_parent()==source:part.reparent(state.root,false)
				state.index=index+1;units+=1
			"owners":
				if state.owners.is_empty():
					source.parts.clear();source.meshes.clear();source.pick_surfaces.clear();source.free();state.source=null
					state.surfaces.clear();state.candidate=Recipe.new();recipe_capture_attempts+=1;_construction_counts.recipe_capture_attempts+=1
					if not state.candidate.begin_capture(state.root):return _staged_failure(state.candidate.failure)
					state.phase="capture";continue
				var owned: Node=state.owners.pop_back();owned.owner=state.root;state.owners.append_array(owned.get_children());units+=1
			"capture":
				result=state.candidate.capture_step(maxi(1,maximum_units-units),maxi(1,budget_us-(Time.get_ticks_usec()-began)) if budget_us>0 else 0);units+=int(result.units)
				if result.status=="pending":break
				if result.status=="failed":
					recipe_fallback_reason=str(result.reason);_construction_counts.recipe_capture_fallbacks+=1
					var reason:=recipe_fallback_reason if _recipe_fallback_reasons.has(recipe_fallback_reason) or _recipe_fallback_reasons.size()<16 else "other-unsupported-graph"
					_recipe_fallback_reasons[reason]=int(_recipe_fallback_reasons.get(reason,0))+1
					state.candidate=null;state.phase="packed-fallback";continue
				recipe_capture_successes+=1;state.phase="commit"
			"packed-fallback":
				# Unknown/local-to-scene graphs preserve the explicit existing fallback.
				# This individual engine call is not preemptible and remains observable.
				var pack_began:=Timing.begin();scene=PackedScene.new();var error:=scene.pack(state.root)
				Timing.finish("publication_template_fallback_pack_ms",pack_began)
				if error!=OK:scene=null;return _staged_failure("Native model template pack failed")
				packed_template_creations+=1;_construction_counts.packed_templates_built+=1;state.phase="commit";units+=1
			"commit":
				if state.candidate!=null:recipe=state.candidate;_construction_counts.recipe_templates_built+=1
				_first_root=state.root;state.root=null;_construction_counts.templates_built+=1
				_build_progress={};result={"status":"ready","units":units};break
	var elapsed:=Time.get_ticks_usec()-began;staged_steps+=1;staged_max_step_us=maxi(staged_max_step_us,elapsed)
	if Timing.enabled:
		preparation_timings.total_ms=float(preparation_timings.get("total_ms",0.0))+elapsed/1000.0
		preparation_timings.template_mode="known-node-recipe" if recipe!=null else "packed-scene";preparation_timings.staged=true
	Timing.record("publication_template_step_ms",elapsed/1000.0)
	return {"status":"ready" if _build_progress.is_empty() else "pending","units":units,"phase":str(_build_progress.get("phase","ready")),"step_us":elapsed,"fallback":recipe_fallback_reason}
func create_step(pending: Dictionary,maximum_nodes: int=8,budget_us: int=1500) -> Dictionary:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():return {"status":"failed","reason":"Native scene publication requires main thread"}
	if not _build_progress.is_empty():return {"status":"failed","reason":"Native staged template is not committed"}
	if not pending.is_empty() and (int(pending.get("owner",-1))!=get_instance_id() or recipe==null or int(pending.get("recipe",-1))!=recipe.get_instance_id()):
		cancel_creation(pending);return {"status":"failed","reason":"Native staged clone template changed"}
	if not is_instance_valid(_first_root) and recipe!=null:
		if pending.is_empty():
			var creation=recipe.begin_create()
			if creation==null:return {"status":"failed","reason":recipe.failure}
			pending.job=creation;pending.owner=get_instance_id();pending.recipe=recipe.get_instance_id()
		var began:=Timing.begin();var result: Dictionary=pending.job.step(maximum_nodes,budget_us);Timing.finish("publication_clone_step_ms",began)
		if result.status=="pending":return result
		if result.status=="failed":pending.clear();return result
		var root_node: Node3D=pending.job.take();pending.clear()
		if root_node==null:return {"status":"failed","reason":"Native staged recipe creation failed"}
		recipe_instance_creations+=1;_construction_counts.recipe_clones+=1
		var placement:=_placement_from_root(root_node)
		return {"status":"ready" if placement!=null else "failed","instance":placement}
	var placement:=create()
	return {"status":"ready" if placement!=null else "failed","instance":placement,"fallback":recipe_fallback_reason}
static func cancel_creation(pending: Dictionary) -> void:
	if pending.has("job"):pending.job.cancel()
	pending.clear()

func _notification(what: int) -> void:
	# Release an unused detached tree when its template binding is evicted.
	if what!=NOTIFICATION_PREDELETE:return
	# Inline the owned-state release: self method dispatch is unavailable while
	# a RefCounted script instance is being destroyed. Explicit cancellation
	# remains the ordinary live API; its external owners are still valid here.
	var state: Dictionary=_build_progress;_build_progress={}
	if not state.is_empty():
		if is_instance_valid(state.source):state.source.cancel_install();state.source.free()
		if is_instance_valid(state.root):state.root.free()
		if state.candidate!=null:state.candidate.cancel_capture()
	scene=null;recipe=null
	var root: Node3D=_first_root;_first_root=null
	if is_instance_valid(root):root.free()
