extends RefCounted
# Godot owner for the normal-launch runtime diagnostic journal. Gameplay never
# consumes these records, but saving/exporting them must retain every event.
signal changed(journal: RefCounted)

var session: String=""
var context: Callable
var records: Array[Dictionary]=[]
var pending: Array[Dictionary]=[]
var storage_error: String=""
var location: String="Memory · persistence not attached"
var sink_path: String=""
var writing:=false
var error_records: Dictionary={}

func _init(session_id: String="",context_provider: Callable=Callable())->void:
	session=session_id if not session_id.is_empty() else _session_id()
	context=context_provider

static func _session_id()->String:
	var bytes:=Crypto.new().generate_random_bytes(16)
	if bytes.size()!=16:return "run-"+str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec())
	bytes[6]=(int(bytes[6]) & 0x0f) | 0x40
	bytes[8]=(int(bytes[8]) & 0x3f) | 0x80
	var hex:=bytes.hex_encode()
	return hex.substr(0,8)+"-"+hex.substr(8,4)+"-"+hex.substr(12,4)+"-"+hex.substr(16,4)+"-"+hex.substr(20,12)

static func _timestamp()->String:
	var now:=Time.get_unix_time_from_system()
	var whole:=floori(now)
	return Time.get_datetime_string_from_unix_time(whole)+".%03dZ" % int(floor((now-float(whole))*1000.0))

static func _safe(value: Variant)->Variant:return _safe_inner(value,0,[])

static func _safe_inner(value: Variant,depth: int,seen: Array)->Variant:
	if depth>64:return "[circular]"
	if value is PackedByteArray:return {"binaryBytes":value.size()}
	if value is PackedInt32Array or value is PackedFloat32Array:return {"binaryBytes":value.size()*4}
	if value is PackedInt64Array or value is PackedFloat64Array:return {"binaryBytes":value.size()*8}
	if value is PackedVector2Array:return {"binaryBytes":value.size()*8}
	if value is PackedVector3Array:return {"binaryBytes":value.size()*12}
	if value is PackedColorArray:return {"binaryBytes":value.size()*16}
	if value is PackedStringArray:return Array(value)
	if value is Vector2:return [value.x,value.y]
	if value is Vector3:return [value.x,value.y,value.z]
	if value is Vector4:return [value.x,value.y,value.z,value.w]
	if value is Color:return [value.r,value.g,value.b,value.a]
	if value is int and (value>9007199254740991 or value< -9007199254740991):return str(value)
	if value is Dictionary:
		for prior in seen:
			if is_same(prior,value):return "[circular]"
		seen.append(value)
		var result: Dictionary={}
		for key in value:result[str(key)]=_safe_inner(value[key],depth+1,seen)
		return result
	if value is Array:
		for prior in seen:
			if is_same(prior,value):return "[circular]"
		seen.append(value)
		var result: Array=[]
		for item in value:result.append(_safe_inner(item,depth+1,seen))
		return result
	if value is Object:return str(value)
	return value

func subscribe(listener: Callable)->Callable:
	if listener.is_valid() and not changed.is_connected(listener):changed.connect(listener)
	if listener.is_valid():listener.call(self)
	return func()->void:
		if listener.is_valid() and changed.is_connected(listener):changed.disconnect(listener)

func publish()->void:changed.emit(self)

func record(code: String,message: String,detail: Dictionary={},severity: String="warning")->Dictionary:
	var supplied: Variant=context.call() if context.is_valid() else {}
	var merged: Dictionary=supplied if supplied is Dictionary else {}
	merged.merge(detail,true)
	var row: Dictionary={"version":1,"session":session,"sequence":records.size()+1,"timestamp":_timestamp(),"code":code,"severity":severity,"message":message,"context":_safe(merged)}
	row=_safe(row)
	records.append(row);pending.append(row);publish()
	if not sink_path.is_empty() and storage_error.is_empty() and not writing:call_deferred("flush",false)
	return row

func error(value: Variant,code: String="runtime.failure",detail: Dictionary={})->Dictionary:
	var message:=str(value)
	var source: Dictionary=value if value is Dictionary else {}
	if source.has("diagnosticCode"):code=str(source.diagnosticCode)
	var merged: Dictionary=source.get("diagnosticContext",{}).duplicate(true) if source.get("diagnosticContext",{}) is Dictionary else {}
	merged.merge(detail,true)
	if source.has("message"):message=str(source.message)
	if source.has("stack"):merged.stack=str(source.stack)
	if value is Dictionary:return record(code,message,merged,"info" if code=="resource.lookup-failed" else "error")
	if value is Object:
		var identity:=str(value.get_instance_id())+":"+code
		if error_records.has(identity):return error_records[identity]
		var captured:=record(code,message,merged,"info" if code=="resource.lookup-failed" else "error")
		error_records[identity]=captured
		return captured
	return record(code,message,merged)

func attach(path: String)->bool:
	sink_path=path;location=path;storage_error="";publish()
	return flush(false)

func flush(_repeated: bool=true)->bool:
	if writing or sink_path.is_empty():return sink_path.is_empty() or storage_error.is_empty()
	writing=true
	var directory:=sink_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		_save_failed("Diagnostic directory could not be created")
		writing=false
		return false
	while not pending.is_empty():
		var batch:=pending.slice(0,mini(200,pending.size()))
		var file: FileAccess
		if FileAccess.file_exists(sink_path):
			file=FileAccess.open(sink_path,FileAccess.READ_WRITE)
			if file!=null:file.seek_end()
		else:file=FileAccess.open(sink_path,FileAccess.WRITE)
		if file==null:
			_save_failed("Diagnostic journal could not be opened")
			writing=false
			return false
		for row in batch:file.store_string(JSON.stringify(row)+"\n")
		file.flush()
		var status:=file.get_error()
		file.close()
		if status!=OK:
			_save_failed("Diagnostic journal could not be written")
			writing=false
			return false
		pending= pending.slice(batch.size())
		storage_error="";publish()
	writing=false
	return true

func _save_failed(reason: String)->void:
	var first:=storage_error!=reason
	storage_error=reason
	if first:record("diagnostic.save-failed",reason,{"location":location},"error")
	publish()

func retry()->bool:
	storage_error=""
	return flush(false)

func jsonl()->String:
	var lines: PackedStringArray=[]
	for row in records:lines.append(JSON.stringify(row))
	return "\n".join(lines)+( "\n" if not lines.is_empty() else "")

func export(path: String)->bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:return false
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_string(jsonl());file.flush()
	var ok:=file.get_error()==OK
	file.close()
	return ok
