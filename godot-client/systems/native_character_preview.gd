extends Node
# One active owned byte reader/decoder and one latest pending selection.
# The file ticket comes from the authenticated protocol host, never a server path.
signal completed
const PreviewData=preload("res://systems/native_data/character_preview.gd")
const MAX_BYTES:=948*65535-16
class ReadJob extends RefCounted:
	var packet: Dictionary={}
	var scope: Array=[]
	var language:=0
	var value: Dictionary={}
	var error:=""
	var elapsed_ms:=0.0
	func run() -> void:
		var began:=Time.get_ticks_usec(); var file:=FileAccess.open(str(packet.path),FileAccess.READ)
		if file==null or file.get_length()!=int(packet.bytes): error="Character preview byte source is unavailable or changed."; return
		var bytes:=file.get_buffer(int(packet.bytes)); file.close()
		if bytes.size()!=int(packet.bytes) or preload("res://systems/native_data/prepared_cache.gd").digest(bytes)!=str(packet.sha256): error="Character preview bytes failed their integrity check."; return
		var parser:=preload("res://systems/native_data/gff_document.gd").new(); var document:=parser.parse(bytes,"BIC ")
		if not parser.failure.is_empty(): error="Character preview is not a valid native BIC record."; return
		value=PreviewData.project(document.root,language)
		if not value.has("error"): value.visualSource=preload("res://systems/native_data/bic_visual.gd").source(document)
		if not value.has("error"): value.skillSource=preload("res://systems/native_data/pregame_skills.gd").source(document)
		if not value.has("error"): value.spellSource=preload("res://systems/native_data/pregame_spells.gd").source(document,value.skillSource)
		if not value.has("error"): value.recordSource=preload("res://systems/native_data/pregame_record.gd").source(document,value.skillSource)
		if value.has("error"): error="Character preview contains an invalid native record field."; value={}
		elapsed_ms=(Time.get_ticks_usec()-began)/1000.0
var directory:=""
var language:=0
var wanted: Array=[]
var pending: Dictionary={}
var active: ReadJob
var task:=-1
var value: Dictionary={}
var error:=""
var closed:=false
var accepted: Array=[]
var stats:={"decoded":0,"stale":0,"failed":0,"last_ms":0.0}
func configure(path: String) -> void: directory=path.replace("\\","/").simplify_path().trim_suffix("/")
func observe(connection: int,key: Variant,packet: Variant,allowed: bool) -> void:
	if closed: return
	var size:=-1
	if packet is Dictionary:
		var count: Variant=packet.get("bytes")
		if (count is int or count is float) and is_finite(float(count)) and count>=56 and count<=MAX_BYTES and float(count)==floor(float(count)): size=int(count)
	var next: Array=[connection,key,str(packet.get("sha256","")),language,packet.get("path"),size] if allowed and packet is Dictionary and packet.get("format","")=="native-bic-file-v1" else []
	if next==wanted: return
	wanted=next; pending={}; value={}; accepted=[]; error=""
	if next.is_empty(): return
	var digest:=str(packet.get("sha256","")); var path:=str(packet.get("path","")).replace("\\","/").simplify_path()
	if directory.is_empty() or not directory.is_absolute_path() or digest.length()!=64 or digest!=digest.to_lower() or not digest.is_valid_hex_number(false) or path.get_base_dir().to_lower()!=directory.to_lower() or path.get_file()!=digest+".bic" or size<0:
		error="Character preview byte ticket is invalid."; stats.failed+=1; completed.emit(); return
	pending=packet.duplicate(); dispatch()
func dispatch() -> void:
	if closed or task>=0 or pending.is_empty(): return
	active=ReadJob.new(); active.packet=pending; active.scope=wanted.duplicate(); active.language=language; pending={}; task=WorkerThreadPool.add_task(active.run,false,"Native character record")
func _process(_delta: float) -> void:
	if closed or task<0 or not WorkerThreadPool.is_task_completed(task): return
	WorkerThreadPool.wait_for_task_completion(task); task=-1
	var done:=active; active=null
	if done.scope==wanted:
		value=done.value; accepted=done.scope; error=done.error; stats.last_ms=done.elapsed_ms
		if error.is_empty(): stats.decoded+=1
		else: stats.failed+=1
		completed.emit()
	else: stats.stale+=1
	dispatch()
func snapshot() -> Dictionary: return {"native_only":true,"closed":closed,"decoded":stats.decoded,"failed":stats.failed,"stale":stats.stale,"last_ms":stats.last_ms,"pending":not pending.is_empty(),"worker_running":task>=0,"ready":not value.is_empty(),"error":error,"derived_combat_ready":false}
func close() -> void:
	if closed: return
	closed=true; wanted=[]; pending={}; value={}; accepted=[]
	if task>=0: WorkerThreadPool.wait_for_task_completion(task)
	task=-1; active=null
func _exit_tree() -> void: close()
