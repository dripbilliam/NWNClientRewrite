extends RefCounted
# B2 experiment only: a bounded name -> current-pool-key directory, not another
# bundle/template store. Every hit must still exist in the authoritative pool.
# Unsupported catalog invalidation contracts always take the ordinary job path.
var maximum_entries := 512
var maximum_metadata_bytes := 1024*1024
var metadata_bytes := 0
var entries: Dictionary = {}
var order: Array = []
var scope: Dictionary = {}
var accepting := false
var stats := {"hits":0,"misses":0,"stores":0,"pool_misses":0,"scope_invalidations":0,"unsupported_scopes":0,"metadata_evictions":0,"metadata_oversize":0}

func _property(owner: Object, name: String) -> bool:
	if not is_instance_valid(owner): return false
	for property in owner.get_property_list():
		if str(property.name) == name: return true
	return false

func _generation(store) -> int:
	if not is_instance_valid(store) or not store.has_method("generation"): return -1
	var value: Variant = store.generation()
	return value if value is int and value >= 0 else -1

func _policy(pool) -> Array:
	return [pool.unshaded,pool.texture_filter,pool.picking,pool.compact_static_parts,
		pool.native_lighting,pool.native_standard,pool.native_surface_output]

func _capture(service, pool, target_area: int) -> Dictionary:
	if target_area < 0 or not is_instance_valid(service) or service.closed or not is_instance_valid(pool): return {}
	var catalog = service.catalog
	if not is_instance_valid(catalog) or not catalog.has_method("preparation_cache"): return {}
	var explicit_scope: bool=catalog.has_method("cache_source_scope_v1")
	if not explicit_scope and not _property(catalog,"source_store"):return {}
	var prepared = catalog.preparation_cache()
	var source = catalog.cache_source_scope_v1() if explicit_scope else catalog.get("source_store")
	var prepared_generation := _generation(prepared)
	var source_generation := 0 if explicit_scope and source is RefCounted else _generation(source)
	var decoded = catalog.decoded_cache() if explicit_scope and catalog.has_method("decoded_cache") else null
	var decoded_generation := _generation(decoded) if explicit_scope else 0
	if prepared_generation < 0 or source_generation < 0 or decoded_generation < 0: return {}
	return {"service":service,"service_epoch":service.epoch,"catalog":catalog,"catalog_script":catalog.get_script(),
		"prepared":prepared,"prepared_generation":prepared_generation,
		"source":source,"source_generation":source_generation,"explicit_scope":explicit_scope,"decoded":decoded,"decoded_generation":decoded_generation,"pool":pool,
		"area":target_area,"cache_directory":str(service.cache_directory),
		"mesh_preparation":service.mesh_preparation_enabled,"skin_preparation":service.skin_preparation_enabled,
		"policy":_policy(pool),"decoder":"static-model","options":{}}

func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty(): return false
	for key in a:
		if not b.has(key) or a[key] != b[key]: return false
	return a.size() == b.size()

func begin_wave(service, pool, target_area: int) -> bool:
	var current := _capture(service,pool,target_area)
	if current.is_empty():
		stats.unsupported_scopes += 1
		clear()
		return false
	if not scope.is_empty() and not _same(scope,current):
		entries.clear(); order.clear(); metadata_bytes = 0; stats.scope_invalidations += 1
	scope = current
	accepting = true
	return true

func _source_current(catalog) -> bool:
	if scope.explicit_scope:
		return catalog.cache_source_scope_v1()==scope.source and catalog.decoded_cache()==scope.decoded and _generation(scope.decoded)==scope.decoded_generation
	return catalog.get("source_store")==scope.source and _generation(scope.source)==scope.source_generation

func _valid() -> bool:
	if not accepting or scope.is_empty(): return false
	var service = scope.service
	var catalog = scope.catalog
	var pool = scope.pool
	# Reflection is a once-per-wave capability check; this hot check compares
	# the already-verified provider/script plus exact generation and policy.
	var valid: bool = is_instance_valid(service) and not service.closed and service.epoch == scope.service_epoch and service.catalog == catalog and is_instance_valid(catalog) and catalog.get_script() == scope.catalog_script and is_instance_valid(pool)
	if valid:
		valid = catalog.preparation_cache() == scope.prepared and _generation(scope.prepared) == scope.prepared_generation and _source_current(catalog) and str(service.cache_directory) == scope.cache_directory and service.mesh_preparation_enabled == scope.mesh_preparation and service.skin_preparation_enabled == scope.skin_preparation and _policy(pool) == scope.policy
	if not valid:
		entries.clear(); order.clear(); metadata_bytes = 0; accepting = false; stats.scope_invalidations += 1
	return valid

func still_bound(name: String, expected) -> bool:
	if not _valid() or not entries.has(name) or not is_instance_valid(expected): return false
	var key: String = entries[name].key
	return scope.pool.templates.has(key) and scope.pool.templates[key] == expected

func lookup(name: String) -> Dictionary:
	if not _valid() or not entries.has(name):
		stats.misses += 1
		return {}
	var row: Dictionary = entries[name]
	var pool = scope.pool
	if not pool.templates.has(row.key) or not is_instance_valid(pool.templates[row.key]):
		metadata_bytes -= int(entries[name].bytes); entries.erase(name); order.erase(name); stats.pool_misses += 1; stats.misses += 1
		return {}
	order.erase(name); order.append(name); stats.hits += 1
	# Preserve the authoritative ResourcePool hit and recent-use bookkeeping.
	pool.stats.template_hits += 1; pool.template_order.erase(row.key); pool.template_order.append(row.key)
	# A transient strong handle is returned for this active wave only; the
	# directory never owns a template, original bundle, placement or object row.
	return {"template":pool.templates[row.key],"warnings":row.warnings.duplicate(true)}

func remember(name: String, key: String, warnings: Array) -> bool:
	if not _valid() or key.is_empty() or maximum_entries <= 0 or maximum_metadata_bytes <= 0 or not scope.pool.templates.has(key): return false
	# Account this separate small directory once on an ordinary model miss;
	# never serialize a complete bundle, scene, catalog or attempted hit.
	var cost: int = name.to_utf8_buffer().size()+key.to_utf8_buffer().size()+var_to_bytes(warnings).size()+512
	if cost > maximum_metadata_bytes: stats.metadata_oversize += 1; return false
	if entries.has(name): metadata_bytes -= int(entries[name].bytes); entries.erase(name); order.erase(name)
	while not order.is_empty() and (entries.size() >= maximum_entries or metadata_bytes+cost > maximum_metadata_bytes):
		var oldest: String = order.pop_front(); metadata_bytes -= int(entries[oldest].bytes); entries.erase(oldest); stats.metadata_evictions += 1
	entries[name] = {"key":key,"warnings":warnings.duplicate(true),"bytes":cost}; metadata_bytes += cost
	order.erase(name); order.append(name); stats.stores += 1
	return true

func snapshot() -> Dictionary:
	var result := stats.duplicate()
	result.entries = entries.size(); result.accepting = accepting; result.maximum_entries = maximum_entries
	result.metadata_bytes = metadata_bytes; result.maximum_metadata_bytes = maximum_metadata_bytes
	return result

func clear() -> void:
	entries.clear(); order.clear(); scope.clear(); metadata_bytes = 0; accepting = false
