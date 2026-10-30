extends RefCounted
# Original binary MDL static geometry/data only. No glTF or scene export.
# Animation, skins, emitters, light behavior and references remain explicitly
# pending consumers; their headers are retained, never silently accepted.
const Binary = preload("res://systems/native_data/binary_data.gd")
const Emitter=preload("res://systems/native_data/emitter_data.gd")
var failure := ""
var reader
var model_size := 0
var raw_start := 0
var raw_size := 0
var declared_nodes := 0
var nodes: Array = []
var visited := {}
func reject(message: String) -> void:
	if failure.is_empty(): failure = message
func model_range(offset: int, size: int) -> bool:
	if offset < 0 or size < 0 or offset > model_size or size > model_size - offset: reject("MDL range exceeds model section"); return false
	return true
func raw_range(offset: int, size: int) -> bool:
	if offset < 0 or size < 0 or offset > raw_size or size > raw_size - offset: reject("MDL range exceeds raw-data section"); return false
	return true
func parse(bytes: PackedByteArray) -> Dictionary:
	failure = ""; nodes.clear(); visited.clear(); reader = Binary.new(bytes)
	if not reader.contains(0, 108, "Binary MDL header"): failure = reader.failure; return {}
	model_size = reader.u32(4); raw_size = reader.u32(8); raw_start = 12 + model_size; declared_nodes = reader.u32(88)
	if reader.u32(0) != 0 or declared_nodes < 1 or declared_nodes > 100000 or not reader.contains(12, model_size + raw_size): reject("Invalid binary MDL header"); return {}
	var name: String = reader.text(20, 64, true)
	if name.is_empty(): reject("Binary MDL model name is empty"); return {}
	read_node(reader.u32(84), -1, 0)
	if not reader.failure.is_empty(): reject(reader.failure)
	if not failure.is_empty(): return {}
	# Original serialized model reader140079f90 copies model+72 to runtime+92.
	if not model_range(0x72,1): return {}
	return {"name": name, "nodes": nodes, "classification_flags":reader.u8(12+0x72), "model_bytes": model_size, "raw_bytes": raw_size, "scope": "Original static binary MDL data; behavioral controllers/animation/skinning not yet admitted"}
func read_node(offset: int, parent: int, depth: int) -> void:
	if not failure.is_empty(): return
	if depth > 128 or nodes.size() >= declared_nodes or visited.has(offset): reject("MDL hierarchy depth/count/cycle invalid"); return
	if not model_range(offset, 112): return
	visited[offset] = true
	var at := 12 + offset; var flags: int = reader.u32(at + 108)
	if flags & ~0x3f7: reject("Unsupported binary MDL node flags"); return
	var row := {"name": reader.text(at + 32, 32, true), "parent": parent, "flags": flags, "position": [0.0,0.0,0.0], "orientation": [0.0,0.0,0.0,1.0], "scale": 1.0, "alpha": 1.0, "selfillum": [0.0,0.0,0.0], "features": [], "mesh": {}, "light": {"color":[1.0,1.0,1.0],"radius":0.0,"multiplier":1.0} if flags & 2 else {}}
	if flags&4: row.emitter={}
	static_controllers(row, at)
	var cursor := at + 112
	for feature in [[2, 92, "light"], [4, 216, "emitter"], [16, 68, "reference"]]:
		if flags & int(feature[0]):
			if not model_range(cursor - 12, feature[1]): return
			if int(feature[0])==2:
				row.light.flareradius=reader.f32(cursor)
				var names: Array=["lightpriority","ambientonly","isdynamic","affectdynamic","shadow","generateflare","fadinglight"]
				for index in names.size(): row.light[names[index]]=reader.u32(cursor+64+index*4)
			elif int(feature[0])==4:
				var emitter:=Emitter.new(); var properties:=emitter.binary_header(reader,cursor)
				if not emitter.failure.is_empty(): reject(emitter.failure); return
				row.emitter.merge(properties,true)
			elif int(feature[0])==16:
				row.reference={"model":reader.text(cursor,64,true),"rawModel":reader.bytes(cursor,64),"reattachable":reader.i32(cursor+64)}
			row.features.append(feature[2]); cursor += int(feature[1])
	if flags & 32: row.mesh = read_mesh(cursor)
	for feature in [[64,"skin"],[128,"animated-mesh"],[256,"dangly"],[512,"aabb"]]:
		if flags & int(feature[0]): row.features.append(feature[1])
	var child_offset: int = reader.u32(at + 72); var count: int = reader.u32(at + 76)
	if count > declared_nodes or not model_range(child_offset, count * 4): reject("MDL child table invalid"); return
	var index := nodes.size(); nodes.append(row)
	for child in count: read_node(reader.u32(12 + child_offset + child * 4), index, depth + 1)
func static_controllers(row: Dictionary, at: int) -> void:
	var keys: int = reader.u32(at + 84); var count: int = reader.u32(at + 88)
	var values: int = reader.u32(at + 96); var value_count: int = reader.u32(at + 100)
	if count == 0 or value_count == 0: return
	if count > 1000000 or value_count > 16000000 or not model_range(keys, count * 12) or not model_range(values, value_count * 4): reject("Invalid MDL static controllers"); return
	for index in count:
		var key := 12 + keys + index * 12
		var type: int = reader.u32(key); var rows: int = reader.u16(key + 4); var time_index: int = reader.u16(key + 6); var value_index: int = reader.u16(key + 8); var columns: int = reader.u8(key + 10)
		if rows in [0, 65535] or columns == 0 or time_index >= value_count or value_index + columns > value_count: continue
		if reader.f32(12 + values + time_index * 4) != 0: continue
		var data: Array = []; var valid := true
		for component in columns:
			var value: float = reader.f32(12 + values + (value_index + component) * 4)
			if not is_finite(value): valid = false
			data.append(value)
		if not valid: continue
		if type == 8 and columns == 3: row.position = data
		elif type == 20 and columns == 4: row.orientation = data
		elif type == 36 and columns == 1: row.scale = data[0]
		elif int(row.flags) & 32 and type == 128 and columns == 1: row.alpha = data[0]
		elif int(row.flags) & 32 and type == 100 and columns == 3: row.selfillum = data
		elif int(row.flags) & 2:
			if type==76 and columns==3: row.light.color=data
			elif columns==1:
				var property: String={88:"radius",96:"shadowradius",100:"verticaldisplacement",140:"multiplier"}.get(type,"")
				if not property.is_empty(): row.light[property]=data[0]
		elif int(row.flags)&4:
			var channel:=Emitter.channel(type)
			if not channel.is_empty() and columns==int(channel.components): row.emitter[channel.property]=data if columns==3 else data[0]
func read_mesh(at: int) -> Dictionary:
	if not model_range(at - 12, 512): return {}
	var face_offset: int = reader.u32(at + 8); var face_count: int = reader.u32(at + 12)
	var count_offset: int = reader.u32(at + 404); var group_count: int = reader.u32(at + 408)
	var draw_offset: int = reader.u32(at + 416); var draw_count: int = reader.u32(at + 420)
	var mode: int = reader.u8(at + 436); var vertex_offset: int = reader.u32(at + 444); var vertex_count: int = reader.u16(at + 448); var texture_count: int = reader.u16(at + 450)
	var normal_offset: int = reader.u32(at + 468)
	var result := {"vertices": PackedFloat32Array(), "normals": PackedFloat32Array(), "uv": [], "indices": PackedInt32Array(), "collision_indices": PackedInt32Array(), "textures": [], "render": reader.u32(at + 108) == 1, "shadow": reader.u32(at + 100) == 1, "transparency_hint": reader.u32(at + 112) == 1, "diffuse": [reader.f32(at + 72),reader.f32(at + 76),reader.f32(at + 80)]}
	# Original header copier078ab0: mesh extension1f8 (disk268) -> runtime2bc.
	# Skin/dangly mesh headers inherit this field; do not derive it from triangles.
	result.native_area=reader.f32(at+0x1f8)
	result.native_planes=PackedFloat32Array(); result.native_surface_types=PackedInt32Array()
	# Empty serialized trimeshes contain no vertex/index/texture payload. Their
	# unused primitive-mode byte may be unspecified (observed 208 and 98 in
	# actual tile resources). Preserve the physical node without drawing it.
	if face_count == 0 and vertex_count == 0 and texture_count == 0 and draw_count == 0: return result
	if mode != 3 or vertex_count == 0 or face_count > 1000000 or (face_count == 0 and draw_count == 0): reject("Invalid MDL mesh mode/count"); return {}
	if not raw_range(vertex_offset, vertex_count * 12) or not model_range(face_offset, face_count * 32): return {}
	for index in vertex_count * 3: result.vertices.append(reader.f32(raw_start + vertex_offset + index * 4))
	if normal_offset != 0xffffffff:
		if not raw_range(normal_offset, vertex_count * 12): return {}
		for index in vertex_count * 3: result.normals.append(reader.f32(raw_start + normal_offset + index * 4))
	for layer in mini(texture_count, 4):
		result.textures.append(reader.text(at + 120 + layer * 64, 64, true))
		var uv_offset: int = reader.u32(at + 452 + layer * 4); var uv := PackedFloat32Array()
		if uv_offset != 0xffffffff:
			if not raw_range(uv_offset, vertex_count * 8): return {}
			for index in vertex_count * 2: uv.append(reader.f32(raw_start + uv_offset + index * 4))
		result.uv.append(uv)
	for face in face_count:
		var original_face:=12+face_offset+face*32
		for field in 4: result.native_planes.append(reader.f32(original_face+field*4))
		result.native_surface_types.append(reader.u32(original_face+16))
		for corner in 3:
			var index: int = reader.u16(12 + face_offset + face * 32 + 26 + corner * 2)
			if index >= vertex_count: reject("MDL collision index exceeds vertices"); return {}
			result.collision_indices.append(index)
	result.indices = result.collision_indices.duplicate()
	if draw_count > 0:
		if draw_count != group_count or draw_count > 1000000 or not model_range(count_offset, draw_count * 4) or not model_range(draw_offset, draw_count * 4): reject("Invalid MDL draw-group table"); return {}
		result.indices = PackedInt32Array()
		for group in draw_count:
			var count: int = reader.u32(12 + count_offset + group * 4); var offset: int = reader.u32(12 + draw_offset + group * 4)
			if count > 3000000 or count % 3 != 0 or not raw_range(offset, count * 2): reject("Invalid MDL triangle-list group"); return {}
			for vertex in count:
				var index: int = reader.u16(raw_start + offset + vertex * 2)
				if index >= vertex_count: reject("MDL draw index exceeds vertices"); return {}
				result.indices.append(index)
	return result
