extends SceneTree
# Build a private reproducible sibling PCK, preserving each pinned source byte.
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	var specification: Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not specification is Dictionary:quit(2);return
	var packer:=PCKPacker.new();var error:=packer.pck_start(specification.output)
	if error==OK:
		for row in specification.files:
			error=packer.add_file("res://"+str(row.relative),str(row.file))
			if error!=OK:break
	if error==OK:error=packer.flush()
	print("PERF140_PACK "+JSON.stringify({"error":error,"files":specification.files.size()}))
	quit(0 if error==OK else 1)
