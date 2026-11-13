extends "res://native_live_world.gd"
const SessionEntry=preload("res://native_session_world.gd")
const Trace=preload("res://systems/native_data/creation_runtime_trace.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	for turn in 2:
		var disabled:=Trace.new();disabled.configure({"report":output+str(turn),"settings-check":"true" if turn==0 else "false","creation-phase-trace":"false" if turn==0 else "true"})
		disabled.event("never",{"ticks_ms":1})
		check(not disabled.enabled and not FileAccess.file_exists(output+str(turn)+".runtime.jsonl"),"Both explicit test flags are required "+str(turn))
	var trace:=Trace.new();trace.configure({"report":output+".sample","settings-check":"true","creation-phase-trace":"true"})
	trace.begin_frame({"ticks_ms":0});trace.phase("unarmed",{})
	check(trace.sequence==0,"No frame file or sampling before first ACK enqueue")
	trace.acknowledge({"ticks_ms":0,"frame":1,"entities":0,"desired":18,"payload":{"credential":"never-written"},"bytes":"private"})
	trace.acknowledge({"ticks_ms":1})
	check(trace.sequence==1 and trace.armed,"First ACK arms exactly once")
	trace.begin_frame({"ticks_ms":0,"frame":2});trace.phase("frame:end",{"ticks_ms":0})
	var first_rows:=trace.sequence
	for now in [1,1999]:trace.begin_frame({"ticks_ms":now});trace.phase("must-not-sample",{})
	check(trace.sequence==first_rows and trace.samples==1,"Unselected frames do not write or flush")
	trace.begin_frame({"ticks_ms":2000,"frame":120});trace.phase("frame:end",{})
	check(trace.samples==2 and trace.sequence==first_rows+2,"Sample interval remains exactly bounded at two seconds")
	for index in 300:
		trace.begin_frame({"ticks_ms":4000+index*2000,"frame":240+index*120})
		for phase in ["poll-after","protocol-after","stats-before","stats-after","camera-after","loading-after","end"]:trace.phase("frame:"+phase,{"ticks_ms":4000+index*2000})
	check(trace.sequence==Trace.FRAME_LIMIT,"Frame stages cannot consume reserved final error/finish rows")
	var before_final_dropped: int=trace.dropped
	for index in 40:trace.event("finish:bounded",{"status":0,"error":0,"credential":"never-written","objects":[1,2],"success":true})
	var text:=FileAccess.get_file_as_string(trace.destination)
	var lines:=text.strip_edges().split("\n")
	check(lines.size()==256 and trace.sequence==256 and trace.dropped-before_final_dropped==8,"All trace I/O stops at the fixed 256-row bound")
	check(not text.contains("never-written") and not text.contains("objects") and not text.contains("payload") and not text.contains("private"),"Only explicitly typed scalar fields survive")
	var first: Dictionary=JSON.parse_string(lines[0]);var last: Dictionary=JSON.parse_string(lines[-1])
	check(first.desired==18 and first.entities==0 and last.phase=="finish:bounded" and last.success,"Durable file retains actual zero-admission state and reserved final boundary")
	var collision:=Trace.new();collision.configure({"report":output+".sample","settings-check":"true","creation-phase-trace":"true"})
	check(not collision.enabled and not collision.failure.is_empty(),"Existing evidence is rejected and retained")
	args={"report":output+".inherited","settings-check":"true","creation-phase-trace":"true"}
	creation_runtime.configure(args);receive({"kind":"finish-ack"})
	check(finish_acknowledged and creation_runtime.sequence==1,"Actual inherited receive records final ACK independently of frame sampling")
	var values:=creation_runtime_values()
	check(values.frame is int and values.ticks_ms is int and values.queued_bytes==0 and SessionEntry!=null,"Actual LiveWorld scalar context and full Session entry compile without a peer")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual inherited native trace/ACK, durable sampled scalar file bounds and both root entry scripts compile. No socket, game peer, key, renderer startup, server, or user process action."}));file.close()
	quit(0 if failures.is_empty() else 1)
