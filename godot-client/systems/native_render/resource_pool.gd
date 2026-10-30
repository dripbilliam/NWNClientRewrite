extends RefCounted
# Native GPU resources shared by content identity, not scene instances.
const Cache = preload("res://systems/native_data/prepared_cache.gd")
const Template = preload("res://systems/native_render/model_template.gd")
const PickGeometry=preload("res://systems/native_render/pick_geometry.gd")
const SceneGeometry=preload("res://systems/native_render/scene_geometry.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const MeshPreparation=preload("res://systems/native_data/mesh_preparation.gd")
var use_prepared_geometry:=MeshPreparation.configured_enabled()
var publication_budget_us:=3000
var maximum_publications_per_frame:=16
var publication_frame:=-1
var publication_us:=0
var publications:=0
var priority_publications:=0
func can_publish(priority: bool=false) -> bool:
	var frame:=int(Engine.get_process_frames())
	if publication_frame!=frame:
		publication_frame=frame; publication_us=0; publications=0; priority_publications=0
	return (priority and priority_publications==0) or publications==0 or publication_us<publication_budget_us and publications<maximum_publications_per_frame
func publication_finished(began: int,priority: bool=false) -> void:
	publication_us+=Time.get_ticks_usec()-began; publications+=1
	if priority: priority_publications+=1
var failure := ""
var meshes: Dictionary = {}
var textures: Dictionary = {}
var materials: Dictionary = {}
var unshaded := false
var texture_filter := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
var picking := false
var compact_static_parts:=OS.get_cmdline_user_args().has("--static-parts=compact")
var pick_shapes: Dictionary = {}
var hidden_hit_geometry: Dictionary={}
var hidden_hit_order: Array=[]
var templates: Dictionary = {}
var template_preparation_peaks: Array=[]
var template_order: Array=[]
var maximum_templates:=512
var maximum_meshes:=4096
var maximum_textures:=512
var maximum_materials:=2048
var resource_order:={"mesh":[],"texture":[],"material":[]}
var stats := {"meshes_created":0,"textures_created":0,"materials_created":0,"mesh_hits":0,"texture_hits":0,"material_hits":0,"native_decompressions":0,"templates_created":0,"template_hits":0,"template_evictions":0,"mesh_evictions":0,"texture_evictions":0,"material_evictions":0,"prepared_mesh_uses":0,"main_mesh_preparations":0,"prepared_hidden_uses":0}
func touch(kind: String,key: String) -> void:
	resource_order[kind].erase(key); resource_order[kind].append(key)
func retain(kind: String,entries: Dictionary,key: String,value: Resource,limit: int) -> void:
	# These bounds cover cache bindings, not resources still referenced by live
	# models/templates. Dropping a binding never changes an admitted instance.
	if limit<=0: return
	while not resource_order[kind].is_empty() and entries.size()>=limit:
		var oldest: String=resource_order[kind].pop_front()
		entries.erase(oldest); stats[kind+"_evictions"]+=1
		if kind=="mesh": pick_shapes.erase(oldest)
	entries[key]=value; touch(kind,key)
func main_thread() -> bool:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): failure = "Native render resources must be published on the main thread"; return false
	return true
func model_template(bundle: Dictionary):
	var began:=Timing.begin(); var result=prepare_model_template(bundle)
	Timing.finish("publication_template_cpu_ms",began); return result
func prepare_model_template(bundle: Dictionary):
	if not main_thread(): return null
	failure=""
	var key:=Template.identity(bundle,self)
	if templates.has(key):
		stats.template_hits+=1; template_order.erase(key); template_order.append(key)
		return templates[key]
	var template:=Template.new()
	if not template.build(bundle,self): failure=template.failure; return null
	if not template.preparation_timings.is_empty():
		var measured: Dictionary=template.preparation_timings.duplicate(); measured.model=str(bundle.get("resource_name",bundle.value.name)); measured.sha256=str(bundle.sha256)
		template_preparation_peaks.append(measured); template_preparation_peaks.sort_custom(func(a,b):return float(a.total_ms)>float(b.total_ms))
		if template_preparation_peaks.size()>16: template_preparation_peaks.resize(16)
	stats.templates_created+=1
	if maximum_templates>0:
		while not template_order.is_empty() and templates.size()>=maximum_templates:
			templates.erase(template_order.pop_front()); stats.template_evictions+=1
		templates[key]=template; template_order.append(key)
	return template
static func point(values: PackedFloat32Array, index: int) -> Vector3:
	return Vector3(values[index*3], values[index*3+2], -values[index*3+1])
func texture(record: Dictionary) -> Texture2D:
	var began:=Timing.begin(); var result:=prepare_texture(record)
	Timing.finish("publication_texture_cpu_ms",began); return result
func prepare_texture(record: Dictionary) -> Texture2D:
	if not main_thread(): return null
	var key := str(record.sha256)
	if textures.has(key): stats.texture_hits += 1; touch("texture",key); return textures[key]
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
	retain("texture",textures,key,result,maximum_textures); stats.textures_created += 1
	return result
func geometry(source_sha: String, index: int, data: Dictionary, rigid_skin: bool=false) -> ArrayMesh:
	var began:=Timing.begin(); var result:=prepare_geometry(source_sha,index,data,rigid_skin)
	Timing.finish("publication_mesh_cpu_ms",began); return result
func prepare_geometry(source_sha: String, index: int, data: Dictionary, rigid_skin: bool=false) -> ArrayMesh:
	if not main_thread(): return null
	var key := Cache.key(source_sha,"mesh:"+str(index)+("-rigid-skin" if rigid_skin else "")+("-pick" if picking else ""))
	if meshes.has(key): stats.mesh_hits += 1; touch("mesh",key); return meshes[key]
	var phase_began:=Timing.begin()
	var vertices: PackedFloat32Array = data.vertices; var source_indices: PackedInt32Array = data.indices
	if vertices.size() % 3 != 0 or source_indices.size() % 3 != 0: failure = "Invalid native mesh stream lengths"; return null
	if vertices.is_empty() or source_indices.is_empty(): return null
	var count := vertices.size()/3; var positions := PackedVector3Array(); var normals := PackedVector3Array(); var uv := PackedVector2Array(); var indices:=PackedInt32Array()
	var prepared: Dictionary=data.get("native_upload",{}) if use_prepared_geometry else {}
	if not prepared.is_empty():
		if not valid_prepared(prepared,count,source_indices.size()): failure="Invalid prepared native geometry"; return null
		positions=prepared.positions; normals=prepared.normals; uv=prepared.uv; indices=prepared.indices; stats.prepared_mesh_uses+=1
	else:
		stats.main_mesh_preparations+=1
		positions.resize(count); normals.resize(count); uv.resize(count)
		var authored_normals: PackedFloat32Array = data.normals
		var authored_uv: PackedFloat32Array = data.uv[0] if not data.uv.is_empty() else PackedFloat32Array()
		if not authored_normals.is_empty() and authored_normals.size() != vertices.size(): failure = "Native normal count does not match geometry"; return null
		if not authored_uv.is_empty() and authored_uv.size() != count*2: failure = "Native UV count does not match geometry"; return null
		for vertex in count:
			positions[vertex] = point(vertices,vertex)
			if not authored_normals.is_empty(): normals[vertex] = point(authored_normals,vertex)
			if not authored_uv.is_empty(): uv[vertex] = Vector2(authored_uv[vertex*2],authored_uv[vertex*2+1])
		indices=source_indices.duplicate()
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
	if rigid_skin:
		var bones:=PackedInt32Array(); var weights:=PackedFloat32Array(); bones.resize(count*4); weights.resize(count*4); bones.fill(0); weights.fill(0)
		for vertex in count: weights[vertex*4]=1.0
		arrays[Mesh.ARRAY_BONES]=bones; arrays[Mesh.ARRAY_WEIGHTS]=weights
	Timing.finish("publication_mesh_arrays_ms",phase_began); phase_began=Timing.begin()
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	Timing.finish("publication_mesh_submit_ms",phase_began); phase_began=Timing.begin()
	var hit:=PickGeometry.new(); hit.vertices=positions; hit.indices=indices; hit.bounds=mesh.get_aabb(); mesh.set_meta("native_pick_geometry",hit)
	var scene_faces:=SceneGeometry.new(); scene_faces.configure(data,prepared); mesh.set_meta("native_scene_geometry",scene_faces)
	Timing.finish("publication_mesh_collision_ms",phase_began); phase_began=Timing.begin()
	if picking:
		mesh.set_meta("native_pick_shape",hit.get_shape())
	Timing.finish("publication_mesh_pick_ms",phase_began); phase_began=Timing.begin()
	retain("mesh",meshes,key,mesh,maximum_meshes)
	if maximum_meshes>0 and picking: pick_shapes[key]=mesh.get_meta("native_pick_shape")
	stats.meshes_created += 1
	Timing.finish("publication_mesh_cache_ms",phase_began)
	return mesh
static func valid_prepared(value: Dictionary,count: int,indices: int) -> bool:
	return value.get("revision")==MeshPreparation.REVISION and value.get("positions") is PackedVector3Array and value.positions.size()==count and value.get("normals") is PackedVector3Array and value.normals.size()==count and value.get("uv") is PackedVector2Array and value.uv.size()==count and value.get("indices") is PackedInt32Array and value.indices.size()==indices and value.get("pick_bounds") is AABB and value.get("source_bounds") is AABB and value.get("planes") is PackedFloat32Array
func hidden_geometry(source_sha: String,index: int,data: Dictionary) -> Resource:
	if not main_thread(): return null
	var key:=Cache.key(source_sha,"hidden-hit:"+str(index))
	if hidden_hit_geometry.has(key): hidden_hit_order.erase(key); hidden_hit_order.append(key); return hidden_hit_geometry[key]
	var vertices: PackedFloat32Array=data.vertices; var indices: PackedInt32Array=data.indices
	if vertices.size()%3!=0 or indices.size()%3!=0: failure="Invalid native hidden hit geometry"; return null
	var hit:=PickGeometry.new(); var prepared: Dictionary=data.get("native_upload",{}) if use_prepared_geometry else {}
	if not prepared.is_empty():
		if not valid_prepared(prepared,vertices.size()/3,indices.size()): failure="Invalid prepared native geometry"; return null
		hit.vertices=prepared.positions; hit.indices=prepared.indices; hit.bounds=prepared.pick_bounds; stats.prepared_hidden_uses+=1
	else:
		hit.vertices.resize(vertices.size()/3); hit.indices=indices.duplicate()
		for vertex in hit.vertices.size():
			hit.vertices[vertex]=point(vertices,vertex)
			hit.bounds=hit.bounds.expand(hit.vertices[vertex]) if vertex>0 else AABB(hit.vertices[vertex],Vector3.ZERO)
		for face in range(0,hit.indices.size(),3):
			for corner in 3:
				if int(hit.indices[face+corner])<0 or int(hit.indices[face+corner])>=hit.vertices.size(): failure="Native hidden triangle exceeds vertices"; return null
			var second: int=hit.indices[face+1]; hit.indices[face+1]=hit.indices[face+2]; hit.indices[face+2]=second
	var scene_faces:=SceneGeometry.new(); scene_faces.configure(data,prepared); hit.set_meta("native_scene_geometry",scene_faces)
	if maximum_meshes>0:
		while hidden_hit_geometry.size()>=maximum_meshes and not hidden_hit_order.is_empty(): hidden_hit_geometry.erase(hidden_hit_order.pop_front())
		hidden_hit_geometry[key]=hit; hidden_hit_order.append(key)
	return hit
func material(part: Dictionary, raster: Dictionary = {}) -> StandardMaterial3D:
	if not main_thread(): return null
	var opacity := clampf(float(part.get("alpha",1)),0,1); var data: Dictionary = part.mesh
	var diffuse: Array = data.get("diffuse",[1.0,1.0,1.0]); var emission: Array = part.get("selfillum",[0.0,0.0,0.0]); var hint: bool = data.get("transparency_hint",false)
	var key := JSON.stringify([raster.get("sha256",""),diffuse,emission,opacity,hint,unshaded,texture_filter])
	if materials.has(key): stats.material_hits += 1; touch("material",key); return materials[key]
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
	retain("material",materials,key,result,maximum_materials); stats.materials_created += 1
	return result
func snapshot() -> Dictionary:
	var state:=stats.duplicate()
	state.static_part_layout="compact" if compact_static_parts else "separate"
	state.retained={"templates":templates.size(),"meshes":meshes.size(),"textures":textures.size(),"materials":materials.size(),"pick_shapes":pick_shapes.size(),"hidden_hit_geometry":hidden_hit_geometry.size()}
	state.limits={"templates":maximum_templates,"meshes":maximum_meshes,"textures":maximum_textures,"materials":maximum_materials}
	state.mesh_preparation={"enabled":use_prepared_geometry,"revision":MeshPreparation.REVISION,"policy":"Immutable worker upload data; main-thread ArrayMesh/scene publication with legacy fallback"}
	state.publication_budget={"frame":publication_frame,"used_us":publication_us,"units":publications,"budget_us":publication_budget_us,"maximum_units":maximum_publications_per_frame,"scope":"Shared scene/GPU API submission budget; asynchronous GPU work measured separately; a single indivisible model may exceed budget"}
	state.scope="Cumulative immutable GPU/template cache bindings; not live draw counts or a hard VRAM budget"
	state.template_preparation_peaks=template_preparation_peaks.duplicate(true)
	return state
func clear() -> void:
	templates.clear(); template_order.clear(); meshes.clear(); textures.clear(); materials.clear(); pick_shapes.clear()
	hidden_hit_geometry.clear(); hidden_hit_order.clear()
	for order in resource_order.values(): order.clear()
