extends Node3D
const Timing=preload("res://systems/native_render/frame_profile.gd")
const Transfer = preload("res://systems/audio_stream_transfer.gd")
const State = preload("res://systems/world_sound_state.gd")
var client
var voice_object_lookup: Callable
var listener_node: AudioListener3D
var listener_state: Dictionary = {}
var voices: Dictionary = {}
var resources: Dictionary = {}
var by_name: Dictionary = {}
var serial := 0
var resource_serial := 0
var closed := false
var cache_bytes := 0
var cache_limit := 0 # GameAudio keeps installed resource buffers until cleared.
var retired_players: Array = []
var retired_playback_refs: Array = []
var history: Array = []
var one_shot_events: Array=[]
var generation:=0
var reported_mixer:=false
var reported_effect_mixer:=false
var delay_sequence:=0
var replace_generations: Dictionary={}
var output_state: Dictionary={"decoded":0,"played":0,"pending":0,"context":"uninitialized","last":null,"delayed":0}
var stats := {"created":0,"played":0,"retired":0,"parked":0,"stereoRejected":0,"failed":0,"imports":0,"cacheHits":0,"listenerUpdates":0}

func configure(owner) -> void:
	client = owner;listener_node = AudioListener3D.new();add_child(listener_node)
	generation=int(client.world_scope.ticket)
	output_state.context="running"
	process_priority = 110
func area_changed() -> void:
	generation+=1
	for row in voices.values().duplicate():
		if row.oneShot and int(row.get("generation",generation))!=generation:destroy(int(row.id))
func cue_current(row: Dictionary) -> bool:
	if closed or int(row.get("generation",generation))!=generation:return false
	var replace_key: String=str(row.get("replaceKey",""))
	if not replace_key.is_empty() and str(row.get("stage",""))!="playing" and int(replace_generations.get(replace_key,0))!=int(row.get("replaceGeneration",0)):return false
	if str(row.get("channel",""))=="voice" and int(row.get("objectId",0x7f000000))!=0x7f000000:
		var actor: Variant=voice_object_lookup.call(int(row.objectId)) if voice_object_lookup.is_valid() else client.object(int(row.objectId))
		if actor==null:return false
	var check: Callable=row.get("current",Callable())
	return not check.is_valid() or bool(check.call())

func create_sound(resource_name: String,effect_id: int = 0,object_id: int = 0x7f000000,channel: String = "visual",report_effect_mixer: bool = true) -> int:
	if closed:return -1
	if report_effect_mixer and not resource_name.is_empty() and not reported_effect_mixer:
		reported_effect_mixer=true
		client.diagnose("audio.effect-mixer-unimplemented","Native effect priority voice limits, synchronized pause and range-resume sample phase are not connected",0)
	serial += 1
	voices[serial] = {"id":serial,"name":State.resource_ref(resource_name).to_lower(),"effectId":effect_id,"objectId":object_id,"channel":channel,"profile":State.profile(),"position":[0.0,0.0,0.0],"requested":false,"resourceId":-1,"player":null,"oneShot":false,"delay":0,"delayStart":0,"stage":"created","decodedCounted":false,"loadedCount":0,"playedCount":0,"loadedNames":{},"sourceResources":{},"rate":null}
	stats.created += 1;return serial

func setting(id: int,key: String,value: int) -> void:
	if not voices.has(id):return
	var profile: Dictionary = voices[id].profile
	match key:
		"setting1401d9e90":profile.positional = value != 0
		"setting1401da060":profile.priority = value&255
		"setting1401d9f90":profile.loop = value != 0
		_:push_error("Unknown original effect sound setting")

func one_shot(resource_name: String,point: Variant,height: float = 0,priority: int = 8,delay: int = 0,volume: int = 0,effect_id: int = 0,object_id: int = 0x7f000000,channel: String = "effect",current: Callable = Callable(),replace: bool = false) -> int:
	if closed:return -1
	var cue: Dictionary=State.one_shot_cue({"resRef":resource_name,"position":point,"height":height,"priority":priority,"volume":volume,"delay":delay,"channel":channel})
	if cue.has("error") and not str(cue.error).is_empty():
		client.diagnose("network.scene-audio-unhandled",str(cue.error),object_id)
		return -1
	if cue.is_empty():return -1
	if not reported_mixer:
		reported_mixer=true
		client.diagnose("network.audio-mixer-settings-unimplemented","Native priority-group voice limits and user mixer settings are not connected; source defaults are used",0)
	var id := create_sound(str(cue.resRef),effect_id,object_id,channel,false);var row: Dictionary = voices[id]
	row.oneShot=true;row.objectId=object_id;row.channel=channel;row.generation=generation;row.current=current
	if replace:
		var key:=str(object_id)+":"+channel
		replace_generations[key]=int(replace_generations.get(key,0))+1
		row.replaceKey=key;row.replaceGeneration=int(replace_generations[key])
	row.profile.merge(cue.nativeSource,true)
	if cue.position!=null:row.position=cue.position
	row.delay = delay&0xffffffff;row.delayStart = Time.get_ticks_msec()&0xffffffff
	if row.delay!=0:row.delayId=delay_sequence;delay_sequence+=1
	one_shot_events.append({"objectId":object_id,"resRef":str(cue.resRef),"position":cue.position.duplicate() if cue.position is Array else null,"priority":int(cue.nativeSource.priority),"delay":delay,"channel":channel})
	if one_shot_events.size()>128:one_shot_events.pop_front()
	if row.delay == 0:play(id)
	else:row.stage = "delayed"
	return id

func receive_cue(cue: Dictionary) -> void:
	var profile: Dictionary = cue.get("nativeSource",{})
	if not cue.get("resRef") is String or not profile.get("positional") is bool:return
	one_shot(cue.resRef,cue.get("position"),0,int(profile.get("priority",8)),int(profile.get("delay",0)),int(profile.get("volume",127)),0,int(cue.get("objectId",0x7f000000)),str(cue.get("channel","effect")),cue.get("current",Callable()),bool(cue.get("replace",false)))

func move(id: int,point: Array,height: float = 0) -> void:
	if voices.has(id):
		voices[id].position = State.position(point,height)
		refresh_voice(id)

func refresh_voice(id: int) -> void:
	if not voices.has(id):return
	var row: Dictionary=voices[id]
	if not is_instance_valid(row.player):return
	var distance:=State.distance(listener_state.position,row.position) if bool(row.profile.positional) and not listener_state.is_empty() else 0.0
	_apply(row,distance)

func set_res_ref(id: int,resource_name: String) -> void:
	# BufferAudioSource.setResRef stops its physical source and resets pitch,
	# while retaining buffers previously loaded by this sound object.
	if not voices.has(id):return
	stop(id)
	var row: Dictionary=voices[id]
	row.name=State.resource_ref(resource_name).to_lower();row.resourceId=-1;row.rate=null;row.stage="created"

func play(id: int) -> void:
	if closed or not voices.has(id):return
	var row: Dictionary = voices[id]
	if row.name == "":return
	_stop_player(row);row.requested = true
	if row.sourceResources.has(row.name) and resources.has(int(row.sourceResources[row.name])):
		row.resourceId=int(row.sourceResources[row.name]);stats.cacheHits += 1
	elif by_name.has(row.name):
		row.resourceId = by_name[row.name];stats.cacheHits += 1
	else:
		resource_serial += 1;row.resourceId = resource_serial
		resources[resource_serial] = {"id":resource_serial,"name":row.name,"transfer":Transfer.new(),"stream":null,"metadata":{},"failed":false,"last":Time.get_ticks_usec(),"bytes":0}
		by_name[row.name] = resource_serial
		client.command({"kind":"world-audio-resource","resourceId":resource_serial,"name":row.name,"transferId":client.world_scope.ticket})
	row.sourceResources[row.name]=row.resourceId
	if not row.oneShot and not row.loadedNames.has(row.name):row.waitForFrame=true
	row.stage = "loading";_tick(row)

func stop(id: int) -> void:
	if not voices.has(id):return
	var row: Dictionary = voices[id];row.requested = false;row.delay = 0;_stop_player(row);_observe(row,"stopped")

func destroy(id: int) -> void:
	if not voices.has(id):return
	var row: Dictionary = voices[id];_stop_player(row);voices.erase(id);stats.retired += 1
	if not closed:_observe(row,"retired")
	for resource_id in row.sourceResources.values():
		var candidate:=int(resource_id)
		if resources.has(candidate) and not by_name.values().has(candidate) and not voices.values().any(func(other):return other.sourceResources.values().has(candidate)):
			cache_bytes-=int(resources[candidate].bytes);resources.erase(candidate)
	_trim()

func _stop_player(row: Dictionary) -> void:
	if is_instance_valid(row.player):
		if row.player.stream != null:retired_playback_refs.append(weakref(row.player.stream))
		if row.player.has_stream_playback():
			var playback = row.player.get_stream_playback()
			if playback != null:retired_playback_refs.append(weakref(playback))
		var player = row.player;row.player = null;player.stop();player.stream = null;retired_players.append(weakref(player));player.queue_free()
		row.erase("lastGain")

func receive(message: Dictionary) -> void:
	if closed:return
	var id := int(message.get("resourceId",-1))
	if not resources.has(id):return
	var resource: Dictionary = resources[id]
	if message.kind == "world-audio-failed":_fail_resource(resource);return
	if str(message.get("name","")).to_lower() != str(resource.name):_fail_resource(resource);return
	if resource.stream != null or resource.failed:return
	var transfer = resource.transfer
	if message.kind == "world-audio-begin":
		if not transfer.pending.is_empty() or not transfer.begin(message):_fail_resource(resource)
	elif message.kind == "world-audio-chunk":
		if not transfer.chunk(message):_fail_resource(resource)
	elif message.kind == "world-audio-commit":
		var stream: AudioStream = transfer.commit(message)
		if stream == null:_fail_resource(resource);return
		resource.stream = stream;resource.metadata = transfer.metadata.duplicate(true);transfer.clear()
		resource.bytes = int(resource.metadata.bytes);cache_bytes += resource.bytes;stats.imports += 1
		for row in voices.values():
			if row.resourceId == id:
				if not row.loadedNames.has(row.name):
					row.loadedNames[row.name]=true;row.loadedCount=int(row.get("loadedCount",0))+1
				_tick(row)
		_trim()

func _fail_resource(resource: Dictionary,reason: String="Original audio resource is unavailable") -> void:
	resource.failed = true;resource.failure=reason;resource.transfer.clear();stats.failed += 1
	for row in voices.values().duplicate():
		if row.resourceId != resource.id:continue
		_resource_failure(row,reason)
		row.failure=reason;row.requested = false;_observe(row,"failed")
		if row.oneShot:destroy(row.id)

func _resource_failure(_row: Dictionary,_reason: String) -> void:
	pass

func _listener() -> void:
	if not client.pivots.has(client.controlled_id) or not is_instance_valid(client.owner_scene.camera):listener_state.clear();return
	var point: Vector3 = client.pivots[client.controlled_id].global_position
	var camera: Camera3D = client.owner_scene.camera;var camera_point := camera.global_position
	# Native camera basis is pre-multiplied by -90deg X for Godot presentation.
	# Undo that existing adapter rather than reinterpret its quaternion axes.
	var q := Quaternion(Vector3.RIGHT,PI/2)*camera.global_basis.get_rotation_quaternion()
	listener_state = State.listener([point.x,-point.z,point.y],[camera_point.x,-camera_point.z,camera_point.y],[q.w,q.x,q.y,q.z])
	var next_position := render(listener_state.position)
	if listener_node.global_position != next_position:listener_node.global_position = next_position
	var forward := render(listener_state.forward);var up := render(listener_state.up)
	if forward.length_squared() > 0.000001 and forward.cross(up).length_squared() > 0.000001:
		var next_basis := Basis.looking_at(forward,up)
		if listener_node.global_basis != next_basis:listener_node.global_basis = next_basis
	if not listener_node.is_current():listener_node.make_current()
	stats.listenerUpdates += 1

static func render(point: Array) -> Vector3:return Vector3(float(point[0]),float(point[2]),-float(point[1]))

func _tick(row: Dictionary) -> void:
	if row.oneShot and not cue_current(row):destroy(int(row.id));return
	if not row.requested or not resources.has(row.resourceId):return
	var resource: Dictionary = resources[row.resourceId]
	if resource.failed:
		_resource_failure(row,str(resource.get("failure","Original audio resource is unavailable")))
		row.requested=false;_observe(row,"failed");return
	if resource.stream == null:return
	if not row.loadedNames.has(row.name):
		row.loadedNames[row.name]=true;row.loadedCount=int(row.get("loadedCount",0))+1
	# BufferAudioSource resolves the buffer first; its owner retries play on its
	# next frame. A newly arrived placed sound does not start inside IO delivery.
	if bool(row.get("waitForFrame",false)):return
	if row.get("rate")==null:
		var variation:=State.f(clampf(float(row.profile.get("pitchVariance",0.0)),0.0,1.0))
		var sample_rate:=int(resource.metadata.get("sampleRate",0))
		var pitch:=1.0
		if variation!=0.0 and sample_rate>0 and not (row.profile.positional and int(resource.metadata.channels)!=1):
			var add: bool=(randi()&1)!=0
			var span:=int(State.f(State.f(float(sample_rate))*(variation if add else State.f(State.f(0.5)*variation))))
			if span>0:
				var random_rate: int=(randi()%0x8000) if bool(row.get("placed",false)) else randi()
				var changed_rate:=sample_rate+(1 if add else -1)*int(random_rate%span)
				if changed_rate>0:pitch=float(changed_rate)/float(sample_rate)
		row.rate=pitch
	if row.profile.positional and int(resource.metadata.channels) != 1:
		row.requested = false;stats.stereoRejected += 1;_observe(row,"stereo-rejected")
		if row.oneShot:destroy(row.id)
		return
	if row.oneShot and not bool(row.get("decodedCounted",false)):
		row.decodedCounted=true;output_state.decoded=int(output_state.decoded)+1
		output_state.last={"resRef":row.name,"objectId":int(row.get("objectId",0x7f000000)),"channel":str(row.get("channel","effect")),"channels":int(resource.metadata.get("channels",0)),"sampleRate":int(resource.metadata.get("sampleRate",0)),"duration":resource.stream.get_length()}
	var distance := (INF if listener_state.is_empty() else State.distance(listener_state.position,row.position)) if row.profile.positional else 0.0
	if row.profile.positional and distance > float(row.profile.maxDistance) and (row.profile.loop or not is_instance_valid(row.player)):
		_stop_player(row)
		if row.profile.loop:
			if row.stage != "parked":stats.parked += 1;_observe(row,"parked")
		else:
			row.requested = false;_observe(row,"out-of-range")
			if row.oneShot:destroy(row.id)
		return
	if not is_instance_valid(row.player):
		if not str(row.get("replaceKey","")).is_empty():
			for previous in voices.values().duplicate():
				if int(previous.id)!=int(row.id) and int(previous.get("objectId",0x7f000000))==int(row.objectId) and str(previous.get("channel",""))==str(row.channel) and is_instance_valid(previous.player):destroy(int(previous.id))
		var stream: AudioStream = resource.stream.duplicate()
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if row.profile.loop else AudioStreamWAV.LOOP_DISABLED
			stream.loop_begin = 0;stream.loop_end = int(resource.metadata.frames)
		elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:stream.loop = row.profile.loop
		var player
		if row.profile.positional:
			player = AudioStreamPlayer3D.new();player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED;player.max_distance = 0;player.unit_size = 1
			player.attenuation_filter_cutoff_hz = 20500;player.attenuation_filter_db = 0;player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		else:player = AudioStreamPlayer.new()
		add_child(player);row.player = player;player.stream = stream;player.pitch_scale=float(row.get("rate",1.0))
		player.finished.connect(func():
			if voices.has(row.id) and row.player == player:
				row.requested = false;_stop_player(row);_observe(row,"finished")
				if row.oneShot:destroy(row.id))
		_apply(row,distance);player.play();stats.played += 1;row.playedCount=int(row.get("playedCount",0))+1
		if row.oneShot:output_state.played=int(output_state.played)+1
		_observe(row,"playing")
	else:_apply(row,distance)
	resource.last = Time.get_ticks_usec()

func _apply(row: Dictionary,distance: float) -> void:
	if not is_instance_valid(row.player):return
	var gain := State.gain(row.profile,distance)
	if row.get("lastGain",-1) != gain:row.player.volume_linear = gain;row.lastGain = gain
	if row.profile.positional:
		var point := render(row.position)
		if row.player.global_position != point:row.player.global_position = point

func _observe(row: Dictionary,stage: String) -> void:
	row.stage = stage
	var event := {"kind":"world-audio-observed","soundId":row.id,"resourceId":row.resourceId,"effectId":row.effectId,"stage":stage,"transferId":client.world_scope.ticket,"driver":AudioServer.get_driver_name()}
	if stage == "playing":
		var resource: Dictionary = resources[row.resourceId]
		history.append({"id":row.id,"effectId":row.effectId,"resourceId":row.resourceId,"name":row.name,"profile":row.profile.duplicate(true),"position":row.position.duplicate(),"metadata":resource.metadata.duplicate(true),"duration":resource.stream.get_length()})
		if history.size() > 128:history.pop_front()
	if not closed:client.command(event)

func _process(_delta: float) -> void:
	var began:=Timing.begin(); advance(); Timing.finish("callback_audio",began)
func advance() -> void:
	if closed:return
	_listener()
	var advancing: Array=voices.values().duplicate()
	advancing.sort_custom(func(a,b):
		if int(a.delay)!=0 and int(b.delay)!=0:return int(a.get("delayId",0))>int(b.get("delayId",0))
		return int(a.delay)!=0 and int(b.delay)==0)
	for row in advancing:
		if not voices.has(row.id):continue
		if row.oneShot and not cue_current(row):destroy(int(row.id));continue
		if row.delay != 0 and State.delay_due(Time.get_ticks_msec(),row.delayStart,row.delay):row.delay = 0;play(row.id)
		if bool(row.get("waitForFrame",false)) and not bool(row.get("placed",false)) and resources.has(int(row.resourceId)) and resources[int(row.resourceId)].stream!=null:row.waitForFrame=false
		_tick(row)
	output_state.delayed=voices.values().filter(func(row):return int(row.delay)!=0).size()
	retired_players = retired_players.filter(func(reference):return reference.get_ref() != null)
	retired_playback_refs = retired_playback_refs.filter(func(reference):return reference.get_ref() != null)

func _trim() -> void:
	if cache_limit<=0:return
	while cache_bytes > cache_limit or resources.size() > 512:
		var candidate: Dictionary = {}
		for resource in resources.values():
			if voices.values().any(func(row):return row.resourceId == resource.id):continue
			if candidate.is_empty() or resource.last < candidate.last:candidate = resource
		if candidate.is_empty():break
		resources.erase(candidate.id);by_name.erase(candidate.name);cache_bytes -= int(candidate.bytes)
func clear_resource_cache() -> void:
	# The old clearResourceCache drops lookup entries. Active sources retain their
	# buffers until completion; a later request loads a fresh resource identity.
	by_name.clear()
	for resource in resources.values().duplicate():
		if voices.values().any(func(row):return row.sourceResources.values().has(int(resource.id))):continue
		resources.erase(resource.id);cache_bytes-=int(resource.bytes)
func delayed_sounds() -> Array:
	var pending: Array=voices.values().filter(func(row):return int(row.delay)!=0)
	pending.sort_custom(func(a,b):return int(a.get("delayId",0))>int(b.get("delayId",0)))
	var result: Array=[]
	for row in pending:
		result.append({"id":int(row.get("delayId",0)),"start":int(row.delayStart),"delay":int(row.delay),"resRef":str(row.name),"objectId":int(row.get("objectId",0x7f000000)),"position":row.position.duplicate(),"priority":int(row.profile.priority),"channel":str(row.get("channel","effect"))})
	return result
func sound_source_snapshot(row: Dictionary) -> Dictionary:
	if row.is_empty():return {}
	var resource: Dictionary=resources.get(int(row.resourceId),{})
	var stream: Variant=resource.get("stream")
	var metadata: Dictionary=resource.get("metadata",{})
	var timing: Dictionary=metadata.get("timing",{}) if metadata.get("timing") is Dictionary else {}
	var stage: String=str(row.stage)
	var status: String="idle" if stage in ["created","stopped","finished","retired"] else "stereo-3d-rejected" if stage=="stereo-rejected" else stage
	var playing: bool=is_instance_valid(row.player) and row.player.playing
	var duration: Variant=null
	if timing.has("duration"):duration=int(timing.duration)
	elif stream!=null:duration=int(stream.get_length()*1000.0)
	return {"objectId":int(row.get("objectId",0x7f000000)),"resource":str(row.name),"status":status,"hardwarePlaying":playing,"loop":bool(row.profile.loop),"positional":bool(row.profile.positional),"priority":int(row.profile.priority),"volume":int(row.profile.volume)&255,"rate":row.get("rate"),"duration":duration,"sampleRate":int(metadata.sampleRate) if metadata.has("sampleRate") else null,"position":row.position.duplicate(),"loaded":int(row.get("loadedCount",0)),"played":int(row.get("playedCount",0))}
func effect_sounds() -> Array:
	var result: Array=[]
	for row in voices.values():
		if row.oneShot:continue
		var source: Dictionary=sound_source_snapshot(row)
		var effect: Dictionary={"objectId":int(row.get("objectId",0x7f000000)),"channel":str(row.get("channel","visual")),"pending":str(row.stage)=="loading" and bool(row.requested)}
		effect.merge(source,true);result.append(effect)
	return result

func snapshot() -> Dictionary:
	var rows: Array = []
	for row in voices.values():
		var resource: Dictionary = resources.get(row.resourceId,{})
		rows.append({"id":row.id,"effectId":row.effectId,"resourceId":row.resourceId,"name":row.name,"profile":row.profile.duplicate(true),"position":row.position.duplicate(),"stage":row.stage,"playing":is_instance_valid(row.player) and row.player.playing,"playback":row.player.get_playback_position() if is_instance_valid(row.player) else 0.0,"duration":resource.stream.get_length() if resource.get("stream") != null else 0.0,"metadata":resource.get("metadata",{}).duplicate(true)})
	var output: Dictionary=output_state.duplicate(true)
	output.delayed=delayed_sounds().size()
	return {"stats":stats.duplicate(true),"voices":rows,"history":history.duplicate(true),"events":one_shot_events.duplicate(true),"output":output,"effectSounds":effect_sounds(),"delayedSounds":delayed_sounds(),"resources":resources.size(),"cacheBytes":cache_bytes,"pendingBytes":resources.values().reduce(func(total,resource):return total+int(resource.transfer.pending.get("received",0)),0),"retiredPlayerSurvivors":retired_players.size(),"listener":listener_state.duplicate(true),"driver":AudioServer.get_driver_name(),"generation":generation}

func close() -> void:
	if closed:return
	closed = true;set_process(false)
	for id in voices.keys():destroy(id)
	for resource in resources.values():resource.transfer.clear()
	resources.clear();by_name.clear();cache_bytes = 0;listener_state.clear()
	history.clear();one_shot_events.clear();replace_generations.clear();output_state.context="closed"
	if is_instance_valid(listener_node):listener_node.clear_current()

func _exit_tree() -> void:close()
