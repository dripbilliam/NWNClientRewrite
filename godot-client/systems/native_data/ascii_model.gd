extends RefCounted
const Emitter=preload("res://systems/native_data/emitter_data.gd")
const Text=preload("res://systems/native_data/binary_data.gd")
# Direct original ASCII MDL static hierarchy and face-corner geometry. No JS,
# Three or scene export. Behavioral headers stay explicit pending features.
var failure:=""
var source_nodes: Array=[]
var output: Array=[]
var by_name: Dictionary={}
var by_folded_name: Dictionary={}
var emitted: Dictionary={}
var active: Dictionary={}
var native_integer_pattern: RegEx
func reject(reason: String) -> void:
	if failure.is_empty(): failure=reason
func numbers(tokens: PackedStringArray) -> Array:
	var values: Array=[]
	for token in tokens:
		# ASCII exporters also serialize smoothing-group bitmasks as 0x...
		if token.to_lower().begins_with("0x") and token.is_valid_hex_number(true): values.append(float(token.hex_to_int())); continue
		if not token.is_valid_float() or not is_finite(token.to_float()): reject("Non-finite or invalid ASCII MDL number: "+token.substr(0,40)); return []
		values.append(token.to_float())
	return values
func parse(text: String) -> Dictionary:
	failure=""; source_nodes.clear(); output.clear(); by_name.clear(); by_folded_name.clear(); emitted.clear(); active.clear()
	var whitespace:=RegEx.new(); whitespace.compile("\\s+")
	var model_name:=""; var in_geometry:=false; var current: Dictionary={}; var array_kind:=""; var remaining:=0; var supermodel:=""; var animation_scale:=1.0; var classification_flags:=0
	for raw in text.replace("\r","").split("\n"):
		var line:=str(raw).strip_edges()
		if line.is_empty() or line.begins_with("#"): continue
		# Numeric animation rows cannot be model-header commands. They are not
		# geometry dependencies and need no token allocation on this pass.
		if remaining==0 and not in_geometry and line.unicode_at(0) in [43,45,46,48,49,50,51,52,53,54,55,56,57]: continue
		var tokens: PackedStringArray=Text.ascii_tokens(line,whitespace)
		if remaining>0:
			var values:=numbers(tokens)
			if not failure.is_empty(): return {}
			current[array_kind].append(values); remaining-=1; continue
		var command:=tokens[0].to_lower()
		if command=="newmodel" and tokens.size()>1: model_name=tokens[1]; continue
		# classification1400a11b0: unknown names retain the previous byte.
		if command=="classification" and tokens.size()>1:
			classification_flags=int({"tile":2,"character":4,"effect":1,"effects":1,"door":8}.get(tokens[1].to_lower(),classification_flags)); continue
		if command=="setsupermodel" and tokens.size()>2: supermodel=tokens[2].to_lower(); continue
		if command=="setanimationscale" and tokens.size()>1:
			var values:=numbers(tokens.slice(1)); if values.is_empty(): return {}
			animation_scale=float(values[0]); continue
		if command=="beginmodelgeom": in_geometry=true; continue
		if command=="endmodelgeom": in_geometry=false; current={}; continue
		if not in_geometry: continue
		if command=="node":
			if tokens.size()<3 or not current.is_empty() or source_nodes.size()>=100000: reject("Invalid ASCII MDL node declaration"); return {}
			var name: String=" ".join(tokens.slice(2))
			# Installed pfh0 legitimately declares two physical Impact nodes.
			# Keep both physical records; name lookup follows the existing JS
			# parser's final declaration, rather than rejecting the whole actor.
			current={"name":name,"kind":tokens[1].to_lower(),"parent_name":"NULL","position":[0.0,0.0,0.0],"orientation":[0.0,0.0,1.0,0.0],"scale":1.0,"alpha":1.0,"selfillum":[0.0,0.0,0.0],"diffuse":[1.0,1.0,1.0],"shadow":0 if tokens[1].to_lower()=="light" else 1,"render":1,"transparencyhint":0,"verts":[],"tverts":[],"faces":[],"textures":[],"properties":{}}
			current.native_tilefade=0;current.native_tilefade_available=true;current.native_tilefade_source="ascii_constructor_default"
			current.ambient=[1.0,1.0,1.0]
			by_name[name]=source_nodes.size()
			var folded:=name.to_lower()
			if not by_folded_name.has(folded): by_folded_name[folded]=[]
			by_folded_name[folded].append(source_nodes.size()); source_nodes.append(current); continue
		if command=="endnode": current={}; continue
		if current.is_empty(): continue
		if tokens.size()>1: current.properties[command]=" ".join(tokens.slice(1))
		if command=="tilefade":native_tilefade_field(current," ".join(tokens.slice(1)));continue
		if command=="parent": current.parent_name=" ".join(tokens.slice(1)); continue
		if command=="bitmap" and tokens.size()>1: current.textures.append(tokens[1].to_lower()); continue
		# Emitter 'render Normal' is a mode, not a mesh visibility number.
		if command=="render" and current.kind=="emitter": continue
		if command in ["verts","tverts","faces"]:
			if tokens.size()!=2 or not tokens[1].is_valid_int() or tokens[1].to_int()<0 or tokens[1].to_int()>1000000: reject("Invalid ASCII MDL array count"); return {}
			array_kind=command; remaining=tokens[1].to_int(); continue
		if command in ["position","orientation","scale","alpha","selfillumcolor","ambient","diffuse","render","shadow","transparencyhint"]:
			var values:=numbers(tokens.slice(1)); var count:=4 if command=="orientation" else (3 if command in ["position","selfillumcolor","ambient","diffuse"] else 1)
			if not failure.is_empty() or values.size()<count: reject("Invalid ASCII MDL static property"); return {}
			var key:="selfillum" if command=="selfillumcolor" else command
			current[key]=values[0] if count==1 else values.slice(0,count)
	if remaining>0 or model_name.is_empty() or source_nodes.is_empty(): reject("Truncated or missing ASCII MDL model/arrays"); return {}
	for index in source_nodes.size(): emit_node(index,0)
	if not failure.is_empty(): return {}
	return {"name":model_name,"nodes":output,"classification_flags":classification_flags,"source_node_count":source_nodes.size(),"supermodel":supermodel,"animation_scale":animation_scale,"format":"ASCII MDL","scope":"Original static ASCII MDL; animation, skin, reference, light/emitter behavior pending"}
func emit_node(index: int, depth: int) -> int:
	if emitted.has(index): return int(emitted[index])
	if active.has(index) or depth>128: reject("ASCII MDL hierarchy cycle/depth"); return -1
	active[index]=true
	var source: Dictionary=source_nodes[index]; var parent:=-1
	if str(source.parent_name).to_upper()!="NULL":
		var parent_index:=int(by_name.get(source.parent_name,-1))
		if parent_index<0:
			# Original distributed ASCII models can reference an existing parent
			# with different capitalization (AShTo_041 / ashto_041). Preserve
			# authored names/physical nodes and exact-name duplicate behavior;
			# resolve only an unambiguous folded alias, never invent an orphan root.
			var aliases: Array=by_folded_name.get(str(source.parent_name).to_lower(),[])
			if aliases.size()!=1: reject("ASCII MDL parent missing" if aliases.is_empty() else "ASCII MDL parent case alias ambiguous"); return -1
			parent_index=int(aliases[0])
		parent=emit_node(parent_index,depth+1)
		if not failure.is_empty(): return -1
	var axis:=Vector3(source.orientation[0],source.orientation[1],source.orientation[2]); var q:=Quaternion.IDENTITY
	if axis.length()>1e-8 and absf(float(source.orientation[3]))>1e-8: q=Quaternion(axis.normalized(),float(source.orientation[3]))
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
	if not groups.is_empty():
		row.mesh=groups[0]
		for group_index in range(1,groups.size()):
			output.append({"name":str(source.name)+"__material_"+str(group_index),"parent":output_index,"source_index":index,"flags":0,"position":[0.0,0.0,0.0],"orientation":[0.0,0.0,0.0,1.0],"scale":1.0,"alpha":source.alpha,"selfillum":source.selfillum,"features":[],"mesh":groups[group_index]})
	active.erase(index); return output_index
func geometry(source: Dictionary) -> Array:
	if source.faces.is_empty() and source.verts.is_empty(): return []
	var groups: Array=[]; var material_indices: Array=[]
	var native_metadata:=native_mesh_metadata(source)
	for face in source.faces:
		if face.size()<7: reject("ASCII MDL face has too few fields"); return []
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
			var vertex: Vector3=vertices[corner]; var uv_index:=int(face[4+corner]); var uv:=Vector2.ZERO
			if float(face[4+corner])!=uv_index: reject("ASCII MDL UV index invalid"); return []
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
