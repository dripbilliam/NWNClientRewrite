extends RefCounted
# Read-only camera evidence. A reparented camera's local pose is not its view.
static func pose(camera: Camera3D) -> Dictionary:
	if not is_instance_valid(camera): return {}
	var transform:=camera.global_transform
	var rotation:=transform.basis.get_rotation_quaternion()
	return {"pose_space":"world","pose_valid":true,"position":[transform.origin.x,transform.origin.y,transform.origin.z],"quaternion":[rotation.x,rotation.y,rotation.z,rotation.w],"fov_degrees":camera.fov,"projection":camera.projection,"keep_aspect":camera.keep_aspect,"near":camera.near,"far":camera.far}
static func capture_view(camera: Camera3D,controller: Variant,defaults: Dictionary) -> Dictionary:
	var result:=defaults.duplicate(true)
	var actual:=pose(camera)
	if actual.is_empty(): return result
	actual.fov=actual.fov_degrees
	actual.camera_state=controller.remembered_pose() if is_instance_valid(controller) else {}
	result.merge(actual,true)
	return result
