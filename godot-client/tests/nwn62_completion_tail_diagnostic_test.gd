extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
class Reader extends RefCounted:
	var failure:=""
	func fork() -> RefCounted:return Reader.new()
	func get_resource(name: String,_type: int) -> PackedByteArray:return ("original:"+name).to_utf8_buffer()
var checks:=0
var failures: Array=[]
var received: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:failures.append(label)
func await_id(id: int) -> void:
	var deadline:=Time.get_ticks_msec()+5000
	while not received.has(id) and Time.get_ticks_msec()<deadline:await process_frame
func run() -> void:
	var service:=Assets.new();root.add_child(service)
	service.configure(Reader.new())
	service.completed.connect(func(id,result):
		if result.resource_name=="slow_a" or result.resource_name=="slow_b":OS.delay_msec(6)
		received[id]={"resource":result.resource_name,"bytes":result.bytes.duplicate(),"error":result.error})
	var normal:=service.request("slow_a",7)
	await await_id(normal)
	check(received.has(normal) and received[normal].bytes=="original:slow_a".to_utf8_buffer(),"Normal completion reaches original consumer")
	check(service.completion_diagnostic_requests.is_empty() and service.completion_diagnostic_peaks.is_empty(),"Default-off path retains no diagnostic request or receipt")
	service.completion_diagnose=true
	var diagnostic:=service.request("slow_b",7)
	await await_id(diagnostic)
	check(received.has(diagnostic) and received[diagnostic].bytes=="original:slow_b".to_utf8_buffer(),"Diagnostic completion reaches same consumer unchanged")
	check(service.completion_diagnostic_requests.is_empty(),"Completed request metadata is released")
	check(service.completion_diagnostic_peaks.size()==1,"One slow completion creates one bounded receipt")
	if service.completion_diagnostic_peaks.size()==1:
		var row: Dictionary=service.completion_diagnostic_peaks[0]
		check(str(row.resource)=="slow_b" and int(row.type)==7 and str(row.decoder)=="bytes" and int(row.request_id)==diagnostic,"Receipt identifies exact request and decoder")
		check(int(row.callback_us)>=5000 and int(row.phases_us.consumer_us)>=5000,"Receipt isolates the slow consumer phase")
		var total:=0
		for value in row.phases_us.values():total+=int(value)
		check(total<=int(row.callback_us)+500,"Phase durations stay within the encompassing callback")
	var receipt: Dictionary=service.completion_diagnostic_peaks[0].duplicate(true) if service.completion_diagnostic_peaks.size()==1 else {}
	service.completion_diagnostic_logged=15
	service._record_completion_diagnostic(100,{"name":"cap_a","type":7,"decoder":"bytes","epoch":service.epoch},"",10000,{"consumer_us":10000})
	service._record_completion_diagnostic(101,{"name":"cap_b","type":7,"decoder":"bytes","epoch":service.epoch},"",20000,{"consumer_us":20000})
	check(service.completion_diagnostic_logged==16 and service.completion_diagnostic_peaks.size()==3 and int(service.completion_diagnostic_peaks[0].callback_us)==20000,"Immediate output is capped while later larger tail remains in final top eight")
	service.retire_scope()
	check(service.completion_diagnostic_requests.is_empty(),"Retirement clears diagnostic request identities")
	check(service.completion_diagnostic_peaks.is_empty() and service.completion_diagnostic_logged==0,"Retirement emits and clears bounded top eight")
	service.close();service.queue_free()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"receipt":receipt,"scope":"Headless actual worker completion and signal parity, default-off retention, opt-in bounded phase attribution; no FPS claim."}
	var args:=OS.get_cmdline_user_args()
	var path: String=args[args.size()-1].trim_prefix("--report=")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:push_error("Cannot write report: "+path);quit(2);return
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("NWN62_COMPLETION_DIAGNOSTIC ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
