extends RefCounted
const Accounting=preload("res://systems/native_data/resource_index_backend.gd")
# Bounded, data-only memory tier above the existing content-addressed disk
# cache. Catalog mounting/reset invalidates request bindings. Returned graphs
# are private copies, so callers cannot mutate another actor's cached source.
var mutex:=Mutex.new()
var epoch:=0
var maximum_bytes:=256*1024*1024
var maximum_entries:=512
var entries: Dictionary={}
var requests: Dictionary={}
var order: Array=[]
var bytes:=0
var hits:=0
var misses:=0
var evictions:=0
var flights: Dictionary={}
var coalesced:=0
var accounting:={"native":0,"serialized":0,"hinted":0,"usec":0,"shared_storage":0,"bounded":0}
func begin_data(request: String,expected: int,private_graph: bool=true) -> Dictionary:
	var flight_key:=str(expected)+":"+request
	mutex.lock()
	if expected==epoch and requests.has(request) and entries.has(requests[request]):
		var saved: Dictionary=entries[requests[request]].value; hits+=1; mutex.unlock()
		return {"owner":false,"value":saved.duplicate(true) if private_graph else saved,"wait_us":0}
	if not flights.has(flight_key):
		flights[flight_key]={"wake":Semaphore.new(),"waiters":0,"value":{}}
		misses+=1; mutex.unlock(); return {"owner":true}
	var flight: Dictionary=flights[flight_key]; flight.waiters+=1; coalesced+=1; mutex.unlock()
	var began:=Time.get_ticks_usec(); flight.wake.wait()
	return {"owner":false,"value":flight.value.duplicate(true) if private_graph else flight.value,"wait_us":Time.get_ticks_usec()-began}
func finish_data(request: String,expected: int,value: Dictionary) -> void:
	var flight_key:=str(expected)+":"+request
	mutex.lock()
	if not flights.has(flight_key): mutex.unlock(); return
	var flight: Dictionary=flights[flight_key]
	# save_data has already frozen a private graph. Reuse that immutable graph
	# for followers; successful leaders keep their own independently mutable copy.
	var frozen: Dictionary=entries[requests[request]].value if expected==epoch and requests.has(request) and entries.has(requests[request]) else {}
	mutex.unlock()
	if frozen.is_empty(): frozen=value.duplicate(true)
	mutex.lock(); flight.value=frozen; flights.erase(flight_key); var count:=int(flight.waiters); mutex.unlock()
	for index in count: flight.wake.post()
var last_snapshot: Dictionary={"generation":0,"entries":0,"estimated_bytes":0,"maximum_bytes":256*1024*1024,"hits":0,"misses":0,"evictions":0,"inflight":0,"coalesced":0,"metadata_busy":false}
func generation() -> int:
	mutex.lock(); var value:=epoch; mutex.unlock(); return value
func clear() -> void:
	mutex.lock(); epoch+=1
	var detached:={"entries":entries,"requests":requests,"order":order}; entries={}; requests={}; order=[]; bytes=0
	mutex.unlock()
	# Recursive Variant destruction can take seconds for expanded model graphs.
	# Never hold the shared catalog lock while releasing those graphs.
	detached.clear()
func load_data(request: String,expected: int) -> Dictionary:
	mutex.lock()
	if expected!=epoch or not requests.has(request) or not entries.has(requests[request]): misses+=1; mutex.unlock(); return {}
	var value: Dictionary=entries[requests[request]].value; hits+=1; mutex.unlock()
	return value.duplicate(true)
func save_data(request: String,identity: String,value: Dictionary,expected: int,size_hint: int=-1,retain_immutable: bool=false) -> void:
	var began:=Time.get_ticks_usec(); var cost:=Accounting.retained_cost(value,maximum_bytes) if size_hint<0 else {}
	var measured: bool=cost.has("estimated_bytes"); var size:=size_hint if size_hint>=0 else (int(cost.estimated_bytes) if measured else var_to_bytes(value).size())
	mutex.lock(); accounting["hinted" if size_hint>=0 else ("native" if measured else "serialized")]+=1; accounting.usec+=Time.get_ticks_usec()-began; accounting.shared_storage+=int(cost.get("shared",0)); accounting.bounded+=int(cost.get("bounded",0)); mutex.unlock()
	if size>maximum_bytes or size<=0: return
	# Borrowing is restricted to an internal immutable source graph. Callers
	# requesting private state retain the deep-copy default.
	var copy: Dictionary=value if retain_immutable else value.duplicate(true)
	var detached: Array=[]
	mutex.lock()
	if epoch!=expected: mutex.unlock(); return
	if not entries.has(identity):
		while not order.is_empty() and (bytes+size>maximum_bytes or entries.size()>=maximum_entries):
			var old: String=order.pop_front(); bytes-=int(entries[old].bytes); detached.append(entries[old]); entries.erase(old); evictions+=1
			for key in requests.keys():
				if requests[key]==old: requests.erase(key)
		entries[identity]={"value":copy,"bytes":size}; order.append(identity); bytes+=size
	requests[request]=identity; mutex.unlock()
	detached.clear() # Worker-owned data disposal, outside the presentation lock.
func snapshot() -> Dictionary:
	# Frame diagnostics cannot wait behind a resource worker. The last snapshot
	# is owned only by this observer; worker code never mutates that dictionary.
	if not mutex.try_lock():
		var previous:=last_snapshot.duplicate(); previous.metadata_busy=true; return previous
	var value:={"generation":epoch,"entries":entries.size(),"estimated_bytes":bytes,"maximum_bytes":maximum_bytes,"hits":hits,"misses":misses,"evictions":evictions,"inflight":flights.size(),"coalesced":coalesced,"metadata_busy":false,"accounting":accounting.duplicate()}; mutex.unlock()
	last_snapshot=value; return value.duplicate()
func retained_size(request: String,expected: int) -> int:
	mutex.lock()
	var result:=int(entries[requests[request]].bytes) if expected==epoch and requests.has(request) and entries.has(requests[request]) else 0
	mutex.unlock(); return result
