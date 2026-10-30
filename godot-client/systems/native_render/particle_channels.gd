extends RefCounted
const Controls=preload("res://systems/model_controllers.gd")
const Emitter=preload("res://systems/native_data/emitter_data.gd")
# Per-emitter immutable compiled channels; mutable parameters stay on instances.
# Binary tracks retain the complete original value pool for endpoint/Bezier reads.
var clips: Dictionary={}
var failure:=""
var cache_constants:=not OS.get_cmdline_user_args().has("--particle-channels=sampled")
var constant_candidates:=0
var constant_hits:=0
var sampled_channels:=0
func configure(asset: Dictionary,part: int) -> void:
	clips.clear(); failure=""; constant_candidates=0; constant_hits=0; sampled_channels=0
	for clip in asset.get("clips",[]):
		var channels: Array=[]
		for track in clip.get("emitterTracks",[]):
			if int(track.part)!=part: continue
			var compiled:=compile_channel(track,clip.get("emitterStorage",[]))
			if compiled.is_empty(): return
			# One linear row reads the same value before/after its time. Bezier
			# endpoints can read adjacent original storage and are never folded.
			compiled.constant_eligible=int(compiled.controller.rows4)==1 and (int(compiled.controller.columnsA)&240)!=16 and (int(compiled.controller.columnsA)&15)==int(compiled.components)
			if compiled.constant_eligible: constant_candidates+=1
			channels.append(compiled)
		clips[str(clip.name)]={"length":clip.length,"channels":channels}
func compile_channel(track: Dictionary,storage_pool: Array=[]) -> Dictionary:
	var count:=Emitter.components(str(track.property))
	if count not in [1,3] or track.frames.is_empty(): failure="Invalid native emitter channel"; return {}
	if track.has("nativeController"):
		var storage_index:=int(track.get("nativeStorageIndex",-1))
		if storage_index<0 or storage_index>=storage_pool.size(): failure="Native emitter controller value-pool reference is absent"; return {}
		return {"property":track.property,"controller":track.nativeController,"storage":storage_pool[storage_index],"components":count}
	var values:=PackedFloat32Array(); var frames: Array=track.frames; var bezier: bool=track.get("sourceInterpolation",track.get("interpolation","linear"))=="bezier"
	for frame in frames: values.append(frame.time)
	for frame in frames:
		values.append_array(PackedFloat32Array(frame.value))
		if bezier: values.append_array(PackedFloat32Array(frame["in"])); values.append_array(PackedFloat32Array(frame["out"]))
	var offset:=int(Emitter.FIELDS.find_key(str(track.property)))
	return {"property":track.property,"controller":{"rows4":frames.size(),"timeIndex6":0,"valueIndex8":frames.size(),"columnsA":count|(16 if bezier else 0),"displacement0":offset},"storage":{"values88":values},"components":count}
func sample_channel(channel: Dictionary,time: float) -> Array:
	var controller: Dictionary=channel.controller; var storage: Dictionary=channel.storage; var count:=int(channel.components); var rows:=int(controller.rows4); var flags:=int(controller.columnsA)
	if rows<=0 or not is_finite(time): failure="Invalid native emitter sampling clock"; return []
	var interval:=Controls.interval(controller,Controls.f(time),storage); var index:=int(interval[0]); var highest:=int(controller.valueIndex8)+count-1
	if index>0:
		if flags&16:
			if count==1: highest=int(controller.valueIndex8)+(index-1)*3+4
			else: highest=int(controller.valueIndex8)+(index-1)*9+14
		else: highest=int(controller.valueIndex8)+(mini(index,rows-1)+1)*count-1
	if highest>=storage.values88.size(): failure="Native emitter Bezier endpoint requires unavailable original value storage"; return []
	var output: Array=[0.0] if count==1 else [0.0,0.0,0.0]
	if count==1: Controls.scalar(controller,time,storage,output)
	else: Controls.vector(controller,time,storage,output,1.0)
	return output
func sample(name: String,time: float,parameters: Dictionary) -> bool:
	if not clips.has(name): return true
	if not clips[name].channels.is_empty() and not is_finite(time): failure="Invalid native emitter sampling clock"; return false
	for channel in clips[name].channels:
		if cache_constants and bool(channel.constant_eligible) and channel.has("constant_value"):
			var cached: Variant=channel.constant_value
			parameters[str(channel.property)]=cached.duplicate() if cached is Array else cached
			constant_hits+=1; continue
		var value:=sample_channel(channel,time)
		if value.is_empty(): return false
		sampled_channels+=1
		var property:=str(channel.property)
		# The original numeric controller writes four-byte fields. These four
		# runtime properties are consumed as BYTEs, rather than integer casts.
		if property.begins_with("percent") or property=="detonate": parameters[property]=PackedFloat32Array(value).to_byte_array()[0]
		else: parameters[property]=value if int(channel.components)==3 else value[0]
		if cache_constants and bool(channel.constant_eligible):
			var cached: Variant=parameters[property]
			channel.constant_value=cached.duplicate() if cached is Array else cached
	return true
func snapshot() -> Dictionary:
	return {"constant_cache_enabled":cache_constants,"constant_candidates":constant_candidates,"constant_hits":constant_hits,"sampled_channels":sampled_channels}
