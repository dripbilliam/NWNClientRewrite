extends SceneTree

const Catalog = preload("res://systems/native_data/resource_catalog.gd")
const Table = preload("res://systems/native_data/two_da.gd")
const Binary = preload("res://systems/native_data/binary_data.gd")

func _initialize() -> void:
	call_deferred("run")

func hash_bytes(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func run() -> void:
	var install := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install = arg.substr(10)
		elif arg.begins_with("--report="): output = arg.substr(9)
	if install.is_empty() or output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	var catalog := Catalog.new()
	if not catalog.mount_install(install):
		quit(3)
		return
	var bytes: PackedByteArray = catalog.get_resource("cloakmodel", 2017)
	var parser := Table.new()
	var table: Dictionary = parser.parse(Binary.new(bytes).text(0, bytes.size()))
	var rows: Array = table.get("orderedRows", [])
	var split_rows: Array = []
	for index in rows.size():
		var row: Dictionary = rows[index]
		var model := str(row.get("MODEL", ""))
		var texture := str(row.get("TEXTURE", ""))
		if model.is_valid_int() and texture.is_valid_int() and int(model) > 0 and int(texture) > 0 and model != texture:
			var model_key := "pfh0_cloak_" + str(int(model)).pad_zeros(3)
			var texture_key := "cloak_" + str(int(texture)).pad_zeros(3)
			split_rows.append({"index": index, "row": row, "model_key": model_key, "texture_key": texture_key,
				"monk_model_present": catalog.has_resource(model_key, 2002), "plt_present": catalog.has_resource(texture_key, 6)})
	var result := {"success": parser.failure.is_empty(), "source_sha256": FileAccess.get_sha256("res://systems/native_data/creature_appearance.gd"),
		"cloakmodel_sha256": hash_bytes(bytes), "row_count": rows.size(),
		"great_cloak_row": rows[3] if rows.size() > 3 else {}, "split_rows": split_rows}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print(JSON.stringify({"success": result.success, "row_count": rows.size(), "split_count": split_rows.size(), "report": output}))
	quit(0 if result.success else 1)
