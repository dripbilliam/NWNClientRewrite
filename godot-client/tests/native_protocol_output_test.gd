extends SceneTree
const Output=preload("res://systems/native_protocol_output.gd")
var checks:=0
var failures: Array=[]
class Writer extends RefCounted:
	var bytes:=PackedByteArray()
	var calls:=0
	var amount:=3
	var code:=OK
	func write(value: PackedByteArray) -> Array:
		calls+=1
		if code!=OK: return [code,0]
		var count:=mini(amount,value.size()); bytes.append_array(value.slice(0,count)); return [OK,count]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var queue:=Output.new(); var writer:=Writer.new()
	queue.enqueue("OLD".to_utf8_buffer(),"observed"); queue.enqueue("OBS2".to_utf8_buffer(),"observed"); queue.enqueue("ACTION".to_utf8_buffer()); queue.enqueue("OLD".to_utf8_buffer(),"observed"); queue.enqueue("OBS4".to_utf8_buffer(),"observed")
	check(queue.snapshot().coalesced==2 and queue.snapshot().queued_messages==3,"Only adjacent unstarted observations coalesce across real ordered commands")
	for frame in 20: queue.flush(writer.write,4,10000)
	check(writer.bytes.get_string_from_utf8()=="OBS2ACTIONOBS4" and queue.queued_bytes==0 and queue.snapshot().sent==3,"Partial writes preserve exact action bytes and FIFO frame boundaries")
	check(queue.snapshot().partial_writes>0,"Short successful writes retain the remaining frame")
	queue=Output.new(); writer=Writer.new(); queue.enqueue("FIRST".to_utf8_buffer(),"observed"); queue.flush(writer.write,1,10000); queue.enqueue("SECOND".to_utf8_buffer(),"observed")
	for frame in 20: queue.flush(writer.write,4,10000)
	check(writer.bytes.get_string_from_utf8()=="FIRSTSECOND","A partially written observation can never be replaced or corrupt the stream")
	queue=Output.new(); writer=Writer.new(); writer.amount=0; queue.enqueue("COMMAND".to_utf8_buffer())
	check(queue.flush(writer.write)==OK and writer.calls==1 and queue.queued_bytes==7,"A nonreading peer yields after one zero-byte write while retaining the command")
	writer.code=ERR_BUSY; check(queue.flush(writer.write)==OK and queue.queued_bytes==7 and queue.snapshot().would_block==2,"Temporary socket backpressure remains retryable across frames")
	writer.code=OK; writer.amount=100; queue.flush(writer.write); check(writer.bytes.get_string_from_utf8()=="COMMAND","Retained command drains when the peer resumes reading")
	queue=Output.new(); queue.maximum_bytes=4; queue.enqueue("ACT!".to_utf8_buffer()); check(queue.enqueue("OBSERVATION".to_utf8_buffer(),"observed")==OK and queue.snapshot().dropped_observations==1 and queue.queued_bytes==4,"Bounded diagnostic dropping preserves queued commands")
	check(queue.enqueue("NEXT".to_utf8_buffer())==ERR_OUT_OF_MEMORY and queue.snapshot().failure==ERR_OUT_OF_MEMORY,"A full command queue fails explicitly rather than dropping an action or waiting")
	queue=Output.new(); queue.enqueue("X".to_utf8_buffer()); writer.code=ERR_CONNECTION_ERROR
	check(queue.flush(writer.write)==ERR_CONNECTION_ERROR and queue.queued_bytes==1,"Disconnect errors retain explicit failure and pending byte accounting")
	queue=Output.new(); queue.enqueue("X".to_utf8_buffer()); check(queue.flush(func(_bytes):return [OK,2])==ERR_INVALID_DATA,"Invalid partial-write counts cannot silently corrupt stream framing")
	var server:=TCPServer.new(); var port:=-1
	for candidate in range(51817,51833):
		if server.listen(candidate,"127.0.0.1")==OK: port=candidate; break
	check(port>=0,"Owned TCP backpressure test binds loopback only")
	var peer:=StreamPeerTCP.new(); var receiver: StreamPeerTCP
	if port>=0:
		check(peer.connect_to_host("127.0.0.1",port)==OK,"Production socket connects to the owned local reader")
		var deadline:=Time.get_ticks_msec()+5000
		while Time.get_ticks_msec()<deadline and (receiver==null or peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED):
			peer.poll()
			if receiver==null and server.is_connection_available(): receiver=server.take_connection()
			await process_frame
		check(receiver!=null and peer.get_status()==StreamPeerTCP.STATUS_CONNECTED,"Owned nonblocking reader and writer become connected")
		if receiver!=null:
			queue=Output.new(); var payload:=PackedByteArray(); payload.resize(32*1024*1024); payload.fill(42); queue.enqueue(payload)
			for frame in 64:
				peer.poll(); queue.flush(Callable(peer,"put_partial_data")); await process_frame
				if queue.snapshot().would_block>0: break
			check(queue.failure==OK and queue.snapshot().would_block>0 and queue.queued_bytes>0,"Actual StreamPeerTCP yields under a nonreading peer instead of blocking the game thread")
			var received:=0; var exact:=true; deadline=Time.get_ticks_msec()+10000
			while Time.get_ticks_msec()<deadline and (received<payload.size() or queue.queued_bytes>0):
				peer.poll(); receiver.poll(); queue.flush(Callable(peer,"put_partial_data"))
				while receiver.get_available_bytes()>0:
					var value: Array=receiver.get_data(mini(receiver.get_available_bytes(),65536)); var bytes: PackedByteArray=value[1]; exact=exact and int(value[0])==OK and bytes.count(42)==bytes.size(); received+=bytes.size()
				await process_frame
			check(received==payload.size() and queue.queued_bytes==0 and exact and queue.failure==OK,"Actual loopback stream resumes and delivers every byte without duplication or loss")
			check(queue.snapshot().bytes_sent==payload.size(),"Production byte accounting matches the receiver after backpressure")
			receiver.disconnect_from_host()
	peer.disconnect_from_host(); server.stop()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"scope":"Deterministic output ordering/partial/backpressure/error cases and actual owned loopback StreamPeerTCP saturation/drain. Not a GPU/FPS benchmark or authoritative gameplay acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
