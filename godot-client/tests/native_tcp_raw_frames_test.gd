extends SceneTree
const Frames=preload("res://systems/bridge_frames.gd")
var checks:=0
var failures: Array=[]
var cases: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label);print("FAIL: ",label)
func digest(bytes: PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func _initialize()->void:run.call_deferred()
func run()->void:
	var output:="";var manifest_path:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--result="):output=argument.trim_prefix("--result=")
		if argument.begins_with("--manifest="):manifest_path=argument.trim_prefix("--manifest=")
	if output.is_empty() or manifest_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	for spec in manifest.cases:
		await run_case(spec,manifest)
	var result: Dictionary={"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"scope":"Actual installed Godot StreamPeerTCP with current Root poll/available/get_data<=1MiB read pattern and actual BridgeFrames. Actual raw-world-frames Node sender, authored 5-object/100-tile UTF8 data. Ephemeral loopback only; no NWN Session/server/assets/extensions/profile/key/GPU/native build."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("NATIVE_TCP_RAW_FRAMES ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func run_case(spec: Dictionary,manifest: Dictionary)->void:
	var peer:=StreamPeerTCP.new();var parser:=Frames.new();var started:=Time.get_ticks_msec();var idle_requested: int=int(spec.get("idleMs",0));var deadline:=started+idle_requested+7500
	var connect_error: int=peer.connect_to_host("127.0.0.1",int(manifest.port));var connected:=false
	while connect_error==OK and Time.get_ticks_msec()<deadline:
		peer.poll()
		if peer.get_status()==StreamPeerTCP.STATUS_CONNECTED:connected=true;break
		if peer.get_status()==StreamPeerTCP.STATUS_ERROR:break
		await process_frame
	check(connected,str(spec.id)+": real loopback peer connects")
	var read_start:=Time.get_ticks_msec()+int(spec.pauseMs);var received: Array=[];var bytes:=0;var reads:=0;var partial_peak:=0;var would_read_peak:=0
	var hash_owner:=HashingContext.new();hash_owner.start(HashingContext.HASH_SHA256)
	var read_error:=OK;var poll_error:=OK;var early_eof:=false;var partial_ack:=false;var pending_samples: Array=[]
	var idle_started_us: int=-1;var idle_elapsed_us: int=-1;var idle_polls:=0;var idle_errors:=0;var idle_pending_ok:=true;var idle_markers: Array=[];var next_idle_marker_us:=0
	while connected and received.size()<int(spec.frames) and Time.get_ticks_msec()<deadline:
		if spec.pauseMode=="no-poll" and Time.get_ticks_msec()<read_start:
			await process_frame;continue
		# Same API order and read-size cap as native_live_world._profile_tick.
		poll_error=peer.poll()
		if peer.get_status()==StreamPeerTCP.STATUS_CONNECTED:
			if idle_started_us>=0 and idle_elapsed_us<0:
				idle_polls+=1
				if poll_error!=OK:idle_errors+=1
				idle_pending_ok=idle_pending_ok and parser.pending.size()==int(spec.minPartial)
				var elapsed_us: int=Time.get_ticks_usec()-idle_started_us
				if elapsed_us>=next_idle_marker_us and idle_markers.size()<12:
					idle_markers.append({"elapsedUs":elapsed_us,"status":peer.get_status(),"pending":parser.pending.size(),"available":peer.get_available_bytes(),"pollError":poll_error});next_idle_marker_us+=5000000
			if Time.get_ticks_msec()>=read_start:
				var count:=peer.get_available_bytes();would_read_peak=maxi(would_read_peak,count)
				if count>0:
					if idle_started_us>=0 and idle_elapsed_us<0:idle_elapsed_us=Time.get_ticks_usec()-idle_started_us
					var chunk:=peer.get_data(mini(count,1048576))
					read_error=int(chunk[0]);if read_error!=OK:break
					hash_owner.update(chunk[1]);bytes+=chunk[1].size();reads+=1
					received.append_array(parser.feed(chunk[1]));partial_peak=maxi(partial_peak,parser.pending.size())
					if pending_samples.size()<12:pending_samples.append({"bytes":bytes,"frames":received.size(),"pending":parser.pending.size(),"available":peer.get_available_bytes()})
					if int(spec.minPartial)>0 and not partial_ack and parser.pending.size()>=int(spec.minPartial):
						partial_ack=true;var partial:={"kind":"partial","id":spec.id,"pending":parser.pending.size()}
						if idle_requested>0:idle_started_us=Time.get_ticks_usec()
						read_error=peer.put_data((JSON.stringify(partial)+"\n").to_utf8_buffer())
					if not parser.failure.is_empty() or read_error!=OK:break
		else:early_eof=true;break
		await process_frame
	var wire_sha:=hash_owner.finish().hex_encode();var kinds: Array=[];var metadata_ok:=true;var header: Dictionary={};var objects: Array=[]
	for frame in received:
		kinds.append(frame.get("kind",""))
		metadata_ok=metadata_ok and frame.get("connection")==manifest.connection and frame.get("generation")==manifest.generation and frame.get("serial")==spec.serial
		if frame.get("kind")=="raw-world-begin":header=frame.get("data",{});metadata_ok=metadata_ok and frame.get("count")==5
		if frame.get("kind")=="raw-world-chunk":objects.append_array(frame.get("objects",[]))
	var expected_header: Dictionary=manifest.data.duplicate(true);expected_header.erase("objects")
	var semantic:=PackedStringArray()
	for object in objects:semantic.append(str(object.get("replicated",{}).get("description","")))
	var semantic_sha:=digest("\n".join(semantic).to_utf8_buffer())
	var equal: bool=header==expected_header and objects==manifest.data.objects
	check(read_error==OK and poll_error==OK and parser.failure.is_empty(),str(spec.id)+": actual reads and bridge parser report no error")
	check(received.size()==int(spec.frames) and bytes==int(spec.bytes),str(spec.id)+": every frame and byte arrives before deadline")
	check(metadata_ok and kinds==["raw-world-begin","raw-world-chunk","raw-world-end"],str(spec.id)+": real sender preserves begin/chunk/end order and scope")
	check(wire_sha==spec.wireSha256,str(spec.id)+": raw received stream SHA256 equals sender")
	check(semantic_sha==manifest.semanticSha256,str(spec.id)+": decoded multibyte UTF8 payload SHA256 equals sender")
	check(equal and objects.size()==5 and header.get("area",{}).get("tiles",[]).size()==100,str(spec.id)+": parsed 5 objects and 100-tile header exactly match")
	check(parser.pending.is_empty() and received.size()==3,str(spec.id)+": no unterminated/missing delimiter remains")
	check(not early_eof,str(spec.id)+": no EOF occurs before complete payload")
	if int(spec.minPartial)>0:check(partial_ack and partial_peak>=int(spec.minPartial),str(spec.id)+": 10971-byte unterminated chunk is retained and later completed")
	if idle_requested>0:check(idle_elapsed_us>=idle_requested*1000 and idle_polls>0 and idle_errors==0 and idle_pending_ok,str(spec.id)+": native polling retains the unterminated frame through35s open-socket idle without error or early EOF")
	var complete:={"kind":"complete","id":spec.id,"bytes":bytes,"frames":received.size(),"wireSha256":wire_sha,"payloadEqual":equal,"semanticSha256":semantic_sha}
	var control_error: int=peer.put_data((JSON.stringify(complete)+"\n").to_utf8_buffer()) if connected and peer.get_status()==StreamPeerTCP.STATUS_CONNECTED else ERR_CONNECTION_ERROR
	var eof:=false;var eof_poll:=-1
	while control_error==OK and Time.get_ticks_msec()<deadline:
		eof_poll=peer.poll()
		if peer.get_status()==StreamPeerTCP.STATUS_NONE:eof=true;break
		if peer.get_status()==StreamPeerTCP.STATUS_ERROR:break
		await process_frame
	check(control_error==OK and eof,str(spec.id)+": sender closes only after reader completion and native EOF is observed")
	peer.disconnect_from_host();check(peer.get_status()==StreamPeerTCP.STATUS_NONE,str(spec.id)+": owned peer is disconnected after case")
	cases.append({"id":spec.id,"receivedFrames":received.size(),"bytes":bytes,"reads":reads,"wireSha256":wire_sha,"semanticSha256":semantic_sha,"payloadEqual":equal,"partialPeak":partial_peak,"partialAck":partial_ack,"pendingSamples":pending_samples,"availablePeak":would_read_peak,"earlyEof":early_eof,"eof":eof,"eofPollError":eof_poll,"idleRequestedMs":idle_requested,"idleElapsedUs":idle_elapsed_us,"idlePolls":idle_polls,"idlePollErrors":idle_errors,"idlePendingStable":idle_pending_ok,"idleMarkers":idle_markers,"elapsedMs":Time.get_ticks_msec()-started})
