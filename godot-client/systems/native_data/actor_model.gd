extends RefCounted
const SOURCE_DECODER:="mdl-actor-packed-ascii-native-v5"
# Original MDL geometry plus original clips, controller storage and skin arrays.
# Data only: safe on workers. Physical node order is retained for bone slots.
const Binary=preload("res://systems/native_data/binary_data.gd")
const BinaryModel=preload("res://systems/native_data/binary_model.gd")
const AsciiModel=preload("res://systems/native_data/ascii_model.gd")
const AsciiNative=preload("res://systems/native_data/ascii_native_animation.gd")
const Emitter=preload("res://systems/native_data/emitter_data.gd")
const PackedKeys=preload("res://systems/native_data/packed_animation_keys.gd")
var packed_keys:=false
static func configured_typed_ascii_keys() -> bool: return not OS.get_cmdline_user_args().has("--ascii-key-write=arrays")
var typed_ascii_keys:=configured_typed_ascii_keys()
var failure:=""
var reader
var model_end:=0
var raw_start:=0
var physical:=0
var visited: Dictionary={}
static var binary_clip_budget_mutex:=Mutex.new()
# One clip helper globally. AncestorPreparation can own two independent
# speculative helpers, so nested source parsing adds at most one more.
static var binary_clip_helpers_active:=0
static var binary_clip_helpers_started:=0
static var binary_clip_start_fallbacks:=0
static func configured_parallel_binary_clips() -> bool: return OS.get_cmdline_user_args().has("--binary-clips=parallel") or OS.get_cmdline_user_args().has("--binary-clips=inline")
static func _claim_binary_clip_helper() -> bool:
	binary_clip_budget_mutex.lock()
	var accepted: bool=binary_clip_helpers_active<1
	if accepted:binary_clip_helpers_active+=1
	binary_clip_budget_mutex.unlock()
	return accepted
static func _release_binary_clip_helper() -> void:
	binary_clip_budget_mutex.lock();binary_clip_helpers_active-=1;binary_clip_budget_mutex.unlock()
static func binary_clip_helper_snapshot() -> Dictionary:
	binary_clip_budget_mutex.lock()
	var result:={"active":binary_clip_helpers_active,"maximum":1,"started":binary_clip_helpers_started,"start_fallbacks":binary_clip_start_fallbacks,"enabled":configured_parallel_binary_clips()}
	binary_clip_budget_mutex.unlock()
	return result
static func _binary_clip_half(bytes: PackedByteArray,packed: bool,first: int,last: int) -> Dictionary:
	# Both halves read the original immutable bytes, each with its own reader,
	# parser and error state. No header or referenced clip payload is rewritten.
	var parser:=new()
	parser.reader=Binary.new(bytes);parser.model_end=12+parser.reader.u32(4)
	parser.raw_start=parser.model_end;parser.packed_keys=packed
	var clips: Array=parser.binary_animations(first,last)
	return {"clips":clips,"failure":parser.failure,"read_failure":parser.reader.failure}
func _parallel_binary_animations(bytes: PackedByteArray) -> Array:
	var count:=int(reader.u32(12+124));var table:=int(reader.u32(12+120))
	# Keep small, >8 MiB, malformed, or contended sources on the exact serial
	# path. The original bytes are shared read-only, without patched copies.
	if bytes.size()<262144 or bytes.size()>8*1024*1024 or count<16 or count>100000 or table<0 or 12+table>model_end or count*4>model_end-(12+table) or not _claim_binary_clip_helper():
		return binary_animations()
	var split:=int(count/2)
	var worker:=Thread.new()
	# The private inline mode exercises the same fallback as a failed start.
	var started:=ERR_CANT_CREATE if OS.get_cmdline_user_args().has("--binary-clips=inline") else worker.start(_binary_clip_half.bind(bytes,packed_keys,split,count),Thread.PRIORITY_NORMAL)
	if started!=OK:
		binary_clip_budget_mutex.lock();binary_clip_start_fallbacks+=1;binary_clip_budget_mutex.unlock()
		_release_binary_clip_helper()
		return binary_animations()
	binary_clip_budget_mutex.lock();binary_clip_helpers_started+=1;binary_clip_budget_mutex.unlock()
	var first: Dictionary=_binary_clip_half(bytes,packed_keys,0,split)
	var second: Variant=worker.wait_to_finish()
	_release_binary_clip_helper()
	if not second is Dictionary or not second.has("clips"):
		# Neither half touched this parser. A failed helper result can safely use
		# the exact serial reader/error path after its thread has joined.
		return binary_animations()
	# The original loop reports the first direct parser error by clip order;
	# reader errors are observed only after the whole animation pass.
	if not str(first.failure).is_empty():reject(str(first.failure))
	elif not str(second.failure).is_empty():reject(str(second.failure))
	elif not reader.failure.is_empty():reject(reader.failure)
	elif not str(first.read_failure).is_empty():reject(str(first.read_failure))
	elif not str(second.read_failure).is_empty():reject(str(second.read_failure))
	var clips: Array=first.clips
	clips.append_array(second.clips)
	return clips
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
		model.animations=_parallel_binary_animations(bytes) if configured_parallel_binary_clips() else binary_animations()
	else:
		var parser:=AsciiModel.new(); var text: String=reader.text(0,bytes.size()); model=parser.parse(text)
		if not parser.failure.is_empty(): reject(parser.failure); return {}
		ascii_skins(text,model,parser.source_nodes)
		model.animations=ascii_animations(text)
		model.native_ascii_preparation=AsciiNative.new().prepare(text,model,parser.source_nodes)
		if parser.source_nodes.any(func(node):return node.kind=="animmesh"):
			var decoder:=preload("res://systems/native_data/animated_mesh.gd").new(); decoder.ascii_tracks(text,model,parser.source_nodes)
			if not decoder.failure.is_empty(): reject(decoder.failure); return {}
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
		if not in_geometry and line.unicode_at(0) not in [66,98]: continue
		var tokens: PackedStringArray=Binary.ascii_tokens(line,regex); var command:=tokens[0].to_lower()
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
			var values: PackedStringArray=Binary.ascii_tokens(str(lines[index]).strip_edges(),regex); index+=1
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
	if flags&128:
		var decoder:=preload("res://systems/native_data/animated_mesh.gd").new(); row.vertex_animation=decoder.binary(reader,model_end,at)
		if not decoder.failure.is_empty(): reject(decoder.failure); return
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
	pool=reader.data.slice(values,values+value_count*4).to_float32_array()
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
func binary_animations(first_index: int=0,last_index: int=-1) -> Array:
	var clips: Array=[]; var array: int=12+reader.u32(12+120); var count: int=reader.u32(12+124)
	if count>100000 or not bounded(array,count*4): reject("Original animation table is invalid"); return []
	var indices: Variant=count if first_index==0 and last_index<0 else range(first_index,last_index)
	for index in indices:
		var at: int=12+reader.u32(array+index*4)
		if not bounded(at,196): return []
		var clip:={"name":reader.text(at+8,64,true).to_lower(),"length":finite(at+112),"transition":finite(at+116),"root":reader.text(at+120,64,true),"tracks":[],"emitter_tracks":[],"events":[],"unsupported":[],"controller_nodes":[]}
		if float(clip.length)<0 or float(clip.transition)<0:
			# Stock plc_s03a has a negative damage length. Retain that literal
			# header as unavailable playback instead of rejecting valid geometry,
			# other clips, skins and emitter data or inventing a positive duration.
			clip.deferred_invalid_duration=true; clip.deferred_source={"offset":at-12,"root":reader.u32(at+72),"nodes":reader.u32(at+76)}; clips.append(clip); continue
		var events: int=12+reader.u32(at+184); var event_count: int=reader.u32(at+188)
		if event_count>100000 or not bounded(events,event_count*36): reject("Original animation events are invalid"); return []
		for event in event_count: clip.events.append({"time":finite(events+event*36),"name":reader.text(events+event*36+4,32,true)})
		var seen: Dictionary={}; var pending: Array=[reader.u32(at+72)]; var declared: int=reader.u32(at+76)
		while not pending.is_empty():
			var offset:=int(pending.pop_back()); var node:=12+offset
			if seen.has(offset) or seen.size()>=declared or seen.size()>=100000 or not bounded(node,112): reject("Original animation hierarchy is invalid"); return []
			seen[offset]=true; var flags: int=reader.u32(node+108); var name: String=reader.text(node+32,32,true)
			if flags&128:
				var decoder:=preload("res://systems/native_data/animated_mesh.gd").new(); var data:=decoder.binary(reader,model_end,node)
				if not decoder.failure.is_empty(): reject(decoder.failure); return []
				if not clip.has("mesh_tracks"): clip.mesh_tracks=[]
				clip.mesh_tracks.append({"node":name,"data":data})
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
				var emitter_channel:=Emitter.channel(type) if flags&4 else {}
				if not emitter_channel.is_empty(): components=int(emitter_channel.components); property=str(emitter_channel.property)
				if components==0: clip.unsupported.append({"node":name,"controller":type,"flags":flags}); continue
				if (columns&15)!=components or (columns&240)>16 or (type==20 and columns!=4): reject("Original transform controller shape is invalid"); return []
				var bezier: bool=(columns&240)==16; var stride:=components*(3 if bezier else 1)
				if times+rows>value_count or first+rows*stride>value_count: reject("Original transform keys exceed value pool"); return []
				if packed_keys:
					var data:={"values":clip.controller_nodes.back().storage.values88,"times":times,"first":first,"rows":rows,"components":components,"bezier":bezier}
					if not PackedKeys.valid(data): reject("Original animation keys are non-finite or times unordered/negative"); return []
					var track:={"node":name,"property":property,"interpolation":"bezier" if bezier else ("slerp" if property=="orientation" else "linear"),"frames":[],"packed_frames":data}
					if not emitter_channel.is_empty(): track.nativeControllerIndex=key; track.nativeNode=clip.controller_nodes.size()-1
					var target: Array=clip.tracks if emitter_channel.is_empty() else clip.emitter_tracks
					target.append(track); continue
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
				var target: Array=clip.tracks if emitter_channel.is_empty() else clip.emitter_tracks
				var track:={"node":name,"property":property,"interpolation":"bezier" if bezier else ("slerp" if property=="orientation" else "linear"),"frames":frames}
				if not emitter_channel.is_empty(): track.nativeControllerIndex=key; track.nativeNode=clip.controller_nodes.size()-1
				target.append(track)
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
	var clips: Array=[]; var clip: Dictionary={}; var node:=""; var node_type:=""; var lines:=text.replace("\r","").split("\n"); var regex:=RegEx.new(); regex.compile("\\s+"); var index:=0
	while index<lines.size():
		var line:=str(lines[index]).strip_edges(); index+=1
		if line.is_empty() or line.begins_with("#"): continue
		var tokens: PackedStringArray=Binary.ascii_tokens(line,regex); var command:=tokens[0].to_lower()
		if command=="newanim":
			if not clip.is_empty() or tokens.size()<3: reject("Invalid ASCII animation declaration"); return []
			clip={"name":tokens[1].to_lower(),"root":tokens[2],"length":0.0,"transition":0.0,"tracks":[],"emitter_tracks":[],"events":[],"unsupported":[]}; clips.append(clip); continue
		if command=="doneanim": clip={}; node=""; continue
		if clip.is_empty(): continue
		if command in ["length","transtime"]:
			if tokens.size()<2 or not tokens[1].is_valid_float() or not is_finite(float(tokens[1])) or float(tokens[1])<0: reject("Invalid ASCII animation duration"); return []
			clip["length" if command=="length" else "transition"]=float(tokens[1]); continue
		if command=="animroot" and tokens.size()>1: clip.root=tokens[1]; continue
		if command=="event" and tokens.size()>2:
			if not tokens[1].is_valid_float() or not is_finite(float(tokens[1])) or float(tokens[1])<0: reject("Invalid ASCII animation event"); return []
			clip.events.append({"time":float(tokens[1]),"name":" ".join(tokens.slice(2))}); continue
		if command=="node" and tokens.size()>2: node=tokens[2]; node_type=tokens[1].to_lower(); continue
		if command=="endnode": node=""; node_type=""; continue
		if node.is_empty(): continue
		var bezier:=command.ends_with("bezierkey"); var keyed:=command.ends_with("key"); var property:=command.trim_suffix("bezierkey") if bezier else command.trim_suffix("key")
		var components: int={"position":3,"orientation":4,"scale":1}.get(property,0)
		var emitter_components:=Emitter.components(property) if node_type=="emitter" else 0
		if emitter_components>0: components=emitter_components
		if components==0:
			if keyed: clip.unsupported.append({"node":node,"controller":command})
			continue
		if bezier and property=="orientation": reject("ASCII quaternion Bezier controller is unsupported"); return []
		if keyed and tokens.size()>1 and (tokens.size()!=2 or not tokens[1].is_valid_int()): reject("ASCII animation key count is invalid"); return []
		var uncounted:=keyed and tokens.size()==1; var count:=100000 if uncounted else (int(tokens[1]) if keyed else 1)
		if count<0 or count>100000: reject("ASCII animation key count exceeds bound"); return []
		var frames: Array=[]; var ended:=false
		# ASCII keeps its existing double precision and axis-angle conversion.
		# A pair of typed arrays avoids a Dictionary and several Arrays per key.
		var packed_values:=PackedFloat64Array(); var packed_times:=PackedFloat64Array(); var previous_time:=-1.0
		var packed_count:=0; var stride:=components*(3 if bezier else 1)
		for row in count:
			var values: PackedStringArray=tokens.slice(1)
			if keyed:
				while index<lines.size() and (str(lines[index]).strip_edges().is_empty() or str(lines[index]).strip_edges().begins_with("#")): index+=1
				if index>=lines.size(): reject("ASCII animation keys are truncated"); return []
				var next:=str(lines[index]).strip_edges(); index+=1
				if uncounted and next.to_lower()=="endlist": ended=true; break
				values=Binary.ascii_tokens(next,regex)
			else: values.insert(0,"0")
			if values.size()!=1+components*(3 if bezier else 1): reject("ASCII transform key shape is invalid"); return []
			if packed_keys and typed_ascii_keys:
				# Preserve double parsing/validation, but write directly to the typed
				# pools. A boxed Array plus sliced Array plus packed copy per key is
				# unnecessary work and allocator contention on large ASCII clips.
				if packed_count==packed_times.size():
					# Counted streams allocate once. Uncounted streams grow by bounded
					# geometric chunks, avoiding an engine method call for every value.
					var capacity:=count if not uncounted else mini(count,maxi(64,packed_times.size()*2))
					packed_times.resize(capacity); packed_values.resize(capacity*stride)
				var time:=0.0; var first:=packed_count*stride
				for component in values.size():
					var value: String=values[component]
					if not value.is_valid_float(): reject("Non-finite ASCII animation key"); return []
					var number:=float(value)
					if not is_finite(number): reject("Non-finite ASCII animation key"); return []
					if component==0: time=number
					else: packed_values[first+component-1]=number
				# Validate the entire numeric row before time ordering, retaining
				# the reference error precedence for a malformed later component.
				if time<0 or time<previous_time: reject("Original animation times are unordered/negative"); return []
				previous_time=time; packed_times[packed_count]=time; packed_count+=1
				continue
			var numbers: Array=[]
			for value in values:
				if not value.is_valid_float() or not is_finite(float(value)): reject("Non-finite ASCII animation key"); return []
				numbers.append(float(value))
			if packed_keys:
				if float(numbers[0])<0 or float(numbers[0])<previous_time: reject("Original animation times are unordered/negative"); return []
				previous_time=float(numbers[0]); packed_times.append(previous_time)
				packed_values.append_array(PackedFloat64Array(numbers.slice(1)))
				continue
			var frame:={"time":numbers[0],"value":numbers.slice(1,components+1)}
			if property=="orientation": frame.value=orientation(frame.value,true)
			if bezier: frame["in"]=numbers.slice(components+1,components*2+1); frame["out"]=numbers.slice(components*2+1)
			frames.append(frame)
		if uncounted and not ended: reject("ASCII animation list has no endlist"); return []
		if not ordered(frames): return []
		if packed_keys and typed_ascii_keys and packed_count<packed_times.size():
			packed_times.resize(packed_count); packed_values.resize(packed_count*stride)
		if packed_keys and not packed_times.is_empty():
			var target: Array=clip.tracks if emitter_components==0 else clip.emitter_tracks
			target.append({"node":node,"property":property,"interpolation":"bezier" if bezier else ("slerp" if property=="orientation" else "linear"),"frames":[],"packed_frames":{"values":packed_values,"time_values":packed_times,"first":0,"rows":packed_times.size(),"components":components,"bezier":bezier,"ascii_axis_angle":property=="orientation"}})
		elif not frames.is_empty():
			var target: Array=clip.tracks if emitter_components==0 else clip.emitter_tracks
			target.append({"node":node,"property":property,"interpolation":"bezier" if bezier else ("slerp" if property=="orientation" else "linear"),"frames":frames})
	if not clip.is_empty(): reject("ASCII animation is missing doneanim"); return []
	return clips
func render_point(value: Array) -> Array: return [float(value[0]),float(value[2]),-float(value[1])]
func render_quaternion(value: Array) -> Array:
	var basis:=Quaternion(Vector3.RIGHT,-PI/2); var q:=Quaternion(value[0],value[1],value[2],value[3])
	q=basis*(q.normalized() if q.length_squared()>1e-16 else Quaternion.IDENTITY)*basis.inverse()
	return [q.x,q.y,q.z,q.w]
func rig_asset(model: Dictionary) -> Dictionary:
	var defaults: Array=[]; var names: Dictionary={}; var clips: Array=[]; var unsupported: Array=[]; var controlled: Dictionary={}; var clip_indices: Dictionary={}
	for index in model.nodes.size():
		var row: Dictionary=model.nodes[index]; names[str(row.name).to_lower()]=index
		defaults.append({"position":render_point(row.position),"quaternion":render_quaternion(row.orientation),"scale":[row.scale,row.scale,row.scale]})
	for original in model.animations:
		if original.get("deferred_invalid_duration",false):
			unsupported.append("Original clip playback unavailable: "+str(original.name)+" has negative length/transition"); continue
		var clip:={"name":original.name,"length":original.length,"transition":original.transition,"events":original.events,"tracks":[],"emitterTracks":[],"emitterStorage":[],"meshTracks":[]}
		for track in original.get("mesh_tracks",[]):
			if names.has(str(track.node).to_lower()): clip.meshTracks.append({"part":names[str(track.node).to_lower()],"data":track.data})
		var emitter_storage: Dictionary={}
		for track in original.tracks:
			var name:=str(track.node).to_lower()
			if not names.has(name): continue
			var property: String="quaternion" if str(track.property)=="orientation" else str(track.property); var keys: Array=[]
			if track.has("packed_frames"):
				clip.tracks.append({"part":names[name],"property":property,"source_property":str(track.property),"native_keys":track.packed_frames,"position_scale":float(track.get("position_scale",1.0)),"sourceInterpolation":track.interpolation})
				var channel_key:=str(names[name])+":"+property; var previous: Dictionary=controlled.get(channel_key,{})
				controlled[channel_key]={"part":names[name],"property":property,"bezier":bool(previous.get("bezier",false)) or str(track.interpolation)=="bezier"}
				continue
			for frame in track.frames:
				var values: Array=frame.value; var value: Array=render_point(values) if property=="position" else (render_quaternion(values) if property=="quaternion" else [values[0],values[0],values[0]])
				var key:={"time":frame.time,"value":value}
				for tangent in ["in","out"]:
					if frame.has(tangent): key[tangent]=render_point(frame[tangent]) if property=="position" else [frame[tangent][0],frame[tangent][0],frame[tangent][0]]
				keys.append(key)
			clip.tracks.append({"part":names[name],"property":property,"keys":keys,"sourceInterpolation":track.interpolation})
			var channel_key:=str(names[name])+":"+property; var previous: Dictionary=controlled.get(channel_key,{})
			controlled[channel_key]={"part":names[name],"property":property,"bezier":bool(previous.get("bezier",false)) or str(track.interpolation)=="bezier"}
		for track in original.get("emitter_tracks",[]):
			var name:=str(track.node).to_lower()
			if names.has(name):
				var channel:={"part":names[name],"property":track.property,"frames":PackedKeys.frames(track),"sourceInterpolation":track.interpolation}
				if track.has("nativeNode"):
					var storage_index:=int(track.nativeNode); var storage: Dictionary=original.controller_nodes[storage_index].storage
					if not emitter_storage.has(storage_index): emitter_storage[storage_index]=clip.emitterStorage.size(); clip.emitterStorage.append(storage)
					channel.nativeController=storage.controllers78[int(track.nativeControllerIndex)]; channel.nativeStorageIndex=emitter_storage[storage_index]
				clip.emitterTracks.append(channel)
		clip_indices[str(clip.name)]=clips.size()
		clips.append(clip)
		for record in original.get("unsupported",[]):
			var label:="deferred controller "+str(record.get("controller"))+" on "+str(record.get("node"))
			if not unsupported.has(label): unsupported.append(label)
	var result:={"name":model.name,"defaults":defaults,"clips":clips,"unsupported":unsupported,"controlled":controlled,"lazyClips":true,"clipIndex":clip_indices}
	var native:=native_animation(model)
	if not native.is_empty(): result.nativeAnimation=native
	return result
func native_animation(model: Dictionary) -> Dictionary:
	if model.has("native_ascii_preparation"):
		var prepared: Dictionary=model.native_ascii_preparation
		if prepared.get("available",false):return prepared.value
		var unavailable: Dictionary={}
		for clip in model.animations:unavailable[clip.name]={"unavailable":str(prepared.get("reason","Native ASCII controller preparation unavailable"))}
		return {"version":1,"root":-1,"parts":[],"clips":unavailable,"emitterFields":Emitter.FIELDS}
	# Preserve original binary controller storage/IDs and physical child order.
	# ASCII and inherited-clip native run reconstruction remain separate work.
	var parts: Array=[]
	for row in model.nodes:
		if not row.has("controller_storage"): return {}
		var type:="emitter" if row.has("emitter") else "light" if not row.get("light",{}).is_empty() else "trimesh" if not row.get("mesh",{}).is_empty() else "dummy"
		parts.append({"type":type,"properties":row.get("emitter",row.get("light",{})),"transparencyHint":float(row.get("alpha",1.0))<1.0,"node":row.controller_storage,"children":[]})
	var root:=-1
	for index in model.nodes.size():
		var parent:=int(model.nodes[index].parent)
		if parent<0: root=index
		else: parts[parent].children.append(index)
	if root<0: return {}
	var clips: Dictionary={}
	for clip in model.animations:
		if clip.has("inheritedFrom") or clip.get("controller_nodes",[]).is_empty():
			clips[clip.name]={"unavailable":"Native inherited/ASCII animation controller reconstruction pending"}; continue
		var nodes: Dictionary={}
		for row in clip.controller_nodes:
			var data: Dictionary=row.storage.duplicate(); data.children68=[]; data.childCount70=row.children.size(); nodes[int(row.offset)]=data
		for row in clip.controller_nodes:
			for child in row.children: nodes[int(row.offset)].children68.append(nodes[int(child)])
		clips[clip.name]={"root":nodes[int(clip.controller_nodes[0].offset)]}
	return {"version":1,"root":root,"parts":parts,"clips":clips,"emitterFields":Emitter.FIELDS}
