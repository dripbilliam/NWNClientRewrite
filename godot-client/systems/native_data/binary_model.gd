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
static func remap_controller(value: int,flags: int) -> int:
	flags&=255
	if (flags&5)==5:
		for pair in [[436,84],[392,64],[356,56],[328,48],[276,44],[228,36],[76,28]]:
			if value>=int(pair[0]):return signed32(value+int(pair[1]))
	elif (flags&33)==33:
		for pair in [[128,40],[116,36],[76,28]]:
			if value>=int(pair[0]):return signed32(value+int(pair[1]))
	elif (flags&3)==3 and value>=76:return signed32(value+28)
	return signed32(value+24 if value>=72 else (value+8 if value>=8 else value))
static func signed32(value: int) -> int:
	var wrapped:=value&0xffffffff
	return wrapped-0x100000000 if wrapped>=0x80000000 else wrapped
static func controller_storage(source,at: int,model_end: int) -> Dictionary:
	# readModelControllerStorage retains the complete remapped native value pool.
	var keys: int=12+int(source.u32(at+84));var count: int=int(source.u32(at+88))
	var values: int=12+int(source.u32(at+96));var value_count: int=int(source.u32(at+100))
	var flags: int=int(source.u32(at+108))
	if count>1000000 or value_count>16000000 or keys<12 or values<12 or keys>model_end or values>model_end or count*12>model_end-keys or value_count*4>model_end-values:
		return {"error":"Original actor controller storage is invalid"}
	var controllers: Array=[]
	for index in count:
		var key: int=keys+index*12
		controllers.append({"displacement0":remap_controller(source.i32(key),flags),"rows4":source.u16(key+4),"timeIndex6":source.u16(key+6),"valueIndex8":source.u16(key+8),"columnsA":source.u8(key+10),"paddingB":source.u8(key+11)})
	return {"id34":source.i32(at+28),"flags98":flags,"controllers78":controllers,"controllerCount80":count,"values88":source.data.slice(values,values+value_count*4).to_float32_array(),"valueCount90":value_count,"children68":[],"childCount70":0}
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
	var material_names: Array=[];var has_skinned_meshes:=false
	for node in nodes:
		var features: Array=node.get("features",[])
		if features.has("skin"):has_skinned_meshes=true
		var names: Array=node.mesh.get("textures",[]) if int(node.flags)&32 else ([node.emitter.get("texture","")] if int(node.flags)&4 else [])
		for texture_name in names:
			if not str(texture_name).is_empty() and str(texture_name).to_lower()!="null" and not material_names.has(texture_name):material_names.append(texture_name)
	return {"name": name, "modelName":name,"nodes": nodes,"nativeRoot":nodes[0].nativeNode,"materialNames":material_names,"hasSkinnedMeshes":has_skinned_meshes,"format":"Binary MDL", "classification_flags":reader.u8(12+0x72), "model_bytes": model_size, "raw_bytes": raw_size, "scope": "Original static binary MDL data; behavioral controllers/animation/skinning not yet admitted"}
func read_node(offset: int, parent: int, depth: int) -> void:
	if not failure.is_empty(): return
	if depth > 128 or nodes.size() >= declared_nodes or visited.has(offset): reject("MDL hierarchy depth/count/cycle invalid"); return
	if not model_range(offset, 112): return
	visited[offset] = true
	var at := 12 + offset; var flags: int = reader.u32(at + 108)
	if flags & ~0x3f7: reject("Unsupported binary MDL node flags"); return
	var native_node:=controller_storage(reader,at,12+model_size)
	if native_node.has("error"):reject(str(native_node.error));return
	var type:="trimesh" if flags&32 else ("light" if flags&2 else ("emitter" if flags&4 else ("reference" if flags&16 else "dummy")))
	var old_properties: Dictionary={"color":[0.0,0.0,0.0],"radius":0.0,"shadowradius":0.0,"verticaldisplacement":0.0,"multiplier":1.0} if flags&2 else {}
	var parent_name: String="NULL" if parent<0 else str(nodes[parent].name)
	var row := {"name": reader.text(at + 32, 32, true), "parent":parent_name,"parentIndex":parent,"parentName":parent_name,"type":type,"properties":old_properties, "flags": flags,"nativeNode":native_node, "position": [0.0,0.0,0.0], "orientation": [0.0,0.0,0.0,1.0], "scale": 1.0, "alpha": 1.0,"bitmap":"","ambient":null,"diffuse":null,"specular":null,"shininess":0.0,"render":true,"textureLayers":[],"skinned":false,"skinData":null,"nativeVertexNormals":null,"tvertsByLayer":[],"tverts":[],"verts":[],"faces":[], "selfillum": [0.0,0.0,0.0], "features": [], "unsupportedFeatures": [], "mesh": {}, "light": {"color":[1.0,1.0,1.0],"radius":0.0,"multiplier":1.0} if flags & 2 else {}}
	for feature in [[4,"Emitter runtime simulation"],[16,"Referenced model attachment"],[128,"Animated vertex/UV channels"],[256,"Dangly-mesh simulation"]]:
		if flags & int(feature[0]):row.unsupportedFeatures.append(feature[1])
	if flags&4: row.emitter={}
	static_controllers(row, at)
	var cursor := at + 112
	for feature in [[2, 92, "light"], [4, 216, "emitter"], [16, 68, "reference"]]:
		if flags & int(feature[0]):
			if not model_range(cursor - 12, feature[1]): return
			if int(feature[0])==2:
				row.light.flareradius=reader.f32(cursor)
				row.properties.flareradius=row.light.flareradius
				var names: Array=["lightpriority","ambientonly","isdynamic","affectdynamic","shadow","generateflare","fadinglight"]
				for index in names.size():
					row.light[names[index]]=reader.u32(cursor+64+index*4)
					row.properties[names[index]]=row.light[names[index]]
				var unresolved_flare:=int(row.light.generateflare)!=0
				for flare_offset in [4,16,28,40,52]:
					if reader.u32(cursor+flare_offset+4)!=0:unresolved_flare=true
				if unresolved_flare:row.unsupportedFeatures.append("Light lens flare presentation")
			elif int(feature[0])==4:
				var emitter:=Emitter.new(); var properties:=emitter.binary_header(reader,cursor)
				if not emitter.failure.is_empty(): reject(emitter.failure); return
				row.emitter.merge(properties,true)
				row.properties.merge(properties,true)
			elif int(feature[0])==16:
				var raw_model: Array=[]
				for byte in reader.bytes(cursor,64):raw_model.append(int(byte))
				row.reference={"model":reader.text(cursor,64,true),"rawModel":raw_model,"reattachable":reader.i32(cursor+64)}
				native_node.referenceModelA0=raw_model;native_node.reattachableE0=int(row.reference.reattachable)
				row.properties.refmodel=row.reference.model;row.properties.reattachable=row.reference.reattachable
			row.features.append(feature[2]); cursor += int(feature[1])
	if flags & 32:
		row.mesh=read_mesh(cursor)
		row.nativeTriMeshArea=row.mesh.get("native_area",0.0)
		row.ambient=row.mesh.get("ambient",null);row.diffuse=row.mesh.get("diffuse",null);row.specular=row.mesh.get("specular",null)
		row.shininess=row.mesh.get("shininess",0.0);row.render=row.mesh.get("render",true)
		row.shadow=row.mesh.get("shadow",false);row.beaming=row.mesh.get("beaming",false);row.transparencyHint=row.mesh.get("transparency_hint",false)
		row.textureLayers=row.mesh.get("textures",[])
		if not row.textureLayers.is_empty() and str(row.textureLayers[0]).to_lower()!="null":row.bitmap=row.textureLayers[0]
		row.nativeVertexNormals=row.mesh.get("normals",null)
		var vertices: PackedFloat32Array=row.mesh.get("vertices",PackedFloat32Array())
		for vertex in int(vertices.size()/3):row.verts.append([vertices[vertex*3],vertices[vertex*3+1],vertices[vertex*3+2]])
		for uv_layer in row.mesh.get("uv",[]):
			var old_layer: Array=[]
			for vertex in int(uv_layer.size()/2):old_layer.append([uv_layer[vertex*2],uv_layer[vertex*2+1],0.0])
			row.tvertsByLayer.append(old_layer)
		if not row.tvertsByLayer.is_empty():row.tverts=row.tvertsByLayer[0]
		var draw_indices: PackedInt32Array=row.mesh.get("indices",PackedInt32Array())
		for face in int(draw_indices.size()/3):
			var a:=draw_indices[face*3];var b:=draw_indices[face*3+1];var c:=draw_indices[face*3+2]
			row.faces.append([a,b,c,0,a,b,c,0])
		row.nativeCollisionFaces=[]
		var collision: PackedInt32Array=row.mesh.get("collision_indices",PackedInt32Array())
		var planes: PackedFloat32Array=row.mesh.get("native_planes",PackedFloat32Array())
		var surfaces: PackedInt32Array=row.mesh.get("native_surface_types",PackedInt32Array())
		for face in int(collision.size()/3):
			row.nativeCollisionFaces.append({"indices":[collision[face*3],collision[face*3+1],collision[face*3+2]],"normal":[planes[face*4],planes[face*4+1],planes[face*4+2]],"constant":planes[face*4+3],"surfaceType":surfaces[face]})
	if flags&64:row.skinned=true
	for feature in [[64,"skin"],[128,"animated-mesh"],[256,"dangly"],[512,"aabb"]]:
		if flags & int(feature[0]): row.features.append(feature[1])
	var child_offset: int = reader.u32(at + 72); var count: int = reader.u32(at + 76)
	if count > declared_nodes or not model_range(child_offset, count * 4): reject("MDL child table invalid"); return
	var index := nodes.size(); nodes.append(row)
	for child in count:
		var child_index:=nodes.size()
		read_node(reader.u32(12 + child_offset + child * 4), index, depth + 1)
		if not failure.is_empty():return
		native_node.children68.append(nodes[child_index].nativeNode)
	native_node.childCount70=count
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
		elif str(row.type)=="trimesh" and type == 128 and columns == 1: row.alpha = data[0]
		elif str(row.type)=="trimesh" and type == 100 and columns == 3:row.selfillum=data;row.selfillumcolor=data
		elif str(row.type)=="light":
			if type==76 and columns==3:row.light.color=data;row.properties.color=data
			elif columns==1:
				var property: String={88:"radius",96:"shadowradius",100:"verticaldisplacement",140:"multiplier"}.get(type,"")
				if not property.is_empty():row.light[property]=data[0];row.properties[property]=data[0]
		elif str(row.type)=="emitter":
			var channel:=Emitter.channel(type)
			if not channel.is_empty() and columns==int(channel.components):row.emitter[channel.property]=data if columns==3 else data[0];row.properties[channel.property]=row.emitter[channel.property]
func read_mesh(at: int) -> Dictionary:
	if not model_range(at - 12, 512): return {}
	var face_offset: int = reader.u32(at + 8); var face_count: int = reader.u32(at + 12)
	var count_offset: int = reader.u32(at + 404); var group_count: int = reader.u32(at + 408)
	var draw_offset: int = reader.u32(at + 416); var draw_count: int = reader.u32(at + 420)
	var mode: int = reader.u32(at + 436); var vertex_offset: int = reader.u32(at + 444); var vertex_count: int = reader.u16(at + 448); var texture_count: int = reader.u16(at + 450)
	var normal_offset: int = reader.u32(at + 468)
	var color_offset: int = reader.u32(at + 472)
	var result := {"vertices": PackedFloat32Array(), "normals": PackedFloat32Array(), "uv": [], "indices": PackedInt32Array(), "collision_indices": PackedInt32Array(), "textures": [], "render": reader.u32(at + 108) == 1, "shadow": reader.u32(at + 100) == 1, "beaming":reader.u32(at+104)==1,"transparency_hint": reader.u32(at + 112) == 1, "diffuse": [reader.f32(at + 72),reader.f32(at + 76),reader.f32(at + 80)],"specular":[reader.f32(at+84),reader.f32(at+88),reader.f32(at+92)],"shininess":reader.f32(at+96)}
	# Native MdlNodeTriMesh header copier078ab0 preserves these authored local
	# bounds (plain full-node84/90 -> runtimeC0/CC). HitCheckGeom uses the header,
	# including invisible Parts; recalculating a vertex AABB can change the box.
	var authored_min: Array=[reader.f32(at+0x14),reader.f32(at+0x18),reader.f32(at+0x1c)]
	var authored_max: Array=[reader.f32(at+0x20),reader.f32(at+0x24),reader.f32(at+0x28)]
	result.native_bounds={"min":authored_min,"max":authored_max}
	result.native_bounds_available=true;result.native_bounds_source="binary_mdl_header";result.native_bounds_offset=at+0x14
	result.native_bounds_valid=true
	for axis in 3:
		if not is_finite(float(authored_min[axis])) or not is_finite(float(authored_max[axis])) or float(authored_min[axis])>float(authored_max[axis]):result.native_bounds_valid=false
	# Serialized full-node1e8 -> runtime224 -> Part+ac is tilefade. The
	# separately exported transparency_hint at extension70 is not this field.
	result.native_tilefade=reader.u32(at+0x178);result.native_tilefade_available=true;result.native_tilefade_source="binary_mdl_header"
	result.native_render_raw=reader.u32(at+0x6c);result.native_render_source="binary_mdl_header"
	result.ambient=[reader.f32(at+60),reader.f32(at+64),reader.f32(at+68)]
	# Original header copier078ab0: mesh extension1f8 (disk268) -> runtime2bc.
	# Skin/dangly mesh headers inherit this field; do not derive it from triangles.
	result.native_area=reader.f32(at+0x1f8)
	result.native_planes=PackedFloat32Array(); result.native_surface_types=PackedInt32Array()
	# The original loader copies the full primitive mode (node+0x224).
	# PartTriMesh::Draw exits before using it for empty binary Parts.
	if vertex_count == 0 and face_count == 0 and texture_count == 0 and group_count == 0 and draw_count == 0:
		return result
	if mode != 3 or vertex_count == 0 or face_count > 1000000 or (face_count == 0 and draw_count == 0): reject("Invalid MDL mesh mode/count"); return {}
	if not raw_range(vertex_offset, vertex_count * 12) or not model_range(face_offset, face_count * 32): return {}
	for index in vertex_count * 3: result.vertices.append(reader.f32(raw_start + vertex_offset + index * 4))
	if normal_offset != 0xffffffff:
		if not raw_range(normal_offset, vertex_count * 12): return {}
		for index in vertex_count * 3: result.normals.append(reader.f32(raw_start + normal_offset + index * 4))
	# Serialized node248 -> runtime29c (header copier140078ab0); reader
	# 14007be10 copies vertexCount*4 unchanged. GLRender::SetVertexDataObject
	# 1400ba770 binds attribute2 as four normalized unsigned bytes, RGBA order.
	if color_offset!=0xffffffff:
		if not raw_range(color_offset,vertex_count*4): return {}
		result.vertex_colors=reader.bytes(raw_start+color_offset,vertex_count*4)
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
