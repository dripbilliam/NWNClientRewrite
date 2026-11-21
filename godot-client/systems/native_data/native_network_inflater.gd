extends RefCounted
# UncompressMessage255c80: bit 2 marks compressed data, bit 0 retains the
# server's zlib window, and the expected output DWORD is at offset 12.
const LIMIT:=0x1400000

var stream: StreamPeerGZIP
var pending:=false
var failed:=false
var closed:=false

func decode(record: PackedByteArray)->Dictionary:
	if closed or failed:
		return {"error":"Native message inflater is unavailable"}
	if record.size()<12:
		return {"error":"Invalid native message record"}
	if (int(record[7]) & 4)==0:
		return {"bytes":record.slice(12)}
	if record.size()<16:
		return {"error":"Truncated native compressed message"}
	var expected:=int(record.decode_u32(12))
	if expected>LIMIT:
		return {"error":"Invalid native decompressed message size"}
	var source:=record.slice(16)
	if (int(record[7]) & 1)==0:
		return _decode_block(source,expected)
	return _decode_stream(source,expected)

func _decode_block(source: PackedByteArray,expected: int)->Dictionary:
	var decoder:=StreamPeerGZIP.new()
	# inflateSync limits output to max(1, expected). Keep Godot's minimum
	# working buffer size, then reject any output over the old limit.
	if decoder.start_decompression(true,maxi(65535,maxi(1,expected)))!=OK:
		return {"error":"Native block message decompression failed"}
	if decoder.put_data(source)!=OK:
		decoder.clear()
		return {"error":"Native block message decompression failed"}
	var size:=decoder.get_available_bytes()
	if size>expected:
		decoder.clear()
		return {"error":"Native block message decompression failed"}
	var result: Array=decoder.get_data(size)
	decoder.clear()
	if int(result[0])!=OK:
		return {"error":"Native block message decompression failed"}
	return {"bytes":result[1]}

func _decode_stream(source: PackedByteArray,expected: int)->Dictionary:
	if pending:
		return {"error":"Concurrent native stream decompression is unavailable"}
	if stream==null:
		stream=StreamPeerGZIP.new()
		if stream.start_decompression(true,LIMIT+65536)!=OK:
			return _stream_failure()
	pending=true
	var status:=stream.put_data(source)
	if status!=OK:
		return _stream_failure()
	var size:=stream.get_available_bytes()
	if size!=expected:
		return _stream_failure()
	var result: Array=stream.get_data(size)
	if int(result[0])!=OK or result[1].size()!=expected:
		return _stream_failure()
	pending=false
	return {"bytes":result[1]}

func _stream_failure()->Dictionary:
	failed=true
	pending=false
	if stream!=null:
		stream.clear()
		stream=null
	return {"error":"Native stream message decompression failed"}

func close()->void:
	if closed:
		return
	closed=true
	if pending:
		failed=true
		pending=false
	if stream!=null:
		stream.clear()
		stream=null
