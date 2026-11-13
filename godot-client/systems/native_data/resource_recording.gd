extends RefCounted
# Diagnostic capture of original bytes, never prepared meshes/textures. One
# writer owns disk I/O and hashing; catalog readers enqueue immutable COW bytes.
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var directory:=""
var thread:=Thread.new()
var mutex:=Mutex.new()
var wake:=Semaphore.new()
var queue: Array=[]
var seen: Dictionary={}
var stopping:=false
var queued_bytes:=0
var maximum_queued_bytes:=256*1024*1024
var maximum_bytes:=4*1024*1024*1024
var failure:=""
var complete:=false
var resources:=0
func start(path: String,layers: Array,talk_files: Dictionary={}) -> bool:
	if not path.is_absolute_path() or thread.is_started(): return false
	directory=path; queue.append({"layers":layers.duplicate(),"talk_files":talk_files.duplicate()})
	var error:=thread.start(write_loop)
	if error!=OK: failure="Resource recording writer could not start"; return false
	wake.post(); return true
func record(name: String,type: int,bytes: PackedByteArray,error: String) -> void:
	var key:=name.to_lower()+":"+str(type)
	mutex.lock()
	if stopping or not failure.is_empty() or seen.has(key): mutex.unlock(); return
	if queued_bytes+bytes.size()>maximum_queued_bytes:
		failure="Resource recording queue exceeded bound"; mutex.unlock(); return
	seen[key]=true; queued_bytes+=bytes.size(); queue.append({"key":key,"bytes":bytes,"error":error})
	mutex.unlock(); wake.post()
func write_loop() -> void:
	var manifest:={"version":2,"complete":false,"availability":{},"resources":{},"talk":{},"bytes":0,"policy":"First native read per resource; exact original bytes, complete winning resource availability/classes, no installed/network fallback for payloads"}
	var error:=""
	if DirAccess.make_dir_recursive_absolute(directory.path_join("objects"))!=OK: error="Resource recording directory could not be created"
	while true:
		wake.wait(); mutex.lock(); var jobs:=queue; queue=[]; var ending:=stopping; mutex.unlock()
		for job in jobs:
			if job.has("layers"):
				manifest.portraitFiles=preload("res://systems/native_data/portrait_resources.gd").files(job.layers)
				for layer in job.layers:
					for key in layer.entries:
						if not manifest.availability.has(key): manifest.availability[key]=int(layer.get("storage_class",1 if layer.kind=="key" else 3))
				for key in job.talk_files:
					var file:=FileAccess.open(str(job.talk_files[key]),FileAccess.READ)
					if file==null: continue
					if file.get_length()>256*1024*1024: error="Recorded talk file exceeds bound"; file.close(); continue
					var raw:=file.get_buffer(file.get_length()); file.close(); var digest:=Cache.digest(raw)
					var output:=FileAccess.open(directory.path_join("objects").path_join(digest),FileAccess.WRITE)
					if output==null: error="Recorded talk file write failed"
					else: output.store_buffer(raw); output.close(); manifest.talk[key]={"sha256":digest,"bytes":raw.size()}; manifest.bytes+=raw.size()
				continue
			var raw: PackedByteArray=job.bytes
			if error.is_empty():
				if not str(job.error).is_empty(): manifest.resources[job.key]={"error":str(job.error)}
				elif int(manifest.bytes)+raw.size()>maximum_bytes: error="Resource recording disk bound exceeded"
				else:
					var digest:=Cache.digest(raw); var target:=directory.path_join("objects").path_join(digest)
					if not FileAccess.file_exists(target):
						var file:=FileAccess.open(target,FileAccess.WRITE)
						if file==null: error="Resource recording payload write failed"
						else: file.store_buffer(raw); file.close(); manifest.bytes+=raw.size()
					manifest.resources[job.key]={"sha256":digest,"bytes":raw.size()}
			mutex.lock(); queued_bytes-=raw.size(); resources=manifest.resources.size(); mutex.unlock()
		if ending: break
	mutex.lock()
	if error.is_empty(): error=failure
	mutex.unlock()
	manifest.complete=error.is_empty(); manifest.failure=error
	var file:=FileAccess.open(directory.path_join("manifest.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(manifest)); file.close()
	else: error="Resource recording manifest write failed"
	mutex.lock(); complete=error.is_empty(); failure=error; mutex.unlock()
func close() -> Dictionary:
	if thread.is_started():
		mutex.lock(); stopping=true; mutex.unlock(); wake.post(); thread.wait_to_finish()
	return {"directory":directory,"complete":complete,"failure":failure,"resources":resources}
