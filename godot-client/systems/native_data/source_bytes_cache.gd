extends RefCounted
# Optional verified NWSync raw-byte tier. Entries use authoritative SHA1 content
# identities, never resrefs/paths; errors fall back to the canonical source.
static var publish_mutex:=Mutex.new()
var metadata_mutex:=Mutex.new()
var directory:=""
var maximum_disk_bytes:=2*1024*1024*1024
var maximum_entry_bytes:=64*1024*1024
var writes:=0
var bytes_since_prune:=0
var failure:=""
var save_timings: Dictionary={}
func take_save_timing() -> Dictionary:
	metadata_mutex.lock(); var id:=OS.get_thread_caller_id(); var value: Dictionary=save_timings.get(id,{}); save_timings.erase(id); metadata_mutex.unlock(); return value
func configure(path: String) -> bool:
	var resolved:=ProjectSettings.globalize_path(path).replace("\\","/").simplify_path().trim_suffix("/")
	var workspace:=ProjectSettings.globalize_path("res://").replace("\\","/").simplify_path().trim_suffix("/")
	if workspace.get_file()=="godot-client": workspace=workspace.get_base_dir()
	if not resolved.is_absolute_path() or resolved.to_lower()==workspace.to_lower() or resolved.to_lower().begins_with(workspace.to_lower()+"/"): return false
	if DirAccess.make_dir_recursive_absolute(resolved)!=OK: return false
	directory=resolved; return true
func filename(identity: String) -> String:
	return directory.path_join(identity+".raw") if not directory.is_empty() and identity.length()==40 and identity==identity.to_lower() and identity.is_valid_hex_number(false) else ""
func read(identity: String,size: int) -> Dictionary:
	var path:=filename(identity)
	if path.is_empty(): return {}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return {}
	var count:=file.get_length()
	if count>maximum_entry_bytes or size>=0 and count!=size: file.close(); return {}
	var bytes:=file.get_buffer(count); file.close()
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA1)
	if not bytes.is_empty(): hash.update(bytes)
	if hash.finish().hex_encode()!=identity: return {}
	return {"bytes":bytes}
func save(identity: String,bytes: PackedByteArray,cancel: Callable=Callable(),defer_prune: bool=false) -> bool:
	var began:=Time.get_ticks_usec(); var timing: Dictionary={}
	var accepted:=save_data(identity,bytes,timing,cancel,defer_prune)
	timing.total_us=Time.get_ticks_usec()-began
	metadata_mutex.lock()
	if save_timings.size()>=64 and not save_timings.has(OS.get_thread_caller_id()): save_timings.erase(save_timings.keys()[0])
	save_timings[OS.get_thread_caller_id()]=timing; metadata_mutex.unlock()
	return accepted
func save_data(identity: String,bytes: PackedByteArray,timing: Dictionary,cancel: Callable=Callable(),defer_prune: bool=false) -> bool:
	var path:=filename(identity)
	if path.is_empty() or bytes.size()>maximum_entry_bytes: return false
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA1)
	if not bytes.is_empty(): hash.update(bytes)
	if hash.finish().hex_encode()!=identity: return false
	if not read(identity,bytes.size()).is_empty(): return true
	var temporary:=path+"."+str(OS.get_process_id())+"-"+str(OS.get_thread_caller_id())+"-"+str(Time.get_ticks_usec())+".part"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return false
	file.store_buffer(bytes); var valid:=file.get_error()==OK; file.close()
	if not valid: DirAccess.remove_absolute(temporary); return false
	publish_mutex.lock()
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var accepted:=DirAccess.rename_absolute(temporary,path)==OK
	publish_mutex.unlock()
	if not accepted: DirAccess.remove_absolute(temporary); return false
	metadata_mutex.lock(); writes+=1; bytes_since_prune+=bytes.size()
	var trim:=writes==1 or bytes_since_prune>=64*1024*1024
	if trim: bytes_since_prune=0
	metadata_mutex.unlock()
	if trim:
		timing.maintenance_requested=true
		if not defer_prune:
			var began:=Time.get_ticks_usec(); prune(cancel); timing.prune_us=Time.get_ticks_usec()-began
	return true
func prune(cancel: Callable=Callable()) -> bool:
	# Only owned exact content filenames in the verified cache root are eligible.
	var folder:=DirAccess.open(directory)
	if folder==null: return true
	if cancel.is_valid() and cancel.call(): return false
	var files: Array=[]; var total:=0
	for name in folder.get_files():
		if cancel.is_valid() and cancel.call(): return false
		if folder.is_link(name) or name.length()!=44 or not name.ends_with(".raw"): continue
		var identity:=name.trim_suffix(".raw"); var path:=filename(identity)
		if path.is_empty() or path.get_base_dir()!=directory: continue
		var file:=FileAccess.open(path,FileAccess.READ)
		if file==null: continue
		var count:=file.get_length(); file.close(); total+=count
		files.append({"path":path,"bytes":count,"modified":FileAccess.get_modified_time(path)})
	files.sort_custom(func(a,b):return a.modified<b.modified or a.modified==b.modified and a.path<b.path)
	for entry in files:
		if cancel.is_valid() and cancel.call(): return false
		if total<=maximum_disk_bytes: break
		if entry.path.get_base_dir()==directory and not folder.is_link(str(entry.path).get_file()) and DirAccess.remove_absolute(entry.path)==OK: total-=int(entry.bytes)
	return true
