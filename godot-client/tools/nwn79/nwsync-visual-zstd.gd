extends SceneTree

func _initialize()->void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	var source:=str(args.get("input-dir","")).replace("\\","/")
	var target:=str(args.get("output-dir","")).replace("\\","/")
	if not source.is_absolute_path() or not target.is_absolute_path() or not DirAccess.dir_exists_absolute(source) or DirAccess.dir_exists_absolute(target):quit(2);return
	if DirAccess.make_dir_recursive_absolute(target)!=OK:quit(2);return
	var count:=0
	for name in DirAccess.get_files_at(source):
		if not name.ends_with(".bin") or name.length()!=44 or not name.trim_suffix(".bin").is_valid_hex_number(false):quit(2);return
		var bytes:=FileAccess.get_file_as_bytes(source.path_join(name))
		if bytes.is_empty():quit(2);return
		var compressed:=bytes.compress(FileAccess.COMPRESSION_ZSTD)
		if compressed.is_empty():quit(2);return
		var file:=FileAccess.open(target.path_join(name),FileAccess.WRITE)
		if file==null:quit(2);return
		file.store_buffer(compressed);file.close();count+=1
	print("NWN79_ZSTD_COMPRESSED ",count)
	quit(0 if count>0 else 2)
