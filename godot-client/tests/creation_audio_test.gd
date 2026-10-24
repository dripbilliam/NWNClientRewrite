extends SceneTree
const NativeAudio = preload("res://systems/creation_audio.gd")
const Creator = preload("res://systems/server_creation.gd")
const Client = preload("res://systems/local_connection.gd")
var checks := 0
var failures: Array[String] = []
var observations: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = control.get_global_rect().get_center(); event.global_position = event.position; root.push_input(event, true); await process_frame
func tone(frames: int, channels: int = 1) -> PackedByteArray:
	var bytes := PackedByteArray(); bytes.resize(frames * channels * 2)
	for i in frames:
		for channel in channels: bytes.encode_s16((i * channels + channel) * 2, int(sin(float(i) * TAU * 220.0 / 8000) * 8191))
	return bytes
func packets(bytes: PackedByteArray, sequence: int, channels: int = 1) -> Array:
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
	var result := [{"kind":"creation-voice-state","owner":10,"sequence":sequence,"state":"loading","code":sequence - 1},{"kind":"creation-audio-begin","owner":10,"sequence":sequence,"codec":"pcm16","channels":channels,"sampleRate":8000,"frames":bytes.size() / (channels * 2),"bytes":bytes.size(),"sha256":digest.finish().hex_encode()}]
	var index := 0
	for at in range(0, bytes.size(), 131072): result.append({"kind":"creation-audio-chunk","owner":10,"sequence":sequence,"index":index,"data":Marshalls.raw_to_base64(bytes.slice(at, mini(bytes.size(), at + 131072)))}); index += 1
	result.append({"kind":"creation-audio-commit","owner":10,"sequence":sequence,"chunks":index}); return result
func run() -> void:
	var output := "res://reports/creation-audio-native-v1.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	root.size = Vector2i(1200, 850)
	var audio := NativeAudio.new(); root.add_child(audio); audio.observed.connect(func(value): observations.append(value)); audio.configure(10)
	var bytes := tone(8000); var first := packets(bytes, 1)
	for packet in first: audio.receive(packet)
	check(audio.player.playing and audio.player.stream is AudioStreamWAV and audio.played == 1, "Native player starts the completely received original-rate PCM stream")
	check(audio.player.stream.mix_rate == 8000 and not audio.player.stream.stereo and audio.player.stream.data == bytes, "Native output preserves mono samples and rate without browser resampling")
	check(absf(audio.player.stream.get_length() - 1.0) < 0.001 and observations.back().sha256 == first[1].sha256, "Decoded duration and native payload checksum match independent metadata")
	await create_timer(0.12).timeout
	check(audio.player.get_playback_position() > 0, "Native audio clock advances while its player is active")
	var stereo := packets(tone(6000, 2), 2, 2)
	for packet in stereo: audio.receive(packet)
	check(audio.played == 2 and audio.player.stream.stereo and audio.pending.is_empty(), "A newer stereo sample replaces playback and releases its transfer buffer")
	var current: AudioStream = audio.player.stream
	for packet in first: audio.receive(packet)
	check(audio.played == 2 and audio.player.stream == current, "Older sample packets cannot replace a newer stream")
	current = null
	var many := packets(tone(100000), 3)
	for packet in many: audio.receive(packet)
	check(audio.played == 3 and many.size() > 4 and audio.player.stream.data.size() == 200000, "Multi-chunk native transport assembles a complete audio stream")
	var broken := packets(bytes, 4); broken[2].index = 1
	for packet in broken: audio.receive(packet)
	check(not audio.player.playing and audio.player.stream == null and audio.pending.is_empty() and audio.status.contains("chunk"), "Out-of-order chunks stop and release their invalid owner")
	broken = packets(bytes, 5); broken[1].sha256 = "0".repeat(64)
	for packet in broken: audio.receive(packet)
	check(audio.played == 3 and audio.status.contains("checksum"), "A checksum mismatch never starts playback")
	broken = packets(bytes, 6); broken.remove_at(2)
	for packet in broken: audio.receive(packet)
	check(audio.played == 3 and audio.status.contains("incomplete"), "Partial audio cannot be committed")
	broken = packets(bytes, 7); broken[1].bytes = 999999999
	for packet in broken: audio.receive(packet)
	check(audio.played == 3 and audio.status.contains("metadata"), "Oversized audio is rejected before buffer allocation")
	for packet in packets(bytes, 8): audio.receive(packet)
	audio.receive({"kind":"creation-voice-stop","owner":11}); check(not audio.player.playing and audio.player.stream == null, "Changing selected voice immediately stops the prior stream")
	for packet in packets(bytes, 9): audio.receive(packet)
	check(audio.played == 4, "A retired voice owner cannot restart playback")
	audio.reset(); check(audio.voice_owner == -1 and not audio.snapshot().hasStream and audio.pending.is_empty(), "Reset releases native stream and pending byte owners")
	var ui := Creator.new(); root.add_child(ui); var requests: Array = []; ui.request.connect(func(value): requests.append(value)); ui.open()
	var choices: Array = []
	for index in 80: choices.append({"type":"button","controlId":100 + index,"label":"Authored voice %s" % index,"tag":"voice","selected":index == 60,"disabled":false})
	choices.append({"type":"voice-sample","controlId":8,"label":"Play sample","disabled":false})
	ui.receive({"kind":"creation-begin","viewId":1,"voiceOwner":10,"step":12,"steps":["Gender","Race","Portrait","Class","Alignment","Package","Abilities","Domains","Skills","Feats","Spells","Appearance","Voice","Name","Review"],"phase":"editing","canEdit":true,"canFinish":false,"canRecommend":false,"canCancel":true,"count":choices.size()})
	ui.receive({"kind":"creation-items","viewId":1,"items":choices}); ui.receive({"kind":"creation-commit","viewId":1}); await process_frame; await process_frame
	check(ui.voice_sample_button.is_visible_in_tree() and ui.voice_sample_button.get_global_rect().end.y < root.size.y and ui.voice_status.text.contains("Authored voice 60"), "Sample and selected-voice feedback remain visible outside an eighty-entry scrolling list")
	await click(ui.controls[8]); check(requests.back().operation == "voice" and requests.back().controlId == 8 and not ui.waiting, "Actual sample click uses a private voice handle without locking the whole creator")
	for packet in first: ui.receive(packet)
	check(ui.voice_status.visible and ui.voice_audio.player.playing, "Creator routes voice packets to its native audio owner before world admission")
	ui.reset(); check(not ui.voice_audio.player.playing and ui.voice_audio.player.stream == null, "Closing creation also retires its native player")
	for packet in packets(bytes, 10): ui.receive(packet)
	check(not ui.voice_audio.player.playing, "Late voice packets cannot play after the creator closes")
	var audio_refs: Array = audio.retired_playback_refs.duplicate();audio_refs.append_array(ui.voice_audio.retired_playback_refs)
	ui.free();audio.free();await process_frame
	var deadline := Time.get_ticks_msec()+500
	while audio_refs.any(func(reference):return reference.get_ref() != null) and Time.get_ticks_msec() < deadline:await create_timer(0.005).timeout
	check(audio_refs.all(func(reference):return reference.get_ref() == null),"Stopped native voice playback references retire on the mixer before engine exit")
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"observations":observations},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
