extends RefCounted
# A small derived-rig partition belongs to each decoded source owner/generation.
# It cannot evict decoded MDLs. Single-use rigs are returned without freezing or
# retained-size accounting; repeated/concurrent requests may retain one rig.
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Accounting=preload("res://systems/native_data/resource_index_backend.gd")
const REVISION:="shared-animation-preparation-v2"
const PARTITION_META:=&"nwn_shared_rig_partition_v2"
static var metadata_mutex:=Mutex.new()
class Flight:
	extends RefCounted
	var wake:=Semaphore.new()
	var waiters:=0
	var value: Dictionary={}
	var retained:=false
class Partition:
	extends RefCounted
	var mutex:=Mutex.new()
	var source: WeakRef
	var generation:=0
	var maximum_bytes:=128*1024*1024
	var maximum_entries:=128
	var entries: Dictionary={}
	var order: Array=[]
	var seen: Dictionary={}
	var seen_order: Array=[]
	var flights: Dictionary={}
	var retained_bytes:=0
	var counts:={"requests":0,"hits":0,"misses":0,"coalesced":0,"builds":0,"seeded":0,"first_uses":0,"admitted":0,"declined":0,"evictions":0,"retired":0,"accounting_us":0,"freeze_us":0}
	func snapshot() -> Dictionary:
		mutex.lock(); var result:=counts.duplicate()
		result.merge({"generation":generation,"entries":entries.size(),"retained_bytes":retained_bytes,"maximum_bytes":maximum_bytes,"maximum_entries":maximum_entries,"seen":seen.size(),"inflight":flights.size(),"scope":"Independent bounded derived-rig cache; cannot evict parsed MDLs"})
		mutex.unlock(); return result
static func configured_enabled() -> bool:
	return OS.get_cmdline_user_args().has("--shared-animation-preparation=true")
static func partition(store) -> Partition:
	if store==null: return null
	var generation:=int(store.generation())
	metadata_mutex.lock()
	var value: Variant=store.get_meta(PARTITION_META) if store.has_meta(PARTITION_META) else null
	if not value is Partition or value.generation!=generation:
		value=Partition.new(); value.source=weakref(store); value.generation=generation
		store.set_meta(PARTITION_META,value)
	metadata_mutex.unlock(); return value
static func snapshot(store) -> Dictionary:
	var value:=partition(store)
	return value.snapshot() if value!=null else {"available":false}
static func set_limits(store,bytes: int,entries: int=128) -> void:
	var value:=partition(store)
	if value==null: return
	value.mutex.lock(); value.maximum_bytes=maxi(1,bytes); value.maximum_entries=maxi(1,entries); value.mutex.unlock()
static func view_identity(sources: Array,selected: Variant) -> String:
	var names: Variant=null
	if selected is Dictionary:
		names=selected.keys(); names.sort()
	return Cache.digest(var_to_bytes([REVISION,sources,names]))
static func freeze(value: Variant) -> void:
	var pending: Array=[value]
	while not pending.is_empty():
		var current: Variant=pending.pop_back()
		if current is Dictionary:
			if current.is_read_only(): continue
			for child in current.values():
				if child is Dictionary or child is Array: pending.append(child)
			current.make_read_only()
		elif current is Array:
			if current.is_read_only(): continue
			for child in current:
				if child is Dictionary or child is Array: pending.append(child)
			current.make_read_only()
static func acquire(store,key: String,build: Callable,seed: Dictionary={}) -> Dictionary:
	var began:=Time.get_ticks_usec(); var owner:=partition(store)
	if owner==null:
		var private_value: Dictionary=build.call() if seed.is_empty() else seed
		return {"value":private_value,"hit":false,"wait_us":0,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"resident":false,"first_use":true,"seeded":not seed.is_empty(),"admitted":false}
	owner.mutex.lock(); owner.counts.requests+=1
	if owner.entries.has(key):
		var saved: Dictionary=owner.entries[key].value; owner.counts.hits+=1; owner.mutex.unlock()
		return {"value":saved,"hit":true,"wait_us":0,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"resident":true,"first_use":false,"seeded":false,"admitted":false}
	if not owner.seen.has(key):
		if owner.seen_order.size()>=1024: owner.seen.erase(owner.seen_order.pop_front())
		owner.seen[key]=0; owner.seen_order.append(key)
	owner.seen[key]=mini(2,int(owner.seen[key])+1)
	if owner.flights.has(key):
		var pending: Flight=owner.flights[key]; pending.waiters+=1; owner.counts.coalesced+=1; owner.mutex.unlock()
		var waiting:=Time.get_ticks_usec(); pending.wake.wait()
		return {"value":pending.value,"hit":true,"wait_us":Time.get_ticks_usec()-waiting,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"resident":pending.retained,"first_use":false,"seeded":false,"admitted":false}
	var flight:=Flight.new(); owner.flights[key]=flight; owner.counts.misses+=1
	var first: bool=int(owner.seen[key])==1
	owner.counts["seeded" if not seed.is_empty() else "builds"]+=1; owner.mutex.unlock()
	var value: Dictionary=build.call() if seed.is_empty() else seed
	owner.mutex.lock()
	var admit: bool=int(owner.seen.get(key,1))>=2 and str(value.get("error","")).is_empty()
	if not admit and flight.waiters==0:
		# No waiter can join after this removal. Single-use data therefore needs
		# neither freezing nor a retained-size traversal.
		owner.flights.erase(key); owner.counts.first_uses+=int(first); owner.mutex.unlock()
		return {"value":value,"hit":false,"wait_us":0,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"resident":false,"first_use":first,"seeded":not seed.is_empty(),"admitted":false}
	var maximum:=owner.maximum_bytes; owner.mutex.unlock()
	var accounted_at:=Time.get_ticks_usec(); var bytes:=0
	if admit:
		var cost:=Accounting.retained_cost(value,maximum)
		bytes=int(cost.estimated_bytes) if cost.has("estimated_bytes") else var_to_bytes(value).size()
	var accounting_us:=Time.get_ticks_usec()-accounted_at
	var source_owner=owner.source.get_ref(); var current: bool=source_owner!=null and int(source_owner.generation())==owner.generation
	var eligible: bool=current and bytes>0 and bytes<=maximum
	var frozen_at:=Time.get_ticks_usec()
	if eligible: freeze(value)
	var freeze_us:=Time.get_ticks_usec()-frozen_at if eligible else 0
	var detached: Array=[]
	owner.mutex.lock(); owner.counts.accounting_us+=accounting_us; owner.counts.freeze_us+=freeze_us
	if eligible:
		while not owner.order.is_empty() and (owner.retained_bytes+bytes>owner.maximum_bytes or owner.entries.size()>=owner.maximum_entries):
			var old: String=owner.order.pop_front(); owner.retained_bytes-=int(owner.entries[old].bytes); detached.append(owner.entries[old]); owner.entries.erase(old); owner.counts.evictions+=1
		owner.entries[key]={"value":value,"bytes":bytes}; owner.order.append(key); owner.retained_bytes+=bytes; owner.counts.admitted+=1
	else:
		owner.counts.declined+=1
		if not current: owner.counts.retired+=1
	var waiters:=flight.waiters
	# A concurrent over-budget/error result can be temporarily shared read-only
	# without retaining it or charging the parsed-source cache.
	if not eligible and waiters>0: freeze(value)
	flight.value=value; flight.retained=eligible; owner.flights.erase(key); owner.mutex.unlock()
	for index in waiters: flight.wake.post()
	detached.clear()
	return {"value":value,"hit":false,"wait_us":0,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"resident":eligible,"first_use":first,"seeded":not seed.is_empty(),"admitted":eligible}
