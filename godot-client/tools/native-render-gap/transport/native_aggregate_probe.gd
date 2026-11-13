extends RefCounted
# PRIVATE, source-only proposal. No project registers or instantiates this file.
# Exact creation FILETIME below is supplied by an independently verified watcher;
# OS.get_process_id() is the actual process read. Cold acceptance joins both.
var enabled:=false
var active:=false
var connection:=-1
var generation:=-1
var window:=""
var expected_creation_filetime:=""
var dropped:=0
var starts:=PackedInt64Array([0,0,0])
var counts:=PackedInt64Array([0,0,0])
var sums:=PackedInt64Array([0,0,0])
var maxima:=PackedInt64Array([0,0,0])
const MAXIMUM:=100000
const PHASES:=["native_commit","native_snapshot","native_protocol_encode"]

func begin_window(proof: Dictionary) -> bool:
	if not enabled:return false
	if not window.is_empty() or int(proof.get("pid",-1))!=OS.get_process_id():return false
	if not proof.get("createdFileTimeUtcExact") is String:return false
	var creation: String=proof.createdFileTimeUtcExact
	if creation.length()<16 or creation.length()>20 or not creation.is_valid_int() or creation.begins_with("-") or creation.begins_with("+"):return false
	if int(proof.get("connection",-1))<0 or int(proof.get("generation",-1))<0:return false
	var token:=str(proof.get("window",""))
	if token.is_empty() or token.length()>80:return false
	connection=int(proof.connection);generation=int(proof.generation);window=token;expected_creation_filetime=creation;active=true;return true

func begin(phase: int,current_connection: int,current_generation: int) -> int:
	if not enabled or not active or current_connection!=connection or current_generation!=generation:return 0
	if phase<0 or phase>=3:return 0
	if starts[phase]!=0 or counts[phase]>=MAXIMUM:dropped+=1;return 0
	var tick:=Time.get_ticks_usec()
	starts[phase]=tick
	return tick

func finish(phase: int,token: int) -> void:
	if token==0:return
	if not active or phase<0 or phase>=3:return
	if starts[phase]!=token:dropped+=1;return
	starts[phase]=0
	var elapsed:=Time.get_ticks_usec()-token
	if elapsed<0 or sums[phase]>9223372036854775807-elapsed:dropped+=1;active=false;return
	counts[phase]+=1;sums[phase]+=elapsed;maxima[phase]=maxi(maxima[phase],elapsed)

func finish_window(token: String) -> Dictionary:
	if not enabled or not active or token!=window:return {}
	for began in starts:
		if began!=0:dropped+=1
	active=false
	var rows: Array=[]
	for i in range(3):rows.append({"name":PHASES[i],"count":counts[i],"sum_usec":sums[i],"maximum_usec":maxima[i]})
	return {"enabled":true,"process_id":OS.get_process_id(),"expected_created_filetime_exact":expected_creation_filetime,"identity_source":"Independent watcher required; supplied FILETIME is not a local Win32 read","connection":connection,"generation":generation,"window":window,"dropped":dropped,"phases":rows,"per_object_timing":false,"object_payloads_retained":false,"clock_domain":"native monotonic only"}
