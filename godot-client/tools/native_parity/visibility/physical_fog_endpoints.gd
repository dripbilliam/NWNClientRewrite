extends RefCounted
# Cold physical endpoints only. Resolver owns Part/TileData association; reducer
# owns factors. No geometry/material clones, timers, alpha/shadow or activation.
const Batches=preload("res://systems/native_render/terrain_batches.gd")
const PARAMETER:="nwn_tile_fog_factor"
var _world: WeakRef
var _scope: Array=[]
var _world_generation: Variant=null
var _world_area: Variant=null
var _scope_guard:=Callable()
var _association_current:=Callable()
var _records: Dictionary={}
var _closed:=true
var _revision:=0
var _serial:=0
var stats:={"bindings":0,"writes":0,"retired":0,"unsupported":0,"stale":0}

static func property(owner: Object,name: String,fallback: Variant=null) -> Variant:
	if not is_instance_valid(owner):return fallback
	for entry in owner.get_property_list():
		if str(entry.name)==name:return owner.get(name)
	return fallback
static func alive(owner: Variant) -> bool:
	if not owner is Node or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree():return false
	# Geometry lifecycle is certified by its physical parent and exact endpoint
	# identities. Do not enumerate its renderer-generated shader property list.
	if owner is GeometryInstance3D:return true
	return property(owner,"retired",false)!=true and property(owner,"closed",false)!=true and property(owner,"retiring",false)!=true
static func weak_identity(owner: Object) -> Dictionary:return {"weak":weakref(owner),"id":owner.get_instance_id()}
static func resolve_identity(value: Dictionary) -> Variant:
	var owner: Variant=value.weak.get_ref()
	return owner if is_instance_valid(owner) and owner.get_instance_id()==value.id else null
func unavailable(reason: String) -> Dictionary:
	stats.unsupported+=1
	return {"available":false,"reason":reason,"default_factor":1.0}
func configure(world: Node,scope: Array,scope_guard: Callable,association_current: Callable) -> Dictionary:
	if not _closed or not alive(world) or scope.is_empty() or not scope_guard.is_valid() or not association_current.is_valid():return unavailable("physical-fog-endpoint-configuration-unavailable")
	var generation: Variant=property(world,"generation");var area: Variant=property(world,"area_id")
	if not generation is int or generation<0 or not area is int or area<0 or area>4294967295:return unavailable("physical-fog-world-generation-unavailable")
	_world_generation=generation;_world_area=area
	_world=weakref(world);_scope=scope.duplicate(true);_scope_guard=scope_guard;_association_current=association_current;_closed=false;_revision+=1
	return {"available":_current()}
func _current() -> bool:
	var world: Variant=_world.get_ref() if _world!=null else null
	if _closed or not alive(world) or property(world,"generation")!=_world_generation or property(world,"area_id")!=_world_area or not _scope_guard.is_valid():return false
	var epoch:=_revision;var accepted: Variant=_scope_guard.call(_scope.duplicate(true))
	return accepted is bool and accepted and not _closed and _revision==epoch and _world.get_ref()==world and alive(world) and property(world,"generation")==_world_generation and property(world,"area_id")==_world_area

static func mesh_endpoint(mesh: GeometryInstance3D) -> Dictionary:
	if not alive(mesh):return {}
	var material: Material=mesh.material_override
	if not material is ShaderMaterial or material.get_meta("native_surface_output",false)!=true or material.shader==null or not material.shader.code.contains("instance uniform float "+PARAMETER):return {}
	var geometry: Mesh
	var data: MultiMesh
	if mesh is MeshInstance3D:
		geometry=mesh.mesh
		for index in mesh.get_surface_override_material_count():
			if mesh.get_surface_override_material(index)!=null:return {}
	elif mesh is MultiMeshInstance3D:
		data=mesh.multimesh
		if data==null or not data.use_custom_data or not material.shader.code.contains("INSTANCE_CUSTOM"):return {}
		geometry=data.mesh
	else:return {}
	if geometry==null:return {}
	var node_ref:=weak_identity(mesh)
	var material_ref:=weak_identity(material)
	var shader_ref:=weak_identity(material.shader)
	var mesh_ref:=weak_identity(geometry)
	var data_ref: Dictionary={}
	if data!=null:data_ref=weak_identity(data)
	return {"node":node_ref,"material":material_ref,"shader":shader_ref,"mesh":mesh_ref,"multimesh":data_ref}
static func mesh_current(endpoint: Dictionary) -> bool:
	var node: Variant=resolve_identity(endpoint.node);var material: Variant=resolve_identity(endpoint.material);var shader: Variant=resolve_identity(endpoint.shader);var geometry: Variant=resolve_identity(endpoint.mesh)
	if not alive(node) or material==null or shader==null or geometry==null or node.material_override!=material or material.shader!=shader or material.get_meta("native_surface_output",false)!=true:return false
	if not shader.code.contains("instance uniform float "+PARAMETER):return false
	if node is MeshInstance3D:
		if node.mesh!=geometry:return false
		for index in node.get_surface_override_material_count():
			if node.get_surface_override_material(index)!=null:return false
		return endpoint.multimesh.is_empty()
	var data: Variant=resolve_identity(endpoint.multimesh) if not endpoint.multimesh.is_empty() else null
	return node is MultiMeshInstance3D and data!=null and node.multimesh==data and data.mesh==geometry and data.use_custom_data and shader.code.contains("INSTANCE_CUSTOM")

func _physical_current(record: Dictionary) -> bool:
	var world: Variant=_world.get_ref() if _world!=null else null;var owner: Variant=resolve_identity(record.owner)
	if not alive(world) or not alive(owner):return false
	if record.route=="static":
		var instances: Variant=property(world,"instances")
		if not instances is Dictionary or instances.get(record.index)!=owner:return false
	else:
		var terrain: Variant=resolve_identity(record.terrain)
		if not alive(terrain) or property(world,"terrain")!=terrain:return false
		if record.route=="terrain":
			var instances: Variant=property(terrain,"instances")
			if not instances is Dictionary or instances.get(record.index)!=owner:return false
		else:
			if property(terrain,"batcher")!=owner or owner.get_script()!=Batches:return false
			var current: Variant=owner.tile_fog_targets.get(record.index)
			if not current is Array or current.size()!=record.endpoints.size():return false
			for index in current.size():
				var endpoint: Dictionary=record.endpoints[index];var row: Variant=current[index]
				if not row is Dictionary or not is_same(row,endpoint.row) or row.get("instance")!=endpoint.slot or row.get("id")!=endpoint.node.id or not row.get("owner") is WeakRef or row.owner.get_ref()!=resolve_identity(endpoint.node):return false
				var node: Variant=resolve_identity(endpoint.node)
				if node==null or not owner.owners.has(node) or not owner.is_ancestor_of(node):return false
				if node is MultiMeshInstance3D:
					var data: Variant=resolve_identity(endpoint.multimesh)
					if data==null or endpoint.slot<0 or endpoint.slot>=data.instance_count or data.get_instance_transform(endpoint.slot)!=endpoint.transform:return false
	for endpoint in record.endpoints:
		if not mesh_current(endpoint):return false
		var node: Variant=resolve_identity(endpoint.node)
		if record.route!="batch" and (not owner.is_ancestor_of(node) or not property(owner,"meshes",[]).has(node)):return false
	return true
func _record_current(record: Dictionary,installed: bool=true) -> bool:
	if not _current() or installed and not is_same(_records.get(record.key),record) or not _physical_current(record):return false
	var epoch:=_revision
	var accepted: Variant=_association_current.call(record.association.duplicate(true))
	# Revalidate physical identities after resolver source/Part guards, which
	# can reenter publication or retire/replace a model/material.
	return accepted is bool and accepted and not _closed and _revision==epoch and (not installed or is_same(_records.get(record.key),record)) and _current() and _revision==epoch and _physical_current(record)
func _bind(key: String,association: Dictionary,owner: Node,index: int,route: String,endpoints: Array,terrain: Node=null) -> Dictionary:
	if not alive(owner) or key.is_empty() or association.is_empty() or endpoints.is_empty() or _records.has(key):return unavailable("physical-fog-endpoint-unsupported-or-key-owned")
	var record:={"key":key,"association":association.duplicate(true),"owner":weak_identity(owner),"index":index,"route":route,"endpoints":endpoints,"terrain":weak_identity(terrain) if terrain!=null else {},"serial":_serial+1}
	if not _record_current(record,false):return unavailable("physical-fog-endpoint-source-or-physical-owner-stale")
	_serial+=1;record.serial=_serial;record.lease={"adapter":get_instance_id(),"serial":_serial,"key":key,"scope":_scope.duplicate(true),"association":association.duplicate(true),"owner":owner.get_instance_id(),"route":route,"index":index}
	_records[key]=record;_revision+=1;stats.bindings+=1
	return {"available":true,"key":key,"lease":record.lease.duplicate(true),"lease_current":lease_current,"publish":publish,"route":route,"endpoints":endpoints.size()}
func static_world_mesh(key: String,association: Dictionary,id: int,owner: Node3D,mesh: MeshInstance3D) -> Dictionary:
	var endpoint:=mesh_endpoint(mesh)
	if endpoint.is_empty():return unavailable("physical-fog-static-native-surface-unavailable")
	return _bind(key,association,owner,id,"static",[endpoint])
func terrain_mesh(key: String,association: Dictionary,index: int,owner: Node3D,mesh: MeshInstance3D) -> Dictionary:
	var world: Variant=_world.get_ref() if _world!=null else null;var terrain: Variant=property(world,"terrain");var endpoint:=mesh_endpoint(mesh)
	if endpoint.is_empty() or not alive(terrain):return unavailable("physical-fog-terrain-native-surface-unavailable")
	return _bind(key,association,owner,index,"terrain",[endpoint],terrain)
func terrain_batch(key: String,association: Dictionary,index: int,batcher: Node3D) -> Dictionary:
	var world: Variant=_world.get_ref() if _world!=null else null;var terrain: Variant=property(world,"terrain")
	if not alive(batcher) or batcher.get_script()!=Batches or not alive(terrain):return unavailable("physical-fog-existing-batch-owner-unavailable")
	var endpoints: Array=[]
	for row in batcher.tile_fog_targets.get(index,[]):
		var node: Variant=row.owner.get_ref();var endpoint:=mesh_endpoint(node)
		if endpoint.is_empty():return unavailable("physical-fog-batch-native-surface-unavailable")
		endpoint.merge({"row":row,"slot":int(row.instance),"transform":node.multimesh.get_instance_transform(int(row.instance)) if node is MultiMeshInstance3D and int(row.instance)>=0 and int(row.instance)<node.multimesh.instance_count else Transform3D.IDENTITY});endpoints.append(endpoint)
	return _bind(key,association,batcher,index,"batch",endpoints,terrain)
func lease_current(lease: Dictionary) -> bool:
	var record: Dictionary=_records.get(lease.get("key"),{})
	if record.is_empty() or lease!=record.lease or record.get("invalidated",false):return false
	if _record_current(record):return true
	# Once a stale physical generation is observed, restoring the same material
	# or numeric World ID cannot revive that older endpoint lease.
	record.invalidated=true;_revision+=1;stats.stale+=1;return false
func publish(factor: float,lease: Dictionary) -> bool:
	if not is_finite(factor) or not lease_current(lease):stats.stale+=1;return false
	var record: Dictionary=_records[lease.key];var epoch:=_revision
	if record.route=="batch":
		var owner: Variant=resolve_identity(record.owner)
		if owner.set_native_tile_fog(int(record.index),factor)!=true:return false
	else:
		var mesh: Variant=resolve_identity(record.endpoints[0].node)
		preload("res://systems/native_render/static_draw_invalidation.gd").withdraw(mesh,"physical-tile-fog-factor")
		mesh.set_instance_shader_parameter(PARAMETER,factor)
	if _revision!=epoch or not lease_current(lease):stats.stale+=1;return false
	stats.writes+=1;return true
func retire(key: String,lease: Dictionary) -> bool:
	var record: Dictionary=_records.get(key,{})
	if record.is_empty() or lease!=record.lease:return false
	_records.erase(key);_revision+=1;stats.retired+=1;return true
func snapshot() -> Dictionary:return {"closed":_closed,"scope":_scope.duplicate(true),"world_generation":_world_generation,"area_id":_world_area,"endpoints":_records.size(),"stats":stats.duplicate(),"active_in_production":false}
func close() -> void:
	_closed=true;_revision+=1;_world=null;_records.clear();_scope.clear();_scope_guard=Callable();_association_current=Callable()
