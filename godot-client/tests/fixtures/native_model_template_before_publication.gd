extends RefCounted
# Prepare a native PackedScene once; repeat instances clone in engine code.
# Private physical nodes and shared immutable resources are both preserved.
const Instance=preload("res://tests/fixtures/native_model_instance_before_publication.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const ReferenceGraph=preload("res://systems/native_render/reference_graph.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const StaticDrawInvalidation=preload("res://systems/native_render/static_draw_invalidation.gd")
const Recipe=preload("res://systems/native_render/native_model_recipe.gd")
static var _construction_counts: Dictionary={"templates_built":0,"recipe_capture_attempts":0,"recipe_templates_built":0,"recipe_capture_fallbacks":0,"recipe_clones":0,"packed_templates_built":0,"packed_clones":0,"first_root_reuses":0}
static var _recipe_fallback_reasons: Dictionary={}
static func configured_recipe() -> bool:return false # Fixed packed oracle, independent of candidate selection.
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
static func scene_bounds(source) -> Dictionary:
	var result:={"valid":false,"bounds":AABB()}; var surfaces: Array=source.meshes.duplicate(); surfaces.append_array(source.pick_surfaces)
	for node in surfaces:
		var data=null
		if node is MeshInstance3D: data=node.mesh.get_meta("native_scene_geometry",null)
		elif node.has_meta("native_pick_geometry"): data=node.get_meta("native_pick_geometry").get_meta("native_scene_geometry",null)
		if data==null or data.indices.is_empty(): continue
		var box: AABB=data.bounds; var local:=AABB(Vector3(box.position.x,box.position.z,-box.end.y),Vector3(box.size.x,box.size.z,box.size.y)); var pose:=Transform3D.IDENTITY; var parent: Node=node
		# Template construction occurs outside the SceneTree. Compose local
		# transforms instead of reading invalid global_transform values.
		while parent!=source and parent!=null:
			if parent is Node3D: pose=parent.transform*pose
			parent=parent.get_parent()
		var transformed: AABB=pose*local
		result.bounds=result.bounds.merge(transformed) if result.valid else transformed; result.valid=true
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
	if scene!=null or recipe!=null or is_instance_valid(_first_root): failure="Native template already prepared"; return false
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
	if scene==null and recipe==null or OS.get_thread_caller_id()!=OS.get_main_thread_id(): return null
	var placement:=Placement.new(); var root_node: Node
	if is_instance_valid(_first_root):
		root_node=_first_root; _first_root=null; first_instance_reuses+=1;_construction_counts.first_root_reuses+=1
	elif recipe!=null:
		root_node=recipe.create()
		if root_node!=null:recipe_instance_creations+=1;_construction_counts.recipe_clones+=1
		else:failure="Native model recipe creation failed: "+recipe.failure
	else:
		root_node=scene.instantiate(); packed_instance_creations+=1;_construction_counts.packed_clones+=1
	if root_node==null: placement.free(); return null
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
	return {"mode":"known-node-recipe" if recipe!=null else "packed-scene","requested_recipe":configured_recipe(),"ready":scene!=null or recipe!=null,"recipe_capture_attempts":recipe_capture_attempts,"recipe_capture_successes":recipe_capture_successes,"recipe_instance_creations":recipe_instance_creations,"recipe_fallback_reason":recipe_fallback_reason,"packed_template_creations":packed_template_creations,"packed_instance_creations":packed_instance_creations,"first_instance_reuses":first_instance_reuses,"recipe":recipe.snapshot() if recipe!=null else {}}

func _notification(what: int) -> void:
	# Release an unused detached tree when its template binding is evicted.
	if what==NOTIFICATION_PREDELETE and is_instance_valid(_first_root):
		_first_root.free(); _first_root=null
