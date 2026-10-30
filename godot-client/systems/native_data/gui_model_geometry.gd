extends RefCounted
# Shared original GUI-model bounds and hooks; no equipment or menu policy.
static func model(value: Dictionary) -> Dictionary:
	var poses: Array[Transform3D]=[]; var hooks: Dictionary={}; var bounds:=Rect2(); var drawn:=false
	for node in value.get("nodes",[]):
		var p: Array=node.get("position",[]); var q: Array=node.get("orientation",[]); var parent:=int(node.get("parent",-1)); var scale:=float(node.get("scale",1))
		if p.size()!=3 or q.size()!=4 or parent < -1 or parent>=poses.size() or not is_finite(scale): return {"error":"Invalid original GUI model hierarchy"}
		var position:=Vector3(p[0],p[1],p[2]); var rotation:=Quaternion(q[0],q[1],q[2],q[3])
		if not position.is_finite() or not rotation.is_finite() or rotation.length_squared()<0.000001: return {"error":"Invalid original GUI model transform"}
		var pose:=Transform3D(Basis(rotation.normalized()).scaled(Vector3.ONE*scale),position)
		if parent>=0: pose=poses[parent]*pose
		poses.append(pose)
		var name:=str(node.get("name","")).to_lower()
		if hooks.has(name): return {"error":"Ambiguous original GUI model hook"}
		hooks[name]=Vector2(pose.origin.x,-pose.origin.y)*100.0
		var mesh: Dictionary=node.get("mesh",{})
		if not mesh.get("render",false): continue
		var vertices: PackedFloat32Array=mesh.get("vertices",PackedFloat32Array())
		if vertices.size()%3!=0: return {"error":"Invalid original GUI model vertices"}
		for at in range(0,vertices.size(),3):
			var point: Vector3=pose*Vector3(vertices[at],vertices[at+1],vertices[at+2])
			if not point.is_finite(): return {"error":"Non-finite original GUI model bounds"}
			var screen:=Vector2(point.x,-point.y)*100.0
			bounds=bounds.expand(screen) if drawn else Rect2(screen,Vector2.ZERO); drawn=true
	return {"error":"","bounds":bounds,"hooks":hooks,"drawn":drawn}
