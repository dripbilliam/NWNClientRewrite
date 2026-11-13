extends RefCounted
# Optional derived-resource cache. The codec owns script-free .res validation;
# this store owns paths, tickets, read leases, publication and disk accounting.
# Publication/configuration are worker work. Contention returns busy, never waits.
const FORMAT:=1
const NAMESPACE:="godot-prepared-resources-v1"
const DEFAULT_BUDGET: int=25*1024*1024*1024
const MAX_ARTIFACT_BYTES: int=256*1024*1024
const MAX_SHARD_ENTRIES:=512
const MAX_SHARD_BYTES:=512*1024
const MAX_EVICTIONS:=64
const MAX_WRITES:=16
const MAX_READS:=256
var directory:=""
var budget_bytes: int=DEFAULT_BUDGET
var failure:=""
var _root_id:=""
var _mutex:=Mutex.new()
var _lock_nonce:=""
var _shards: Dictionary={}
var _tickets: Dictionary={}
var _reads: Dictionary={}
var _touches: Dictionary={}
var _state: Dictionary={}
var _closed:=false
var _folders: Dictionary={}
var _stats:={"hits":0,"misses":0,"writes":0,"deduplicated":0,"evictions":0,"busy":0,"rejected":0,"recovered":0,"index_reads":0,"index_writes":0,"read_acquires":0,"read_releases":0,"directory_opens":0,"leaf_link_checks":0,"ancestor_checks":0,"file_opens":0,"metadata_bytes_read":0,"lookup_calls":0,"lookup_us":0,"lookup_max_us":0,"read_acquire_us":0,"read_acquire_max_us":0,"reader_leaf_mkdir_attempts":0,"reader_leaf_mkdir_created":0,"reader_leaf_mkdir_existing":0,"reader_leaf_mkdir_failed":0,"read_attempts":0,"read_hint_checks":0,"read_hint_misses":0,"read_hint_us":0,"read_strong_attempts":0}

func _nonce() -> String:return Crypto.new().generate_random_bytes(16).hex_encode()
func _key(value: String) -> bool:return value.length()==64 and value==value.to_lower() and value.is_valid_hex_number(false)
func _hex(value: String,length: int) -> bool:return value.length()==length and value==value.to_lower() and value.is_valid_hex_number(false)
func _clock() -> int:return int(Time.get_unix_time_from_system()*1000.0)
func _uint(value: Variant,maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and float(value)==floor(float(value))
func _enter() -> bool:
	if not _mutex.try_lock():failure="busy";return false
	if _closed or directory.is_empty():failure="unconfigured";_mutex.unlock();return false
	failure="";return true
func _safe_file(path: String,parent: String) -> bool:
	if path.simplify_path()!=path or path.get_base_dir()!=parent:return false
	var folder=_folders.get(parent)
	if folder==null:
		folder=DirAccess.open(parent);_stats.directory_opens+=1
		if folder!=null and _folders.size()<128:_folders[parent]=folder
	_stats.leaf_link_checks+=1
	return folder!=null and not folder.is_link(path.get_file())
func _safe_tree(path: String) -> bool:
	var current:=path
	while current.length()>3:
		_stats.ancestor_checks+=1
		var parent:=DirAccess.open(current.get_base_dir())
		_stats.directory_opens+=1
		if parent!=null and parent.is_link(current.get_file()):return false
		var next:=current.get_base_dir()
		if next==current:break
		current=next
	return true
func _path(category: String,name: String) -> String:return directory.path_join(category).path_join(name)
func _mutation_root_current() -> bool:
	# Configuration seals the canonical root ancestry. Mutation boundaries
	# recheck its owned namespace/category links; hot read helpers do not walk it.
	if not _safe_file(directory.path_join("owner.json"),directory):return false
	var parent:=DirAccess.open(directory.get_base_dir());_stats.directory_opens+=1
	if parent==null or parent.is_link(directory.get_file()):return false
	var folder=_folders.get(directory)
	if folder==null:return false
	for child in ["artifacts","staging","index","readers","publish.lock"]:
		_stats.leaf_link_checks+=1
		if folder.is_link(child):return false
	return true
func _doc(path: String,limit: int=MAX_SHARD_BYTES) -> Dictionary:
	if not _safe_file(path,path.get_base_dir()) or not FileAccess.file_exists(path):return {}
	var file:=FileAccess.open(path,FileAccess.READ)
	_stats.file_opens+=1
	if file==null or file.get_length()<2 or file.get_length()>limit:return {}
	_stats.metadata_bytes_read+=file.get_length()
	var value: Variant=JSON.parse_string(file.get_as_text());file.close()
	return value if value is Dictionary and value.get("format")==FORMAT and value.get("root_id")==_root_id else {}
func _write_doc(path: String,data: Dictionary) -> bool:
	if not _safe_file(path,path.get_base_dir()):failure="linked-metadata";return false
	var temporary:=path+"."+_nonce()+".tmp";var backup:=path+".bak"
	if not _safe_file(backup,path.get_base_dir()):failure="linked-backup";return false
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:failure="metadata-write";return false
	var packet:=data.duplicate();packet.format=FORMAT;packet.root_id=_root_id
	file.store_string(JSON.stringify(packet));file.flush();var error:=file.get_error();file.close()
	if error!=OK:DirAccess.remove_absolute(temporary);failure="metadata-flush";return false
	if FileAccess.file_exists(backup):
		if _doc(path).is_empty():
			if _doc(backup).is_empty():DirAccess.remove_absolute(temporary);failure="metadata-recovery-required";return false
			if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
			if DirAccess.rename_absolute(backup,path)!=OK:DirAccess.remove_absolute(temporary);failure="metadata-backup-recovery";return false
		else:DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(path) and DirAccess.rename_absolute(path,backup)!=OK:DirAccess.remove_absolute(temporary);failure="metadata-backup";return false
	if DirAccess.rename_absolute(temporary,path)!=OK:failure="metadata-publication";return false
	if FileAccess.file_exists(backup):DirAccess.remove_absolute(backup)
	return true
func _try_publish_lock() -> bool:
	var lock_path:=directory.path_join("publish.lock")
	if not _mutation_root_current():failure="linked-lock-or-root";return false
	if DirAccess.make_dir_absolute(lock_path)!=OK:
		# OS process probes can report false for another live restricted process.
		# Never turn that ambiguous result into permission to steal its lock.
		failure="busy";_stats.busy+=1;return false
	_lock_nonce=_nonce()
	if not _write_doc(lock_path.path_join("owner.json"),{"pid":OS.get_process_id(),"nonce":_lock_nonce}):
		DirAccess.remove_absolute(lock_path);_lock_nonce="";return false
	return true
func _unlock_publish() -> void:
	if _lock_nonce.is_empty():return
	var path:=directory.path_join("publish.lock");var owner:=_doc(path.path_join("owner.json"),2048)
	if owner.get("pid")==OS.get_process_id() and owner.get("nonce")==_lock_nonce:
		DirAccess.remove_absolute(path.path_join("owner.json"));DirAccess.remove_absolute(path)
	_lock_nonce=""
func _empty_state() -> Dictionary:return {"format":FORMAT,"root_id":_root_id,"bytes":0,"entries":0,"revision":_nonce(),"shards":{}}
func _state_valid(value: Dictionary) -> bool:
	if value.is_empty() or not value.get("shards") is Dictionary or value.shards.size()>256 or not _uint(value.get("bytes"),9007199254740991) or not _uint(value.get("entries"),256*MAX_SHARD_ENTRIES) or not _hex(str(value.get("revision","")),32):return false
	var bytes: int=0;var count: int=0
	for prefix in value.shards:
		var row: Variant=value.shards[prefix]
		if not prefix is String or not _hex(prefix,2) or not row is Dictionary or not _uint(row.get("bytes"),9007199254740991) or not _uint(row.get("entries"),MAX_SHARD_ENTRIES) or not _uint(row.get("oldest"),9007199254740991):return false
		bytes+=int(row.bytes);count+=int(row.entries)
	return bytes==int(value.bytes) and count==int(value.entries)
func _artifact(row: Dictionary) -> String:return _path("artifacts",str(row.get("file","")))
func _row_valid(key: String,row: Dictionary) -> bool:
	if not _key(key) or not _hex(str(row.get("nonce","")),32) or row.get("file")!=key+"."+str(row.nonce)+".res":return false
	return _uint(row.get("bytes"),MAX_ARTIFACT_BYTES) and row.bytes>=4 and _uint(row.get("used"),9007199254740991)
func _load_shard(prefix: String,force: bool=false) -> Dictionary:
	if not _hex(prefix,2):return {}
	if not force and _shards.has(prefix):return _shards[prefix]
	var path:=_path("index",prefix+".json");var value:=_doc(path)
	if value.is_empty() and FileAccess.file_exists(path+".bak"):value=_doc(path+".bak")
	if value.is_empty():
		if FileAccess.file_exists(path):failure="invalid-shard";return {}
		value={"format":FORMAT,"root_id":_root_id,"prefix":prefix,"entries":{}}
	if value.get("prefix")!=prefix or not value.get("entries") is Dictionary or value.entries.size()>MAX_SHARD_ENTRIES:failure="invalid-shard";return {}
	for key in value.entries:
		if not key is String or not key.begins_with(prefix) or not value.entries[key] is Dictionary or not _row_valid(key,value.entries[key]):failure="invalid-shard-entry";return {}
	_shards[prefix]=value.entries;_stats.index_reads+=1
	return value.entries
func _save_shard(prefix: String,rows: Dictionary) -> bool:
	if rows.size()>MAX_SHARD_ENTRIES:failure="shard-full";return false
	if not _write_doc(_path("index",prefix+".json"),{"prefix":prefix,"entries":rows}):return false
	var bytes: int=0;var oldest: int=9223372036854775807
	for row in rows.values():bytes+=int(row.bytes);oldest=mini(oldest,int(row.used))
	_state.shards[prefix]={"bytes":bytes,"entries":rows.size(),"oldest":0 if rows.is_empty() else oldest}
	_shards[prefix]=rows;_stats.index_writes+=1;return true
func _valid_artifact(row: Dictionary) -> bool:
	var path:=_artifact(row)
	if not _safe_file(path,_path("artifacts","" ).trim_suffix("/")) or not FileAccess.file_exists(path):return false
	var file:=FileAccess.open(path,FileAccess.READ)
	_stats.file_opens+=1
	if file==null or file.get_length()!=int(row.bytes):return false
	var magic:=file.get_buffer(4).get_string_from_ascii();file.close()
	return magic in ["RSRC","RSCC"]
func _refresh_state() -> bool:
	var value:=_doc(directory.path_join("state.json"),131072)
	if value.is_empty():value=_doc(directory.path_join("state.json.bak"),131072)
	if not _state_valid(value):failure="invalid-state";return false
	_state=value;return true
func _recover() -> bool:
	var transaction_path:=directory.path_join("transaction.json")
	if not FileAccess.file_exists(transaction_path) and not FileAccess.file_exists(directory.path_join("state.json.bak")):return true
	var transaction:=_doc(transaction_path,16384)
	if FileAccess.file_exists(transaction_path) and transaction.is_empty():failure="invalid-transaction";return false
	_state=_empty_state();_shards.clear()
	for index in 256:
		var prefix:="%02x"%index;var rows:=_load_shard(prefix,true)
		if not failure.is_empty():return false
		for key in rows.keys():
			if not _valid_artifact(rows[key]):rows.erase(key)
		if not rows.is_empty() or FileAccess.file_exists(_path("index",prefix+".json")):
			if not _save_shard(prefix,rows):return false
		for row in rows.values():_state.bytes+=int(row.bytes);_state.entries+=1
	var name:=str(transaction.get("new_file",""));var key:=str(transaction.get("key",""));var nonce:=str(transaction.get("nonce",""))
	if _key(key) and _hex(nonce,32) and name==key+"."+nonce+".res":
		var rows:=_load_shard(key.left(2))
		if not rows.has(key) or rows[key].get("file")!=name:
			var artifact:=_path("artifacts",name)
			if _safe_file(artifact,artifact.get_base_dir()) and FileAccess.file_exists(artifact):DirAccess.remove_absolute(artifact)
	if not _write_doc(directory.path_join("state.json"),_state):return false
	if FileAccess.file_exists(transaction_path):DirAccess.remove_absolute(transaction_path)
	_stats.recovered+=1;return true
func configure(root: String,limit: int=DEFAULT_BUDGET) -> bool:
	if not _mutex.try_lock():failure="busy";return false
	failure=""
	if not _tickets.is_empty() or not _reads.is_empty():failure="active-leases";_mutex.unlock();return false
	var base:=ProjectSettings.globalize_path(root).replace("\\","/").simplify_path().trim_suffix("/")
	if not base.is_absolute_path() or base.length()<=3 or base.begins_with("//") or not _safe_tree(base) or limit<4 or limit>9007199254740991:failure="invalid-root-or-budget";_mutex.unlock();return false
	var target:=base.path_join(NAMESPACE);var fresh:=not DirAccess.dir_exists_absolute(target)
	if DirAccess.make_dir_recursive_absolute(base)!=OK or not _safe_tree(target) or fresh and DirAccess.make_dir_absolute(target)!=OK:failure="root-unavailable";_mutex.unlock();return false
	directory=target;_root_id=target.sha256_text();budget_bytes=limit;_closed=false;_shards.clear();_touches.clear();_folders.clear()
	if fresh:
		if not _write_doc(target.path_join("owner.json"),{"namespace":NAMESPACE}):directory="";_mutex.unlock();return false
	var marker:=_doc(target.path_join("owner.json"),2048)
	if marker.get("namespace")!=NAMESPACE:failure="unowned-namespace";directory="";_mutex.unlock();return false
	for child in ["artifacts","staging","index","readers"]:
		if not _safe_tree(target.path_join(child)) or DirAccess.make_dir_recursive_absolute(target.path_join(child))!=OK:failure="owned-directory-unavailable";directory="";_mutex.unlock();return false
	if not _try_publish_lock():_mutex.unlock();return false
	if fresh:
		_state=_empty_state()
		if not _write_doc(target.path_join("state.json"),_state):_unlock_publish();_mutex.unlock();return false
	var success:=_recover() and _refresh_state()
	_unlock_publish();_mutex.unlock();return success
func lookup(key: String) -> String:
	if not _enter():return ""
	var began:=Time.get_ticks_usec();_stats.lookup_calls+=1
	var result:=""
	if _key(key):
		var rows:=_load_shard(key.left(2))
		var valid: bool=rows.has(key) and _valid_artifact(rows[key])
		if not valid:
			rows=_load_shard(key.left(2),true);valid=rows.has(key) and _valid_artifact(rows[key])
		if valid:result=_artifact(rows[key]);_stats.hits+=1
	if result.is_empty():_stats.misses+=1
	var elapsed:=Time.get_ticks_usec()-began;_stats.lookup_us+=elapsed;_stats.lookup_max_us=maxi(_stats.lookup_max_us,elapsed)
	_mutex.unlock();return result
func begin_write(key: String) -> Dictionary:
	if not _enter():return {}
	if not _key(key) or _tickets.size()>=MAX_WRITES:failure="invalid-key-or-write-limit";_stats.rejected+=1;_mutex.unlock();return {}
	var nonce:=_nonce();var ticket:={"key":key,"path":_path("staging",key+"."+nonce+".res"),"nonce":nonce}
	_tickets[nonce]=ticket.duplicate();_mutex.unlock();return ticket
func _ticket_matches(ticket: Dictionary,owned: Dictionary) -> bool:
	return ticket.size()==3 and ticket.get("key")==owned.get("key") and ticket.get("nonce")==owned.get("nonce") and ticket.get("path")==owned.get("path")
func cancel_write(ticket: Dictionary) -> void:
	if not _enter():return
	var nonce:=str(ticket.get("nonce",""));var own: Dictionary=_tickets.get(nonce,{})
	if not own.is_empty() and _ticket_matches(ticket,own) and _mutation_root_current():
		if _safe_file(own.path,_path("staging","").trim_suffix("/")) and FileAccess.file_exists(own.path):DirAccess.remove_absolute(own.path)
		_tickets.erase(nonce)
	else:failure="invalid-ticket"
	_mutex.unlock()
func _leased(row: Dictionary) -> bool:
	var path:=_path("readers",str(row.file).trim_suffix(".res"))
	if not DirAccess.dir_exists_absolute(path):return false
	if not _safe_file(path,path.get_base_dir()):return true
	var folder:=DirAccess.open(path)
	if folder==null:return true
	# Only the acquiring owner may retire its marker. Crashed-owner cleanup needs
	# an external, unambiguous process-lifetime proof, not a best-effort PID probe.
	folder.list_dir_begin();var name:=folder.get_next();folder.list_dir_end()
	return not name.is_empty()
func _choose_victims(target: String,size: int) -> Array:
	var victims: Array=[];var available:=budget_bytes-int(_state.bytes);var skipped: Dictionary={};var loaded: Dictionary={};var target_rows:=_load_shard(target,true)
	if not failure.is_empty():return []
	var target_count:=target_rows.size()
	while available<size or target_count>=MAX_SHARD_ENTRIES:
		if victims.size()>=MAX_EVICTIONS:failure="budget-pinned-or-maintenance-needed";return []
		var selected:="";var shard_oldest: int=9223372036854775807
		for prefix in _state.shards:
			if skipped.has(prefix) or target_count>=MAX_SHARD_ENTRIES and prefix!=target:continue
			var summary: Dictionary=_state.shards[prefix]
			if int(summary.get("entries",0))==0:continue
			var used:=int(summary.get("oldest",0))
			if used<shard_oldest or used==shard_oldest and (selected.is_empty() or prefix<selected):selected=prefix;shard_oldest=used
		if selected.is_empty():failure="budget-pinned";return []
		if not loaded.has(selected):loaded[selected]=_load_shard(selected,true)
		if not failure.is_empty():return []
		var best: Dictionary={};var oldest: int=9223372036854775807
		for key in loaded[selected]:
			var row: Dictionary=loaded[selected][key]
			if victims.any(func(value):return value.key==key) or _leased(row):continue
			var used: int=maxi(int(row.used),int(_touches.get(key,0)))
			if used<oldest or used==oldest and (best.is_empty() or key<best.key):oldest=used;best={"key":key,"row":row,"prefix":selected}
		if best.is_empty():skipped[selected]=true;continue
		victims.append(best);available+=int(best.row.bytes)
		if best.prefix==target:target_count-=1
	return victims
func _finish_mutation(changed: Dictionary) -> bool:
	# Approximate LRU touches are coalesced and piggyback on worker publication.
	# Bound extra metadata work to four shards /64 touches per mutation.
	var touch_shards: Dictionary={};var processed:=0
	for key in _touches.keys():
		if processed>=64:break
		var prefix:=str(key).left(2)
		if not changed.has(prefix) and not touch_shards.has(prefix) and touch_shards.size()>=4:continue
		if not changed.has(prefix):changed[prefix]=_load_shard(prefix,true).duplicate();touch_shards[prefix]=true
		if not failure.is_empty():return false
		if changed[prefix].has(key):changed[prefix][key].used=maxi(int(changed[prefix][key].used),int(_touches[key]))
		_touches.erase(key);processed+=1
	for prefix in changed:
		if not _save_shard(prefix,changed[prefix]):return false
	_state.revision=_nonce()
	if not _write_doc(directory.path_join("state.json"),_state):return false
	DirAccess.remove_absolute(directory.path_join("transaction.json"));return true
func commit_write(ticket: Dictionary) -> bool:
	if not _enter():return false
	var own: Dictionary=_tickets.get(str(ticket.get("nonce","")),{})
	if own.is_empty() or not _ticket_matches(ticket,own) or not _safe_file(str(own.path),_path("staging","").trim_suffix("/")):failure="invalid-ticket";_stats.rejected+=1;_mutex.unlock();return false
	var file:=FileAccess.open(own.path,FileAccess.READ)
	if file==null:failure="staged-file-unavailable";_mutex.unlock();return false
	var size:=file.get_length();var magic:=file.get_buffer(4).get_string_from_ascii();file.close()
	if size<4 or size>mini(MAX_ARTIFACT_BYTES,budget_bytes) or magic not in ["RSRC","RSCC"]:failure="invalid-resource-envelope-or-size";_stats.rejected+=1;_mutex.unlock();return false
	if not _try_publish_lock():_mutex.unlock();return false
	var success:=_recover() and _refresh_state()
	if not success:_unlock_publish();_mutex.unlock();return false
	var key: String=own.key;var prefix:=key.left(2);var rows:=_load_shard(prefix,true)
	if rows.has(key) and _valid_artifact(rows[key]):
		DirAccess.remove_absolute(own.path);_tickets.erase(str(own.nonce));_stats.deduplicated+=1;_unlock_publish();_mutex.unlock();return true
	if rows.has(key):failure="corrupt-entry-needs-invalidation";_unlock_publish();_mutex.unlock();return false
	var victims:=_choose_victims(prefix,size)
	if not failure.is_empty():_unlock_publish();_mutex.unlock();return false
	var name:=key+"."+str(own.nonce)+".res";var destination:=_path("artifacts",name)
	if not _write_doc(directory.path_join("transaction.json"),{"key":key,"nonce":own.nonce,"new_file":name}):_unlock_publish();_mutex.unlock();return false
	var changed: Dictionary={}
	for victim in victims:
		var path:=_artifact(victim.row)
		if not _safe_file(path,path.get_base_dir()) or DirAccess.remove_absolute(path)!=OK:failure="eviction-unavailable";_unlock_publish();_mutex.unlock();return false
		var part: Dictionary=changed.get(victim.prefix,_shards[victim.prefix].duplicate())
		part.erase(victim.key);changed[victim.prefix]=part;_state.bytes-=int(victim.row.bytes);_state.entries-=1;_stats.evictions+=1
	if DirAccess.rename_absolute(own.path,destination)!=OK:failure="artifact-publication";_unlock_publish();_mutex.unlock();return false
	var current: Dictionary=changed.get(prefix,rows.duplicate())
	current[key]={"file":name,"nonce":own.nonce,"bytes":size,"used":_clock()};changed[prefix]=current
	_state.bytes+=size;_state.entries+=1
	success=_finish_mutation(changed)
	if success:_tickets.erase(str(own.nonce));_stats.writes+=1
	_unlock_publish();_mutex.unlock();return success
func _ensure_reader_parent(parent: String) -> bool:
	# configure() already owns/creates readers/. Rebuilding the absolute ancestor
	# chain here makes Windows issue CreateDirectoryW for every path component
	# on every lease. Only this validated artifact-specific leaf is missing.
	_stats.reader_leaf_mkdir_attempts+=1
	var result:=DirAccess.make_dir_absolute(parent)
	if result==OK:_stats.reader_leaf_mkdir_created+=1;return true
	# Windows also maps access-denied to ALREADY_EXISTS: verify a real directory,
	# rather than admitting an ordinary file or unavailable leaf as a reader root.
	if result==ERR_ALREADY_EXISTS and DirAccess.dir_exists_absolute(parent):_stats.reader_leaf_mkdir_existing+=1;return true
	_stats.reader_leaf_mkdir_failed+=1;return false
func acquire_read(key: String) -> Dictionary:
	if not _enter():return {}
	var began:=Time.get_ticks_usec()
	if not _key(key) or _reads.size()>=MAX_READS:failure="invalid-key-or-read-limit";_mutex.unlock();return {}
	_stats.read_attempts+=1;_stats.read_hint_checks+=1
	# Optional-cache absence can conservatively select original publication. A
	# fresh bounded shard hint never supplies a read path/ticket. A racing writer
	# can cause only a false miss; real hits still take the unchanged lock and
	# revalidate the current row before creating the cross-process reader pin.
	var hint_began:=Time.get_ticks_usec();var hint:=_load_shard(key.left(2))
	if not hint.has(key) and failure.is_empty():hint=_load_shard(key.left(2),true)
	_stats.read_hint_us+=Time.get_ticks_usec()-hint_began
	if not hint.has(key) and failure.is_empty():
		_stats.read_hint_misses+=1;_stats.misses+=1
		var miss_elapsed:=Time.get_ticks_usec()-began;_stats.read_acquire_us+=miss_elapsed;_stats.read_acquire_max_us=maxi(int(_stats.read_acquire_max_us),miss_elapsed)
		_mutex.unlock();return {}
	# A hint cannot make a recovery/error decision. Re-enter the original strong
	# path with a clean diagnostic, including recovery under its publication lock.
	failure="";_stats.read_strong_attempts+=1
	if not _try_publish_lock():_mutex.unlock();return {}
	if not _recover():_unlock_publish();_mutex.unlock();return {}
	var rows:=_load_shard(key.left(2),true);var ticket: Dictionary={}
	if rows.has(key) and _valid_artifact(rows[key]):
		var row: Dictionary=rows[key];var nonce:=_nonce();var parent:=_path("readers",str(row.file).trim_suffix(".res"))
		if _safe_file(parent,parent.get_base_dir()) and _ensure_reader_parent(parent):
			var marker:=parent.path_join(str(OS.get_process_id())+"."+nonce+".json")
			if _write_doc(marker,{"pid":OS.get_process_id(),"nonce":nonce,"file":row.file}):
				ticket={"key":key,"path":_artifact(row),"nonce":nonce};_reads[nonce]={"ticket":ticket.duplicate(),"marker":marker};_stats.read_acquires+=1
				if _touches.size()<512 or _touches.has(key):_touches[key]=_clock()
	if ticket.is_empty():_stats.misses+=1
	var elapsed:=Time.get_ticks_usec()-began;_stats.read_acquire_us+=elapsed;_stats.read_acquire_max_us=maxi(_stats.read_acquire_max_us,elapsed)
	_unlock_publish();_mutex.unlock();return ticket
func release_read(ticket: Dictionary) -> void:
	if not _enter():return
	var nonce:=str(ticket.get("nonce",""));var own: Dictionary=_reads.get(nonce,{})
	if not own.is_empty() and _ticket_matches(ticket,own.ticket) and _mutation_root_current():
		var marker: String=own.marker
		if _safe_file(marker,marker.get_base_dir()) and DirAccess.remove_absolute(marker)==OK:
			_reads.erase(nonce);_stats.read_releases+=1
			# Nonrecursive remove succeeds only when no other lease occupies it.
			DirAccess.remove_absolute(marker.get_base_dir())
	else:failure="invalid-read-ticket"
	_mutex.unlock()
func invalidate(key: String) -> bool:
	if not _enter():return false
	if not _key(key) or not _try_publish_lock():_mutex.unlock();return false
	if not _recover() or not _refresh_state():_unlock_publish();_mutex.unlock();return false
	var prefix:=key.left(2);var rows:=_load_shard(prefix,true)
	if not rows.has(key):_unlock_publish();_mutex.unlock();return true
	var row: Dictionary=rows[key]
	if _leased(row):failure="read-pinned";_unlock_publish();_mutex.unlock();return false
	var success:=_write_doc(directory.path_join("transaction.json"),{"operation":"invalidate","key":key})
	if success:
		var path:=_artifact(row)
		if FileAccess.file_exists(path):success=_safe_file(path,path.get_base_dir()) and DirAccess.remove_absolute(path)==OK
	if success:
		rows.erase(key);_state.bytes-=int(row.bytes);_state.entries-=1;success=_finish_mutation({prefix:rows})
	_unlock_publish();_mutex.unlock();return success
func snapshot() -> Dictionary:
	if not _mutex.try_lock():return {"busy":true,"available":not directory.is_empty()}
	var result:=_stats.duplicate();var staged: int=0
	for ticket in _tickets.values():
		if _safe_file(ticket.path,ticket.path.get_base_dir()) and FileAccess.file_exists(ticket.path):
			var file:=FileAccess.open(ticket.path,FileAccess.READ)
			if file!=null:staged+=file.get_length();file.close()
	result.merge({"available":not directory.is_empty() and not _closed,"directory":directory,"budget_bytes":budget_bytes,"committed_bytes":int(_state.get("bytes",0)),"committed_entries":int(_state.get("entries",0)),"staged_bytes_this_owner":staged,"pending_writes":_tickets.size(),"active_reads":_reads.size(),"resident_shards":_shards.size(),"failure":failure,"budget_scope":"Actual committed resource bytes; bounded metadata and temporary ResourceSaver staging are additional","codec_scope":"Built-in script-free resource type validation belongs to the codec; store checks path, envelope and actual byte count"})
	_mutex.unlock();return result
func close() -> bool:
	if not _enter():return false
	if not _reads.is_empty():failure="active-reads";_mutex.unlock();return false
	# A ticket may still be owned by asynchronous ResourceSaver work. Its caller
	# must drain/cancel that task explicitly before the store can close.
	if not _tickets.is_empty():failure="active-writes";_mutex.unlock();return false
	_tickets.clear();_shards.clear();_touches.clear();_folders.clear();_closed=true;_mutex.unlock();return true
