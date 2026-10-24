extends RefCounted
# Original MDL geometry plus original clips, controller storage and skin arrays.
# Data only: safe on workers. Physical node order is retained for bone slots.
const Binary=preload("res://systems/native_data/binary_data.gd")
const BinaryModel=preload("res://systems/native_data/binary_model.gd")
const AsciiModel=preload("res://systems/native_data/ascii_model.gd")
var failure:=""
var reader
var model_end:=0
var raw_start:=0
var physical:=0
var visited: Dictionary={}
func reject(reason: String) -> void:
	if failure.is_empty(): failure=reason
func bounded(at: int,size: int) -> bool:
	if at<12 or size<0 or at>model_end or size>model_end-at: reject("Original actor model range exceeds model section"); return false
	return true
func finite(at: int) -> float:
	var value: float=reader.f32(at)
	if not is_finite(value): reject("Non-finite original actor value")
	return value
func parse(bytes: PackedByteArray) -> Dictionary:
	failure=""; reader=Binary.new(bytes); visited={}; physical=0
	var model: Dictionary={}
	if bytes.size()>=4 and bytes.decode_u32(0)==0:
		var parser:=BinaryModel.new(); model=parser.parse(bytes)
		if not parser.failure.is_empty(): reject(parser.failure); return {}
		model_end=12+reader.u32(4); raw_start=model_end
		if not bounded(12,232): return {}
		model.supermodel=reader.text(12+168,64,true).to_lower(); model.animation_scale=finite(12+164)
		binary_parts(reader.u32(84),model.nodes,0)
		model.animations=binary_animations()
	else:
		var parser:=AsciiModel.new(); var text: String=reader.text(0,bytes.size()); model=parser.parse(text)
		if not parser.failure.is_empty(): reject(parser.failure); return {}
		ascii_skins(text,model,parser.source_nodes)
		model.animations=ascii_animations(text)
	if not reader.failure.is_empty(): reject(reader.failure)
	if not is_finite(float(model.get("animation_scale",1.0))) or float(model.get("animation_scale",1.0))<0: reject("Original actor animation scale is invalid")
	if not failure.is_empty(): return {}
	model.behavior_version=2
	return model
func ascii_skins(text: String,model: Dictionary,sources: Array) -> void:
	var weights_by_name: Dictionary={}; var lines:=text.replace("\r","").split("\n"); var regex:=RegEx.new(); regex.compile("\\s+"); var current:=""; var index:=0; var in_geometry:=false
	while index<lines.size():
		var line:=str(lines[index]).strip_edges(); index+=1
		if line.is_empty() or line.begins_with("#"): continue
		var tokens: PackedStringArray=regex.sub(line," ",true).split(" ",false); var command:=tokens[0].to_lower()
		if command=="beginmodelgeom": in_geometry=true; continue
		if command=="endmodelgeom": in_geometry=false; continue
		if not in_geometry: continue
		if command=="node": current=tokens[2].to_lower() if tokens.size()>2 and tokens[1].to_lower()=="skin" else ""; continue
		if command=="endnode": current=""; continue
		if command!="weights" or current.is_empty(): continue
		if tokens.size()!=2 or not tokens[1].is_valid_int() or int(tokens[1])<0 or int(tokens[1])>1000000: reject("Original ASCII skin weight count is invalid"); return
		var rows: Array=[]
		for vertex in int(tokens[1]):
			while index<lines.size() and (str(lines[index]).strip_edges().is_empty() or str(lines[index]).strip_edges().begins_with("#")): index+=1
			if index>=lines.size(): reject("Original ASCII skin weights are truncated"); return
			var values: PackedStringArray=regex.sub(str(lines[index]).strip_edges()," ",true).split(" ",false); index+=1
			if values.size()%2!=0 or values.size()>8: reject("Original ASCII skin influence shape is invalid"); return
			var influences: Array=[]
			for component in values.size()/2:
				var number: String=values[component*2+1]
				if not number.is_valid_float() or not is_finite(float(number)) or float(number)<0: reject("Original ASCII skin influence is invalid"); return
				influences.append({"bone":values[component*2].to_lower(),"weight":float(number)})
			rows.append(influences)
		weights_by_name[current]=rows
	var names: Dictionary={}; var rests: Array=[]
	for part in model.nodes.size():
		var node: Dictionary=model.nodes[part]; names[str(node.name).to_lower()]=part
		var q:=Quaternion(node.orientation[0],node.orientation[1],node.orientation[2],node.orientation[3]); var local:=Transform3D(Basis(q),Vector3(node.position[0],node.position[1],node.position[2])); var parent:=int(node.parent)
		rests.append(local if parent<0 else rests[parent]*local)
	var group_indices: Dictionary={}
	for part in model.nodes.size():
		var node: Dictionary=model.nodes[part]; var source_index:=int(node.source_index); var source: Dictionary=sources[source_index]
		if str(source.kind)!="skin" or node.mesh.is_empty(): continue
		var weights: Array=weights_by_name.get(str(source.name).to_lower(),[])
		if weights.size()!=source.verts.size(): reject("Original ASCII skin has no matching per-vertex weights: "+str(source.name)); return
		var mapping: Array=[]; var groups: Array=[]; var previous_material:=-1
		for face in source.faces:
			var material:=int(face[7]) if face.size()>7 and float(face[7])==floor(float(face[7])) and face[7]>=0 and face[7]<source.textures.size() else 0
			if material!=previous_material: groups.append([]); previous_material=material
			groups.back().append_array([int(face[0]),int(face[1]),int(face[2])])
		var group:=int(group_indices.get(source_index,0)); group_indices[source_index]=group+1
		if group>=groups.size(): reject("Original ASCII skin material mapping is invalid"); return
		mapping=groups[group]
		var slots:=PackedInt32Array(); slots.resize(64); slots.fill(-1); var bone_slots: Dictionary={}; var original_weights:=PackedFloat32Array(); var original_bones:=PackedInt32Array()
		for influences in weights:
			for component in 4:
				var weight:=float(influences[component].weight) if component<influences.size() else 0.0; var slot:=0
				if weight>0:
					var bone_name:=str(influences[component].bone)
					if not names.has(bone_name): reject("Original ASCII skin bone is absent: "+bone_name); return
					var bone:=int(names[bone_name])
					if not bone_slots.has(bone):
						if bone_slots.size()>=64: reject("Original ASCII skin exceeds native bone slots"); return
						bone_slots[bone]=bone_slots.size(); slots[int(bone_slots[bone])]=bone
					slot=int(bone_slots[bone])
				original_weights.append(weight); original_bones.append(slot)
		var skin_data:={"weights":PackedFloat32Array(),"boneIndices":PackedInt32Array(),"boneConstantSlots":slots,"qboneRefInv":[],"tboneRefInv":[],"boneIndexTable":[],"boneConstantIndices":[],"ascii_bind":true,"originalWeights":original_weights,"originalBones":original_bones,"sourceVertices":mapping}
		for bone in model.nodes.size():
			var inverse: Transform3D=rests[bone].affine_inverse()*rests[part] if bone_slots.has(bone) else Transform3D.IDENTITY
			var q:=inverse.basis.get_rotation_quaternion(); skin_data.qboneRefInv.append([q.w,q.x,q.y,q.z]); skin_data.tboneRefInv.append([inverse.origin.x,inverse.origin.y,inverse.origin.z])
		for vertex in mapping:
			for component in 4: skin_data.weights.append(original_weights[int(vertex)*4+component]); skin_data.boneIndices.append(original_bones[int(vertex)*4+component])
		node.skin=skin_data
func binary_parts(offset: int,nodes: Array,depth: int) -> void:
	if not failure.is_empty(): return
	var at:=12+offset
	if depth>128 or visited.has(offset) or physical>=nodes.size() or not bounded(at,112): reject("Original actor physical hierarchy is invalid"); return
	visited[offset]=true; var index:=physical; physical+=1
	var row: Dictionary=nodes[index]; var flags: int=reader.u32(at+108)
	row.controller_storage=storage(at)
	var cursor:=at+112+(92 if flags&2 else 0)+(216 if flags&4 else 0)+(68 if flags&16 else 0)+(512 if flags&32 else 0)
	if flags&64: row.skin=skin(cursor,int(row.mesh.get("vertices",PackedFloat32Array()).size()/3))
	var children: int=reader.u32(at+72); var count: int=reader.u32(at+76)
	if not bounded(12+children,count*4): return
	for child in count: binary_parts(reader.u32(12+children+child*4),nodes,depth+1)
static func remap_controller(value: int,flags: int) -> int:
	flags&=255
	if (flags&5)==5:
		for pair in [[436,84],[392,64],[356,56],[328,48],[276,44],[228,36],[76,28]]:
			if value>=int(pair[0]): return value+int(pair[1])
	elif (flags&33)==33:
		for pair in [[128,40],[116,36],[76,28]]:
			if value>=int(pair[0]): return value+int(pair[1])
	elif (flags&3)==3 and value>=76: return value+28
	return value+24 if value>=72 else (value+8 if value>=8 else value)
func storage(at: int) -> Dictionary:
	var keys: int=12+reader.u32(at+84); var count: int=reader.u32(at+88); var values: int=12+reader.u32(at+96); var value_count: int=reader.u32(at+100); var flags: int=reader.u32(at+108)
	if count>1000000 or value_count>16000000 or not bounded(keys,count*12) or not bounded(values,value_count*4): reject("Original actor controller storage is invalid"); return {}
	var controllers: Array=[]; var pool:=PackedFloat32Array()
	for index in count:
		var key:=keys+index*12
		controllers.append({"displacement0":remap_controller(reader.i32(key),flags),"rows4":reader.u16(key+4),"timeIndex6":reader.u16(key+6),"valueIndex8":reader.u16(key+8),"columnsA":reader.u8(key+10),"paddingB":reader.u8(key+11)})
	for index in value_count: pool.append(reader.f32(values+index*4))
	return {"id34":reader.i32(at+28),"flags98":flags,"controllers78":controllers,"controllerCount80":count,"values88":pool,"valueCount90":value_count}
func skin(at: int,count: int) -> Dictionary:
	if not bounded(at,192): return {}
	var weights_at: int=raw_start+reader.u32(at+12); var bones_at: int=raw_start+reader.u32(at+16)
	if not reader.contains(weights_at,count*16) or not reader.contains(bones_at,count*8): reject("Original actor skin vertices exceed resource"); return {}
	var result:={"weights":PackedFloat32Array(),"boneIndices":PackedInt32Array(),"boneConstantSlots":PackedInt32Array()}
	for index in count*4: result.weights.append(finite(weights_at+index*4)); result.boneIndices.append(reader.u16(bones_at+index*2))
	for slot in 64: result.boneConstantSlots.append(reader.data.decode_s16(at+64+slot*2))
	for definition in [[20,24,2,"boneIndexTable"],[28,32,16,"qboneRefInv"],[40,44,12,"tboneRefInv"],[52,56,4,"boneConstantIndices"]]:
		var cursor: int=12+reader.u32(at+definition[0]); var length: int=reader.u32(at+definition[1]); var stride: int=definition[2]; var key: String=definition[3]
		if length>1000000 or not bounded(cursor,length*stride): reject("Original actor inverse-bind arrays are invalid"); return {}
		var values: Array=[]
		for index in length:
			if stride==2: values.append(reader.u16(cursor+index*stride))
			elif stride==4: values.append(reader.i32(cursor+index*stride))
			else:
				var vector: Array=[]
				for axis in stride/4: vector.append(finite(cursor+index*stride+axis*4))
				values.append(vector)
		result[key]=values
	return result
func binary_animations() -> Array:
	var clips: Array=[]; var array: int=12+reader.u32(12+120); var count: int=reader.u32(12+124)
	if count>100000 or not bounded(array,count*4): reject("Original animation table is invalid"); return []
	for index in count:
		var at: int=12+reader.u32(array+index*4)
		if not bounded(at,196): return []
		var clip:={"name":reader.text(at+8,64,true).to_lower(),"length":finite(at+112),"transition":finite(at+116),"root":reader.text(at+120,64,true),"tracks":[],"events":[],"unsupported":[],"controller_nodes":[]}
		if float(clip.length)<0 or float(clip.transition)<0: reject("Original animation duration is invalid"); return []
		var events: int=12+reader.u32(at+184); var event_count: int=reader.u32(at+188)
		if event_count>100000 or not bounded(events,event_count*36): reject("Original animation events are invalid"); return []
		for event in event_count: clip.events.append({"time":finite(events+event*36),"name":reader.text(events+event*36+4,32,true)})
		var seen: Dictionary={}; var pending: Array=[reader.u32(at+72)]; var declared: int=reader.u32(at+76)
		while not pending.is_empty():
			var offset:=int(pending.pop_back()); var node:=12+offset
			if seen.has(offset) or seen.size()>=declared or seen.size()>=100000 or not bounded(node,112): reject("Original animation hierarchy is invalid"); return []
			seen[offset]=true; var flags: int=reader.u32(node+108); var name: String=reader.text(node+32,32,true)
			var children: int=12+reader.u32(node+72); var child_count: int=reader.u32(node+76)
			if not bounded(children,child_count*4): return []
			var child_offsets: Array=[]
			for child in child_count: child_offsets.append(reader.u32(children+child*4))
			clip.controller_nodes.append({"offset":offset,"name":name,"storage":storage(node),"children":child_offsets})
			for child in child_count: pending.append(reader.u32(children+child*4))
			var keys: int=12+reader.u32(node+84); var key_count: int=reader.u32(node+88); var values: int=12+reader.u32(node+96); var value_count: int=reader.u32(node+100)
			if key_count>1000000 or value_count>16000000 or not bounded(keys,key_count*12) or not bounded(values,value_count*4): return []
			for key in key_count:
				var entry:=keys+key*12; var type: int=reader.u32(entry); var rows: int=reader.u16(entry+4); var times: int=reader.u16(entry+6); var first: int=reader.u16(entry+8); var columns: int=reader.u8(entry+10)
				if rows in [0,65535]: continue
				var components: int={8:3,20:4,36:1}.get(type,0); var property: String={8:"position",20:"orientation",36:"scale"}.get(type,"")
				if components==0: clip.unsupported.append({"node":name,"controller":type,"flags":flags}); continue
				if (columns&15)!=components or (columns&240)>16 or (type==20 and columns!=4): reject("Original transform controller shape is invalid"); return []
				var bezier: bool=(columns&240)==16; var stride:=components*(3 if bezier else 1)
				if times+rows>value_count or first+rows*stride>value_count: reject("Original transform keys exceed value pool"); return []
				var frames: Array=[]
				for row in rows:
					var frame:={"time":finite(values+(times+row)*4),"value":[]}
					for component in components: frame.value.append(finite(values+(first+row*stride+component)*4))
					if property=="orientation": frame.value=orientation(frame.value,false)
					if bezier:
						frame["in"]=[]; frame["out"]=[]
						for component in components: frame["in"].append(finite(values+(first+row*stride+components+component)*4)); frame["out"].append(finite(values+(first+row*stride+components*2+component)*4))
					frames.append(frame)
				if not ordered(frames): return []
				clip.tracks.append({"node":name,"property":property,"interpolation":"bezier" if bezier else ("slerp" if property=="orientation" else "linear"),"frames":frames})
		clips.append(clip)
	return clips
func ordered(frames: Array) -> bool:
	var previous:=-1.0
	for frame in frames:
		if float(frame.time)<0 or float(frame.time)<previous: reject("Original animation times are unordered/negative"); return false
		previous=float(frame.time)
	return true
func orientation(values: Array,axis_angle: bool) -> Array:
	if axis_angle:
		var length:=sqrt(float(values[0])*float(values[0])+float(values[1])*float(values[1])+float(values[2])*float(values[2]))
		if length<1e-8 or absf(float(values[3]))<1e-8: return [0.0,0.0,0.0,1.0]
		var factor:=sin(float(values[3])*0.5)/length
		return [float(values[0])*factor,float(values[1])*factor,float(values[2])*factor,cos(float(values[3])*0.5)]
	var length:=sqrt(float(values[0])*float(values[0])+float(values[1])*float(values[1])+float(values[2])*float(values[2])+float(values[3])*float(values[3]))
	return values.map(func(value): return float(value)/length) if length>=1e-8 else [0.0,0.0,0.0,1.0]
func ascii_animations(text: String) -> Array:
	var clips: Array=[]; var clip: Dictionary={}; var node:=""; var lines:=text.replace("\r","").split("\n"); var regex:=RegEx.new(); regex.compile("\\s+"); var index:=0
	while index<lines.size():
		var line:=str(lines[index]).strip_edges(); index+=1
		if line.is_empty() or line.begins_with("#"): continue
		var tokens: PackedStringArray=regex.sub(line," ",true).split(" ",false); var command:=tokens[0].to_lower()
		if command=="newanim":
			if not clip.is_empty() or tokens.size()<3: reject("Invalid ASCII animation declaration"); return []
			clip={"name":tokens[1].to_lower(),"root":tokens[2],"length":0.0,"transition":0.0,"tracks":[],"events":[],"unsupported":[]}; clips.append(clip); continue
		if command=="doneanim": clip={}; node=""; continue
		if clip.is_empty(): continue
		if command in ["length","transtime"]:
			if tokens.size()<2 or not tokens[1].is_valid_float() or not is_finite(float(tokens[1])) or float(tokens[1])<0: reject("Invalid ASCII animation duration"); return []
			clip["length" if command=="length" else "transition"]=float(tokens[1]); continue
		if command=="animroot" and tokens.size()>1: clip.root=tokens[1]; continue
		if command=="event" and tokens.size()>2:
			if not tokens[1].is_valid_float() or not is_finite(float(tokens[1])) or float(tokens[1])<0: reject("Invalid ASCII animation event"); return []
			clip.events.append({"time":float(tokens[1]),"name":" ".join(tokens.slice(2))}); continue
		if command=="node" and tokens.size()>2: node=tokens[2]; continue
		if command=="endnode": node=""; continue
		if node.is_empty(): continue
		var bezier:=command.ends_with("bezierkey"); var keyed:=command.ends_with("key"); var property:=command.trim_suffix("bezierkey") if bezier else command.trim_suffix("key")
		var components: int={"position":3,"orientation":4,"scale":1}.get(property,0)
		if components==0:
			if keyed: clip.unsupported.append({"node":node,"controller":command})
			continue
		if bezier and property=="orientation": reject("ASCII quaternion Bezier controller is unsupported"); return []
		var uncounted:=keyed and tokens.size()==1; var count:=100000 if uncounted else (int(tokens[1]) if keyed and tokens.size()>1 and tokens[1].is_valid_int() else 1)
		if count<0 or count>100000: reject("ASCII animation key count exceeds bound"); return []
		var frames: Array=[]; var ended:=false
		for row in count:
			var values: PackedStringArray=tokens.slice(1)
			if keyed:
				while index<lines.size() and (str(lines[index]).strip_edges().is_empty() or str(lines[index]).strip_edges().begins_with("#")): index+=1
				if index>=lines.size(): reject("ASCII animation keys are truncated"); return []
				var next:=str(lines[index]).strip_edges(); index+=1
				if uncounted and next.to_lower()=="endlist": ended=true; break
				values=regex.sub(next," ",true).split(" ",false)
			else: values.insert(0,"0")
			if values.size()!=1+components*(3 if bezier else 1): reject("ASCII transform key shape is invalid"); return []
			var numbers: Array=[]
			for value in values:
				if not value.is_valid_float() or not is_finite(float(value)): reject("Non-finite ASCII animation key"); return []
				numbers.append(float(value))
			var frame:={"time":numbers[0],"value":numbers.slice(1,components+1)}
			if property=="orientation": frame.value=orientation(frame.value,true)
			if bezier: frame["in"]=numbers.slice(components+1,components*2+1); frame["out"]=numbers.slice(components*2+1)
			frames.append(frame)
		if uncounted and not ended: reject("ASCII animation list has no endlist"); return []
		if not ordered(frames): return []
		if not frames.is_empty(): clip.tracks.append({"node":node,"property":property,"interpolation":"bezier" if bezier else ("slerp" if property=="orientation" else "linear"),"frames":frames})
	if not clip.is_empty(): reject("ASCII animation is missing doneanim"); return []
	return clips
func render_point(value: Array) -> Array: return [float(value[0]),float(value[2]),-float(value[1])]
func render_quaternion(value: Array) -> Array:
	var basis:=Quaternion(Vector3.RIGHT,-PI/2); var q:=Quaternion(value[0],value[1],value[2],value[3])
	q=basis*(q.normalized() if q.length_squared()>1e-16 else Quaternion.IDENTITY)*basis.inverse()
	return [q.x,q.y,q.z,q.w]
func rig_asset(model: Dictionary) -> Dictionary:
	var defaults: Array=[]; var names: Dictionary={}; var clips: Array=[]; var unsupported: Array=[]; var controlled: Dictionary={}
	for index in model.nodes.size():
		var row: Dictionary=model.nodes[index]; names[str(row.name).to_lower()]=index
		defaults.append({"position":render_point(row.position),"quaternion":render_quaternion(row.orientation),"scale":[row.scale,row.scale,row.scale]})
	for original in model.animations:
		var clip:={"name":original.name,"length":original.length,"transition":original.transition,"events":original.events,"tracks":[]}
		for track in original.tracks:
			var name:=str(track.node).to_lower()
			if not names.has(name): continue
			var property: String="quaternion" if str(track.property)=="orientation" else str(track.property); var keys: Array=[]
			for frame in track.frames:
				var values: Array=frame.value; var value: Array=render_point(values) if property=="position" else (render_quaternion(values) if property=="quaternion" else [values[0],values[0],values[0]])
				var key:={"time":frame.time,"value":value}
				for tangent in ["in","out"]:
					if frame.has(tangent): key[tangent]=render_point(frame[tangent]) if property=="position" else [frame[tangent][0],frame[tangent][0],frame[tangent][0]]
				keys.append(key)
			clip.tracks.append({"part":names[name],"property":property,"keys":keys,"sourceInterpolation":track.interpolation})
			var channel_key:=str(names[name])+":"+property; var previous: Dictionary=controlled.get(channel_key,{})
			controlled[channel_key]={"part":names[name],"property":property,"bezier":bool(previous.get("bezier",false)) or str(track.interpolation)=="bezier"}
		clips.append(clip)
		for record in original.get("unsupported",[]):
			var label:="deferred controller "+str(record.get("controller"))+" on "+str(record.get("node"))
			if not unsupported.has(label): unsupported.append(label)
	return {"name":model.name,"defaults":defaults,"clips":clips,"unsupported":unsupported,"controlled":controlled,"lazyClips":true}
