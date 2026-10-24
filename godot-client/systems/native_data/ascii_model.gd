extends RefCounted
# Direct original ASCII MDL static hierarchy and face-corner geometry. No JS,
# Three or scene export. Behavioral headers stay explicit pending features.
var failure:=""
var source_nodes: Array=[]
var output: Array=[]
var by_name: Dictionary={}
var emitted: Dictionary={}
var active: Dictionary={}
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
	failure=""; source_nodes.clear(); output.clear(); by_name.clear(); emitted.clear(); active.clear()
	var whitespace:=RegEx.new(); whitespace.compile("\\s+")
	var model_name:=""; var in_geometry:=false; var current: Dictionary={}; var array_kind:=""; var remaining:=0; var supermodel:=""; var animation_scale:=1.0
	for raw in text.replace("\r","").split("\n"):
		var line:=str(raw).strip_edges()
		if line.is_empty() or line.begins_with("#"): continue
		var tokens: PackedStringArray=whitespace.sub(line," ",true).split(" ",false)
		if remaining>0:
			var values:=numbers(tokens)
			if not failure.is_empty(): return {}
			current[array_kind].append(values); remaining-=1; continue
		var command:=tokens[0].to_lower()
		if command=="newmodel" and tokens.size()>1: model_name=tokens[1]; continue
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
			if by_name.has(name): reject("Duplicate ASCII MDL physical node name"); return {}
			current={"name":name,"kind":tokens[1].to_lower(),"parent_name":"NULL","position":[0.0,0.0,0.0],"orientation":[0.0,0.0,1.0,0.0],"scale":1.0,"alpha":1.0,"selfillum":[0.0,0.0,0.0],"diffuse":[1.0,1.0,1.0],"shadow":0 if tokens[1].to_lower()=="light" else 1,"render":1,"transparencyhint":0,"verts":[],"tverts":[],"faces":[],"textures":[],"properties":{}}
			by_name[name]=source_nodes.size(); source_nodes.append(current); continue
		if command=="endnode": current={}; continue
		if current.is_empty(): continue
		if tokens.size()>1: current.properties[command]=" ".join(tokens.slice(1))
		if command=="parent": current.parent_name=" ".join(tokens.slice(1)); continue
		if command=="bitmap" and tokens.size()>1: current.textures.append(tokens[1].to_lower()); continue
		# Emitter 'render Normal' is a mode, not a mesh visibility number.
		if command=="render" and current.kind=="emitter": continue
		if command in ["verts","tverts","faces"]:
			if tokens.size()!=2 or not tokens[1].is_valid_int() or tokens[1].to_int()<0 or tokens[1].to_int()>1000000: reject("Invalid ASCII MDL array count"); return {}
			array_kind=command; remaining=tokens[1].to_int(); continue
		if command in ["position","orientation","scale","alpha","selfillumcolor","diffuse","render","shadow","transparencyhint"]:
			var values:=numbers(tokens.slice(1)); var count:=4 if command=="orientation" else (3 if command in ["position","selfillumcolor","diffuse"] else 1)
			if not failure.is_empty() or values.size()<count: reject("Invalid ASCII MDL static property"); return {}
			var key:="selfillum" if command=="selfillumcolor" else command
			current[key]=values[0] if count==1 else values.slice(0,count)
	if remaining>0 or model_name.is_empty() or source_nodes.is_empty(): reject("Truncated or missing ASCII MDL model/arrays"); return {}
	for index in source_nodes.size(): emit_node(index,0)
	if not failure.is_empty(): return {}
	return {"name":model_name,"nodes":output,"source_node_count":source_nodes.size(),"supermodel":supermodel,"animation_scale":animation_scale,"format":"ASCII MDL","scope":"Original static ASCII MDL; animation, skin, reference, light/emitter behavior pending"}
func emit_node(index: int, depth: int) -> int:
	if emitted.has(index): return int(emitted[index])
	if active.has(index) or depth>128: reject("ASCII MDL hierarchy cycle/depth"); return -1
	active[index]=true
	var source: Dictionary=source_nodes[index]; var parent:=-1
	if str(source.parent_name).to_upper()!="NULL":
		if not by_name.has(source.parent_name): reject("ASCII MDL parent missing"); return -1
		parent=emit_node(int(by_name[source.parent_name]),depth+1)
		if not failure.is_empty(): return -1
	var axis:=Vector3(source.orientation[0],source.orientation[1],source.orientation[2]); var q:=Quaternion.IDENTITY
	if axis.length()>1e-8 and absf(float(source.orientation[3]))>1e-8: q=Quaternion(axis.normalized(),float(source.orientation[3]))
	var features: Array=[]
	var feature: String={"light":"light","emitter":"emitter","reference":"reference","skin":"skin","animmesh":"animated-mesh","danglymesh":"dangly","aabb":"aabb"}.get(source.kind,"")
	if not feature.is_empty(): features.append(feature)
	var row: Dictionary={"name":source.name,"parent":parent,"source_index":index,"flags":0,"position":source.position,"orientation":[q.x,q.y,q.z,q.w],"scale":source.scale,"alpha":source.alpha,"selfillum":source.selfillum,"features":features,"mesh":{},"properties":source.properties,"light":{}}
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
	for face in source.faces:
		if face.size()<7: reject("ASCII MDL face has too few fields"); return []
		var material_index:=0
		if face.size()>7 and float(face[7])==floor(float(face[7])) and face[7]>=0 and face[7]<source.textures.size(): material_index=int(face[7])
		if material_indices.is_empty() or material_indices.back()!=material_index:
			groups.append({"vertices":PackedFloat32Array(),"normals":PackedFloat32Array(),"uv":[PackedFloat32Array()],"indices":PackedInt32Array(),"collision_indices":PackedInt32Array(),"textures":[source.textures[material_index]] if not source.textures.is_empty() else [],"render":float(source.render)!=0 and source.kind!="aabb","shadow":float(source.shadow)!=0,"transparency_hint":float(source.transparencyhint)!=0,"diffuse":source.diffuse}); material_indices.append(material_index)
		var group: Dictionary=groups.back(); var vertices: Array=[]
		for corner in 3:
			var vertex_index:=int(face[corner])
			if float(face[corner])!=vertex_index or vertex_index<0 or vertex_index>=source.verts.size() or source.verts[vertex_index].size()<3: reject("ASCII MDL vertex index invalid"); return []
			var v: Array=source.verts[vertex_index]; vertices.append(Vector3(v[0],v[1],v[2]))
		var normal: Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
		for corner in 3:
			var vertex: Vector3=vertices[corner]; var uv_index:=int(face[4+corner]); var uv:=Vector2.ZERO
			if float(face[4+corner])!=uv_index: reject("ASCII MDL UV index invalid"); return []
			if uv_index>=0 and uv_index<source.tverts.size() and source.tverts[uv_index].size()>=2: uv=Vector2(source.tverts[uv_index][0],source.tverts[uv_index][1])
			group.vertices.append_array(PackedFloat32Array([vertex.x,vertex.y,vertex.z])); group.normals.append_array(PackedFloat32Array([normal.x,normal.y,normal.z])); group.uv[0].append_array(PackedFloat32Array([uv.x,uv.y])); group.indices.append(group.indices.size()); group.collision_indices.append(group.collision_indices.size())
	return groups
