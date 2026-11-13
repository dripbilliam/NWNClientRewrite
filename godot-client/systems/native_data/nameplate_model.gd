extends RefCounted
# Static original popup meshes in GUI pixels. Preserve the authored triangles,
# UVs, transforms and depth order; neither a stretched raster nor a new frame.
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
static func parse(model: Dictionary) -> Dictionary:
	var geometry:=Geometry.model(model)
	if not str(geometry.error).is_empty(): return geometry
	var poses: Array[Transform3D]=[]; var parts: Array=[]
	for node in model.get("nodes",[]):
		var p: Array=node.position; var q: Array=node.orientation; var parent:=int(node.parent)
		var pose:=Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3]).normalized()).scaled(Vector3.ONE*float(node.get("scale",1))),Vector3(p[0],p[1],p[2]))
		if parent>=0: pose=poses[parent]*pose
		poses.append(pose)
		var mesh: Dictionary=node.get("mesh",{})
		if not mesh.get("render",false): continue
		var xyz: PackedFloat32Array=mesh.get("vertices",PackedFloat32Array()); var indices: PackedInt32Array=mesh.get("indices",PackedInt32Array()); var uv: Array=mesh.get("uv",[])
		if xyz.is_empty() or xyz.size()%3!=0 or indices.is_empty() or indices.size()%3!=0 or uv.size()!=1 or uv[0].size()!=xyz.size()/3*2 or mesh.get("textures",[]).size()!=1: return {"error":"Unsupported original popup mesh topology or texture layers"}
		var points:=PackedVector2Array(); var coords:=PackedVector2Array(); var depth:=0.0; var bounds:=Rect2()
		for index in xyz.size()/3:
			var point:=pose*Vector3(xyz[index*3],xyz[index*3+1],xyz[index*3+2]); var tex:=Vector2(uv[0][index*2],uv[0][index*2+1])
			if not point.is_finite() or not tex.is_finite(): return {"error":"Non-finite original popup geometry"}
			var screen:=Vector2(point.x,-point.y)*100.0
			bounds=bounds.expand(screen) if index>0 else Rect2(screen,Vector2.ZERO)
			points.append(screen); coords.append(tex); depth+=point.z
		var faces: Array=[]
		for start in range(0,indices.size(),3):
			var vertices:=PackedVector2Array(); var tex:=PackedVector2Array()
			for index in 3:
				var at:=int(indices[start+index])
				if at<0 or at>=points.size(): return {"error":"Original popup triangle index is invalid"}
				vertices.append(points[at]); tex.append(coords[at])
			if (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0])<0: faces.append({"vertices":vertices,"uv":tex})
		parts.append({"id":str(node.name).to_lower(),"resource":str(mesh.textures[0]).to_lower(),"alpha":float(node.get("alpha",1)),"depth":depth/points.size(),"bounds":bounds,"faces":faces})
	parts.sort_custom(func(a,b):return float(a.depth)<float(b.depth))
	return {"error":"","bounds":geometry.bounds,"hooks":geometry.hooks,"parts":parts}
