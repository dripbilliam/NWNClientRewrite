extends RefCounted
# Bounded in-memory stream assembly. Original bytes never enter project files.
const MAX_BYTES := 64*1024*1024
const CHUNK_BYTES := 128*1024
var pending: Dictionary = {}
var metadata: Dictionary = {}
var error := ""
var pattern := RegEx.new()
func _init() -> void: pattern.compile("^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$")
func fail(reason: String) -> bool:
	error = reason;pending.clear();return false
func begin(message: Dictionary) -> bool:
	error = "";pending.clear();metadata.clear()
	var count := int(message.get("bytes",0));var codec := str(message.get("codec",""));var channels := int(message.get("channels",0));var rate := int(message.get("sampleRate",0));var frames := int(message.get("frames",0))
	if count < 1 or count > MAX_BYTES or codec not in ["pcm16","mp3","ogg"] or channels not in [1,2] or str(message.get("sha256","")).length() != 64 or (codec == "pcm16" and (rate < 1 or rate > 384000 or frames < 1 or frames > 16000000 or frames*channels*2 != count)):return fail("Invalid world audio metadata")
	var buffer := StreamPeerBuffer.new();buffer.resize(count)
	pending = message.duplicate(true);pending.buffer = buffer;pending.received = 0;pending.chunks = 0
	return true
func chunk(message: Dictionary) -> bool:
	if pending.is_empty():return fail("Audio chunk has no pending owner")
	var encoded := str(message.get("data",""))
	if int(message.get("index",-1)) != int(pending.chunks) or encoded.length() < 4 or encoded.length() > ((CHUNK_BYTES+2)/3)*4+4 or pattern.search(encoded) == null:return fail("Invalid world audio chunk")
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.is_empty() or bytes.size() > CHUNK_BYTES or int(pending.received)+bytes.size() > int(pending.bytes):return fail("World audio chunk exceeds its owner")
	if pending.buffer.put_data(bytes) != OK:return fail("World audio transfer failed")
	pending.received += bytes.size();pending.chunks += 1;return true
func commit(message: Dictionary) -> AudioStream:
	if pending.is_empty():fail("No world audio transfer to commit");return null
	if int(pending.received) != int(pending.bytes) or int(message.get("chunks",-1)) != int(pending.chunks):fail("Incomplete world audio transfer");return null
	var bytes: PackedByteArray = pending.buffer.data_array
	var digest := HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes)
	if digest.finish().hex_encode() != str(pending.sha256):fail("World audio checksum mismatch");return null
	var stream: AudioStream
	if pending.codec == "pcm16":
		var wave := AudioStreamWAV.new();wave.format = AudioStreamWAV.FORMAT_16_BITS;wave.stereo = int(pending.channels) == 2;wave.mix_rate = int(pending.sampleRate);wave.data = bytes;stream = wave
	elif pending.codec == "mp3":
		var mp3 := AudioStreamMP3.new();mp3.data = bytes;stream = mp3
	else:stream = AudioStreamOggVorbis.load_from_buffer(bytes)
	if stream == null or stream.get_length() <= 0:fail("Native world audio decoder rejected the stream");return null
	metadata = pending.duplicate();metadata.erase("buffer");pending.clear();return stream
func clear() -> void:pending.clear();metadata.clear()
