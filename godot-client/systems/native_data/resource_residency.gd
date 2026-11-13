extends RefCounted
# Process-owned immutable data, not a server's resref bindings or live objects.
# Catalogs still select their own winning layer before using these stores.
const Store=preload("res://systems/native_data/preparation_store.gd")
const Accounting=preload("res://systems/native_data/resource_index_backend.gd")
static var indexes=make_store(256*1024*1024,256)
static var bindings=make_store(256*1024*1024,16)
static var decoded=make_store(1024*1024*1024,4096)
static var synced_bytes=make_store(256*1024*1024,4096)
static func prepared_budget() -> int:
	var requested:=OS.get_environment("NWN_RESOURCE_PREPARED_MIB")
	# Retained-container accounting includes allocator/container overhead absent
	# from the old serialized-byte charge. This is an eviction threshold, not a
	# reservation; preserve the prior working set under the new conservative units.
	return clampi(int(requested),64,4096)*1024*1024 if requested.is_valid_int() else (2048 if Accounting.accounting_available() else 512)*1024*1024
static func make_store(budget: int,limit: int):
	var store:=Store.new(); store.maximum_bytes=budget; store.maximum_entries=limit; return store
static func freeze_index(value: Variant) -> void:
	if value is Dictionary:
		for item in value.values(): freeze_index(item)
		value.make_read_only()
	elif value is Array:
		for item in value: freeze_index(item)
		value.make_read_only()
static func index(kind: String,identity: Array,parts: Array,decode: Callable,cache=null) -> Dictionary:
	# Hash the actual index bytes, not just second-resolution file timestamps.
	# Same-size edits and changed archive tables cannot revive an old binding.
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(["native-resident-index-v1",kind,identity]))
	var bytes:=0
	for part in parts:
		hash.update(var_to_bytes(part.size()))
		if not part.is_empty(): hash.update(part)
		bytes+=part.size()
	var key:=hash.finish().hex_encode(); var store=indexes if cache==null else cache; var generation: int=store.generation()
	var lease: Dictionary=store.begin_data(key,generation,false)
	if not lease.owner:
		var hit: Dictionary=lease.value.duplicate(); hit.cache_hit=true; hit.wait_us=int(lease.wait_us); hit.identity=key; return hit
	var result: Dictionary=decode.call()
	if str(result.get("error","")).is_empty():
		var value: Dictionary=result.value
		freeze_index(value)
		var entries: int=value.get("entries",{}).size()
		store.save_data(key,key,result,generation,bytes*2+entries*256+1024,true)
	store.finish_data(key,generation,result)
	var owned:=result.duplicate(); owned.cache_hit=false; owned.wait_us=0; owned.identity=key; return owned
static func snapshot() -> Dictionary:
	return {"indexes":indexes.snapshot(),"bindings":bindings.snapshot(),"decoded":decoded.snapshot(),"synced_bytes":synced_bytes.snapshot()}
