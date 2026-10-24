extends SceneTree
const Catalog = preload("res://systems/native_data/resource_catalog.gd")
const Gff = preload("res://systems/native_data/gff_document.gd")
const Table = preload("res://systems/native_data/two_da.gd")
const Binary = preload("res://systems/native_data/binary_data.gd")
const Model = preload("res://systems/native_data/binary_model.gd")
const Assets = preload("res://systems/native_data/asset_service.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func resource_digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()
func run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2: args[pair[0]] = pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var catalog := Catalog.new(); var start := Time.get_ticks_usec()
	check(catalog.mount_install(fixture.install), "Native-only installed resource registration: " + catalog.failure)
	var index_ms := (Time.get_ticks_usec() - start) / 1000.0
	var observations: Array = []
	for sample in fixture.samples:
		start = Time.get_ticks_usec()
		var bytes: PackedByteArray = catalog.get_resource(sample.name, int(sample.type))
		check(catalog.failure.is_empty() and bytes.size() == int(sample.bytes) and resource_digest(bytes) == sample.sha256, "Original resource bytes/hash agree: " + str(sample.name))
		if sample.has("tableRows"):
			var parser := Table.new(); var table: Dictionary = parser.parse(Binary.new(bytes).text(0, bytes.size()))
			check(parser.failure.is_empty() and table.orderedRows.size() == int(sample.tableRows), "Actual installed visualeffects table parses natively")
		if sample.has("gff"):
			var parser := Gff.new(); var document: Dictionary = parser.parse(bytes, sample.gff.type)
			check(parser.failure.is_empty() and document.root.size() == int(sample.gff.rootFields) and int(document.struct_types[0]) == int(sample.gff.rootType), "Actual installed item blueprint parses natively with struct metadata")
		if sample.has("model"):
			var parser := Model.new(); var model: Dictionary = parser.parse(bytes)
			check(parser.failure.is_empty() and not model.is_empty(), "Original model decodes natively: " + parser.failure)
			if not model.is_empty():
				check(model.name == sample.model.name and model.nodes.size() == sample.model.nodes.size(), "Original physical model node roster agrees")
				for index in mini(model.nodes.size(), sample.model.nodes.size()):
					var actual: Dictionary = model.nodes[index]; var expected: Dictionary = sample.model.nodes[index]
					check(actual.name == expected.name and int(actual.parent) == int(expected.parent), "Physical MDL hierarchy identity: " + str(actual.name))
					var transform := PackedFloat32Array(actual.position + actual.orientation + [actual.scale, actual.alpha] + actual.selfillum)
					check(resource_digest(transform.to_byte_array()) == expected.transformSha256, "Original static transform/controller bits: " + str(actual.name))
					if expected.has("mesh"):
						var mesh: Dictionary = actual.mesh
						for attribute in ["vertices", "normals", "indices", "collision_indices"]:
							check(resource_digest(mesh[attribute].to_byte_array()) == expected.mesh[attribute], "Original geometry bytes " + attribute + ": " + str(actual.name))
						check(mesh.textures == expected.mesh.textures and mesh.render == expected.mesh.render and mesh.shadow == expected.mesh.shadow, "Original texture names and visibility: " + str(actual.name))
						check(mesh.uv.size() == expected.mesh.uv.size(), "Original UV layer count: " + str(actual.name))
						for layer in mini(mesh.uv.size(), expected.mesh.uv.size()): check(resource_digest(mesh.uv[layer].to_byte_array()) == expected.mesh.uv[layer], "Original UV bytes: " + str(actual.name))
			for bad_kind in ["truncated", "node-count", "node-cycle", "node-flags"]:
				var bad := bytes.duplicate()
				match bad_kind:
					"truncated": bad.resize(19)
					"node-count": bad.encode_u32(88, 0)
					"node-cycle":
						var root_at := 12 + bad.decode_u32(84); var child_table := 12 + bad.decode_u32(root_at + 72)
						bad.encode_u32(child_table, bad.decode_u32(84))
					"node-flags": bad.encode_u32(12 + bad.decode_u32(84) + 108, 0x80000000)
				check(parser.parse(bad).is_empty() and not parser.failure.is_empty(), "Invalid in-memory model rejected: " + bad_kind)
		observations.append({"name": sample.name, "type": sample.type, "bytes": bytes.size(), "read_decode_ms": (Time.get_ticks_usec() - start) / 1000.0})
	var service := Assets.new(); root.add_child(service); service.configure(catalog)
	var received: Array = []; service.completed.connect(func(_id, result): received.append(result))
	service.request("c_golstone", 2002, "mdl-binary")
	var deadline := Time.get_ticks_msec() + 10000
	while received.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(received.size() == 1 and received[0].error.is_empty() and received[0].value.name == "c_golstone" and int(received[0].thread) != OS.get_main_thread_id(), "Actual original model parses on a native Godot worker thread")
	service.close(); check(service.running.is_empty() and service.results.is_empty(), "Actual model worker and original payload retire cleanly")
	service.free(); await process_frame
	var source_hashes := {}
	for name in ["binary_data", "archive_index", "resource_catalog", "gff_document", "two_da", "binary_model", "asset_service"]: source_hashes[name + ".gd"] = FileAccess.get_sha256("res://systems/native_data/" + name + ".gd")
	source_hashes["native_install_data_test.gd"] = FileAccess.get_sha256("res://tests/native_install_data_test.gd")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": fixture.scope, "native_only": true, "index_ms": index_ms, "stats": catalog.stats, "resources": observations, "sourceSha256": source_hashes}
	var file := FileAccess.open(args.report, FileAccess.WRITE); file.store_string(JSON.stringify(report, "\t")); file.close()
	quit(0 if failures.is_empty() else 1)
