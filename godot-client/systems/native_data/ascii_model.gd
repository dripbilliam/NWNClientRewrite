extends RefCounted
const Emitter=preload("res://systems/native_data/emitter_data.gd")
const Text=preload("res://systems/native_data/binary_data.gd")
const Orientation=preload("res://systems/native_data/model_orientation.gd")
# Direct original ASCII MDL static hierarchy and face-corner geometry. No JS,
# Three or scene export. Behavioral headers stay explicit pending features.
var failure:=""
var source_nodes: Array=[]
var output: Array=[]
var by_name: Dictionary={}
var current_model_name:="unnamed"
var emitted: Dictionary={}
var active: Dictionary={}
var native_integer_pattern: RegEx
static func is_ascii_mdl(bytes: PackedByteArray) -> bool:
	# src/mdl_format.js inspects only the first 4096 bytes and requires both
	# authored ASCII model commands after the leading comment marker.
	var prefix:=bytes.slice(0,mini(bytes.size(),4096)).get_string_from_ascii()
	if not prefix.begins_with("#"):return false
	var model:=RegEx.new();model.compile("(?i)\\bnewmodel\\s+\\S+")
	var geometry:=RegEx.new();geometry.compile("(?i)\\bbeginmodelgeom\\s+\\S+")
	return model.search(prefix)!=null and geometry.search(prefix)!=null
func reject(reason: String) -> void:
	if failure.is_empty(): failure=reason
static func animation_scale_number(token: String) -> float:
	var value:=token.strip_edges()
	if value.is_empty():return 0.0
	if value.length()>=2 and value[0]=="0" and value[1].to_lower() in ["x","b","o"]:
		if value.length()==2:return NAN
		var radix: int={"x":16,"b":2,"o":8}[value[1].to_lower()]
		var number:=0.0
		for at in range(2,value.length()):
			var code:=value.unicode_at(at);var digit:=-1
			if code>=48 and code<=57:digit=code-48
			elif code>=65 and code<=70:digit=code-65+10
			elif code>=97 and code<=102:digit=code-97+10
			if digit<0 or digit>=radix:return NAN
			number=number*radix+digit
		return number
	return float(value) if value.is_valid_float() else NAN
func numbers(tokens: PackedStringArray) -> Array:
	var values: Array=[]
	for token in tokens:
		var number:=animation_scale_number(token)
		if not is_finite(number): reject("Non-finite or invalid ASCII MDL number: "+token.substr(0,40)); return []
		values.append(number)
	return values
static func old_property_name_valid(name: String) -> bool:
	if name.is_empty():return false
	for at in name.length():
		var code:=name.unicode_at(at)
		if code>=97 and code<=122:continue
		if at>0 and (code>=48 and code<=57 or code==95):continue
		return false
	return true
static func record_public_property(source: Dictionary,line: String,tokens: PackedStringArray) -> void:
	if tokens.size()<2:return
	var key:=tokens[0].to_lower()
	if not old_property_name_valid(key):return
	var value_text:=line.substr(tokens[0].length()).strip_edges()
	var values: Array=[];var numeric:=true
	for token in tokens.slice(1):
		var value:=animation_scale_number(token)
		if not is_finite(value):numeric=false;break
		values.append(value)
	if numeric:source.public_properties[key]=values[0] if values.size()==1 else values
	else:source.public_properties[key]=value_text
func parse(text: String) -> Dictionary:
	failure=""; source_nodes.clear(); output.clear(); by_name.clear(); emitted.clear(); active.clear()
	var whitespace:=RegEx.new(); whitespace.compile("\\s+")
	var old_node_pattern:=RegEx.new();old_node_pattern.compile("(?i)^node\\s+(\\S+)\\s+(.+)$")
	var model_name:="unnamed"; var in_geometry:=false; var current: Dictionary={}; var array_kind:=""; var remaining:=0; var supermodel:=""; var animation_scale:=1.0; var animation_scale_error:=""; var classification_flags:=0
	for raw in text.replace("\r","").split("\n"):
		var line:=str(raw).strip_edges()
		if line.is_empty() or line.begins_with("#"): continue
		# Numeric animation rows cannot be model-header commands. They are not
		# geometry dependencies and need no token allocation on this pass.
		if remaining==0 and not in_geometry and line.unicode_at(0) in [43,45,46,48,49,50,51,52,53,54,55,56,57]: continue
		var tokens: PackedStringArray=Text.ascii_tokens(line,whitespace)
		if remaining>0:
			var values:=numbers(tokens)
			if not failure.is_empty():failure="Invalid "+array_kind+" data near "+str(current.name)+".";return {}
			current[array_kind].append(values); remaining-=1; continue
		var command:=tokens[0].to_lower()
		if line.begins_with("newmodel "): model_name=line.substr("newmodel ".length()).strip_edges(); continue
		# classification1400a11b0: unknown names retain the previous byte.
		if command=="classification" and tokens.size()>1:
			classification_flags=int({"tile":2,"character":4,"effect":1,"effects":1,"door":8}.get(tokens[1].to_lower(),classification_flags)); continue
		if command=="setsupermodel" and tokens.size()>2: supermodel=tokens[2]; continue
		if command=="setanimationscale":
			var value:=animation_scale_number(tokens[1]) if tokens.size()>1 else NAN
			animation_scale_error="" if is_finite(value) and value>=0 else "Invalid ASCII animation scale."
			if animation_scale_error.is_empty():animation_scale=value
			continue
		if line.begins_with("beginmodelgeom "): in_geometry=true; continue
		if line.begins_with("endmodelgeom "): in_geometry=false; current={}; continue
		if not in_geometry: continue
		if command=="node":
			var old_node_match:=old_node_pattern.search(line)
			if old_node_match==null:
				if not current.is_empty():record_public_property(current,line,tokens)
				continue # Old node regex leaves a malformed declaration as a property.
			var name: String=old_node_match.get_string(2).strip_edges()
			# Installed pfh0 legitimately declares two physical Impact nodes.
			# Keep both physical records; name lookup follows the existing JS
			# parser's final declaration, rather than rejecting the whole actor.
			current={"name":name,"kind":tokens[1].to_lower(),"parent_name":"NULL","position":[0.0,0.0,0.0],"orientation":[0.0,0.0,1.0,0.0],"scale":1.0,"alpha":1.0,"selfillum":[0.0,0.0,0.0],"diffuse":[1.0,1.0,1.0],"shadow":0 if tokens[1].to_lower()=="light" else 1,"render":1,"transparencyhint":0,"verts":[],"tverts":[],"faces":[],"textures":[],"properties":{},"public_properties":{}}
			current.native_tilefade=0;current.native_tilefade_available=true;current.native_tilefade_source="ascii_constructor_default"
			current.ambient=[1.0,1.0,1.0]
			by_name[name]=source_nodes.size()
			source_nodes.append(current); continue
		if line=="endnode": current={}; continue
		if current.is_empty(): continue
		record_public_property(current,line,tokens)
		if tokens.size()>1 and command not in ["parent","bitmap","position","orientation","verts","tverts","faces"]: current.properties[command]=" ".join(tokens.slice(1))
		if command=="tilefade":native_tilefade_field(current," ".join(tokens.slice(1)));continue
		if command=="parent":
			if tokens.size()>1:current.parent_name=line.substr(tokens[0].length()).strip_edges()
			continue
		if command=="bitmap" and tokens.size()>1: current.textures.append(tokens[1]); continue
		# Emitter 'render Normal' is a mode, not a mesh visibility number.
		if command=="render" and current.kind=="emitter": continue
		if command in ["verts","tverts","faces"]:
			var decimal_digits:=tokens.size()==2 and not tokens[1].is_empty()
			if decimal_digits:
				for at in tokens[1].length():
					var code:=tokens[1].unicode_at(at)
					if code<48 or code>57:decimal_digits=false;break
			if not decimal_digits:continue # Old parser treats a malformed count as an ordinary property.
			var amount:=animation_scale_number(tokens[1])
			if not is_finite(amount) or amount>1000000: reject("Unreasonable "+command+" count in "+str(current.name)+"."); return {}
			array_kind=command; remaining=int(amount); continue
		if command in ["position","orientation","scale","alpha","selfillumcolor","ambient","diffuse","render","shadow","transparencyhint"]:
			if command in ["position","orientation"] and tokens.size()==1:continue
			var count:=4 if command=="orientation" else (3 if command in ["position","selfillumcolor","ambient","diffuse"] else 1)
			var values:=numbers(tokens.slice(1,1+count) if command in ["position","orientation"] else tokens.slice(1))
			if not failure.is_empty() or values.size()<count:
				if command in ["position","orientation"]:failure="Invalid transform in node "+str(current.name)+".";return {}
				failure="";continue # Old generic property parse keeps malformed static fields as text.
			var key:="selfillum" if command=="selfillumcolor" else command
			current[key]=values[0] if count==1 else values.slice(0,count)
	if remaining>0: reject("Truncated "+array_kind+" section in "+str(current.name)+"."); return {}
	if source_nodes.is_empty(): reject("No model nodes were found."); return {}
	var material_names: Array=[]
	for source in source_nodes:
		if source.kind in ["trimesh","danglymesh"]:
			for bitmap in source.textures:
				if not str(bitmap).is_empty() and str(bitmap).to_lower()!="null" and not material_names.has(bitmap):material_names.append(bitmap)
		elif source.kind=="emitter":
			var emitter_texture: Variant=source.public_properties.get("texture")
			if emitter_texture is String and not material_names.has(emitter_texture):material_names.append(emitter_texture)
	current_model_name=model_name
	for index in source_nodes.size(): emit_node(index)
	if not failure.is_empty(): return {}
	var parser_nodes: Array=[];var public_by_name: Dictionary={}
	for source in source_nodes:
		var kind:=str(source.kind)
		var node: Dictionary={"type":"trimesh" if kind=="danglymesh" else kind,"name":source.name,"parent":source.parent_name,"position":source.position,"orientation":source.orientation,"orientationFormat":"axis-angle","scale":1.0,"bitmap":source.textures[0] if not source.textures.is_empty() else "","bitmaps":source.textures,"properties":source.public_properties,"verts":source.verts,"tverts":source.tverts,"faces":source.faces}
		if kind=="danglymesh":node.meshSubtype="danglymesh";node.unsupportedFeatures=["Dangly-mesh simulation"]
		parser_nodes.append(node);public_by_name[str(source.name)]=node
	var geometry_errors: Array=[]
	for source in source_nodes:
		if source.has("deferred_geometry_error"):
			var render_property: Variant=source.public_properties.get("render",1)
			geometry_errors.append({"name":source.name,"reason":source.deferred_geometry_error,"renderRequested":source.kind in ["trimesh","danglymesh"] and render_property!=0 and render_property!="0"})
	var result: Dictionary={"name":model_name,"modelName":model_name,"nodes":output,"sourceNodes":parser_nodes,"byName":public_by_name,"materialNames":material_names,"deferredGeometryErrors":geometry_errors,"classification_flags":classification_flags,"source_node_count":source_nodes.size(),"supermodel":supermodel,"animation_scale":animation_scale,"format":"ASCII MDL","scope":"Original static ASCII MDL; animation, skin, reference, light/emitter behavior pending"}
	if not animation_scale_error.is_empty():result.animation_scale_error=animation_scale_error;result.unsupportedAnimations=[animation_scale_error];result.animation_scale=1.0;result.supermodel=""
	return result
func emit_node(index: int) -> int:
	if emitted.has(index): return int(emitted[index])
	# The source recurses to each parent before emitting a child. Walk the same
	# chain explicitly so a valid deeply nested model does not consume the
	# GDScript call stack. A repeated physical index is the same cycle guard.
	var chain: Array[int]=[]
	var cursor:=index
	while not emitted.has(cursor):
		if active.has(cursor):
			reject("Model "+current_model_name+" has a parent cycle at "+str(source_nodes[cursor].name))
			for pending in chain:active.erase(pending)
			return -1
		active[cursor]=true;chain.append(cursor)
		var source: Dictionary=source_nodes[cursor]
		# modelParentIndices resolves only the exact last-name match. A missing
		# parent name is an orphan root, including a case-only mismatch.
		var parent_index:=int(by_name.get(source.parent_name,-1)) if str(source.parent_name)!="NULL" else -1
		if parent_index<0:break
		cursor=parent_index
	var parent:=int(emitted[cursor]) if emitted.has(cursor) else -1
	while not chain.is_empty():
		var child: int=chain.pop_back()
		parent=_emit_node_with_parent(child,parent)
		active.erase(child)
		if not failure.is_empty():
			for pending in chain:active.erase(pending)
			return -1
	return int(emitted[index])
func _emit_node_with_parent(index: int,parent: int) -> int:
	var source: Dictionary=source_nodes[index]
	var decoded: Array=Orientation.decode(source.orientation,"axis-angle")
	var q:=Quaternion(decoded[0],decoded[1],decoded[2],decoded[3])
	var features: Array=[]
	var feature: String={"light":"light","emitter":"emitter","reference":"reference","skin":"skin","animmesh":"animated-mesh","danglymesh":"dangly","aabb":"aabb"}.get(source.kind,"")
	if not feature.is_empty(): features.append(feature)
	var row: Dictionary={"name":source.name,"parent":parent,"source_index":index,"flags":0,"position":source.position,"orientation":[q.x,q.y,q.z,q.w],"scale":source.scale,"alpha":source.alpha,"selfillum":source.selfillum,"features":features,"mesh":{},"properties":source.properties,"light":{}}
	if source.kind=="emitter":
		var emitter:=Emitter.new(); row.emitter=emitter.ascii_properties(source.properties)
		if not emitter.failure.is_empty(): reject(emitter.failure); return -1
	if source.kind=="reference":
		var reattachable:=str(source.properties.get("reattachable","0")); var reattach_values:=numbers(PackedStringArray([reattachable]))
		if reattach_values.size()!=1 or float(reattach_values[0])!=floor(float(reattach_values[0])) or float(reattach_values[0])< -2147483648.0 or float(reattach_values[0])>4294967295.0: reject("Invalid original reference reattachable DWORD"); return -1
		var bits:=int(reattach_values[0])&0xffffffff
		row.flags=0x11; row.reference={"model":str(source.properties.get("refmodel","")),"reattachable":bits-4294967296 if bits>=2147483648 else bits}
	if source.kind=="light":
		row.light={"color":[1.0,1.0,1.0],"radius":0.0,"multiplier":1.0,"shadow":source.shadow,"ambientonly":0}
		for property in ["color","radius","shadowradius","verticaldisplacement","multiplier","lightpriority","ambientonly","isdynamic","affectdynamic","generateflare","fadinglight"]:
			if not source.properties.has(property): continue
			var values:=numbers(str(source.properties[property]).split(" ",false))
			if not values.is_empty(): row.light[property]=values.slice(0,3) if property=="color" and values.size()>=3 else values[0]
	var output_index:=output.size(); output.append(row); emitted[index]=output_index
	var groups:=geometry(source)
	if not failure.is_empty() and failure in ["ASCII MDL face has too few fields","ASCII MDL vertex index invalid"]:
		source.deferred_geometry_error=failure;failure="";groups=[]
	if not groups.is_empty():
		row.mesh=groups[0]
		for group_index in range(1,groups.size()):
			output.append({"name":str(source.name)+"__material_"+str(group_index),"parent":output_index,"source_index":index,"flags":0,"position":[0.0,0.0,0.0],"orientation":[0.0,0.0,0.0,1.0],"scale":1.0,"alpha":source.alpha,"selfillum":source.selfillum,"features":[],"mesh":groups[group_index]})
	return output_index
func geometry(source: Dictionary) -> Array:
	if source.faces.is_empty() and source.verts.is_empty(): return []
	var groups: Array=[]; var material_indices: Array=[]
	var native_metadata:=native_mesh_metadata(source)
	for face in source.faces:
		# groupFacesByMaterial skips incomplete faces before creating a material
		# run; they contribute neither draw triangles nor a parse failure.
		if face.size()<7: continue
		var material_index:=0
		if face.size()>7 and float(face[7])==floor(float(face[7])) and face[7]>=0 and face[7]<source.textures.size(): material_index=int(face[7])
		if material_indices.is_empty() or material_indices.back()!=material_index:
			groups.append({"vertices":PackedFloat32Array(),"normals":PackedFloat32Array(),"uv":[PackedFloat32Array()],"indices":PackedInt32Array(),"collision_indices":PackedInt32Array(),"textures":[source.textures[material_index]] if not source.textures.is_empty() else [],"render":float(source.render)!=0 and source.kind!="aabb","shadow":float(source.shadow)!=0,"transparency_hint":float(source.transparencyhint)!=0,"diffuse":source.diffuse}); material_indices.append(material_index)
			groups.back().merge(native_metadata,true)
		var group: Dictionary=groups.back(); var vertices: Array=[]
		group.ambient=source.ambient
		if source.kind=="animmesh" and not group.has("animation_vertices"): group.animation_vertices=[]; group.animation_uv=[]
		for corner in 3:
			var vertex_index:=int(face[corner])
			if float(face[corner])!=vertex_index or vertex_index<0 or vertex_index>=source.verts.size() or source.verts[vertex_index].size()<3: reject("ASCII MDL vertex index invalid"); return []
			var v: Array=source.verts[vertex_index]; vertices.append(Vector3(v[0],v[1],v[2]))
		var normal: Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
		for corner in 3:
			var vertex: Vector3=vertices[corner]; var uv_index:=-1; var uv:=Vector2.ZERO
			if face.size()>4+corner and float(face[4+corner])==int(face[4+corner]):uv_index=int(face[4+corner])
			if uv_index>=0 and uv_index<source.tverts.size() and source.tverts[uv_index].size()>=2: uv=Vector2(source.tverts[uv_index][0],source.tverts[uv_index][1])
			if source.kind=="animmesh": group.animation_vertices.append(int(face[corner])); group.animation_uv.append(uv_index)
			group.vertices.append_array(PackedFloat32Array([vertex.x,vertex.y,vertex.z])); group.normals.append_array(PackedFloat32Array([normal.x,normal.y,normal.z])); group.uv[0].append_array(PackedFloat32Array([uv.x,uv.y])); group.indices.append(group.indices.size()); group.collision_indices.append(group.collision_indices.size())
	return groups
func native_tilefade_field(source: Dictionary,text: String) -> void:
	# Parse(char*,int&)0a0280: %d first; return0 then token TRUE/FALSE;
	# unknown/empty retains the previous field. Process every occurrence rather
	# than only the final property, so "1" then "unknown" correctly retains1.
	source.native_tilefade_ascii=text
	if native_integer_pattern==null:native_integer_pattern=RegEx.new();native_integer_pattern.compile("^\\s*([+-]?[0-9]+)")
	var match_value:=native_integer_pattern.search(text)
	if match_value!=null:
		var token: String=match_value.get_string(1);var negative:=token.begins_with("-")
		var digits:=token.trim_prefix("-").trim_prefix("+")
		while digits.length()>1 and digits.begins_with("0"):digits=digits.substr(1)
		var limit:="2147483648" if negative else "2147483647"
		if digits.length()>10 or digits.length()==10 and digits>limit:
			source.native_tilefade=null;source.native_tilefade_available=false;source.native_tilefade_source="ascii_integer_overflow_unresolved";return
		source.native_tilefade=token.to_int()&0xffffffff;source.native_tilefade_available=true;source.native_tilefade_source="ascii_decimal_prefix";return
	var tokens:=text.strip_edges().split(" ",false)
	if not tokens.is_empty() and tokens[0].to_lower() in ["true","false"]:
		source.native_tilefade=1 if tokens[0].to_lower()=="true" else 0;source.native_tilefade_available=true;source.native_tilefade_source="ascii_boolean_token"
func native_mesh_metadata(source: Dictionary) -> Dictionary:
	# Once per physical source, shared by material groups. Native ASCII ctor
	# zeroes C0..D4; explicit bmin/bmax seed those fields, then ProcessVerts
	# reduces ALL original input vertices BEFORE face reindexing. Our generated
	# face-corner AABB would lose origin, unused vertices and original seeds.
	var result: Dictionary={"native_bounds":null,"native_bounds_available":false,"native_bounds_valid":false,"native_bounds_source":"ascii_processverts_unavailable","native_bounds_offset":null}
	var minimum: Array=[0.0,0.0,0.0];var maximum: Array=[0.0,0.0,0.0];var scratch:=PackedFloat32Array([0.0])
	# Exact native ProcessVerts proof currently covers ordinary unprocessed
	# trimesh. Subtype/processed bypass ownership is not inferred from geometry.
	var available: bool=source.kind=="trimesh"
	if not available:result.native_bounds_source="ascii_subtype_bounds_unproven"
	for entry in [["bmin",minimum],["bmax",maximum]]:
		if not available:break
		if not source.properties.has(entry[0]):continue
		var tokens:=str(source.properties[entry[0]]).split(" ",false)
		if tokens.size()<3:available=false;break
		for axis in 3:
			if not tokens[axis].is_valid_float() or not is_finite(tokens[axis].to_float()):available=false;break
			scratch[0]=tokens[axis].to_float();entry[1][axis]=scratch[0]
		if not available:break
	if available:
		for vertex in source.verts:
			if vertex.size()<3:available=false;break
			for axis in 3:
				scratch[0]=float(vertex[axis]);var value: float=scratch[0]
				if value<float(minimum[axis]):minimum[axis]=value
				if value>float(maximum[axis]):maximum[axis]=value
	if available:
		result.native_bounds={"min":minimum,"max":maximum};result.native_bounds_available=true;result.native_bounds_valid=true;result.native_bounds_source="ascii_processverts"
		for axis in 3:
			if not is_finite(float(minimum[axis])) or not is_finite(float(maximum[axis])) or float(minimum[axis])>float(maximum[axis]):result.native_bounds_valid=false
	result.native_tilefade=source.get("native_tilefade");result.native_tilefade_available=source.get("native_tilefade_available",false);result.native_tilefade_source=source.get("native_tilefade_source","ascii_unavailable")
	if source.has("native_tilefade_ascii"):result.native_tilefade_ascii=source.native_tilefade_ascii
	result.native_render_raw=source.render;result.native_render_source="ascii_field" if source.properties.has("render") else "client_parser_default"
	return result
