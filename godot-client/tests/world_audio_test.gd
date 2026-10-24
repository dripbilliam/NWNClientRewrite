extends SceneTree
const Audio = preload("res://systems/world_audio.gd")
const Transfer = preload("res://systems/audio_stream_transfer.gd")
const State = preload("res://systems/world_sound_state.gd")
class Client:
	extends RefCounted
	var pivots: Dictionary = {}
	var controlled_id := 1
	var owner_scene: Dictionary = {}
	var world_scope := {"ticket":3}
	var sent: Array = []
	func command(message: Dictionary) -> void:sent.append(message)
var checks: Array = []
var failures: Array = []
var captured: Dictionary = {}
var poses: Dictionary = {}
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks.append({"name":label,"passed":value})
	if not value:failures.append(label)
func tone(frames: int,channels: int = 1) -> PackedByteArray:
	var bytes := PackedByteArray();bytes.resize(frames*channels*2)
	for i in frames:
		for c in channels:bytes.encode_s16((i*channels+c)*2,int(sin(float(i)*TAU*220/8000)*4095))
	return bytes
func packets(bytes: PackedByteArray,id: int,name: String,channels: int = 1) -> Array:
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	var rows := [{"kind":"world-audio-begin","resourceId":id,"name":name,"codec":"pcm16","channels":channels,"sampleRate":8000,"frames":bytes.size()/(channels*2),"bytes":bytes.size(),"sha256":hash.finish().hex_encode()}]
	var index := 0
	for at in range(0,bytes.size(),131072):rows.append({"kind":"world-audio-chunk","resourceId":id,"name":name,"index":index,"data":Marshalls.raw_to_base64(bytes.slice(at,mini(bytes.size(),at+131072)))});index += 1
	rows.append({"kind":"world-audio-commit","resourceId":id,"name":name,"chunks":index});return rows
func frames(count: int = 3) -> void:
	for i in count:await process_frame
func energy(capture: AudioEffectCapture) -> Vector2:
	var available := capture.get_frames_available()
	if available < 1:return Vector2.ZERO
	var value := Vector2.ZERO
	for sample in capture.get_buffer(available):value += Vector2(sample.x*sample.x,sample.y*sample.y)
	return value/float(available)
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var capture := AudioEffectCapture.new();capture.buffer_length = 0.5
	var capture_index := AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,capture)
	var scene := Node3D.new();root.add_child(scene)
	var camera := Camera3D.new();scene.add_child(camera);camera.make_current()
	var actor := Node3D.new();scene.add_child(actor)
	var client := Client.new();client.owner_scene.camera = camera;client.pivots[1] = actor
	var audio := Audio.new();scene.add_child(audio);audio.configure(client);await frames()
	check(audio.listener_state.position == [0.0,0.0,1.5],"Listener is five-sixths controlled eye plus one-sixth camera")
	check(audio.listener_node.global_position == Vector3(0,1.5,0) and audio.listener_node.is_current(),"Actual native listener owns converted Z-up position")
	check(audio.listener_node.global_basis.z.distance_to(camera.global_basis.z) < 0.00001,"Native camera adapter is undone before original listener orientation")
	var id := audio.create_sound("LOOP")
	check(audio.voices[id].profile == State.profile(),"Effect sound constructor preserves original default priority/range/volume/2D state")
	for pair in [["setting1401d9e90",1],["setting1401da060",11],["setting1401d9f90",1]]:audio.setting(id,pair[0],pair[1])
	audio.move(id,[0,0,0],1.5);audio.play(id)
	check(client.sent.filter(func(row):return row.kind == "world-audio-resource").size() == 1 and audio.voices[id].player == null,"Native sound requests one resource and waits without starting a partial stream")
	var mono := tone(8000);var data := packets(mono,1,"loop")
	for message in data:audio.receive(message)
	await frames()
	var player = audio.voices[id].player
	check(is_instance_valid(player) and player is AudioStreamPlayer3D and player.playing,"Completed mono resource starts actual positional Godot playback")
	check(player.stream is AudioStreamWAV and player.stream.data == mono and player.stream.mix_rate == 8000,"Native positional stream preserves exact PCM bytes and original rate")
	check(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and player.stream.loop_end == 8000 and audio.resources[1].stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,"Per-source looping does not mutate immutable cached stream")
	check(absf(player.volume_linear-State.f(127.0/255.0)) < 0.000001 and player.global_position == Vector3(0,1.5,0),"Native volume denominator and effect height reach actual source")
	check(player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_DISABLED and player.max_distance == 0 and player.attenuation_filter_cutoff_hz == 20500,"Godot extra distance attenuation and low-pass filter are disabled")
	await create_timer(0.13).timeout
	check(player.get_playback_position() > 0,"Actual native audio clock advances after complete resource admission")
	if AudioServer.get_driver_name() != "Dummy" or OS.get_cmdline_user_args().has("--capture-mixer"):
		captured.center = energy(capture)
		poses.center = {"player":str(player.global_transform),"listener":str(audio.listener_node.global_transform),"children":audio.get_child_count(),"voices":audio.voices.size()}
		check(captured.center.x > 0.000001 and captured.center.y > 0.000001,"Actual native mixer captures nonzero positional output in both channels")
		audio.move(id,[5,0,1.5]);await create_timer(0.25).timeout;capture.clear_buffer();await create_timer(0.15).timeout
		captured.right = energy(capture)
		poses.right = {"player":str(player.global_transform),"listener":str(audio.listener_node.global_transform),"children":audio.get_child_count(),"voices":audio.voices.size()}
		var rightward: bool = captured.right.y > captured.right.x*1.2 if AudioServer.get_speaker_mode() == AudioServer.SPEAKER_MODE_STEREO else captured.right.x/captured.right.y < (captured.center.x/captured.center.y)/1.2
		check(rightward and captured.right.y > 0.000001,"Right source shifts captured channel energy rightward relative to centered source")
		audio.move(id,[-5,0,1.5]);await create_timer(0.25).timeout;capture.clear_buffer();await create_timer(0.15).timeout
		captured.left = energy(capture)
		poses.left = {"player":str(player.global_transform),"listener":str(audio.listener_node.global_transform),"children":audio.get_child_count(),"voices":audio.voices.size()}
		# Capture instances for all surround channel pairs share one resource
		# buffer, including the right-lane LFE. In surround this is a relative
		# paired-channel readback, not a claim of isolated front-left/right data.
		var leftward: bool = captured.left.x > captured.left.y*1.2 if AudioServer.get_speaker_mode() == AudioServer.SPEAKER_MODE_STEREO else captured.left.x/captured.left.y > (captured.center.x/captured.center.y)*1.2
		check(leftward and captured.left.x > 0.000001,"Left source reverses captured directional energy relative to centered source")
		audio.move(id,[0,0,1.5]);await frames()
	var duplicate := audio.one_shot("loop",[0,0,0],1.5,11)
	check(audio.stats.imports == 1 and audio.stats.cacheHits == 1 and audio.voices[duplicate].player.playing,"Simultaneous one-shot and loop share one cached import with independent players")
	check(audio.voices[duplicate].player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,"One-shot copy remains non-looping beside its duration source")
	audio.move(id,[50,0,0]);await frames()
	check(audio.voices[id].player == null and audio.voices[id].stage == "parked" and audio.voices[id].requested,"Out-of-range loop parks while preserving requested ownership")
	var played: int = audio.stats.played;await frames(5)
	check(audio.stats.played == played,"Parked source does not restart or request its resource every frame")
	audio.move(id,[0,0,1.5]);await frames()
	check(audio.stats.played == played+1 and audio.stats.imports == 1 and audio.voices[id].player.playing,"Returning to range resumes once using cached bytes")
	check(absf(audio.voices[id].player.volume_linear-State.f(127.0/255.0)) < 0.000001,"A recreated parked player reapplies gain even when the requested value is unchanged")
	audio.stop(id);await frames()
	check(not audio.voices[id].requested and audio.voices[id].player == null,"Stop releases hardware player while retaining its explicit effect owner")
	var stereo := audio.one_shot("stereo",[0,0,1.5])
	for message in packets(tone(6000,2),2,"stereo",2):audio.receive(message)
	check(audio.stats.stereoRejected == 1 and not audio.voices.has(stereo),"Original positional mono-only gate rejects a decoded stereo source")
	var flat := audio.one_shot("stereo",null)
	check(audio.voices[flat].player is AudioStreamPlayer and audio.voices[flat].player.playing,"Same stereo bytes remain playable through non-positional output")
	var remote := audio.one_shot("loop",[100,0,0])
	check(not audio.voices.has(remote),"Out-of-range one-shot is discarded rather than deferred until listener moves")
	var delayed := audio.one_shot("loop",null,0,8,100)
	check(audio.voices[delayed].player == null and audio.voices[delayed].stage == "delayed","Explicit one-shot delay does not start playback early")
	await create_timer(0.13).timeout
	check(audio.voices[delayed].player != null and audio.voices[delayed].player.playing,"Native frame/timer owner admits delayed audio after its due interval")
	var canceled := audio.one_shot("loop",null,0,8,200);audio.destroy(canceled);await create_timer(0.23).timeout
	check(not audio.voices.has(canceled),"Destroyed delayed cue cannot revive after its timer matures")
	var empty := audio.create_sound("");var requests := client.sent.size();audio.play(empty)
	check(audio.voices.has(empty) and not audio.voices[empty].requested and client.sent.size() == requests,"Empty duration resource retains silent native handle without resource IO")
	var transfer := Transfer.new();var many := packets(tone(100000),9,"authored")
	check(transfer.begin(many[0]) and transfer.chunk(many[1]) and transfer.chunk(many[2]) and transfer.commit(many[3]) != null,"Ordered multi-chunk assembly commits exact complete audio")
	var bad := data.duplicate(true);bad[1].index = 1;transfer.begin(bad[0]);check(not transfer.chunk(bad[1]) and transfer.pending.is_empty(),"Out-of-order chunk clears its transfer buffer")
	bad = data.duplicate(true);bad[0].sha256 = "0".repeat(64);transfer.begin(bad[0]);transfer.chunk(bad[1]);check(transfer.commit(bad[2]) == null and transfer.pending.is_empty(),"Digest mismatch cannot create a decoded stream")
	transfer.begin(data[0]);check(transfer.commit(data[2]) == null,"Incomplete bytes cannot be committed")
	var bad_metadata: Dictionary = data[0].duplicate();bad_metadata.bytes = 999999999;check(not transfer.begin(bad_metadata),"Oversized transfer is rejected before buffer allocation")
	bad_metadata = data[0].duplicate();bad_metadata.frames = 3;check(not transfer.begin(bad_metadata),"PCM channel/frame/byte mismatch is rejected")
	var before: int = audio.stats.imports
	audio.receive({"kind":"world-audio-begin","resourceId":999,"name":"absent"})
	check(audio.stats.imports == before,"Unknown resource identity cannot allocate a native transfer")
	client.pivots.clear();await frames();check(audio.listener_state.is_empty(),"Missing controlled actor suppresses listener projection")
	client.pivots[1] = actor;await frames()
	var snapshot := audio.snapshot();audio.close();await frames()
	check(audio.voices.is_empty() and audio.resources.is_empty() and audio.cache_bytes == 0,"World close retires all player, resource and transfer owners")
	check(audio.retired_players.all(func(reference):return reference.get_ref() == null),"Native queued players are freed after world retirement")
	var playback_refs: Array = audio.retired_playback_refs.duplicate();var playback_deadline := Time.get_ticks_msec()+500
	while playback_refs.any(func(reference):return reference.get_ref() != null) and Time.get_ticks_msec() < playback_deadline:await create_timer(0.005).timeout
	check(playback_refs.all(func(reference):return reference.get_ref() == null),"Stopped native audio stream/playback resources retire through the actual mixer")
	var audio_ref: WeakRef = weakref(audio);scene.queue_free();await frames()
	check(audio_ref.get_ref() == null,"Outer scene retirement frees native audio owner and listener")
	AudioServer.remove_bus_effect(0,capture_index)
	await create_timer(0.08).timeout
	for key in captured:captured[key] = [captured[key].x,captured[key].y]
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"observed":client.sent.filter(func(row):return row.kind == "world-audio-observed"),"snapshot":snapshot,"driver":AudioServer.get_driver_name(),"speakerMode":AudioServer.get_speaker_mode(),"mixRate":AudioServer.get_mix_rate(),"mixedChannelEnergy":captured,"spatialPoses":poses,"sourceSha256":FileAccess.get_sha256("res://systems/world_audio.gd"),"transportSha256":FileAccess.get_sha256("res://systems/audio_stream_transfer.gd"),"scope":"Authored PCM native source/transport/lifetime fixture; surround capture aggregates channel pairs, pure stereo uses strict L/R dominance. Original resource playback is a separate owned-server check"},"\t"));file.close()
	print("WORLD_AUDIO_TEST ",checks.size()," checks, ",failures.size()," failures; ",AudioServer.get_driver_name());quit(0 if failures.is_empty() else 1)
