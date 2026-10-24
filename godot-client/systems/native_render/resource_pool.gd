extends RefCounted
# Native GPU resources shared by content identity, not scene instances.
const Cache = preload("res://systems/native_data/prepared_cache.gd")
var failure := ""
var meshes: Dictionary = {}
var textures: Dictionary = {}
var materials: Dictionary = {}
var unshaded := false
var texture_filter := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
var stats := {"meshes_created":0,"textures_created":0,"materials_created":0,"mesh_hits":0,"texture_hits":0,"material_hits":0,"native_decompressions":0}
func main_thread() -> bool:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): failure = "Native render resources must be published on the main thread"; return false
	return true
static func point(values: PackedFloat32Array, index: int) -> Vector3:
	return Vector3(values[index*3], values[index*3+2], -values[index*3+1])
func texture(record: Dictionary) -> Texture2D:
	if not main_thread(): return null
	var key := str(record.sha256)
	if textures.has(key): stats.texture_hits += 1; return textures[key]
	var data: Dictionary = record.value; var mips: Array = data.mips
	if mips.is_empty(): failure = "Native raster has no image levels"; return null
	var width := int(data.width); var height := int(data.height)
	var image_format: int = {"rgba8":Image.FORMAT_RGBA8,"dxt1_rgb":Image.FORMAT_DXT1,"dxt1_rgba":Image.FORMAT_DXT1,"dxt3":Image.FORMAT_DXT3,"dxt5":Image.FORMAT_DXT5,"etc1":Image.FORMAT_ETC,"bc6h_signed":Image.FORMAT_BPTC_RGBF,"bc6h_unsigned":Image.FORMAT_BPTC_RGBFU}.get(data.format,-1)
	if image_format < 0: failure = "Native upload format is unavailable"; return null
	if mips.size() > 1 and (int(mips.back().width) != 1 or int(mips.back().height) != 1): failure = "Partial native mip chain needs completion before upload"; return null
	var bytes := PackedByteArray()
	for mip in mips: bytes.append_array(mip.data)
	var image := Image.create_from_data(width,height,mips.size()>1,image_format,bytes)
	if image == null or image.is_empty(): failure = "Native image construction failed"; return null
	# Native desktop fallback avoids an unsupported compressed-format readback.
	if image_format == Image.FORMAT_ETC:
		if image.decompress() != OK: failure = "Native ETC decompression failed"; return null
		stats.native_decompressions += 1
	if bool(data.get("generate_mips",false)) and image.generate_mipmaps() != OK: failure = "Native mip generation failed"; return null
	var result := ImageTexture.create_from_image(image)
	textures[key] = result; stats.textures_created += 1
	return result
func geometry(source_sha: String, index: int, data: Dictionary) -> ArrayMesh:
	if not main_thread(): return null
	var key := Cache.key(source_sha,"mesh:"+str(index))
	if meshes.has(key): stats.mesh_hits += 1; return meshes[key]
	var vertices: PackedFloat32Array = data.vertices; var source_indices: PackedInt32Array = data.indices
	if vertices.size() % 3 != 0 or source_indices.size() % 3 != 0: failure = "Invalid native mesh stream lengths"; return null
	if vertices.is_empty() or source_indices.is_empty(): return null
	var count := vertices.size()/3; var positions := PackedVector3Array(); var normals := PackedVector3Array(); var uv := PackedVector2Array()
	positions.resize(count); normals.resize(count); uv.resize(count)
	var authored_normals: PackedFloat32Array = data.normals
	var authored_uv: PackedFloat32Array = data.uv[0] if not data.uv.is_empty() else PackedFloat32Array()
	if not authored_normals.is_empty() and authored_normals.size() != vertices.size(): failure = "Native normal count does not match geometry"; return null
	if not authored_uv.is_empty() and authored_uv.size() != count*2: failure = "Native UV count does not match geometry"; return null
	for vertex in count:
		positions[vertex] = point(vertices,vertex)
		if not authored_normals.is_empty(): normals[vertex] = point(authored_normals,vertex)
		if not authored_uv.is_empty(): uv[vertex] = Vector2(authored_uv[vertex*2],authored_uv[vertex*2+1])
	var indices := source_indices.duplicate()
	for face in range(0,indices.size(),3):
		var a := int(source_indices[face]); var b := int(source_indices[face+1]); var c := int(source_indices[face+2])
		if mini(a,mini(b,c)) < 0 or maxi(a,maxi(b,c)) >= count: failure = "Native triangle exceeds vertices"; return null
		# Godot's front-face convention is clockwise; source MDL is CCW.
		indices[face+1] = c; indices[face+2] = b
		if authored_normals.is_empty():
			var normal := (positions[b]-positions[a]).cross(positions[c]-positions[a])
			normals[a] += normal; normals[b] += normal; normals[c] += normal
	if authored_normals.is_empty():
		for vertex in count: normals[vertex] = normals[vertex].normalized()
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	meshes[key] = mesh; stats.meshes_created += 1
	return mesh
func material(part: Dictionary, raster: Dictionary = {}) -> StandardMaterial3D:
	if not main_thread(): return null
	var opacity := clampf(float(part.get("alpha",1)),0,1); var data: Dictionary = part.mesh
	var diffuse: Array = data.get("diffuse",[1.0,1.0,1.0]); var emission: Array = part.get("selfillum",[0.0,0.0,0.0]); var hint: bool = data.get("transparency_hint",false)
	var key := JSON.stringify([raster.get("sha256",""),diffuse,emission,opacity,hint,unshaded,texture_filter])
	if materials.has(key): stats.material_hits += 1; return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(diffuse[0],diffuse[1],diffuse[2],opacity)
	result.roughness = 1; result.metallic = 0; result.cull_mode = BaseMaterial3D.CULL_BACK
	result.texture_repeat = true; result.texture_filter = texture_filter
	if unshaded: result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if hint or opacity < 1:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; result.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if emission.any(func(value): return float(value)>0): result.emission_enabled = true; result.emission = Color(emission[0],emission[1],emission[2])
	if not raster.is_empty():
		result.albedo_texture = texture(raster)
		if result.albedo_texture == null: return null
		if not hint and opacity >= 1 and raster.value.format != "dxt1_rgb":
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; result.alpha_scissor_threshold = 0.035
	materials[key] = result; stats.materials_created += 1
	return result
func clear() -> void:
	meshes.clear(); textures.clear(); materials.clear()
