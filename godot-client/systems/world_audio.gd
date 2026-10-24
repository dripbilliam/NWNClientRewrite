extends Node3D
const Transfer = preload("res://systems/audio_stream_transfer.gd")
const State = preload("res://systems/world_sound_state.gd")
var client
var listener_node: AudioListener3D
var listener_state: Dictionary = {}
var voices: Dictionary = {}
var resources: Dictionary = {}
var by_name: Dictionary = {}
var serial := 0
var resource_serial := 0
var closed := false
var cache_bytes := 0
var cache_limit := 32*1024*1024
var retired_players: Array = []
var retired_playback_refs: Array = []
var history: Array = []
var stats := {"created":0,"played":0,"retired":0,"parked":0,"stereoRejected":0,"failed":0,"imports":0,"cacheHits":0,"listenerUpdates":0}

func configure(owner) -> void:
	client = owner;listener_node = AudioListener3D.new();add_child(listener_node)
	process_priority = 110

func create_sound(resource_name: String,effect_id: int = 0) -> int:
	if closed:return -1
	serial += 1
	voices[serial] = {"id":serial,"name":State.resource_ref(resource_name).to_lower(),"effectId":effect_id,"profile":State.profile(),"position":[0.0,0.0,0.0],"requested":false,"resourceId":-1,"player":null,"oneShot":false,"delay":0,"delayStart":0,"stage":"created"}
	stats.created += 1;return serial

func setting(id: int,key: String,value: int) -> void:
	if not voices.has(id):return
	var profile: Dictionary = voices[id].profile
	match key:
		"setting1401d9e90":profile.positional = value != 0
		"setting1401da060":profile.priority = value&255
		"setting1401d9f90":profile.loop = value != 0
		_:push_error("Unknown original effect sound setting")

func one_shot(resource_name: String,point: Variant,height: float = 0,priority: int = 8,delay: int = 0,volume: int = 0,effect_id: int = 0) -> int:
	if State.resource_ref(resource_name).is_empty() or closed:return -1
	var id := create_sound(resource_name,effect_id);var row: Dictionary = voices[id]
	row.oneShot = true;row.profile.positional = point != null;row.profile.priority = priority&255
	row.profile.volume = (volume&255) if (volume&255) != 0 else 127
	if point != null:row.position = State.position(point,height)
	row.delay = delay&0xffffffff;row.delayStart = Time.get_ticks_msec()&0xffffffff
	if row.delay == 0:play(id)
	else:row.stage = "delayed"
	return id

func receive_cue(cue: Dictionary) -> void:
	var profile: Dictionary = cue.get("nativeSource",{})
	if not cue.get("resRef") is String or not profile.get("positional") is bool:return
	one_shot(cue.resRef,cue.get("position"),0,int(profile.get("priority",8)),int(profile.get("delay",0)),int(profile.get("volume",127)))

func move(id: int,point: Array,height: float = 0) -> void:
	if voices.has(id):voices[id].position = State.position(point,height)

func play(id: int) -> void:
	if closed or not voices.has(id):return
	var row: Dictionary = voices[id]
	if row.name == "":return
	_stop_player(row);row.requested = true
	if by_name.has(row.name):
		row.resourceId = by_name[row.name];stats.cacheHits += 1
	else:
		resource_serial += 1;row.resourceId = resource_serial
		resources[resource_serial] = {"id":resource_serial,"name":row.name,"transfer":Transfer.new(),"stream":null,"metadata":{},"failed":false,"last":Time.get_ticks_usec(),"bytes":0}
		by_name[row.name] = resource_serial
		client.command({"kind":"world-audio-resource","resourceId":resource_serial,"name":row.name,"transferId":client.world_scope.ticket})
	row.stage = "loading";_tick(row)

func stop(id: int) -> void:
	if not voices.has(id):return
	var row: Dictionary = voices[id];row.requested = false;row.delay = 0;_stop_player(row);_observe(row,"stopped")

func destroy(id: int) -> void:
	if not voices.has(id):return
	var row: Dictionary = voices[id];_stop_player(row);voices.erase(id);stats.retired += 1
	if not closed:_observe(row,"retired")
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
			if row.resourceId == id:_tick(row)
		_trim()

func _fail_resource(resource: Dictionary) -> void:
	resource.failed = true;resource.transfer.clear();stats.failed += 1
	for row in voices.values().duplicate():
		if row.resourceId != resource.id:continue
		row.requested = false;_observe(row,"failed")
		if row.oneShot:destroy(row.id)

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
	if not row.requested or not resources.has(row.resourceId):return
	var resource: Dictionary = resources[row.resourceId]
	if resource.stream == null or resource.failed:return
	if row.profile.positional and int(resource.metadata.channels) != 1:
		row.requested = false;stats.stereoRejected += 1;_observe(row,"stereo-rejected")
		if row.oneShot:destroy(row.id)
		return
	if row.profile.positional and listener_state.is_empty():return
	var distance := State.distance(listener_state.position,row.position) if row.profile.positional else 0.0
	if row.profile.positional and distance > float(row.profile.maxDistance) and (row.profile.loop or not is_instance_valid(row.player)):
		_stop_player(row)
		if row.profile.loop:
			if row.stage != "parked":stats.parked += 1;_observe(row,"parked")
		else:row.requested = false;_observe(row,"out-of-range");destroy(row.id)
		return
	if not is_instance_valid(row.player):
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
		add_child(player);row.player = player;player.stream = stream
		player.finished.connect(func():
			if voices.has(row.id) and row.player == player:
				row.requested = false;_stop_player(row);_observe(row,"finished")
				if row.oneShot:destroy(row.id))
		_apply(row,distance);player.play();stats.played += 1;_observe(row,"playing")
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
	if closed:return
	_listener()
	for row in voices.values().duplicate():
		if row.delay != 0 and State.delay_due(Time.get_ticks_msec(),row.delayStart,row.delay):row.delay = 0;play(row.id)
		_tick(row)
	retired_players = retired_players.filter(func(reference):return reference.get_ref() != null)
	retired_playback_refs = retired_playback_refs.filter(func(reference):return reference.get_ref() != null)

func _trim() -> void:
	while cache_bytes > cache_limit or resources.size() > 512:
		var candidate: Dictionary = {}
		for resource in resources.values():
			if voices.values().any(func(row):return row.resourceId == resource.id):continue
			if candidate.is_empty() or resource.last < candidate.last:candidate = resource
		if candidate.is_empty():break
		resources.erase(candidate.id);by_name.erase(candidate.name);cache_bytes -= int(candidate.bytes)

func snapshot() -> Dictionary:
	var rows: Array = []
	for row in voices.values():
		var resource: Dictionary = resources.get(row.resourceId,{})
		rows.append({"id":row.id,"effectId":row.effectId,"resourceId":row.resourceId,"name":row.name,"profile":row.profile.duplicate(true),"position":row.position.duplicate(),"stage":row.stage,"playing":is_instance_valid(row.player) and row.player.playing,"playback":row.player.get_playback_position() if is_instance_valid(row.player) else 0.0,"duration":resource.stream.get_length() if resource.get("stream") != null else 0.0,"metadata":resource.get("metadata",{}).duplicate(true)})
	return {"stats":stats.duplicate(true),"voices":rows,"history":history.duplicate(true),"resources":resources.size(),"cacheBytes":cache_bytes,"pendingBytes":resources.values().reduce(func(total,resource):return total+int(resource.transfer.pending.get("received",0)),0),"retiredPlayerSurvivors":retired_players.size(),"listener":listener_state.duplicate(true),"driver":AudioServer.get_driver_name()}

func close() -> void:
	if closed:return
	closed = true;set_process(false)
	for id in voices.keys():destroy(id)
	for resource in resources.values():resource.transfer.clear()
	resources.clear();by_name.clear();cache_bytes = 0;listener_state.clear()
	history.clear()
	if is_instance_valid(listener_node):listener_node.clear_current()

func _exit_tree() -> void:close()
