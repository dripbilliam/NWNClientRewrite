extends SceneTree
const Catalog = preload("res://systems/native_data/resource_catalog.gd")
const Archive = preload("res://systems/native_data/archive_index.gd")
const Gff = preload("res://systems/native_data/gff_document.gd")
const Table = preload("res://systems/native_data/two_da.gd")
const Assets = preload("res://systems/native_data/asset_service.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()
func equal_values(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equal_values(a[key], b[key]): return false
		return true
	if (a is Array or a is PackedByteArray) and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not equal_values(a[index], b[index]): return false
		return true
	if a is Dictionary or b is Dictionary or a is Array or b is Array or a is PackedByteArray: return false
	return a == b
func run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2: args[pair[0]] = pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var folder: String = fixture.root
	for key in ["base.key", "retail.key"]:
		var catalog := Catalog.new()
		check(catalog.mount_key(folder.path_join(key), folder), "Native KEY mount: " + key)
		check(catalog.bifs.is_empty() and catalog.stats.payload_bytes == 0, "KEY catalog does not read BIF payloads")
		for entry in fixture.entries:
			check(catalog.has_resource(str(entry.name).to_upper(), int(entry.type)), "Case-insensitive native catalog presence")
			var bytes: PackedByteArray = catalog.get_resource(entry.name, int(entry.type))
			check(catalog.failure.is_empty() and digest(bytes) == entry.sha256 and bytes.size() == int(entry.bytes), "Native file-backed BIF bytes match source oracle: " + str(entry.name))
		check(catalog.stats.payload_bytes < 10000 and catalog.stats.index_bytes < 10000, "Unused one-MiB resource is never loaded")
		check(catalog.mount_erf(folder.path_join("override.hak"), 100), "Native override archive mount")
		check(catalog.get_resource("SHARED", 2017).get_string_from_ascii() == "override", "Explicit archive priority overrides KEY")
		catalog.get_resource("missing", 2002); check(not catalog.failure.is_empty(), "Missing resource returns a distinct failure")
		catalog.reset(); check(catalog.layers.is_empty() and catalog.bifs.is_empty() and catalog.stats.reads == 0, "Session retirement clears native catalogs")
	for name in ["override.hak", "long.hak", "legacy11.hak"]:
		var reader := Archive.new(); var archive: Dictionary = reader.erf(folder.path_join(name))
		check(reader.failure.is_empty() and archive.entries.size() == 2, "Native ERF key-stride handling: " + name)
		check(reader.payload(archive, archive.entries["shared:2017"]).get_string_from_ascii() == "override", "Native lazy ERF payload: " + name)
	for row in fixture.corrupt:
		var reader := Archive.new(); var result: Dictionary = reader.call(row.kind, folder.path_join(row.path))
		check(result.is_empty() and not reader.failure.is_empty(), "Corrupt/traversal archive rejected: " + str(row.path))
	var changed_path := folder.path_join("changed.hak")
	var changed_file := FileAccess.open(changed_path, FileAccess.WRITE); changed_file.store_buffer(FileAccess.get_file_as_bytes(folder.path_join("override.hak"))); changed_file.close()
	var changed_reader := Archive.new(); var changed_index: Dictionary = changed_reader.erf(changed_path)
	changed_file = FileAccess.open(changed_path, FileAccess.READ_WRITE); changed_file.seek_end(); changed_file.store_8(1); changed_file.close()
	changed_reader.payload(changed_index, changed_index.entries["shared:2017"])
	check(not changed_reader.failure.is_empty(), "A changed archive cannot supply bytes through a stale index")
	DirAccess.remove_absolute(changed_path)
	var type_path := folder.path_join("wrong-type.bif"); var wrong_bytes := FileAccess.get_file_as_bytes(folder.path_join("data/base.bif"))
	wrong_bytes.encode_u32(32, 4)
	var type_file := FileAccess.open(type_path, FileAccess.WRITE); type_file.store_buffer(wrong_bytes); type_file.close()
	var mismatch := Catalog.new(); mismatch.mount_key(folder.path_join("base.key"), folder)
	mismatch.layers[0].entries = mismatch.layers[0].entries.duplicate(true)
	mismatch.layers[0].entries["shared:2017"].bif = "wrong-type.bif"
	mismatch.get_resource("shared", 2017)
	check(not mismatch.failure.is_empty(), "A KEY/BIF type mismatch fails without substituting lower-priority bytes")
	DirAccess.remove_absolute(type_path)
	var gff := Gff.new(); var document: Dictionary = gff.parse(FileAccess.get_file_as_bytes(folder.path_join("area.are")), "ARE ")
	check(gff.failure.is_empty() and document.struct_types[0] == 99, "Native GFF retains struct identity")
	if not document.is_empty():
		var actual: Dictionary = document.root.duplicate(true); actual.I64 = str(actual.I64)
		for key in fixture.expectedGff:
			check(equal_values(actual.get(key), fixture.expectedGff[key]), "GFF field agrees with source parser: " + str(key))
		check(equal_values(document.field_types[0], fixture.gffTypes), "Native GFF field metadata remains separate from gameplay fields")
	for name in fixture.badGffs:
		check(gff.parse(FileAccess.get_file_as_bytes(folder.path_join(name)), "ARE ").is_empty() and not gff.failure.is_empty(), "Malformed GFF bounds rejected: " + str(name))
	var table := Table.new(); var parsed: Dictionary = table.parse(fixture.table)
	check(table.failure.is_empty(), "Native 2DA parser accepts authored defaults/quotes")
	check(equal_values(parsed.columns, fixture.expectedTable.columns) and equal_values(parsed.orderedCells, fixture.expectedTable.orderedCells) and parsed.defaultValue == fixture.expectedTable.defaultValue, "2DA physical cells/defaults/duplicate columns match JS source oracle")
	check(parsed.orderedRows.size() == 3 and parsed.rows[9].Name == "replacement" and parsed.orderedRows[0].Name == 'quoted "name"', "Physical row order stays distinct from repeated printed row labels")
	check(table.parse("broken").is_empty() and not table.failure.is_empty(), "Invalid 2DA signature rejected")
	var worker_catalog := Catalog.new(); worker_catalog.mount_key(folder.path_join("base.key"), folder)
	var service := Assets.new(); root.add_child(service); service.configure(worker_catalog)
	var received: Dictionary = {}; service.completed.connect(func(id, result): received[id] = result)
	var queued: Array = []
	for index in 12: queued.append(service.request("auth_area", 2012, "gff"))
	var deadline := Time.get_ticks_msec() + 10000
	while received.size() < queued.size() and Time.get_ticks_msec() < deadline: await process_frame
	check(received.size() == 12 and service.running.is_empty(), "Twelve real native worker reads/decodes finish within the bounded pool")
	check(worker_catalog.bif_index_build_count()==1,"Concurrent native jobs publish one shared BIF index instead of rebuilding it for every resource")
	check(received.values().all(func(row): return row.error.is_empty() and int(row.thread) != OS.get_main_thread_id() and row.value.root.Byte == 255), "GFF bytes are decoded on native worker threads, not the presentation thread")
	var delivered := received.size()
	for index in 12: service.request("shared", 2017, "2da")
	service.retire_scope()
	deadline = Time.get_ticks_msec() + 10000
	while not service.running.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(received.size() == delivered and service.pending.is_empty() and service.results.is_empty(), "Area retirement discards pending and completed old-scope results")
	service.request("shared", 2017, "2da")
	deadline = Time.get_ticks_msec() + 10000
	while received.size() == delivered and Time.get_ticks_msec() < deadline: await process_frame
	check(received.size() == delivered + 1 and received.values().back().value.orderedRows.size() == 3, "A new native scope loads tables after retirement")
	service.close(); check(service.running.is_empty() and service.results.is_empty() and service.catalog == null, "Native service shutdown drains actual worker task handles")
	service.free(); await process_frame
	var source_hashes := {}
	for name in ["binary_data", "archive_index", "resource_catalog", "gff_document", "two_da", "asset_service", "binary_model"]: source_hashes[name + ".gd"] = FileAccess.get_sha256("res://systems/native_data/" + name + ".gd")
	source_hashes["native_data_test.gd"] = FileAccess.get_sha256("res://tests/native_data_test.gd")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": fixture.scope, "native_only": true, "renderer": DisplayServer.get_name(), "sourceSha256": source_hashes}
	var file := FileAccess.open(args.report, FileAccess.WRITE); file.store_string(JSON.stringify(report, "\t")); file.close()
	quit(0 if failures.is_empty() else 1)
