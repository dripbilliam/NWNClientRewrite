extends Node
signal completed
const Policy=preload("res://systems/native_data/local_character_metadata.gd")
const MAX_BYTES:=948*65535-16
class Batch extends RefCounted:
	var scope:=""
	var inputs: Array=[]
	var roots: Array=[]
	var values: Dictionary={}
	var errors: Dictionary={}
	var decoded:=0
	var elapsed_ms:=0.0
	var mutex:=Mutex.new()
	var cancelled:=false
	func stop() -> void: mutex.lock(); cancelled=true; mutex.unlock()
	func stopped() -> bool: mutex.lock(); var result:=cancelled; mutex.unlock(); return result
	func run() -> void:
		var began:=Time.get_ticks_usec(); read_rows(); elapsed_ms=(Time.get_ticks_usec()-began)/1000.0
	func read_rows() -> void:
		for item in inputs:
			if stopped(): return
			var packet: Dictionary=item.get("nativeFile",{}); var path:=str(packet.get("path","")).replace("\\","/").simplify_path(); var digest:=str(packet.get("sha256","")); var size: Variant=packet.get("bytes")
			if packet.get("format")!="native-local-bic-v1" or not path.is_absolute_path() or not roots.has(path.get_base_dir().to_lower()) or path.get_extension().to_lower()!="bic" or digest.length()!=64 or digest!=digest.to_lower() or not digest.is_valid_hex_number(false) or not (size is int or size is float) or not is_finite(float(size)) or float(size)!=floor(float(size)) or size<56 or size>MAX_BYTES:
				errors[item.key]="Local character byte ticket is invalid."; continue
			var file:=FileAccess.open(path,FileAccess.READ)
			if file==null or file.get_length()!=int(size): errors[item.key]="Local character file is unavailable or changed."; continue
			var bytes:=file.get_buffer(int(size)); file.close()
			if bytes.size()!=int(size) or preload("res://systems/native_data/prepared_cache.gd").digest(bytes)!=digest: errors[item.key]="Local character integrity check failed."; continue
			var parser=preload("res://systems/native_data/gff_document.gd").new(); var document: Dictionary=parser.parse(bytes,"BIC ")
			if not parser.failure.is_empty(): errors[item.key]="Local character is not a valid BIC record."; continue
			values[item.key]=Policy.project(document); decoded+=1
var roots: Array=[]
var wanted:=""
var accepted:=""
var pending: Array=[]
var values: Dictionary={}
var errors: Dictionary={}
var active: Batch
var task:=-1
var closed:=false
var batches:=0
var decoded:=0
var failed:=0
var last_ms:=0.0
var stale:=0
func configure(directories: Array) -> void:
	roots=[]
	for path in directories:
		var root:=str(path).replace("\\","/").simplify_path().trim_suffix("/")
		if root.is_absolute_path() and not roots.has(root.to_lower()): roots.append(root.to_lower())
func observe(connection: int,choices: Array) -> void:
	if closed: return
	var inputs: Array=choices.filter(func(row):return row.get("source")!="server" and row.get("nativeFile") is Dictionary)
	var scope:=JSON.stringify([connection,roots,inputs])
	if wanted==scope: return
	wanted=scope; pending=inputs.duplicate(true); accepted=""; values={}; errors={}
	if active!=null: active.stop()
	if pending.is_empty(): accepted=wanted
	dispatch()
func dispatch() -> void:
	if closed or task>=0 or pending.is_empty(): return
	active=Batch.new(); active.scope=wanted; active.inputs=pending; active.roots=roots.duplicate(); pending=[]
	task=WorkerThreadPool.add_task(active.run,false,"Native local character catalog")
func _process(_delta: float) -> void:
	if closed or task<0 or not WorkerThreadPool.is_task_completed(task): return
	WorkerThreadPool.wait_for_task_completion(task); task=-1; var done:=active; active=null
	if done.scope==wanted:
		values=done.values; errors=done.errors; accepted=wanted; batches+=1; decoded+=done.decoded; failed+=done.errors.size(); last_ms=done.elapsed_ms; completed.emit()
	else: stale+=1
	dispatch()
func ready() -> bool: return accepted==wanted
func snapshot() -> Dictionary: return {"native_only":true,"ready":ready(),"batches":batches,"decoded":decoded,"stale":stale,"failed":failed,"last_ms":last_ms,"worker_running":task>=0,"closed":closed}
func close() -> void:
	if closed: return
	closed=true; pending=[]
	if active!=null: active.stop()
	if task>=0: WorkerThreadPool.wait_for_task_completion(task)
	task=-1; active=null; values={}; errors={}
func _exit_tree() -> void: close()
