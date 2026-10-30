extends RefCounted
# Data-only deferred expansion: original binary32 controller pools or ASCII
# double-precision keys. No clip, event, binding, rule or key is discarded.
static var native_available: bool=ClassDB.class_exists(&"NwnParticleKernel") and ClassDB.class_has_method(&"NwnParticleKernel",&"animation_keys_valid")
static func valid(data: Dictionary) -> bool:
	if native_available and not OS.get_cmdline_user_args().has("--animation-keys=gd") and not data.has("time_values") and data.values is PackedFloat32Array:
		return ClassDB.class_call_static(&"NwnParticleKernel",&"animation_keys_valid",data.values,int(data.times),int(data.first),int(data.rows),int(data.components)*(3 if data.bezier else 1))
	return valid_gd(data)
static func valid_gd(data: Dictionary) -> bool:
	var values: Variant=data.values; var previous:=-1.0
	var stride:=int(data.components)*(3 if data.bezier else 1)
	var first:=int(data.first); var rows:=int(data.rows); var times:=int(data.get("times",0))
	if first<0 or times<0 or rows<0 or rows>1000000 or stride<1 or stride>12 or first>values.size() or rows>(values.size()-first)/stride: return false
	if data.has("time_values"):
		if data.time_values.size()<rows: return false
	elif times>values.size() or rows>values.size()-times: return false
	for row in int(data.rows):
		var time:=float(data.time_values[row]) if data.has("time_values") else float(values[int(data.times)+row])
		if not is_finite(time) or time<0 or time<previous: return false
		previous=time
		for component in stride:
			if not is_finite(float(values[int(data.first)+row*stride+component])): return false
	return true
static func frames(track: Dictionary) -> Array:
	if not track.has("packed_frames"): return track.frames
	var data: Dictionary=track.packed_frames; var values: Variant=data.values
	var components:=int(data.components); var stride:=components*(3 if data.bezier else 1)
	var output: Array=[]; var scale:=float(track.get("position_scale",1.0))
	for row in int(data.rows):
		var frame:={"time":float(data.time_values[row]) if data.has("time_values") else float(values[int(data.times)+row]),"value":[]}
		for component in components: frame.value.append(float(values[int(data.first)+row*stride+component]))
		if track.property=="orientation":
			if data.get("ascii_axis_angle",false): frame.value=axis_angle(frame.value)
			elif not data.get("axis_angle_converted",false):
				var v: Array=frame.value; var length:=sqrt(v[0]*v[0]+v[1]*v[1]+v[2]*v[2]+v[3]*v[3])
				frame.value=v.map(func(value):return float(value)/length) if length>=1e-8 else [0.0,0.0,0.0,1.0]
		if data.bezier:
			for side in ["in","out"]:
				frame[side]=[]
				var offset:=components if side=="in" else components*2
				for component in components: frame[side].append(float(values[int(data.first)+row*stride+offset+component]))
		if track.property=="position" and scale!=1.0:
			for field in ["value","in","out"]:
				if frame.has(field): frame[field]=frame[field].map(func(value):return float(value)*scale)
		output.append(frame)
	return output
static func axis_angle(values: Array) -> Array:
	# Same operation order and double precision as ActorModel.orientation.
	# Defer trigonometry for clips/channels that may never be played.
	var length:=sqrt(float(values[0])*float(values[0])+float(values[1])*float(values[1])+float(values[2])*float(values[2]))
	if length<1e-8 or absf(float(values[3]))<1e-8: return [0.0,0.0,0.0,1.0]
	var factor:=sin(float(values[3])*0.5)/length
	return [float(values[0])*factor,float(values[1])*factor,float(values[2])*factor,cos(float(values[3])*0.5)]
static func point(values: Array) -> Array: return [float(values[0]),float(values[2]),-float(values[1])]
static func quaternion(values: Array) -> Array:
	var basis:=Quaternion(Vector3.RIGHT,-PI/2); var q:=Quaternion(values[0],values[1],values[2],values[3])
	q=basis*(q.normalized() if q.length_squared()>1e-16 else Quaternion.IDENTITY)*basis.inverse()
	return [q.x,q.y,q.z,q.w]
static func keys(channel: Dictionary) -> Array:
	if not channel.has("native_keys"): return channel.keys
	var output: Array=[]
	for frame in frames({"packed_frames":channel.native_keys,"property":channel.source_property,"position_scale":channel.get("position_scale",1.0)}):
		var key:={"time":frame.time,"value":point(frame.value) if channel.property=="position" else (quaternion(frame.value) if channel.property=="quaternion" else [frame.value[0],frame.value[0],frame.value[0]])}
		for tangent in ["in","out"]:
			if frame.has(tangent): key[tangent]=point(frame[tangent]) if channel.property=="position" else [frame[tangent][0],frame[tangent][0],frame[tangent][0]]
		output.append(key)
	return output
