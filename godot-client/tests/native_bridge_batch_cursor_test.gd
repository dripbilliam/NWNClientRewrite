extends SceneTree
# Exact frozen decoder oracle. Synthetic protocol/CPU checks only; no sockets,
# accounts, rendering, frame pacing or FPS measurement.
const Current=preload("res://systems/bridge_frames.gd")
const Before=preload("res://tests/fixtures/bridge_frames_before_batch_cursor.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value and failures.size()<20:failures.append(label)
func json(value: Variant)->PackedByteArray:return (JSON.stringify(value)+"\n").to_utf8_buffer()
func binary(metadata: Variant,tail: PackedByteArray=PackedByteArray())->PackedByteArray:
	var body:=JSON.stringify(metadata).to_utf8_buffer()
	var bytes:=PackedByteArray([0x89,0x50,0x41,0x52,0,0,0,0,0,0,0,0])
	bytes.encode_u32(4,4+body.size()+tail.size());bytes.encode_u32(8,body.size());bytes.append_array(body);bytes.append_array(tail);return bytes
func metadata()->Dictionary:
	return {"kind":"particle-stream","connection":1,"areaId":2147483649,"generation":2,"transferId":3,"epoch":4,"sequence":5,"emitters":[]}
func same_feed(old,now,bytes: PackedByteArray,label: String)->void:
	var expected: Array=old.feed(bytes);var actual: Array=now.feed(bytes)
	check(var_to_bytes(actual)==var_to_bytes(expected),label+" exact returned messages/stream bytes")
	check(now.pending==old.pending and now.failure==old.failure,label+" exact retained suffix/failure")
	check(now.last_frame_sizes==old.last_frame_sizes,label+" exact private wire accounting")
func fragmentation(bytes: PackedByteArray)->void:
	for width in [1,2,3,7,31,128,1024,bytes.size()]:
		var old:=Before.new();var now:=Current.new()
		for offset in range(0,bytes.size(),width):same_feed(old,now,bytes.slice(offset,mini(offset+width,bytes.size())),"Fragment "+str(width)+":"+str(offset))
		check(old.failure.is_empty() and now.pending.is_empty(),"Mixed batch terminates cleanly for width "+str(width))
		old=null;now=null
func rejection(prefix: PackedByteArray,bad: PackedByteArray,label: String)->void:
	var old:=Before.new();var now:=Current.new()
	same_feed(old,now,prefix+bad,label)
	check(not now.failure.is_empty() and now.pending.is_empty() and now.last_frame_sizes.is_empty(),label+" rejects whole batch and clears byte accounting")
	same_feed(old,now,json({"kind":"notice"}),label+" stays failed")
func once(script,bytes: PackedByteArray)->Dictionary:
	var decoder=script.new();var began:=Time.get_ticks_usec()
	var result: Array=decoder.feed(bytes);var elapsed:=Time.get_ticks_usec()-began
	return {"us":elapsed,"messages":result.size(),"wire_bytes":decoder.last_frame_sizes,"failure":decoder.failure,"pending":decoder.pending.size()}
func run()->void:
	var report_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.substr(9)
	if report_path.is_empty() or FileAccess.file_exists(report_path):quit(2);return
	check(FileAccess.get_sha256("res://tests/fixtures/bridge_frames_before_batch_cursor.gd")=="ec41b0cd761902f31a1bed7926bf1668b5521c2272df87b4030ccb08c089d09b","Exact pre-change frozen parser identity")
	var stream:=metadata();stream.emitters=[{"id":11,"count":6,"capacity":6,"positionBytes":72,"attributeBytes":72,"bounds":{"min":[0,0,0],"max":[1,1,1]}}]
	var tail:=PackedByteArray();tail.resize(144)
	for index in tail.size():tail[index]=[10,0x89,0x50,0,34,255][index%6]
	var corpus:=json({"kind":"notice","text":"é·😀\n\"\\","items":[1,null,{"key":true}]})+binary(metadata())+json({"kind":"raw-world-begin","serial":1})+binary(stream,tail)
	for index in 12:corpus.append_array(json({"kind":"raw-world-chunk","serial":index,"objects":[{"id":index,"text":"é·","replicated":{"position":[1,2,3]}}]}))
	corpus.append_array(json({"kind":"raw-world-end","serial":1}));fragmentation(corpus)
	var prefix:=json({"kind":"notice","text":"accepted prefix"})
	for bad in [json(null),json([]),json({"kind":"particle-stream"}),PackedByteArray([0x89,0,0,0,4,0,0,0]),PackedByteArray([0x89,0x50,0x41,0x52,255,255,255,127]),binary(null),binary({"kind":"particle-stream","emitters":[]}),binary(metadata(),PackedByteArray([0]))]:rejection(prefix,bad,"Malformed tail "+str(bad.size()))
	var bad_bounds:=stream.duplicate(true);bad_bounds.emitters[0].bounds.max=[-1,-1,-1];rejection(prefix,binary(bad_bounds,tail),"Inverted particle bounds")
	var duplicate:=stream.duplicate(true);duplicate.emitters.append(duplicate.emitters[0]);rejection(prefix,binary(duplicate,tail+tail),"Duplicate particle identity")
	var padded:=json({"kind":"notice","text":""});var padding:="x".repeat(Current.MAX_JSON-(padded.size()-1))
	var exact:=json({"kind":"notice","text":padding})
	check(exact.size()==Current.MAX_JSON+1,"Exact JSON size-limit fixture")
	var old:=Before.new();var now:=Current.new()
	same_feed(old,now,prefix+exact.slice(0,-1),"Valid prefix followed by maximum-size partial line")
	check(now.failure.is_empty() and now.pending.size()==Current.MAX_JSON,"Size cap is relative to unread suffix")
	same_feed(old,now,PackedByteArray([10]),"Maximum-size line completes after partial prefix")
	check(now.failure.is_empty() and now.pending.is_empty(),"Exact maximum JSON line stays accepted")
	rejection(prefix,exact.slice(0,-1)+PackedByteArray([120]),"Oversized partial JSON after consumed prefix")
	rejection(prefix,exact.slice(0,-1)+PackedByteArray([120,10]),"Oversized complete JSON after consumed prefix")
	# A realistic <=1MiB read containing many complete messages. Time only feed,
	# preserve all rows, and alternate order to reduce systematic first-run bias.
	var burst:=PackedByteArray();var suffix_copies:=0
	for index in 512:burst.append_array(json({"kind":"raw-world-chunk","serial":index,"data":"x".repeat(1024),"objects":[{"id":index}]}))
	var remaining:=burst.size()
	for index in 512:
		var end:=burst.find(10,burst.size()-remaining);remaining=burst.size()-(end+1);suffix_copies+=remaining
	var timings: Array=[]
	for index in 6:
		var first: Dictionary;var second: Dictionary
		if index%2==0:first=once(Before,burst);second=once(Current,burst)
		else:second=once(Current,burst);first=once(Before,burst)
		check(first.messages==512 and second.messages==512 and first.wire_bytes==second.wire_bytes and first.pending==0 and second.pending==0 and first.failure.is_empty() and second.failure.is_empty(),"Burst retains all512 messages and exact boundaries "+str(index))
		timings.append({"before_us":first.us,"cursor_us":second.us})
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"burst_bytes":burst.size(),"burst_messages":512,"old_suffix_copy_bytes_from_boundaries":suffix_copies,"new_suffix_copy_bytes_complete_batch":0,"timings":timings,"scope":"Frozen parser equivalence for JSON/binary/UTF8, fragment boundaries, complete-batch rejection, private wire sizes and size limits. Six alternating bounded synthetic CPU decode pairs; no socket, renderer, replay, game latency or FPS test."}
	var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
func _initialize()->void:call_deferred("run")
