extends RefCounted

# Optional DenseSync join receipt. Driven by existing events on the publishing
# thread. No resource probes or scheduler scans are needed to collect it.
static var enabled := false
static var _started := 0
static var _area_id := 0
static var _pool: WeakRef
static var _owners: Dictionary = {}
static var _built: Dictionary = {}
static var _types: Dictionary = {}
static var _buckets: Dictionary = {}
static var _model_jobs: Dictionary = {}
static var _blocked: Dictionary = {}
static var _frame_denials: Dictionary = {}
static var _budget: Dictionary = {}
static var _control_ms: Variant

static func start(started: int) -> void:
	enabled = true
	_started = started
	_area_id = 0
	_pool = null
	_owners = {}
	_built = {}
	_types = {}
	_buckets = {}
	_model_jobs = {}
	_blocked = {}
	_frame_denials = {}
	_budget = {"observedFrames":0, "usedFrames":0, "usedMs":0.0, "maxUsedMs":0.0, "completionMs":0.0,
		"publicationUnits":0, "constructionSteps":0, "completionUnits":0, "denials":{}, "deniedFrames":{}}
	_control_ms = null

static func bind_area(area: Node, pool: RefCounted) -> void:
	var area_id := area.get_instance_id()
	if _area_id == 0:
		_area_id = area_id
	if _area_id == area_id:
		_pool = weakref(pool)

static func owns_pool(pool: RefCounted) -> bool:
	return _pool != null and _pool.get_ref() == pool

static func owns_area(area: Node) -> bool:
	return is_instance_valid(area) and area.get_instance_id() == _area_id

static func increment(counts: Dictionary, key: String, amount: int = 1) -> void:
	counts[key] = int(counts.get(key, 0)) + amount

static func _counter(type: String, event: String, now: int) -> Dictionary:
	var stats: Dictionary = _types.get_or_add(type, {})
	increment(stats, event)
	var bucket := floori(float(now - _started) / 1000000.0)
	var frame: Dictionary = _buckets.get_or_add(bucket, {"elapsedMs":bucket * 1000})
	var counts: Dictionary = frame.get_or_add(event, {})
	increment(counts, type)
	return stats

static func _duration(stats: Dictionary, label: String, start: int, end: int) -> void:
	if start <= 0:
		return
	var duration := float(end - start) / 1000.0
	var summary: Dictionary = stats.get_or_add(label, {"samples":0, "totalMs":0.0, "maxMs":0.0})
	summary.samples += 1
	summary.totalMs += duration
	summary.maxMs = maxf(float(summary.maxMs), duration)

static func wave(pool: RefCounted, owner: int, kind: String, objects: Array) -> void:
	if not owns_pool(pool):
		return
	var now := Time.get_ticks_usec()
	var rows: Dictionary = _owners.get_or_add(owner, {})
	var waved_types: Dictionary = {}
	for object in objects:
		if not object is Dictionary or not object.has("id"):
			continue
		var type := str(object.get("objectType", 0))
		rows[int(object.id)] = {"type":type, "requested":now}
		_counter(type, "requested", now)
		waved_types[type] = true
	for type in waved_types:
		_counter(type, kind + "Waves", now)

static func stage(owner: int, id: int, event: String, instance: Node = null) -> void:
	if not _owners.has(owner):
		return
	var row: Dictionary = _owners[owner].get(id, {})
	if row.is_empty() or row.has(event):
		return
	var now := Time.get_ticks_usec()
	row[event] = now
	var stats := _counter(row.type, event, now)
	match event:
		"assetsReady":_duration(stats, "requestToAssetsReady", row.requested, now)
		"eligible":_duration(stats, "assetsReadyToEligible", int(row.get("assetsReady", 0)), now)
		"built":
			_duration(stats, "eligibleToBuilt", int(row.get("eligible", 0)), now)
			_built[instance.get_instance_id()] = row

static func published(source: Dictionary, instance: Node) -> void:
	var now := Time.get_ticks_usec()
	var row: Dictionary = _built.get(instance.get_instance_id(), {})
	var stats := _counter(str(source.get("objectType", 0)), "published", now)
	if row.is_empty():
		increment(stats, "publishedWithoutBuildWitness")
		return
	_built.erase(instance.get_instance_id())
	_duration(stats, "builtToPublished", row.built, now)
	_duration(stats, "requestToPublished", row.requested, now)

static func model_job(pool: RefCounted, owner_kind: String, result: Dictionary) -> void:
	if not owns_pool(pool):
		return
	var jobs: Dictionary = _model_jobs.get_or_add(owner_kind, {"results":0, "failed":0, "memoryHits":0,
		"workerMs":0.0, "readMs":0.0, "queueSamples":0, "queuedMs":0.0})
	jobs.results += 1
	jobs.failed += int(not str(result.get("error", "")).is_empty())
	jobs.memoryHits += int(result.get("memory_cache_hit", false))
	jobs.workerMs += float(result.get("worker_ms", 0.0))
	jobs.readMs += float(result.get("read_ms", 0.0))
	var requested := float(result.get("requested_ms", 0.0))
	var started := float(result.get("started_ms", 0.0))
	if requested > 0.0 and started >= requested:
		jobs.queueSamples += 1
		jobs.queuedMs += started - requested

static func blocked(owner: int, reason: String) -> void:
	if _owners.has(owner):
		increment(_blocked, reason)

static func pool_denied(reason: String) -> void:
	increment(_budget.denials, reason)
	_frame_denials[reason] = true

static func pool_frame(used: int, completed: int, publishes: int, steps: int, completions: int) -> void:
	_budget.observedFrames += 1
	_budget.usedFrames += int(used > 0 or publishes > 0 or steps > 0 or completions > 0)
	_budget.usedMs += used / 1000.0
	_budget.maxUsedMs = maxf(float(_budget.maxUsedMs), used / 1000.0)
	_budget.completionMs += completed / 1000.0
	_budget.publicationUnits += publishes
	_budget.constructionSteps += steps
	_budget.completionUnits += completions
	for reason in _frame_denials:
		increment(_budget.deniedFrames, reason)
	_frame_denials.clear()

static func controllable() -> void:
	_control_ms = (Time.get_ticks_usec() - _started) / 1000.0

static func stop(reason: String) -> Dictionary:
	var pool: Variant = _pool.get_ref() if _pool != null else null
	if pool != null and pool.publication_frame >= 0:
		pool_frame(pool.publication_us, pool.completion_us, pool.publications, pool.construction_steps, pool.completion_units)
	enabled = false
	_owners.clear()
	_built.clear()
	return {"reason":reason, "controllableMs":_control_ms, "stopMs":(Time.get_ticks_usec() - _started) / 1000.0,
		"byObjectType":_types, "oneSecondWaves":_buckets.values(), "directModelJobs":_model_jobs, "ownerBlocks":_blocked,
		"poolBudget":_budget, "scope":"Assets ready is first observed by the owner. Asset-to-eligible includes prerequisites and waiting for a queue turn. Install is cooperative. Direct model jobs exclude shared-prefetch delivery. Worker totals may overlap."}
