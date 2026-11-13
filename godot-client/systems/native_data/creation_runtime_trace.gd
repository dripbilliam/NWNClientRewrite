extends RefCounted
# Opt-in CreationCheck evidence. Only sampled frame boundaries and scalar errors
# are written; no object payloads, buffers, names, authentication or credentials.
const MAX_ROWS:=256
const FRAME_LIMIT:=224
const INTERVAL_MS:=2000
const INTEGERS:=["frame","epoch","ticks_ms","serial","generation","status","poll_error","error","bytes","expected","queued_bytes","entities","desired","pending_batches","hidden","failed","received","connection"]
const BOOLEANS:=["closing","initialized","acknowledged","success","world_closed","world_retiring","world_processing"]
var enabled:=false
var armed:=false
var sampling:=false
var sequence:=0
var dropped:=0
var samples:=0
var next_sample:=0
var destination:=""
var failure:=""
func configure(options: Dictionary) -> void:
	enabled=options.get("creation-phase-trace","")=="true" and options.get("settings-check","")=="true"
	if not enabled:return
	destination=str(options.get("report",""))+".runtime.jsonl"
	if str(options.get("report","")).is_empty() or FileAccess.file_exists(destination):
		failure="Existing or missing owned runtime trace destination";enabled=false
func write(stage: String,values: Dictionary,critical: bool=false) -> void:
	if not enabled:return
	if sequence>=(MAX_ROWS if critical else FRAME_LIMIT):dropped+=1;return
	var row: Dictionary={"kind":"creation-runtime-phase","phase":stage.left(160),"sequence":sequence+1}
	for key in INTEGERS:
		if values.get(key) is int:row[key]=values[key]
	for key in BOOLEANS:
		if values.get(key) is bool:row[key]=values[key]
	var file:=FileAccess.open(destination,FileAccess.WRITE if sequence==0 else FileAccess.READ_WRITE)
	if file==null:failure="Cannot open owned runtime trace";enabled=false;return
	file.seek_end();file.store_line(JSON.stringify(row));file.flush();file.close();sequence+=1
func acknowledge(values: Dictionary) -> void:
	if not enabled or armed:return
	armed=true;write("first-world:ack-enqueued",values,true)
func begin_frame(values: Dictionary) -> void:
	sampling=enabled and armed and int(values.get("ticks_ms",0))>=next_sample and sequence<FRAME_LIMIT
	if sampling:
		next_sample=int(values.get("ticks_ms",0))+INTERVAL_MS;samples+=1;write("frame:begin",values)
func phase(stage: String,values: Dictionary) -> void:
	if sampling:write(stage,values)
func event(stage: String,values: Dictionary) -> void:
	write(stage,values,true)
func snapshot() -> Dictionary:
	return {"enabled":enabled,"armed":armed,"rows":sequence,"dropped":dropped,"samples":samples,"failure":failure,"maximum_rows":MAX_ROWS,"sample_interval_ms":INTERVAL_MS,"scope":"Opt-in CreationCheck only; durable sampled native frame stages after first world ACK, with reserved error/finish rows. Scalar observations, no payload capture or timing acceptance."}
