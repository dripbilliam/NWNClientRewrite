extends RefCounted
# Data only. These are exactly the original resource_pool/scene_geometry loops,
# prepared once on asset workers. Raw NWN geometry remains authoritative for
# skin/collision consumers. Main-thread ArrayMesh/Resource publication stays put.
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
const Skins=preload("res://systems/native_data/skin_preparation.gd")
const REVISION:="mesh-upload-v1"
static func configured_enabled() -> bool: return not OS.get_cmdline_user_args().has("--mesh-preparation=main")
static func point(values: PackedFloat32Array,index: int) -> Vector3: return Vector3(values[index*3],values[index*3+2],-values[index*3+1])
static func prepare(data: Dictionary) -> Dictionary:
	var vertices: PackedFloat32Array=data.vertices; var source_indices: PackedInt32Array=data.indices
	if vertices.size()%3!=0 or source_indices.size()%3!=0: return {"error":"Invalid native mesh stream lengths"}
	if vertices.is_empty() or source_indices.is_empty(): return {"error":"","empty":true}
	var count:=vertices.size()/3; var positions:=PackedVector3Array(); var normals:=PackedVector3Array(); var uv:=PackedVector2Array()
	positions.resize(count); normals.resize(count); uv.resize(count)
	var authored_normals: PackedFloat32Array=data.normals; var authored_uv: PackedFloat32Array=data.uv[0] if not data.uv.is_empty() else PackedFloat32Array()
	if not authored_normals.is_empty() and authored_normals.size()!=vertices.size(): return {"error":"Native normal count does not match geometry"}
	if not authored_uv.is_empty() and authored_uv.size()!=count*2: return {"error":"Native UV count does not match geometry"}
	var source_bounds:=AABB(); var pick_bounds:=AABB()
	for vertex in count:
		positions[vertex]=point(vertices,vertex)
		if not authored_normals.is_empty(): normals[vertex]=point(authored_normals,vertex)
		if not authored_uv.is_empty(): uv[vertex]=Vector2(authored_uv[vertex*2],authored_uv[vertex*2+1])
		var p:=Vector3(vertices[vertex*3],vertices[vertex*3+1],vertices[vertex*3+2])
		source_bounds=source_bounds.expand(p) if vertex>0 else AABB(p,Vector3.ZERO)
		pick_bounds=pick_bounds.expand(positions[vertex]) if vertex>0 else AABB(positions[vertex],Vector3.ZERO)
	var indices:=source_indices.duplicate()
	for face in range(0,indices.size(),3):
		var a:=int(source_indices[face]); var b:=int(source_indices[face+1]); var c:=int(source_indices[face+2])
		if mini(a,mini(b,c))<0 or maxi(a,maxi(b,c))>=count: return {"error":"Native triangle exceeds vertices"}
		indices[face+1]=c; indices[face+2]=b
		if authored_normals.is_empty():
			var normal:=(positions[b]-positions[a]).cross(positions[c]-positions[a]); normals[a]+=normal; normals[b]+=normal; normals[c]+=normal
	if authored_normals.is_empty():
		for vertex in count: normals[vertex]=normals[vertex].normalized()
	# Native collision order/planes are independent of optimized draw indices.
	var collision: PackedInt32Array=data.get("collision_indices",source_indices); var planes: PackedFloat32Array=data.get("native_planes",PackedFloat32Array())
	if collision.size()%3!=0: return {"error":"Invalid native collision stream lengths"}
	if planes.is_empty():
		for face in range(0,collision.size(),3):
			var physical: Array=[]
			for corner in 3:
				var index:=int(collision[face+corner])*3
				if index<0 or index>vertices.size()-3: return {"error":"Native collision triangle exceeds vertices"}
				physical.append([vertices[index],vertices[index+1],vertices[index+2]])
			var p:=Polygon.plane(physical); planes.append_array(PackedFloat32Array([p.normal[0],p.normal[1],p.normal[2],p.constant]))
	source_bounds=source_bounds.grow(maxf(1.0,maxf(source_bounds.position.abs().length(),source_bounds.end.abs().length()))*0.000003814697265625)
	return {"error":"","revision":REVISION,"positions":positions,"normals":normals,"uv":uv,"indices":indices,"pick_bounds":pick_bounds,"source_bounds":source_bounds,"planes":planes}
static func model(value: Dictionary,prepare_skins: bool=false) -> Dictionary:
	var began:=Time.get_ticks_usec(); var meshes:=0; var vertices:=0; var faces:=0
	var skins:=0; var skin_vertices:=0; var skin_ms:=0.0; var skin_fallbacks: Array=[]
	for node in value.nodes:
		if node.mesh.is_empty(): continue
		var prepared:=prepare(node.mesh)
		if not str(prepared.error).is_empty(): return {"error":prepared.error,"mesh_ms":(Time.get_ticks_usec()-began)/1000.0}
		if prepared.get("empty",false): continue
		node.mesh.native_upload=prepared; meshes+=1; vertices+=prepared.positions.size(); faces+=prepared.indices.size()/3
		if prepare_skins and node.has("skin") and node.mesh.get("render",false):
			var skin_began:=Time.get_ticks_usec(); var cooked:=Skins.prepare(node); skin_ms+=(Time.get_ticks_usec()-skin_began)/1000.0
			if str(cooked.error).is_empty(): node.skin.native_upload=cooked; skins+=1; skin_vertices+=cooked.positions.size()
			else: skin_fallbacks.append(str(cooked.error)) # Preserve the original runtime validation/failure scope.
	return {"error":"","mesh_ms":(Time.get_ticks_usec()-began)/1000.0,"meshes":meshes,"vertices":vertices,"faces":faces,"skins":skins,"skin_vertices":skin_vertices,"skin_ms":skin_ms,"skin_fallbacks":skin_fallbacks,"thread":OS.get_thread_caller_id()}
