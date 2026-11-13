extends RefCounted
# Cold benchmark boundary only. Never called by an ordinary frame callback.
# The existing quaternion/position witness remains the comparison authority;
# these raw words additionally allow a future exact stationary view input.
static func transform_words(value: Transform3D) -> String:
	var words:=PackedFloat32Array([
		value.basis.x.x,value.basis.x.y,value.basis.x.z,
		value.basis.y.x,value.basis.y.y,value.basis.y.z,
		value.basis.z.x,value.basis.z.y,value.basis.z.z,
		value.origin.x,value.origin.y,value.origin.z])
	var bytes:=PackedByteArray();bytes.resize(48)
	for index in 12:bytes.encode_float(index*4,words[index])
	return bytes.hex_encode()

static func capture(camera: Camera3D,controller,world,connection: Variant) -> Dictionary:
	if not is_instance_valid(camera):return {"available":false,"reason":"camera unavailable"}
	if not camera.is_inside_tree():return {"available":false,"reason":"camera outside tree"}
	var view:=camera.global_transform
	if not view.is_finite():return {"available":false,"reason":"camera transform nonfinite"}
	var result:={"available":true,"format":"basis-columns-origin-f32le-v1","transform_hex":transform_words(view),
		"projection":{"mode":camera.projection,"fov":camera.fov,"near":camera.near,"far":camera.far,"size":camera.size,
			"keep_aspect":camera.keep_aspect,"h_offset":camera.h_offset,"v_offset":camera.v_offset,
			"frustum_offset":[camera.frustum_offset.x,camera.frustum_offset.y],"cull_mask":camera.cull_mask}}
	# All returned values are detached scalars/arrays/dictionaries. Live instance
	# IDs are within-run witnesses, never cross-run lookup instructions.
	if is_instance_valid(world):
		result.scope={"connection":connection,"generation":world.generation,"area_id":world.area_id,"controlled_id":world.controlled_id,"world_instance":world.get_instance_id()}
		if world.instances.has(world.controlled_id) and is_instance_valid(world.instances[world.controlled_id]):
			var actor=world.instances[world.controlled_id]
			result.controlled={"instance":actor.get_instance_id(),"position":[actor.position.x,actor.position.y,actor.position.z]}
	if is_instance_valid(controller) and controller.follow_state!=null:
		var state: Dictionary=controller.follow_state.state
		result.follow={"controller_instance":controller.get_instance_id(),"mode":state.get("mode"),"yaw":state.get("yaw"),"pitch":state.get("pitch"),"distance":state.get("distance"),"height":state.get("height"),"offset":state.get("offset",[]).duplicate(),"dragging":controller.dragging,"queued_keys":not controller.camera_keys.is_empty()}
	return result
