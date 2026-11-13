extends "res://tests/native_render_gap_hot_parameters_test.gd"

class Reader extends RefCounted:
	func sample(owner: RefCounted, count: int) -> Dictionary:
		var failures: Array[String] = []
		for iteration in count:
			var sampled: Dictionary = owner.call("dispatch", 4, {"clip": "missing", "time": NAN}, {})
			if sampled.has("error") or sampled.get("sentinel", -1) != 17:
				failures.append("worker value/error changed")
				break
		return {"success": failures.is_empty(), "failures": failures, "count": count}

func concurrent_empty(scene: Node3D, skip: bool) -> void:
	var seed: Dictionary = make_owner(false, "fountain", 0, false, false)
	var owner: RefCounted = ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch", 0, {"state": seed.state, "parameters": {"sentinel": 17}, "clips": {"empty": {"channels": []}}, "update": "fountain", "compactRecords": true, "typedEmitter": true, "poseId": scene.get_instance_id(), "sourceId": scene.get_instance_id(), "skipEmptyClipLookups": skip}, {}).has("error"), "Shared empty owner configures before worker publication")
	var before: Dictionary = owner.call("dispatch", 10, {}, {})
	check(int(before.sample_calls) == 0 and before.map_sealed, "Worker starts from sealed, immutable copied map and zero counters")
	var threads: Array[Thread] = []
	var readers: Array[RefCounted] = []
	const WORKERS: int = 4
	const ITERATIONS: int = 2000
	for index in WORKERS:
		var reader: RefCounted = Reader.new()
		var thread := Thread.new()
		readers.append(reader)
		threads.append(thread)
		check(thread.start(Callable(reader, "sample").bind(owner, ITERATIONS)) == OK, "Independent worker starts")
	for thread: Thread in threads:
		var result: Variant = thread.wait_to_finish()
		check(result is Dictionary and result.success and result.count == ITERATIONS, "Concurrent same-owner empty reads preserve values and errors")
	var after: Dictionary = owner.call("dispatch", 10, {}, {})
	check(after.configured and after.map_sealed and not after.has_any_channels, "Workers leave the immutable map/configuration unchanged")
	check(int(after.sample_calls) == WORKERS * ITERATIONS, "Relaxed atomic sample counter accounts for every concurrent caller")
	check(int(after.lookup_skips) == (WORKERS * ITERATIONS if skip else 0), "Optimized counter accounts for exact concurrent skipped lookups")
	check(int(after.lookup_calls) == (0 if skip else WORKERS * ITERATIONS), "Legacy counter accounts for exact concurrent lookups")
	check(int(after.preconfigure_sample_calls) == 0, "No worker observes preconfiguration")
	seed.providers.clear()
	owner = null
	readers.clear()
	threads.clear()

func run() -> void:
	var report_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.substr(9)
	if report_path.is_empty() or FileAccess.file_exists(report_path):
		quit(2)
		return
	var scene := Node3D.new()
	root.add_child(scene)
	concurrent_empty(scene, false)
	concurrent_empty(scene, true)
	scene.free()
	await process_frame
	await process_frame
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"success": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Same actual native Owner, four independent workers, legacy and optimized all-empty sampling: immutable values and exact relaxed atomic diagnostics. No ThreadSanitizer or unsupported configure/frame concurrency claim."}, "\t"))
	file.close()
	quit(0 if failures.is_empty() else 1)
