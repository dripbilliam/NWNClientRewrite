extends RefCounted
# One original GUI quad with original indices/UVs, including animated transforms
# and back-face hiding. No axis-alignment assumption or rendered-image rotation.
const Pose=preload("res://systems/native_data/gui_pose.gd")
static func sample(model: Dictionary,clip: String,time: float) -> Dictionary:
	var posed:=Pose.nodes(model,[{"clip":clip,"time":time}])
	if not str(posed.error).is_empty(): return posed
	var transforms: Array[Transform3D]=[]; var output: Dictionary={"error":"","faces":[],"resource":""}
	for node in posed.model.get("nodes",[]):
		var p: Array=node.get("position",[]); var q: Array=node.get("orientation",[]); var parent:=int(node.get("parent",-1))
		if p.size()!=3 or q.size()!=4 or parent < -1 or parent>=transforms.size(): return {"error":"Invalid original GUI quad hierarchy"}
		var pose:=Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3]).normalized()).scaled(Vector3.ONE*float(node.get("scale",1))),Vector3(p[0],p[1],p[2]))
		if parent>=0: pose=transforms[parent]*pose
		transforms.append(pose)
		var mesh: Dictionary=node.get("mesh",{})
		if not mesh.get("render",false): continue
		var xyz: PackedFloat32Array=mesh.get("vertices",PackedFloat32Array()); var indices: PackedInt32Array=mesh.get("indices",PackedInt32Array()); var uv: Array=mesh.get("uv",[]); var textures: Array=mesh.get("textures",[])
		if not str(output.resource).is_empty() or xyz.size()!=12 or indices.size()!=6 or uv.size()!=1 or uv[0].size()!=8 or textures.size()!=1: return {"error":"Original GUI quad topology/material is unsupported"}
		output.resource=str(textures[0]); var points:=PackedVector2Array(); var texcoords:=PackedVector2Array()
		for index in 4:
			var point:=pose*Vector3(xyz[index*3],xyz[index*3+1],xyz[index*3+2])
			if not point.is_finite(): return {"error":"Non-finite original GUI quad pose"}
			points.append(Vector2(point.x,-point.y)*100.0); texcoords.append(Vector2(uv[0][index*2],uv[0][index*2+1]))
		for at in [0,3]:
			var face:=PackedVector2Array(); var tex:=PackedVector2Array()
			for index in 3:
				var vertex:=int(indices[at+index])
				if vertex<0 or vertex>=4: return {"error":"Original GUI quad index is out of range"}
				face.append(points[vertex]); tex.append(texcoords[vertex])
			# Source GUI front faces point toward+Z; projecting-Y reverses winding.
			if (face[1]-face[0]).cross(face[2]-face[0])<0: output.faces.append({"vertices":face,"uv":tex})
	return output if not str(output.resource).is_empty() else {"error":"Original GUI quad is missing"}
