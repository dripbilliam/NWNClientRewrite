extends RefCounted
# Fixed GUI state sampling. Original clips supply transforms and vertex/UV data;
# composing size/thumbsize does not rescale a finished screenshot.
const Keys=preload("res://systems/native_data/packed_animation_keys.gd")
static func sample(keys: Array,time: float,property: String,interpolation: String) -> Array:
	if keys.is_empty(): return []
	if time<=float(keys[0].time): return keys[0].value.duplicate()
	if time>=float(keys[-1].time): return keys[-1].value.duplicate()
	var upper:=1
	while upper<keys.size() and float(keys[upper].time)<=time: upper+=1
	var a: Dictionary=keys[upper-1]; var b: Dictionary=keys[upper]
	var span:=float(b.time)-float(a.time); var t:=(time-float(a.time))/span
	if property in ["quaternion","orientation"]:
		var av: Array=a.value; var bv: Array=b.value
		var q:=Quaternion(av[0],av[1],av[2],av[3]).slerp(Quaternion(bv[0],bv[1],bv[2],bv[3]),t)
		return [q.x,q.y,q.z,q.w]
	var out: Array=[]
	# Existing native GUI clip binding gives Bezier time handles span/3.
	# Their x curve is linear, so the normalized sample time is exact here.
	for axis in a.value.size():
		var start:=float(a.value[axis]); var end:=float(b.value[axis])
		if interpolation=="bezier":
			var first:=start+float(a.get("out",[])[axis]); var last:=end+float(b.get("in",[])[axis]); var inv:=1.0-t
			out.append(inv*inv*inv*start+3.0*inv*inv*t*first+3.0*inv*t*t*last+t*t*t*end)
		else: out.append(lerpf(start,end,t))
	return out
static func compose(asset: Dictionary,poses: Array) -> Dictionary:
	var channels: Dictionary={}; var meshes: Dictionary={}
	for pose in poses:
		var found:=false; var time:=float(pose.get("time",-1))
		if not is_finite(time) or time<0: return {"error":"Invalid original GUI state time"}
		for clip in asset.get("clips",[]):
			if str(clip.name)!=str(pose.get("clip","")): continue
			found=true
			for track in clip.get("meshTracks",[]):
				if not meshes.has(int(track.part)): meshes[int(track.part)]={}
				meshes[int(track.part)].merge(preload("res://systems/native_data/animated_mesh.gd").sample(track.data,clampf(time,0,float(clip.length))),true)
			for channel in clip.tracks:
				var value:=sample(Keys.keys(channel),clampf(time,0,float(clip.length)),str(channel.property),str(channel.get("sourceInterpolation","linear")))
				if value.is_empty(): return {"error":"Original GUI state has no transform keys"}
				channels[str(channel.part)+":"+str(channel.property)]={"part":channel.part,"property":channel.property,"sourceInterpolation":"linear","keys":[{"time":0.0,"value":value}]}
		if not found: return {"error":"Original GUI state animation is missing: "+str(pose.get("clip",""))}
	var result:=asset.duplicate(); result.erase("nativeAnimation"); result.erase("clipIndex"); result.lazyClips=false
	result.clips=[{"name":"native_gui_pose","length":0.001,"transition":0.0,"events":[],"tracks":channels.values(),"emitterTracks":[],"emitterStorage":[]}]
	return {"error":"","asset":result,"meshes":meshes}
static func nodes(model: Dictionary,poses: Array) -> Dictionary:
	var values: Dictionary={}
	for pose in poses:
		var found:=false
		for clip in model.get("animations",[]):
			if str(clip.name)!=str(pose.get("clip","")): continue
			found=true
			for track in clip.tracks:
				var value:=sample(Keys.frames(track),clampf(float(pose.time),0,float(clip.length)),str(track.property),str(track.interpolation))
				if value.is_empty(): return {"error":"Original GUI hook has no transform keys"}
				var name:=str(track.node).to_lower()
				if not values.has(name): values[name]={}
				values[name][str(track.property)]=value
		if not found: return {"error":"Original GUI hook state animation is missing"}
	var rows: Array=[]
	for row in model.get("nodes",[]):
		var node: Dictionary=row.duplicate()
		for property in values.get(str(row.name).to_lower(),{}):
			var value: Array=values[str(row.name).to_lower()][property]
			node[property]=value[0] if property=="scale" else value
		rows.append(node)
	var result:=model.duplicate(); result.nodes=rows
	return {"error":"","model":result}
