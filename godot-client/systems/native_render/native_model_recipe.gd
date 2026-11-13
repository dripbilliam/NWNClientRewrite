extends RefCounted
# A construction-boundary recipe, not a general Node serializer. Read only
# the properties ModelInstance owns: GeometryInstance property enumeration can
# synchronously drain unrelated render-server work. Resources stay pool-owned;
# every created tree and its mutable script/metadata containers are private.
const Light=preload("res://systems/native_render/model_point_light.gd")
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
const Reference=preload("res://systems/native_render/model_reference.gd")
const REVISION:="known-model-node-recipe-v3-native-containers"
const MAX_NODES:=65536
const MAX_DATA_DEPTH:=64
const NODE_FIELDS:=["name","transform","visible","top_level","visibility_parent","process_mode","process_priority","process_physics_priority","process_thread_group","process_thread_group_order","process_thread_messages","physics_interpolation_mode","unique_name_in_owner"]
const MESH_FIELDS:=["mesh","skeleton","material_override","material_overlay","cast_shadow","layers","extra_cull_margin","custom_aabb","lod_bias","transparency","gi_mode","visibility_range_begin","visibility_range_end","visibility_range_begin_margin","visibility_range_end_margin","visibility_range_fade_mode","ignore_occlusion_culling","sorting_offset","sorting_use_aabb_center"]
const LIGHT_FIELDS:=["light_color","light_energy","light_indirect_energy","light_volumetric_fog_energy","light_specular","light_negative","light_cull_mask","light_bake_mode","light_projector","shadow_enabled","shadow_bias","shadow_normal_bias","shadow_reverse_cull_face","shadow_transmittance_bias","shadow_opacity","omni_range","omni_attenuation","omni_shadow_mode"]
const EMITTER_FIELDS:=["original_properties","physical_part","source_path","original_texture","origin_resource","source_model_flags","reference_paths","force_reference","frustum_enabled","particles_enabled","collision_enabled"]
const REFERENCE_FIELDS:=["original_header","origin_resource"]
var failure:=""
var _rows: Array=[]
var _asset_inputs: Array=[]
var _asset_snapshots: Array=[]
var _created:=0
var _capture_us:=0
var _create_us:=0
var _capture_state: Dictionary={}
var _defaults_cache: Dictionary={}
static var _builtin_defaults_cache: Dictionary={}
var _shared_resources: Dictionary={}

func _reject(reason: String) -> bool:
	failure=reason;return false
func _kind(node: Node) -> String:
	var script: Script=node.get_script()
	if script==Light:return "light"
	if script==Emitter:return "emitter"
	if script==Reference:return "reference"
	if script!=null:return ""
	if node.get_class()=="Node3D":return "node"
	if node.get_class()=="MeshInstance3D":return "mesh"
	return ""
func _copy_data(value: Variant,freeze: bool=false,ancestors: Array=[],depth: int=0) -> Variant:
	if not failure.is_empty():return null
	if depth>MAX_DATA_DEPTH:_reject("recipe-data-depth");return null
	if value is Resource:
		if value.resource_local_to_scene:_reject("recipe-local-resource");return null
		_shared_resources[value.get_instance_id()]=value
		return value
	if value is Object or value is Callable or value is Signal:_reject("recipe-runtime-data-reference");return null
	if value is float and not is_finite(value):_reject("recipe-nonfinite-data");return null
	if value is Array or value is Dictionary:
		for previous in ancestors:
			if is_same(previous,value):_reject("recipe-cyclic-data");return null
		var path: Array=ancestors+[value]
		if value is Array:
			var array: Array=[]
			for item in value:array.append(_copy_data(item,freeze,path,depth+1))
			if freeze:array.make_read_only()
			return array
		var dictionary: Dictionary={}
		for key in value:
			if not (key is String or key is StringName or key is int or key is bool or key is float):_reject("recipe-data-key");return null
			dictionary[key]=_copy_data(value[key],freeze,path,depth+1)
		if freeze:dictionary.make_read_only()
		return dictionary
	# Packed arrays are value/COW storage. Scalars, paths, transforms, colors
	# and bounds are values too; no live object binding is retained here.
	return value
func _clone_validated_data(value: Variant) -> Variant:
	# Capture already rejected cycles, runtime owners, unsupported keys and
	# nonfinite values. Native deep duplication gives each placement private
	# mutable containers without interpreting every scalar again in GDScript.
	# Resources stay shared; packed arrays retain their normal COW ownership.
	return value.duplicate(true) if value is Dictionary or value is Array else value
func _shared_asset(value: Dictionary) -> Dictionary:
	for index in _asset_inputs.size():
		if is_same(_asset_inputs[index],value):return _asset_snapshots[index]
	var snapshot: Variant=_copy_data(value,true)
	if not failure.is_empty():return {}
	_asset_inputs.append(value);_asset_snapshots.append(snapshot);return snapshot
func _constructor_defaults(kind: String) -> Dictionary:
	# Built-in Node3D/MeshInstance3D defaults are process-constant. Hundreds
	# of templates can share these read-only comparisons instead of creating
	# and freeing two probe nodes per template. Script-owned kinds keep their
	# per-recipe constructor probes and initializer semantics.
	var builtin:=kind=="node" or kind=="mesh"
	if builtin and _builtin_defaults_cache.has(kind):return _builtin_defaults_cache[kind]
	if _defaults_cache.has(kind):return _defaults_cache[kind]
	# Compare with the exact constructor used by _create_one, including script
	# initializers. Default values need no render-server setter on every clone.
	var node:=_new_node(kind);var fields: Dictionary={};var mesh: Dictionary={}
	for field in NODE_FIELDS:fields[field]=node.get(field)
	if kind=="mesh":
		for field in MESH_FIELDS:mesh[field]=node.get(field)
	node.free();var result:={"node":fields,"mesh":mesh}
	if builtin:
		fields.make_read_only();mesh.make_read_only();result.make_read_only()
		_builtin_defaults_cache[kind]=result
	else:_defaults_cache[kind]=result
	return result
func _fields(node: Node,names: Array,defaults: Dictionary={},retain_visible: bool=false) -> Dictionary:
	var result: Dictionary={}
	for field in names:
		var value: Variant=node.get(field)
		if field=="visible" and retain_visible or not defaults.has(field) or value!=defaults[field]:result[field]=_copy_data(value,true)
	return result
func _internal_path(node: Node,path: NodePath) -> bool:
	if path.is_empty() or path.is_absolute():return false
	var target:=node.get_node_or_null(path)
	if target==null:return false
	var construction_root:=node
	while construction_root.get_parent()!=null:construction_root=construction_root.get_parent()
	return target==construction_root or construction_root.is_ancestor_of(target)
func _capture_one(node: Node,parent: int,rows: Array) -> bool:
	if rows.size()>=MAX_NODES:return _reject("recipe-node-limit")
	var kind:=_kind(node)
	if kind.is_empty():return _reject("recipe-unsupported-node:"+str(node.get_class()))
	if node.is_inside_tree() or node.is_node_ready() or node.is_queued_for_deletion():return _reject("recipe-already-admitted-node")
	if not node.get_groups().is_empty():return _reject("recipe-configured-groups")
	var defaults:=_constructor_defaults(kind)
	var row: Dictionary={"kind":kind,"parent":parent,"node":_fields(node,NODE_FIELDS,defaults.node,kind=="light"),"metadata":{}}
	if not node.transform.is_finite():return _reject("recipe-nonfinite-transform")
	for name in node.get_meta_list():row.metadata[name]=_copy_data(node.get_meta(name),true)
	match kind:
		"mesh":
			if node.skin!=null or node.skeleton not in [NodePath(),NodePath("..")]:return _reject("recipe-managed-skeleton")
			if node.mesh!=null and not node.mesh is ArrayMesh:return _reject("recipe-unsupported-mesh")
			if node.mesh!=null and node.mesh.get_blend_shape_count()>0:return _reject("recipe-blend-shape-state")
			row.fields=_fields(node,MESH_FIELDS,defaults.mesh);row.surfaces=[]
			for surface in node.get_surface_override_material_count():row.surfaces.append(_copy_data(node.get_surface_override_material(surface),true))
		"light":
			if node.native_slot>=0 or node.focus_owner!=null or node.animation_cached or not node.native_admitted or node.native_fade!=1.0:return _reject("recipe-active-light-binding")
			if not node.has_meta("native_model_light_properties"):return _reject("recipe-unconfigured-model-light")
			row.fields=_fields(node,LIGHT_FIELDS)
		"emitter":
			if node.retired or node.native_owner!=null or node.surface!=null or node.source!=null or node.frames!=0 or node.elapsed!=0.0 or not node.state.is_empty() or not node.parameters.is_empty() or not node.providers.is_empty() or not node.failure.is_empty() or not node.services.is_empty() or node.clock_provider.is_valid() or not node.channels.clips.is_empty():return _reject("recipe-active-emitter-binding")
			if not _internal_path(node,node.source_path):return _reject("recipe-external-emitter-source")
			for path in node.reference_paths:
				if not _internal_path(node,path):return _reject("recipe-external-reference-path")
			row.fields=_fields(node,EMITTER_FIELDS);row.channel_asset=_shared_asset(node.channel_asset)
		"reference":
			if node.retired or node.model68!=null or node.hub!=null or node.external_anchor!=null or node.generation!=-1 or node.revision!=0 or not node.failure.is_empty():return _reject("recipe-active-reference-binding")
			row.fields=_fields(node,REFERENCE_FIELDS)
	if not failure.is_empty():return false
	rows.append(row)
	row.node.make_read_only();row.metadata.make_read_only()
	if row.has("fields"):row.fields.make_read_only()
	if row.has("surfaces"):row.surfaces.make_read_only()
	row.make_read_only();return true
func _capture_node(node: Node,parent: int,rows: Array) -> bool:
	var index:=rows.size()
	if not _capture_one(node,parent,rows):return false
	for child in node.get_children():
		if not _capture_node(child,index,rows):return false
	return true
func capture(source: Node3D) -> bool:
	if not _rows.is_empty() or not _capture_state.is_empty():return _reject("recipe-already-captured")
	failure="";_asset_inputs.clear();_asset_snapshots.clear();_shared_resources.clear()
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():return _reject("recipe-main-thread-required")
	if not is_instance_valid(source) or source.get_parent()!=null:return _reject("recipe-detached-root-required")
	var began:=Time.get_ticks_usec();var rows: Array=[]
	var accepted:=_capture_node(source,-1,rows)
	_asset_inputs.clear() # Never retain source-tree objects or mutable source graphs.
	if not accepted:_asset_snapshots.clear();_shared_resources.clear();return false
	rows.make_read_only();_rows=rows;_capture_us=Time.get_ticks_usec()-began;return true
func begin_capture(source: Node3D,own_during_capture: bool=false) -> bool:
	if not _rows.is_empty() or not _capture_state.is_empty():return _reject("recipe-already-captured")
	failure="";_asset_inputs.clear();_asset_snapshots.clear();_shared_resources.clear()
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():return _reject("recipe-main-thread-required")
	if not is_instance_valid(source) or source.get_parent()!=null:return _reject("recipe-detached-root-required")
	_capture_state={"queue":[{"node":source,"parent":-1}],"rows":[],"cpu_us":0,"owner_root":source if own_during_capture else null}
	return true
func capture_step(maximum_nodes: int=8,budget_us: int=1500) -> Dictionary:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():return {"status":"failed","reason":"recipe-main-thread-required","units":0}
	if not _rows.is_empty():return {"status":"ready","units":0}
	if _capture_state.is_empty():return {"status":"failed","reason":"recipe-no-active-capture","units":0}
	var began:=Time.get_ticks_usec();var units:=0
	while not _capture_state.queue.is_empty() and units<maxi(1,maximum_nodes):
		if units>0 and budget_us>0 and Time.get_ticks_usec()-began>=budget_us:break
		var entry: Dictionary=_capture_state.queue.pop_back();var node: Node=entry.node;var index: int=_capture_state.rows.size()
		var valid:=is_instance_valid(node)
		# Large staged templates visit every node here already. Assign the
		# detached root as owner during that visit instead of walking the whole
		# graph once before capture. The root itself remains unowned.
		if valid and index>0 and _capture_state.owner_root!=null:node.owner=_capture_state.owner_root
		if not valid or not _capture_one(node,int(entry.parent),_capture_state.rows):
			if failure.is_empty():_reject("recipe-capture-node-retired")
			cancel_capture();return {"status":"failed","reason":failure,"units":units}
		units+=1;var children:=node.get_children()
		for child in range(children.size()-1,-1,-1):_capture_state.queue.append({"node":children[child],"parent":index})
	_capture_state.cpu_us+=Time.get_ticks_usec()-began
	if _capture_state.queue.is_empty():
		var rows: Array=_capture_state.rows;rows.make_read_only();_rows=rows;_capture_us=int(_capture_state.cpu_us)
		_capture_state.clear();_asset_inputs.clear();return {"status":"ready","units":units}
	return {"status":"pending","units":units}
func cancel_capture() -> void:
	_capture_state.clear();_asset_inputs.clear()
	if _rows.is_empty():_asset_snapshots.clear();_shared_resources.clear()
func _new_node(kind: String) -> Node3D:
	match kind:
		"node":return Node3D.new()
		"mesh":return MeshInstance3D.new()
		"light":return Light.new()
		"emitter":return Emitter.new()
		"reference":return Reference.new()
	return null
func _create_one(row: Dictionary,nodes: Array[Node3D]) -> Node3D:
	var node:=_new_node(str(row.kind))
	if node==null:failure="recipe-invalid-node-kind";return null
	for field in row.node:
		# Detached template roots are intentionally unnamed. A fresh Node is
		# already unnamed; assigning an empty name invokes Godot's error guard.
		if field!="name" or not str(row.node[field]).is_empty():node.set(field,row.node[field])
	for name in row.metadata:node.set_meta(name,_clone_validated_data(row.metadata[name]))
	if row.kind=="light":node.configure(node.get_meta("native_model_light_properties"))
	if row.has("fields"):
		for field in row.fields:
			if row.kind!="emitter" or field!="reference_paths":node.set(field,_clone_validated_data(row.fields[field]))
	if row.kind=="emitter":
		node.channel_asset=row.channel_asset
		# Preserve the typed exported path array without reflection.
		var paths: Array[NodePath]=[]
		for path in row.fields.reference_paths:paths.append(path)
		node.reference_paths=paths
	if row.kind=="mesh":
		for surface in row.surfaces.size():node.set_surface_override_material(surface,row.surfaces[surface])
	# Light configure computes visibility; restore the authored construction
	# value after its private native-property initialization. Other nodes have
	# already received any nondefault visibility in the normal field order.
	if row.kind=="light":node.visible=row.node.visible
	nodes.append(node)
	if int(row.parent)>=0:nodes[row.parent].add_child(node);node.owner=nodes[0]
	return node
class Creation:
	extends RefCounted
	var owner
	var nodes: Array[Node3D]=[]
	var cursor:=0
	var cpu_us:=0
	var status:="pending"
	var failure:=""
	var capture_placement_index:=false
	# Rows are captured in the same depth-first order that placement scans.
	# Collect the clone's private lookup as nodes are created so the later
	# publication step need not traverse this entire tree a second time.
	var placement_meshes: Array=[]
	var placement_part_slots: Array=[]
	var placement_part_failure:=""
	func step(maximum_nodes: int=8,budget_us: int=1500) -> Dictionary:
		if OS.get_thread_caller_id()!=OS.get_main_thread_id():return {"status":"failed","reason":"recipe-main-thread-required","units":0}
		if status!="pending":return {"status":status,"reason":failure,"units":0}
		var began:=Time.get_ticks_usec();var units:=0
		while cursor<owner._rows.size() and units<maxi(1,maximum_nodes):
			if units>0 and budget_us>0 and Time.get_ticks_usec()-began>=budget_us:break
			var created: Node3D=owner._create_one(owner._rows[cursor],nodes)
			if created==null:
				failure=owner.failure;cancel();status="failed";return {"status":status,"reason":failure,"units":units}
			# The root itself was not visited by the original placement walk.
			if capture_placement_index and cursor>0:
				if created is MeshInstance3D:placement_meshes.append(created)
				if str(created.name).match("part_*"):
					var part:=int(created.get_meta("native_part_index"))
					if part<0 or part>=65536:placement_part_failure="Native placement physical part index is unavailable"
					elif placement_part_failure.is_empty():
						if placement_part_slots.size()<=part:placement_part_slots.resize(part+1)
						placement_part_slots[part]=created
			cursor+=1;units+=1
		cpu_us+=Time.get_ticks_usec()-began
		if cursor>=owner._rows.size():status="ready"
		return {"status":status,"units":units}
	func placement_index() -> Dictionary:
		if status!="ready" or not capture_placement_index:return {}
		# Transfer the private arrays before this short-lived Creation is freed.
		# Its predelete cleanup otherwise clears Array references held by the job.
		var index:={"meshes":placement_meshes,"part_slots":placement_part_slots,"failure":placement_part_failure}
		placement_meshes=[];placement_part_slots=[]
		return index
	func take() -> Node3D:
		if OS.get_thread_caller_id()!=OS.get_main_thread_id():return null
		if status!="ready" or nodes.is_empty():return null
		var root: Node3D=nodes[0];nodes.clear();owner._created+=1;owner._create_us+=cpu_us;owner=null;status="taken";return root
	func cancel() -> void:
		if not nodes.is_empty() and is_instance_valid(nodes[0]):nodes[0].free()
		nodes.clear();placement_meshes.clear();placement_part_slots.clear();owner=null;status="cancelled"
	func _notification(what: int) -> void:
		if what!=NOTIFICATION_PREDELETE:return
		# RefCounted script teardown cannot dispatch another method on self.
		# Clear the owned root before releasing the recipe reference; a taken
		# graph was already removed from nodes and is never freed here.
		var root: Node3D=nodes[0] if not nodes.is_empty() else null
		nodes.clear();placement_meshes.clear();placement_part_slots.clear()
		if is_instance_valid(root):root.free()
		owner=null;status="cancelled"
func begin_create(with_placement_index: bool=false) -> Creation:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id() or _rows.is_empty():failure="recipe-unavailable-or-wrong-thread";return null
	for resource in _shared_resources.values():
		if resource.resource_local_to_scene:failure="recipe-local-resource";return null
	failure="";var creation:=Creation.new();creation.owner=self;creation.capture_placement_index=with_placement_index;return creation
func node_count() -> int:return _rows.size()
func create() -> Node3D:
	var creation:=begin_create()
	if creation==null:return null
	while creation.status=="pending":creation.step(65536,0)
	return creation.take()
func snapshot() -> Dictionary:
	# Diagnostics expose counts only, never live Nodes, Resources or records.
	return {"revision":REVISION,"ready":not _rows.is_empty(),"nodes":_rows.size(),"shared_channel_assets":_asset_snapshots.size(),"created":_created,"capture_us":_capture_us,"create_us":_create_us,"failure":failure}
