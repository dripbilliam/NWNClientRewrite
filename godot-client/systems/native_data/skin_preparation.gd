extends RefCounted
# Exact data derivatives of ActorInstance.skin_source and ModelRigs._skin.
# Original geometry/weights remain untouched. Runtime skeleton/bind validation
# and every rendering-resource API stay on the presentation thread.
const REVISION:="skin-upload-v1"
static func configured_enabled() -> bool: return not OS.get_cmdline_user_args().has("--skin-preparation=main")
static func point(values: PackedFloat32Array,index: int) -> Vector3: return Vector3(values[index*3],values[index*3+2],-values[index*3+1])
static func prepare(row: Dictionary) -> Dictionary:
	var data: Dictionary=row.mesh; var skin: Dictionary=row.skin
	var vertices: PackedFloat32Array=data.vertices; var faces: PackedInt32Array=data.indices
	var authored: PackedFloat32Array=data.normals; var texcoords: PackedFloat32Array=data.uv[0] if not data.uv.is_empty() else PackedFloat32Array()
	var original_weights: PackedFloat32Array=skin.weights; var original_bones: PackedInt32Array=skin.boneIndices
	if vertices.size()%3!=0 or faces.size()%3!=0: return {"error":"Invalid native skin geometry stream lengths"}
	var vertex_count:=vertices.size()/3
	if original_weights.size()!=vertex_count*4 or original_bones.size()!=vertex_count*4: return {"error":"Invalid native skin influence stream lengths"}
	if not authored.is_empty() and authored.size()!=vertices.size(): return {"error":"Invalid native skin normal stream length"}
	if not texcoords.is_empty() and texcoords.size()!=vertex_count*2: return {"error":"Invalid native skin UV stream length"}
	var count:=faces.size(); var positions:=PackedVector3Array(); var normals:=PackedVector3Array(); var uv:=PackedVector2Array()
	var source_weights:=PackedFloat32Array(); var source_bones:=PackedInt32Array(); var weights:=PackedFloat32Array(); var bones:=PackedInt32Array(); var used: Dictionary={}; var invalid:=false
	positions.resize(count); normals.resize(count); uv.resize(count); source_weights.resize(count*4); source_bones.resize(count*4); weights.resize(count*4); bones.resize(count*4)
	var cursor:=0
	for face in range(0,count,3):
		var a:=int(faces[face]); var b:=int(faces[face+1]); var c:=int(faces[face+2])
		if mini(a,mini(b,c))<0 or maxi(a,maxi(b,c))>=vertex_count: return {"error":"Native skin triangle exceeds vertices"}
		# The existing skin route uses one flat face normal when absent. Do not
		# substitute the accumulated smooth normal of static-mesh preparation.
		var normal:=(point(vertices,b)-point(vertices,a)).cross(point(vertices,c)-point(vertices,a)).normalized()
		for corner in [0,2,1]:
			var index:=int(faces[face+corner]); positions[cursor]=point(vertices,index); normals[cursor]=point(authored,index) if not authored.is_empty() else normal
			if not texcoords.is_empty(): uv[cursor]=Vector2(texcoords[index*2],texcoords[index*2+1])
			var total:=0.0
			for component in 4: total+=maxf(0,float(original_weights[index*4+component]))
			for component in 4:
				var from:=index*4+component; var to:=cursor*4+component; var weight:=maxf(0,float(original_weights[from])); var bone:=int(original_bones[from])
				source_weights[to]=original_weights[from]; source_bones[to]=bone
				if weight>1.0 or weight>0.0 and (bone<0 or bone>=64): invalid=true
				if weight>0.0 and bone>=0 and bone<64: used[bone]=true
				bones[to]=64 if total==0.0 or weight==0.0 else bone
				weights[to]=(1.0 if component==0 else 0.0) if total==0.0 else weight
			cursor+=1
	var slots:=PackedInt32Array()
	for slot in used: slots.append(int(slot))
	# Flat views retain the old skin-source interface without boxed float Arrays.
	return {"error":"","revision":REVISION,"positions":positions,"normals":normals,"uv":uv,"weights":weights,"bones":bones,"used_slots":slots,"invalid_weights":invalid,"position":positions.to_byte_array().to_float32_array(),"normal":normals.to_byte_array().to_float32_array(),"source_uv":uv.to_byte_array().to_float32_array(),"source_weights":source_weights,"source_bones":source_bones}
