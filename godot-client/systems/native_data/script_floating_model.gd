extends RefCounted
# The actual pnl_floatytext supplies attachment transforms, not a fabricated
# text rectangle. Stock has three dummies and no mesh. Unsupported custom
# 3D text-plane rotations or visible geometry remain explicit.
static func finite_array(value: Variant,count: int) -> bool:
	if not value is Array or value.size()!=count:return false
	for scalar in value:
		if not (scalar is int or scalar is float) or not is_finite(float(scalar)):return false
	return true
static func parse(model: Dictionary) -> Dictionary:
	var nodes: Variant=model.get("nodes")
	if not nodes is Array or nodes.is_empty():return {"ready":false,"reason":"Native floaty attachment model is unavailable."}
	var poses: Array[Transform3D]=[];var hooks: Dictionary={}
	for index in nodes.size():
		var node: Variant=nodes[index]
		if not node is Dictionary or not finite_array(node.get("position"),3) or not finite_array(node.get("orientation"),4):return {"ready":false,"reason":"Native floaty hook transform is unavailable."}
		var parent: Variant=node.get("parent");var scale: Variant=node.get("scale",1.0)
		if not parent is int or parent< -1 or parent>=index or not (scale is int or scale is float) or not is_finite(float(scale)):return {"ready":false,"reason":"Native floaty model hierarchy is invalid."}
		var p: Array=node.position;var q: Array=node.orientation;var rotation:=Quaternion(q[0],q[1],q[2],q[3])
		if rotation.length_squared()==0:return {"ready":false,"reason":"Native floaty model rotation is invalid."}
		var pose:=Transform3D(Basis(rotation.normalized()).scaled(Vector3.ONE*float(scale)),Vector3(p[0],p[1],p[2]))
		if int(parent)>=0:pose=poses[int(parent)]*pose
		poses.append(pose)
		var mesh: Variant=node.get("mesh",{})
		if mesh is Dictionary and mesh.get("render",false) and not mesh.get("vertices",PackedFloat32Array()).is_empty():return {"ready":false,"reason":"A custom floaty model with visible geometry is not supported by this passive text view."}
		var name:=str(node.get("name","")).to_lower()
		if name in ["foreground","background"] and not hooks.has(name):
			if absf(pose.basis.x.z)>0.000001 or absf(pose.basis.y.z)>0.000001:return {"ready":false,"reason":"A custom floaty 3D text-plane rotation is unavailable."}
			hooks[name]={"pose":pose,"offset":Vector2(pose.origin.x,-pose.origin.y)*100.0,"depth":pose.origin.z,"transform":Transform2D(Vector2(pose.basis.x.x,-pose.basis.x.y),Vector2(-pose.basis.y.x,pose.basis.y.y),Vector2(pose.origin.x,-pose.origin.y)*100.0)}
	if not hooks.has_all(["foreground","background"]):return {"ready":false,"reason":"Native floaty Foreground/Background hooks are unavailable."}
	return {"ready":true,"resource":"pnl_floatytext","hooks":hooks,"font":"ttf fnt_maintext 17","shadow":false,"softWidthGui":1000000.0,"maximumLines":1048576,"alignment":Vector2(0.5,1.0)}
