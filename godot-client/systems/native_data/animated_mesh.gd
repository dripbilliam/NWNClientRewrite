extends RefCounted
# Serialized MdlNodeAnimMesh reader14007a530 and controller140051e60.
# The serialized samples are vertex-major, not one whole mesh per frame.
const F=preload("res://systems/native_render/particle_math.gd")
var failure:=""
func ascii_tracks(text: String,model: Dictionary,sources: Array) -> void:
	var records: Dictionary={}; var clip:=""; var node:=""; var lines:=text.replace("\r","").split("\n"); var cursor:=0
	var regex:=RegEx.new(); regex.compile("\\s+")
	while cursor<lines.size():
		var line:=str(lines[cursor]).strip_edges(); cursor+=1
		if line.is_empty() or line.begins_with("#"): continue
		var tokens: PackedStringArray=preload("res://systems/native_data/binary_data.gd").ascii_tokens(line,regex); var command:=tokens[0].to_lower()
		if command=="newanim" and tokens.size()>1: clip=tokens[1].to_lower(); records[clip]={}; continue
		if command=="doneanim": clip=""; node=""; continue
		if clip.is_empty(): continue
		if command=="node":
			node=tokens[2].to_lower() if tokens.size()>2 and tokens[1].to_lower()=="animmesh" else ""
			if not node.is_empty(): records[clip][node]={"period":0.0,"animverts":[],"animtverts":[]}
			continue
		if command=="endnode": node=""; continue
		if node.is_empty(): continue
		if command=="sampleperiod":
			if tokens.size()!=2 or not tokens[1].is_valid_float() or not is_finite(float(tokens[1])) or float(tokens[1])<0: failure="Invalid ASCII animated-mesh sample period"; return
			records[clip][node].period=float(tokens[1]); continue
		if command not in ["animverts","animtverts"]: continue
		if tokens.size()!=2 or not tokens[1].is_valid_int() or int(tokens[1])<0 or int(tokens[1])>1000000: failure="Invalid ASCII animated-mesh array count"; return
		for row in int(tokens[1]):
			while cursor<lines.size() and (str(lines[cursor]).strip_edges().is_empty() or str(lines[cursor]).strip_edges().begins_with("#")): cursor+=1
			if cursor>=lines.size(): failure="Truncated ASCII animated-mesh array"; return
			var values: PackedStringArray=preload("res://systems/native_data/binary_data.gd").ascii_tokens(str(lines[cursor]).strip_edges(),regex); cursor+=1
			if values.size()!=3: failure="Invalid ASCII animated-mesh sample shape"; return
			for value in values:
				if not value.is_valid_float() or not is_finite(float(value)): failure="Non-finite ASCII animated-mesh sample"; return
				records[clip][node][command].append(float(value))
	for animation in model.animations:
		for part in model.nodes:
			var source: Dictionary=sources[int(part.source_index)]; var record: Dictionary=records.get(str(animation.name),{}).get(str(source.name).to_lower(),{})
			if source.kind!="animmesh" or record.is_empty() or part.mesh.is_empty(): continue
			var data:={"vertices":part.mesh.animation_vertices.size(),"period":record.period,"position_frames":0,"uv_frames":0,"positions":PackedFloat32Array(),"uv":PackedFloat32Array()}
			for kind in ["positions","uv"]:
				var input: Array=record.animverts if kind=="positions" else record.animtverts
				if input.is_empty(): continue
				var source_count: int=source.verts.size() if kind=="positions" else source.tverts.size(); var components:=3 if kind=="positions" else 2
				if source_count<=0 or input.size()%(source_count*3)!=0: failure="ASCII animated-mesh samples do not match original topology"; return
				var frames:=int(input.size()/(source_count*3)); data["position_frames" if kind=="positions" else "uv_frames"]=frames
				if frames>1 and float(data.period)<=0: failure="ASCII animated-mesh frames need a sample period"; return
				var mapping: Array=part.mesh.animation_vertices if kind=="positions" else part.mesh.animation_uv
				var output:=PackedFloat32Array()
				for index in mapping:
					if int(index)<0 or int(index)>=source_count: failure="ASCII animated-mesh source index is invalid"; return
					for frame in frames:
						for axis in components: output.append(input[(frame*source_count+int(index))*3+axis])
				data[kind]=output
			if not animation.has("mesh_tracks"): animation.mesh_tracks=[]
			animation.mesh_tracks.append({"node":part.name,"data":data})
func binary(reader,model_end: int,node: int) -> Dictionary:
	if node<12 or node+0x2a8>model_end: failure="Original animated-mesh header exceeds model section"; return {}
	var count:=int(reader.u16(node+0x230)); var period: float=reader.f32(node+0x270)
	var result:={"vertices":count,"period":period,"position_frames":int(reader.u32(node+0x2a0)),"uv_frames":int(reader.u32(node+0x2a4)),"positions":PackedFloat32Array(),"uv":PackedFloat32Array()}
	if not is_finite(period) or period<0: failure="Invalid original animated-mesh sample period"; return {}
	for kind in ["positions","uv"]:
		var frames: int=result.position_frames if kind=="positions" else result.uv_frames; var components:=3 if kind=="positions" else 2
		if frames<0 or frames>1000000 or count*frames*components>16000000 or (frames>1 and period<=0): failure="Invalid original animated-mesh sample count"; return {}
		if frames==0: continue
		var offset:=12+int(reader.u32(node+(0x298 if kind=="positions" else 0x29c))); var values: int=count*frames*components
		if offset<12 or offset>model_end or values*4>model_end-offset: failure="Original animated-mesh samples exceed model section"; return {}
		var output:=PackedFloat32Array(); output.resize(values)
		for index in values:
			var value: float=reader.f32(offset+index*4)
			if not is_finite(value): failure="Non-finite original animated-mesh sample"; return {}
			output[index]=value
		result[kind]=output
	return result
static func sample(data: Dictionary,time: float) -> Dictionary:
	var out: Dictionary={}; var period:=float(data.period); var phase:=F.f(F.f(time)/period) if period>0 else 0.0; var index:=int(phase)
	for kind in ["positions","uv"]:
		var count: int=data.position_frames if kind=="positions" else data.uv_frames; var components:=3 if kind=="positions" else 2
		if count<=0: continue
		var interpolate:=index>=0 and index<count-1
		# The original position endpoint clamp updates the shared index before
		# processing UVs. Unequal stream lengths retain that observable behavior.
		if kind=="positions" and not interpolate: index=clampi(index,0,count-1)
		var first:=clampi(index,0,count-1); var second:=mini(first+1,count-1); var blend:=F.f(phase-index) if interpolate else 0.0
		var values: PackedFloat32Array=data[kind]; var result:=PackedFloat32Array(); result.resize(int(data.vertices)*components)
		for vertex in int(data.vertices):
			for axis in components:
				var a: float=values[(vertex*count+first)*components+axis]; var b: float=values[(vertex*count+second)*components+axis]
				result[vertex*components+axis]=F.f(F.f(F.f(1.0-blend)*a)+F.f(blend*b))
		out[kind]=result
	return out
