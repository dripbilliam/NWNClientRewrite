extends RefCounted
# Prepare a native PackedScene once; repeat instances clone in engine code.
# Private physical nodes and shared immutable resources are both preserved.
const Instance=preload("res://systems/native_render/model_instance.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const ReferenceGraph=preload("res://systems/native_render/reference_graph.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var scene: PackedScene
var limitations: Array=[]
var failure:=""
var reference_rows: Array=[]
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
		return not retired and (reference_graph==null or reference_graph.reattach(target))
	func retire() -> void:
		if retired: return
		retired=true
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
	return Cache.digest(var_to_bytes(policy))
func build(bundle: Dictionary, pool) -> bool:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id(): failure="Native scene publication requires main thread"; return false
	if scene!=null: failure="Native template already prepared"; return false
	var began:=Timing.begin(); var phase_began:=began
	var source:=Instance.new()
	if not source.install(bundle,pool): failure=source.failure; source.free(); return false
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
	scene=PackedScene.new(); var result:=scene.pack(root_node)
	if began>0: preparation_timings.pack_ms=(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
	root_node.free()
	if began>0: preparation_timings.root_dispose_ms=(Time.get_ticks_usec()-phase_began)/1000.0; preparation_timings.total_ms=(Time.get_ticks_usec()-began)/1000.0
	if result!=OK: failure="Native model template pack failed"; scene=null; return false
	return true
func create() -> Placement:
	var began:=Timing.begin(); var result:=prepare_instance()
	Timing.finish("publication_clone_cpu_ms",began); return result
func prepare_instance() -> Placement:
	if scene==null or OS.get_thread_caller_id()!=OS.get_main_thread_id(): return null
	var placement:=Placement.new(); var root_node:=scene.instantiate()
	if root_node==null: placement.free(); return null
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
