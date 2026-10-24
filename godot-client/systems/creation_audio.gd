extends Node
signal observed(value: Dictionary)
const MAX_BYTES := 64 * 1024 * 1024
const CHUNK_BYTES := 128 * 1024
var player: AudioStreamPlayer
var voice_owner := -1
var sequence := -1
var pending: Dictionary = {}
var status := ""
var played := 0
var last: Dictionary = {}
var base64_pattern := RegEx.new()
var retired_playback_refs: Array = []

func _ready() -> void:
	player = AudioStreamPlayer.new(); player.max_polyphony = 1; add_child(player)
	player.finished.connect(func(): status = "Sample finished. Play sample for the next line.")
	base64_pattern.compile("^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$")

func stop() -> void:
	retired_playback_refs = retired_playback_refs.filter(func(reference):return reference.get_ref() != null)
	if is_instance_valid(player):
		if player.stream != null:retired_playback_refs.append(weakref(player.stream))
		if player.has_stream_playback():
			var playback = player.get_stream_playback()
			if playback != null:retired_playback_refs.append(weakref(playback))
		player.stop();player.stream = null
	pending.clear()

func reset() -> void:
	stop(); voice_owner = -1; sequence = -1; status = ""; last.clear()

func configure(value: int) -> void:
	if voice_owner != value: stop(); voice_owner = value; sequence = -1; status = ""; last.clear()

func fail(reason: String) -> void:
	stop(); status = reason
	observed.emit({"owner":voice_owner,"sequence":sequence,"state":"error","reason":reason})

func receive(message: Dictionary) -> void:
	if message.kind == "creation-voice-stop":
		if int(message.owner) >= voice_owner: configure(int(message.owner)); stop(); status = ""
		return
	if int(message.get("owner", -2)) != voice_owner: return
	var next := int(message.get("sequence", -1))
	if message.kind == "creation-voice-state":
		if next < sequence: return
		if message.state == "loading":
			stop(); sequence = next; status = "Loading sample %s…" % (int(message.get("code", 0)) + 1)
		elif next == sequence:
			stop(); status = "This soundset has no line in sample %s. Play sample advances to the next line." % (int(message.get("code", 0)) + 1) if message.state == "empty" else str(message.get("text", "Voice sample failed"))
		return
	if next != sequence or sequence < 0: return
	if message.kind == "creation-audio-begin":
		var count := int(message.get("bytes", 0)); var codec := str(message.get("codec", "")); var channels := int(message.get("channels", 0)); var rate := int(message.get("sampleRate", 0)); var frames := int(message.get("frames", 0))
		if count < 1 or count > MAX_BYTES or codec not in ["pcm16", "mp3", "ogg"] or str(message.get("sha256", "")).length() != 64 or codec == "pcm16" and (channels not in [1, 2] or rate < 1 or rate > 384000 or frames < 1 or frames > 16000000 or frames * channels * 2 != count): fail("Invalid native audio metadata"); return
		stop(); var buffer := StreamPeerBuffer.new(); buffer.resize(count)
		pending = message.duplicate(true); pending["buffer"] = buffer; pending["received"] = 0; pending["chunks"] = 0
	elif message.kind == "creation-audio-chunk":
		if pending.is_empty(): return
		var encoded := str(message.get("data", ""))
		if int(message.get("index", -1)) != int(pending.chunks) or encoded.length() < 4 or encoded.length() > ((CHUNK_BYTES + 2) / 3) * 4 + 4 or base64_pattern.search(encoded) == null: fail("Invalid native audio chunk"); return
		var bytes := Marshalls.base64_to_raw(encoded)
		if bytes.is_empty() or bytes.size() > CHUNK_BYTES or int(pending.received) + bytes.size() > int(pending.bytes): fail("Native audio chunk exceeds its owner"); return
		if pending.buffer.put_data(bytes) != OK: fail("Native audio transfer failed"); return
		pending["received"] += bytes.size(); pending["chunks"] += 1
	elif message.kind == "creation-audio-commit":
		if pending.is_empty(): return
		if int(pending.received) != int(pending.bytes) or int(message.get("chunks", -1)) != int(pending.chunks): fail("Native audio transfer is incomplete"); return
		var bytes: PackedByteArray = pending.buffer.data_array; var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
		if digest.finish().hex_encode() != str(pending.sha256): fail("Native audio transfer checksum failed"); return
		var stream: AudioStream
		if pending.codec == "pcm16":
			var wave := AudioStreamWAV.new(); wave.format = AudioStreamWAV.FORMAT_16_BITS; wave.stereo = int(pending.channels) == 2; wave.mix_rate = int(pending.sampleRate); wave.data = bytes; stream = wave
		elif pending.codec == "mp3":
			var mp3 := AudioStreamMP3.new(); mp3.data = bytes; stream = mp3
		else: stream = AudioStreamOggVorbis.load_from_buffer(bytes)
		if stream == null or stream.get_length() <= 0: fail("Native audio decoder could not load the sample"); return
		last = {"owner":voice_owner,"sequence":sequence,"state":"playing","code":pending.get("code", -1),"voiceId":pending.get("voiceId", -1),"codec":pending.codec,"bytes":pending.bytes,"sha256":pending.sha256,"duration":stream.get_length(),"driver":AudioServer.get_driver_name()}
		pending.clear(); player.stream = stream; player.volume_db = 0; player.play(); played += 1; status = "Playing voice sample"; observed.emit(last.duplicate(true))

func snapshot() -> Dictionary:
	return {"owner":voice_owner,"sequence":sequence,"played":played,"playing":player.playing,"position":player.get_playback_position(),"pendingBytes":pending.get("received", 0),"hasStream":player.stream != null,"last":last.duplicate(true)}

func _exit_tree() -> void: stop()
