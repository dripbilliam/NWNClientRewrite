extends RefCounted
# Data only. These are exactly the original resource_pool/scene_geometry loops,
# prepared once on asset workers. Raw NWN geometry remains authoritative for
# skin/collision consumers. Main-thread ArrayMesh/Resource publication stays put.
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
const Skins=preload("res://systems/native_data/skin_preparation.gd")
const Orientation=preload("res://systems/native_data/model_orientation.gd")
const REVISION:="mesh-upload-v3-face-corners"
static func colors(bytes: PackedByteArray,count: int) -> PackedColorArray:
	var result:=PackedColorArray()
	if bytes.is_empty() or bytes.size()!=count*4: return result
	result.resize(count)
	for index in count:
		var at:=index*4; result[index]=Color(bytes[at]/255.0,bytes[at+1]/255.0,bytes[at+2]/255.0,bytes[at+3]/255.0)
	return result
static func configured_enabled() -> bool: return not OS.get_cmdline_user_args().has("--mesh-preparation=main")
static func point(values: PackedFloat32Array,index: int) -> Vector3: return Vector3(values[index*3],values[index*3+2],-values[index*3+1])
static func initial_skin(model: Dictionary,node_index: int) -> Dictionary:
	# buildObject obtains a deformed indexed vertex array before making a tile's
	# first mesh. Actors instead use ModelRigs' per-pose CPU publisher.
	if node_index<0 or node_index>=model.get("nodes",[]).size():return {"error":"Native tile skin node is unavailable"}
	var nodes: Array=model.nodes; var row: Dictionary=nodes[node_index]
	if not row.has("skin"):return {"error":"","vertices":PackedVector3Array()}
	var source: Dictionary=row.mesh; var skin: Dictionary=row.skin
	var vertices: PackedFloat32Array=source.get("vertices",PackedFloat32Array())
	var weights: PackedFloat32Array=skin.get("weights",PackedFloat32Array())
	var indices: PackedInt32Array=skin.get("boneIndices",PackedInt32Array())
	var count:=int(vertices.size()/3)
	if vertices.size()%3!=0 or weights.size()!=count*4 or indices.size()!=count*4:return {"error":"Native tile skin source streams are invalid"}
	var basis:=Quaternion(Vector3.RIGHT,-PI/2); var rigid: Array[Transform3D]=[]
	for part in nodes.size():
		var bone: Dictionary=nodes[part]; var parent:=int(bone.get("parentIndex",bone.get("parent",-1)))
		if parent>=part or parent< -1:return {"error":"Native tile skin hierarchy is invalid"}
		var decoded: Array=Orientation.decode(bone.get("orientation"),str(bone.get("orientationFormat","quaternion")))
		var rotation:=basis*Quaternion(decoded[0],decoded[1],decoded[2],decoded[3])*basis.inverse()
		var position: Array=bone.get("position",[0.0,0.0,0.0])
		if position.size()<3:return {"error":"Native tile skin Part position is unavailable"}
		var local:=Transform3D(Basis(rotation),Vector3(float(position[0]),float(position[2]),-float(position[1])))
		rigid.append(local if parent<0 else rigid[parent]*local)
	var inverse_skin:=rigid[node_index].affine_inverse()
	var slots: Variant=skin.get("boneConstantSlots",PackedInt32Array())
	var inverse_positions: Array=skin.get("tboneRefInv",[])
	var inverse_quaternions: Array=skin.get("qboneRefInv",[])
	# Empty but present inverse arrays are still the binary path in JS; a
	# weighted bone then fails instead of silently falling back to identity.
	var binary_bind:=skin.has("tboneRefInv") and skin.has("qboneRefInv")
	var transforms: Array=[];var accumulated: Dictionary={};var root_seen:=false
	for slot in mini(64,slots.size()):
		var part:=int(slots[slot]);var transform: Variant=null
		if part>=0 and part<nodes.size():
			if part==0:
				if root_seen:break
				root_seen=true
			var pose: Transform3D=accumulated.get(part,inverse_skin*rigid[part])
			if binary_bind:
				if part>=inverse_positions.size() or part>=inverse_quaternions.size():return {"error":"Native tile skin inverse bind is unavailable"}
				var p: Array=inverse_positions[part];var q: Array=inverse_quaternions[part]
				if p.size()<3 or q.size()<4:return {"error":"Native tile skin inverse bind is invalid"}
				var bind:=Transform3D(Basis(Quaternion(float(q[1]),float(q[3]),-float(q[2]),float(q[0]))),Vector3(float(p[0]),float(p[2]),-float(p[1])))
				pose=pose*bind;accumulated[part]=pose
			transform=pose
		transforms.append(transform)
	var deformed:=PackedVector3Array();deformed.resize(count)
	for vertex in count:
		var original:=point(vertices,vertex);var output:=Vector3.ZERO;var weighted:=false
		for component in 4:
			var at:=vertex*4+component;var weight:=float(weights[at])
			if weight<=0.0:continue
			var slot:=int(indices[at])
			if slot<0 or slot>=transforms.size() or transforms[slot]==null:return {"error":"Native weighted tile skin slot is unavailable"}
			var transformed_point: Vector3=transforms[slot]*original
			output+=transformed_point*weight;weighted=true
		deformed[vertex]=output if weighted else original
	return {"error":"","vertices":deformed}
static func prepare(data: Dictionary,transformed: PackedVector3Array=PackedVector3Array()) -> Dictionary:
	var vertices: PackedFloat32Array=data.vertices; var source_indices: PackedInt32Array=data.indices
	if vertices.size()%3!=0 or source_indices.size()%3!=0: return {"error":"Invalid native mesh stream lengths"}
	if vertices.is_empty() or source_indices.is_empty(): return {"error":"","empty":true}
	var count:=vertices.size()/3; var positions:=PackedVector3Array(); var normals:=PackedVector3Array(); var uv:=PackedVector2Array()
	if not transformed.is_empty() and transformed.size()!=count:return {"error":"Native tile skin vertex count differs from source mesh"}
	var hit_vertices:=PackedFloat32Array()
	if not transformed.is_empty():hit_vertices.resize(vertices.size())
	var authored_colors: PackedByteArray=data.get("vertex_colors",PackedByteArray())
	if not authored_colors.is_empty() and authored_colors.size()!=count*4: return {"error":"Native vertex color count does not match geometry"}
	positions.resize(count); normals.resize(count); uv.resize(count)
	var authored_normals: PackedFloat32Array=data.normals; var authored_uv: PackedFloat32Array=data.uv[0] if not data.uv.is_empty() else PackedFloat32Array()
	if not authored_normals.is_empty() and authored_normals.size()!=vertices.size(): return {"error":"Native normal count does not match geometry"}
	if not authored_uv.is_empty() and authored_uv.size()!=count*2: return {"error":"Native UV count does not match geometry"}
	var source_bounds:=AABB(); var pick_bounds:=AABB()
	for vertex in count:
		positions[vertex]=transformed[vertex] if not transformed.is_empty() else point(vertices,vertex)
		if not authored_normals.is_empty(): normals[vertex]=point(authored_normals,vertex)
		if not authored_uv.is_empty(): uv[vertex]=Vector2(authored_uv[vertex*2],authored_uv[vertex*2+1])
		var p:=Vector3(positions[vertex].x,-positions[vertex].z,positions[vertex].y) if not transformed.is_empty() else Vector3(vertices[vertex*3],vertices[vertex*3+1],vertices[vertex*3+2])
		if not transformed.is_empty():hit_vertices[vertex*3]=p.x;hit_vertices[vertex*3+1]=p.y;hit_vertices[vertex*3+2]=p.z
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
	# buildModelGeometry expands every draw corner, then computes a separate
	# normal for each face. Keep the indexed source stream above for collision and
	# other native consumers; only the renderer receives this old draw shape.
	var draw_positions:=PackedVector3Array(); var draw_normals:=PackedVector3Array(); var draw_uv:=PackedVector2Array(); var draw_colors:=PackedColorArray()
	var source_colors:=colors(authored_colors,count)
	for face in range(0,source_indices.size(),3):
		var a:=int(source_indices[face]); var b:=int(source_indices[face+1]); var c:=int(source_indices[face+2])
		var flat: Vector3=(positions[b]-positions[a]).cross(positions[c]-positions[a]).normalized()
		# Godot draws clockwise faces; the old Three geometry was ordered a,b,c.
		for corner in [a,c,b]:
			draw_positions.append(positions[corner]);draw_normals.append(flat);draw_uv.append(uv[corner])
			if not source_colors.is_empty():draw_colors.append(source_colors[corner])
	# Native collision order/planes are independent of optimized draw indices.
	var collision: PackedInt32Array=data.get("collision_indices",source_indices); var planes: PackedFloat32Array=PackedFloat32Array() if not transformed.is_empty() else data.get("native_planes",PackedFloat32Array())
	if collision.size()%3!=0: return {"error":"Invalid native collision stream lengths"}
	if planes.is_empty():
		for face in range(0,collision.size(),3):
			var physical: Array=[]
			for corner in 3:
				var index:=int(collision[face+corner])*3
				var hit_source: PackedFloat32Array=hit_vertices if not transformed.is_empty() else vertices
				if index<0 or index>hit_source.size()-3: return {"error":"Native collision triangle exceeds vertices"}
				physical.append([hit_source[index],hit_source[index+1],hit_source[index+2]])
			var p:=Polygon.plane(physical); planes.append_array(PackedFloat32Array([p.normal[0],p.normal[1],p.normal[2],p.constant]))
	source_bounds=source_bounds.grow(maxf(1.0,maxf(source_bounds.position.abs().length(),source_bounds.end.abs().length()))*0.000003814697265625)
	return {"error":"","revision":REVISION,"positions":positions,"normals":normals,"uv":uv,"colors":source_colors,"indices":indices,"draw_positions":draw_positions,"draw_normals":draw_normals,"draw_uv":draw_uv,"draw_colors":draw_colors,"pick_bounds":pick_bounds,"source_bounds":source_bounds,"planes":planes,"hit_vertices":hit_vertices}
static func model(value: Dictionary,prepare_skins: bool=false) -> Dictionary:
	var began:=Time.get_ticks_usec(); var meshes:=0; var vertices:=0; var faces:=0
	for deferred in value.get("deferredGeometryErrors",[]):
		if deferred.get("renderRequested",false):return {"error":str(deferred.reason)+" in "+str(deferred.name),"mesh_ms":(Time.get_ticks_usec()-began)/1000.0}
	var worker_meshes:=0;var worker_vertices:=0
	var skins:=0; var skin_vertices:=0; var skin_ms:=0.0; var skin_fallbacks: Array=[]
	for node in value.nodes:
		if node.mesh.is_empty(): continue
		var prepared:=prepare(node.mesh)
		if not str(prepared.error).is_empty(): return {"error":prepared.error,"mesh_ms":(Time.get_ticks_usec()-began)/1000.0}
		if prepared.get("empty",false): continue
		node.mesh.native_upload=prepared; meshes+=1; vertices+=prepared.positions.size(); faces+=prepared.indices.size()/3
		# The old dedicated model worker recorded only visible, unskinned
		# trimeshes. Keep Godot's additional collision/skin preparation for its
		# existing consumers, while preserving that worker receipt separately.
		var features: Array=node.get("features",[])
		if node.mesh.get("render",false) and not node.has("skin") and not features.has("skin") and not features.has("aabb") and not features.has("animated-mesh"):
			worker_meshes+=1;worker_vertices+=prepared.indices.size()
		if prepare_skins and node.has("skin") and node.mesh.get("render",false):
			var skin_began:=Time.get_ticks_usec(); var cooked:=Skins.prepare(node); skin_ms+=(Time.get_ticks_usec()-skin_began)/1000.0
			if str(cooked.error).is_empty(): node.skin.native_upload=cooked; skins+=1; skin_vertices+=cooked.positions.size()
			else: skin_fallbacks.append(str(cooked.error)) # Preserve the original runtime validation/failure scope.
	return {"error":"","mesh_ms":(Time.get_ticks_usec()-began)/1000.0,"meshes":meshes,"vertices":vertices,"faces":faces,"skins":skins,"skin_vertices":skin_vertices,"skin_ms":skin_ms,"skin_fallbacks":skin_fallbacks,"old_worker_geometry":{"meshes":worker_meshes,"vertices":worker_vertices,"bytes":worker_vertices*32},"thread":OS.get_thread_caller_id()}
