extends RefCounted
const M=preload("res://systems/native_render/particle_math.gd")
# Original CNWCCreature::LoadModel803347 and world popup766ea0.
# Model-local hook height is fixed at installation, independent of animation,
# weapons, wings, robes and the rendered mesh's expanding bounding box.
static func height_for_head(found: bool,height: float) -> float:
	if not found: return M.f(2.1)
	height=M.f(height)
	return M.f(height-M.f(M.f(height*M.f(0.3))/M.f(2.4)))
static func model_height(model: Dictionary) -> float:
	var nodes: Array=model.get("nodes",[]); var defaults: Array=model.get("rig_asset",{}).get("defaults",[])
	if defaults.size()!=nodes.size(): return height_for_head(false,0)
	var poses: Array[Transform3D]=[]
	for index in nodes.size():
		var node: Dictionary=nodes[index]; var rest: Dictionary=defaults[index]; var parent:=int(node.parent)
		if parent< -1 or parent>=poses.size(): return height_for_head(false,0)
		var p: Array=rest.position; var q: Array=rest.quaternion; var s: Array=rest.scale
		var pose:=Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3])).scaled(Vector3(s[0],s[1],s[2])),Vector3(p[0],p[1],p[2]))
		if parent>=0: pose=poses[parent]*pose
		poses.append(pose)
		if str(node.name).to_lower()=="headconjure": return height_for_head(true,pose.origin.y)
	return height_for_head(false,0)
static func lift(point: Vector3,camera: Vector3) -> Vector3:
	var delta:=camera-point
	# Preserve original Z-up vector magnitude accumulation order after conversion.
	var square:=M.f(M.f(M.f(delta.x*delta.x)+M.f(delta.z*delta.z))+M.f(delta.y*delta.y))
	var distance:=M.f(sqrt(square))
	point.y=M.f(M.f(M.f(M.f(distance-M.f(6.06218))*M.f(0.2))/M.f(9.5))+point.y)
	return point
static func screen(point: Vector2) -> Vector2:
	# Original CVTTSS2SI after +0.5, rather than floor for negative coordinates.
	return Vector2(M.cvtt(M.f(point.x+0.5)),M.cvtt(M.f(point.y+0.5)))
