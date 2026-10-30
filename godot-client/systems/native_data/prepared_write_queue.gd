extends RefCounted
# Optional immutable-source cache publication. One low-priority native thread
# per active asset-service lifetime, never scene/GPU work or a reader pool task.
# Bounds charge the existing decoded-store serialized-size estimate, not RSS.
static var service_mutex:=Mutex.new()
static var shared
static func configured_enabled() -> bool:
	var args:=OS.get_cmdline_user_args()
	return not args.has("--prepared-cache-write=sync") and not args.has("--prepared-cache-write=disabled")
class State:
	extends RefCounted
	const Cache=preload("res://systems/native_data/prepared_cache.gd")
	const RawCache=preload("res://systems/native_data/source_bytes_cache.gd")
	var raw_caches: Dictionary={}
	var maintenance_pending: Dictionary={}
	var mutex:=Mutex.new()
	var wake:=Semaphore.new()
	var thread: Thread
	var owners:=0
	var closed:=false
	var maximum_packets:=128
	var maximum_bytes:=64*1024*1024
	var packets: Array=[]
	var identities: Dictionary={}
	var retained_bytes:=0
	var active:=false
	var stats:={"submitted":0,"coalesced":0,"completed":0,"failed":0,"skipped_full":0,"skipped_closed":0,"peak_packets":0,"peak_estimated_bytes":0,"worker_ms":0.0,"max_worker_ms":0.0,"bytes_written":0,"threads":[],"errors":[]}
	func enqueue(directory: String,key: String,source_sha: String,decoder: String,value: Dictionary,estimated_bytes: int) -> bool:
		var identity:=directory+":"+key
		return submit({"directory":directory,"key":key,"source_sha":source_sha,"decoder":decoder,"value":value.duplicate(),"identity":identity,"estimated_bytes":estimated_bytes},estimated_bytes)
	func enqueue_raw(directory: String,key: String,bytes: PackedByteArray,disk_limit: int,entry_limit: int) -> bool:
		if key.length()!=40 or key!=key.to_lower() or not key.is_valid_hex_number(false) or bytes.size()>entry_limit: return false
		var charge:=bytes.size()+128
		return submit({"kind":"raw","directory":directory,"key":key,"value":bytes.duplicate(),"identity":"raw:"+directory+":"+key,"estimated_bytes":charge,"disk_limit":disk_limit,"entry_limit":entry_limit},charge)
	func submit(packet: Dictionary,estimated_bytes: int) -> bool:
		var identity: String=packet.identity
		mutex.lock()
		if closed: stats.skipped_closed+=1; mutex.unlock(); return false
		if identities.has(identity): stats.coalesced+=1; mutex.unlock(); return true
		if estimated_bytes<=0 or identities.size()>=maximum_packets or estimated_bytes>maximum_bytes-retained_bytes:
			stats.skipped_full+=1; mutex.unlock(); return false
		# The caller has published this graph to the immutable decoded store and
		# hands mutable consumers private wrappers/copies. Snapshot only the outer
		# header, preventing later added rig metadata from entering the disk schema.
		packets.append(packet)
		identities[identity]=true; retained_bytes+=estimated_bytes; stats.submitted+=1
		stats.peak_packets=maxi(stats.peak_packets,identities.size()); stats.peak_estimated_bytes=maxi(stats.peak_estimated_bytes,retained_bytes)
		if thread==null:
			thread=Thread.new(); var error:=thread.start(drain,Thread.PRIORITY_LOW)
			if error!=OK:
				thread=null; packets.clear(); identities.clear(); retained_bytes=0; stats.failed+=1; stats.errors.append("Native prepared writer could not start: "+str(error)); mutex.unlock(); return false
		mutex.unlock(); wake.post(); return true
	func save(packet: Dictionary) -> Dictionary:
		if packet.get("kind","")=="raw":
			var raw=raw_caches.get(packet.directory)
			if raw==null:
				raw=RawCache.new()
				if not raw.configure(packet.directory): return {"success":false,"error":"Native raw cache directory is unavailable","bytes":0}
				raw_caches[packet.directory]=raw
			raw.maximum_disk_bytes=int(packet.disk_limit); raw.maximum_entry_bytes=int(packet.entry_limit)
			var ok: bool=raw.save(packet.key,packet.value,cancel_prune,true)
			var timing: Dictionary=raw.take_save_timing()
			return {"success":ok,"error":raw.failure,"bytes":packet.value.size() if ok else 0,"raw":true,"maintenance":timing.get("maintenance_requested",false),"directory":packet.directory}
		var cache:=Cache.new()
		var ok:=cache.configure(packet.directory) and cache.save_data(packet.key,packet.source_sha,packet.decoder,packet.value)
		return {"success":ok,"error":cache.failure,"bytes":int(cache.last_save.get("bytes",0))}
	func cancel_prune() -> bool:
		mutex.lock(); var value:=closed; mutex.unlock(); return value
	func cancel_maintenance() -> bool:
		mutex.lock(); var value:=closed or not packets.is_empty(); mutex.unlock(); return value
	func drain() -> void:
		while true:
			wake.wait()
			while true:
				mutex.lock()
				if packets.is_empty():
					var done:=closed; var directory: String="" if done or maintenance_pending.is_empty() else str(maintenance_pending.keys()[0]); active=not directory.is_empty(); mutex.unlock()
					if done: return
					if not directory.is_empty():
						var began:=Time.get_ticks_usec(); var raw=raw_caches[directory]
						var complete: bool=raw.prune(cancel_maintenance)
						mutex.lock(); active=false; stats["raw_prune_us"]=int(stats.get("raw_prune_us",0))+Time.get_ticks_usec()-began
						if complete: maintenance_pending.erase(directory)
						mutex.unlock(); continue
					break
				var packet: Dictionary=packets.pop_front(); active=true; mutex.unlock()
				var began:=Time.get_ticks_usec(); var result:=save(packet); var elapsed:=(Time.get_ticks_usec()-began)/1000.0
				var identity:=str(packet.identity); var charge:=int(packet.estimated_bytes)
				# Release our references on this worker before declaring the packet
				# complete or making its retention budget available to new work.
				packet.clear()
				mutex.lock(); active=false; identities.erase(identity); retained_bytes-=charge
				stats.completed+=1; stats.worker_ms+=elapsed; stats.max_worker_ms=maxf(stats.max_worker_ms,elapsed); stats.bytes_written+=int(result.bytes)
				if result.get("raw",false):
					stats["raw_completed"]=int(stats.get("raw_completed",0))+1
					if result.get("maintenance",false): maintenance_pending[str(result.directory)]=true
				if not stats.threads.has(OS.get_thread_caller_id()): stats.threads.append(OS.get_thread_caller_id())
				if not result.success:
					stats.failed+=1
					if stats.errors.size()<16: stats.errors.append(str(result.error))
				mutex.unlock()
	func snapshot() -> Dictionary:
		mutex.lock(); var value: Dictionary=stats.duplicate(true)
		value.merge({"pending":identities.size(),"queued":packets.size(),"active":active,"maintenance_pending":maintenance_pending.size(),"estimated_bytes":retained_bytes,"maximum_packets":maximum_packets,"maximum_bytes":maximum_bytes,"owners":owners,"closed":closed,"scope":"Immutable decoded models and verified raw bytes; optional full queues skip cache publication, never world assets. Idle cache maintenance yields to newly queued writes and shutdown."}); mutex.unlock(); return value
	func close() -> void:
		mutex.lock(); closed=true; var worker:=thread; mutex.unlock(); wake.post()
		if worker!=null: worker.wait_to_finish()
		mutex.lock(); thread=null; active=false; maintenance_pending.clear(); raw_caches.clear(); mutex.unlock()
static func acquire() -> void:
	service_mutex.lock()
	# A retiring last owner closes outside this lock. Never give a new owner
	# that zero-owner state while its close has not yet set the closed flag.
	if shared==null or shared.owners==0 or shared.closed: shared=State.new()
	shared.owners+=1; service_mutex.unlock()
static func release() -> void:
	service_mutex.lock(); var state=shared
	if state==null or state.owners<=0: service_mutex.unlock(); return
	state.owners-=1; var last: bool=state.owners==0; service_mutex.unlock()
	if last: state.close()
static func enqueue(directory: String,key: String,source_sha: String,decoder: String,value: Dictionary,estimated_bytes: int) -> bool:
	service_mutex.lock(); var state=shared; var available: bool=state!=null and state.owners>0; service_mutex.unlock()
	return state.enqueue(directory,key,source_sha,decoder,value,estimated_bytes) if available else false
static func enqueue_raw(directory: String,key: String,bytes: PackedByteArray,disk_limit: int,entry_limit: int) -> bool:
	service_mutex.lock(); var state=shared; var available: bool=state!=null and state.owners>0; service_mutex.unlock()
	return state.enqueue_raw(directory,key,bytes,disk_limit,entry_limit) if available else false
static func snapshot() -> Dictionary:
	service_mutex.lock(); var state=shared; service_mutex.unlock()
	var value: Dictionary=state.snapshot() if state!=null else {"pending":0,"owners":0,"closed":true}
	value.enabled=configured_enabled(); return value
