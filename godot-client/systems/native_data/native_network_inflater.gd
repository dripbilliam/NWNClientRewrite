extends RefCounted
# Native UncompressMessage255c80: bit 2 is compressed, bit 0 retains the
# server's zlib window. Godot's StreamPeerGZIP with use_deflate=true accepts
# that zlib stream and preserves it across sync-flush records.
const LIMIT:=0x1400000
var stream: StreamPeerGZIP
var failed:=false

func decode(record: PackedByteArray)->Dictionary:
	if failed or record.size()<12:return {"error":"Invalid native game record"}
	if (int(record[7]) & 4)==0:return {"bytes":record.slice(12)}
	if record.size()<16:return fail("Truncated native compressed record")
	var expected:=int(record.decode_u32(12))
	if expected>LIMIT:return fail("Native decompressed message exceeds bound")
	var persistent: bool=(int(record[7]) & 1)!=0
	var decoder: StreamPeerGZIP=stream if persistent and stream!=null else StreamPeerGZIP.new()
	if decoder!=stream:
		var capacity:=LIMIT+65536 if persistent else maxi(expected+65536,65535)
		if decoder.start_decompression(true,capacity)!=OK:return fail("Native zlib inflater could not start")
		if persistent:stream=decoder
	var status:=decoder.put_data(record.slice(16))
	if status!=OK:return fail("Native zlib data is invalid")
	if decoder.get_available_bytes()!=expected:return fail("Native decompressed message size differs")
	var result: Array=decoder.get_data(expected)
	if int(result[0])!=OK or result[1].size()!=expected:return fail("Native zlib output is incomplete")
	if not persistent:decoder.clear()
	return {"bytes":result[1]}

func fail(reason: String)->Dictionary:
	failed=true
	close()
	return {"error":reason}

func close()->void:
	if stream!=null:stream.clear();stream=null
