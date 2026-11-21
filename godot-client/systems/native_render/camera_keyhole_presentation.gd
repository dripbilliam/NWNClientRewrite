extends Node
const ShaderState=preload("res://systems/native_render/native_camera_keyhole.gd")
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
const StandardMaterial=preload("res://systems/native_render/standard_keyhole_material.gd")

var terrain
var camera: Camera3D
var controller
var bindings: Dictionary={}
var unsupported:=0
var blocked:=false
var enabled:=false
var closed:=false
var plane:=Vector4(0,0,1,0)
var height:=0.0
var _float32:=PackedFloat32Array([0.0])

func _f32(value: float) -> float:
	_float32[0]=value
	return _float32[0]

func _box_above_plane(minimum: Vector3,maximum: Vector3,near_plane: Vector4) -> float:
	var corner:=Vector3(minimum.x if near_plane.x>0.0 else maximum.x,minimum.y if near_plane.y>0.0 else maximum.y,minimum.z if near_plane.z>0.0 else maximum.z)
	return _f32(_f32(_f32(_f32(corner.x*near_plane.x)+_f32(corner.y*near_plane.y))+_f32(corner.z*near_plane.z))+near_plane.w)

func _camera_plane(camera_native: Vector3,forward_native: Vector3,player_native: Vector3) -> Vector4:
	var delta:=Vector3(_f32(player_native.x-camera_native.x),_f32(player_native.y-camera_native.y),_f32(player_native.z-camera_native.z))
	var squared:=_f32(_f32(_f32(delta.x*delta.x)+_f32(delta.y*delta.y))+_f32(delta.z*delta.z))
	var distance:=_f32(sqrt(squared))
	var normal:=Vector3(_f32(forward_native.x),_f32(forward_native.y),_f32(forward_native.z))
	var dot:=_f32(_f32(_f32(normal.x*camera_native.x)+_f32(normal.y*camera_native.y))+_f32(normal.z*camera_native.z))
	return Vector4(normal.x,normal.y,normal.z,_f32(-dot-distance))

func configure(terrain_owner,camera_owner: Camera3D,controller_owner,catalog=null) -> void:
	terrain=terrain_owner;camera=camera_owner;controller=controller_owner
	if not ShaderState.load_profile(catalog):
		blocked=true
		return
	if is_instance_valid(terrain):
		terrain.tile_published.connect(_tile_published)
		for index in terrain.instances:_tile_published(int(index),terrain.instances[index])

func _tile_published(_index: int,model) -> void:
	if blocked or not is_instance_valid(model) or not model.get("meshes") is Array:return
	for candidate in model.meshes:
		if not candidate is MeshInstance3D or not candidate.has_meta("native_mesh_source") or bindings.has(candidate):continue
		var mesh: MeshInstance3D=candidate
		var original: Material=mesh.material_override
		# The pool shares material resources across tile and non-tile instances.
		# The old Three path cloned each material before adding its shader hook.
		var specialized: Material
		if original is NativeMaterial:
			specialized=original.duplicate()
			specialized.set("native_keyhole_enabled",true)
		elif original is StandardMaterial3D:
			var standard:=StandardMaterial.new()
			if standard.configure(original):specialized=standard
		if specialized==null:
			unsupported+=1
			blocked=true
			_restore_bindings()
			return
		mesh.material_override=specialized
		mesh.set_instance_shader_parameter("nwn_keyhole_can",0)
		bindings[mesh]={"original":original,"specialized":specialized,"can":0}

func ready_for_camera() -> bool:
	# The old update remains enabled with zero eligible tile meshes and does not
	# wait for the entire terrain load or unrelated diagnostics to finish.
	return ShaderState.loaded() and not blocked and unsupported==0 and is_instance_valid(camera) and is_instance_valid(controller) and is_instance_valid(terrain)

func _world_bounds(mesh: MeshInstance3D) -> AABB:
	var bounds: AABB=mesh.global_transform*mesh.get_aabb()
	if mesh.get_child_count()==0 and mesh.skin==null:return bounds
	var pending: Array=mesh.get_children()
	while not pending.is_empty():
		var node: Node=pending.pop_back()
		if node is MeshInstance3D and node.mesh!=null:bounds=bounds.merge(node.global_transform*node.get_aabb())
		pending.append_array(node.get_children())
	return bounds

func update(player: Vector3,active: bool) -> void:
	enabled=active and ready_for_camera()
	if not enabled:
		for mesh in bindings:
			if is_instance_valid(mesh) and int(bindings[mesh].can)!=0:
				mesh.set_instance_shader_parameter("nwn_keyhole_can",0)
				bindings[mesh].can=0
		ShaderState.reset()
		return
	var camera_position: Vector3=camera.global_position
	var forward: Vector3=-camera.global_basis.z
	var native_camera:=Vector3(camera_position.x,-camera_position.z,camera_position.y)
	var native_forward:=Vector3(forward.x,-forward.z,forward.y)
	var native_player:=Vector3(player.x,-player.z,player.y)
	plane=_camera_plane(native_camera,native_forward,native_player)
	height=_f32(native_player.z+1.0)
	var pitch:=float(controller.follow_state.state.pitch) if is_instance_valid(controller) and controller.follow_state!=null else 50.0
	var distance:=float(controller.follow_state.state.distance) if is_instance_valid(controller) and controller.follow_state!=null else 20.0
	# Renderer.getDrawingBufferSize reads physical render pixels, not the UI
	# viewport's logical rectangle. The keyhole uses pixel coordinates in its
	# fragment stage, so publish the viewport texture's actual buffer size.
	var viewport_size:=camera.get_viewport().get_texture().get_size()
	ShaderState.publish(Vector2(maxf(1.0,viewport_size.x),maxf(1.0,viewport_size.y)),pitch,distance,native_player)
	for mesh in bindings.keys():
		if not is_instance_valid(mesh):bindings.erase(mesh);continue
		var value:=0
		if mesh.is_visible_in_tree() and mesh.mesh!=null:
			var bounds: AABB=_world_bounds(mesh)
			var minimum:=Vector3(bounds.position.x,-bounds.end.z,bounds.position.y)
			var maximum:=Vector3(bounds.end.x,-bounds.position.z,bounds.end.y)
			if height<maximum.z and _box_above_plane(minimum,maximum,plane)<0.0:value=1
		if int(bindings[mesh].can)!=value:
			mesh.set_instance_shader_parameter("nwn_keyhole_can",value)
			bindings[mesh].can=value

func snapshot() -> Dictionary:
	var eligible:=0
	for row in bindings.values():eligible+=int(row.can)
	return {"loaded":ShaderState.loaded(),"enabled":enabled,"meshes":bindings.size(),"unsupported":unsupported,"eligible":eligible,"plane":[plane.x,plane.y,plane.z,plane.w],"height":height,"shader":ShaderState.snapshot(),"source":ShaderState.profile_snapshot()}

func close() -> void:
	if closed:return
	closed=true
	if is_instance_valid(terrain) and terrain.tile_published.is_connected(_tile_published):terrain.tile_published.disconnect(_tile_published)
	_restore_bindings()
	unsupported=0;blocked=false;enabled=false
	ShaderState.reset()

func _restore_bindings() -> void:
	for mesh in bindings:
		if not is_instance_valid(mesh):continue
		var record: Dictionary=bindings[mesh]
		if mesh.material_override==record.specialized:mesh.material_override=record.original
		mesh.set_instance_shader_parameter("nwn_keyhole_can",0)
	bindings.clear()

func _exit_tree() -> void:close()
