extends RefCounted
# Exact-content GPU bindings may leave the bounded strong cache while admitted
# models still own their Resources. A weak secondary directory finds those live
# Resources without extending their lifetime or changing the strong-cache bound.
# Only main-thread ResourcePool publication calls this helper.
var maximum_per_kind: int
var kinds: Dictionary={}
var counters:={"remembered":0,"hits":0,"misses":0,"expired":0,"metadata_evictions":0,"forgotten":0,"clears":0}
func _init(capacity: int=2048) -> void:
	maximum_per_kind=clampi(capacity,1,65536)
func remember(kind: String,key: String,value: Resource) -> void:
	if value==null or key.is_empty():return
	if not kinds.has(kind):kinds[kind]={"entries":{},"slots":[],"cursor":0}
	var state: Dictionary=kinds[kind]
	if state.entries.has(key):
		state.entries[key].reference=weakref(value);counters.remembered+=1;return
	var slot: int=state.cursor
	if state.slots.size()<maximum_per_kind:
		slot=state.slots.size();state.slots.append(key)
	else:
		var previous: String=state.slots[slot]
		# A stale ring slot must not remove the same key reinserted elsewhere.
		if state.entries.has(previous) and int(state.entries[previous].slot)==slot:
			state.entries.erase(previous);counters.metadata_evictions+=1
		state.slots[slot]=key
	state.entries[key]={"reference":weakref(value),"slot":slot}
	state.cursor=(slot+1)%maximum_per_kind;counters.remembered+=1
func take(kind: String,key: String) -> Resource:
	if not kinds.has(kind) or not kinds[kind].entries.has(key):counters.misses+=1;return null
	var entries: Dictionary=kinds[kind].entries
	var reference: WeakRef=entries[key].reference;entries.erase(key)
	var value: Variant=reference.get_ref()
	if not value is Resource:counters.expired+=1;counters.misses+=1;return null
	counters.hits+=1;return value
func forget(kind: String,key: String) -> void:
	if kinds.has(kind) and kinds[kind].entries.erase(key):counters.forgotten+=1
func clear() -> void:
	kinds.clear();counters.clears+=1
func snapshot() -> Dictionary:
	var result:=counters.duplicate();var entries: Dictionary={};var slots: Dictionary={}
	for kind in kinds:entries[kind]=kinds[kind].entries.size();slots[kind]=kinds[kind].slots.size()
	result.entries=entries;result.slots=slots;result.maximum_per_kind=maximum_per_kind
	result.scope="Weak directory of evicted exact-content Resource bindings; does not own resources or change primary cache limits"
	return result
