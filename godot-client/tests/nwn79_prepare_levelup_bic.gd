extends SceneTree
const Patch=preload("res://systems/native_data/gff_root_patch.gd")
const Document=preload("res://systems/native_data/gff_document.gd")

func _initialize()->void:
	var args: Dictionary={}
	for entry in OS.get_cmdline_user_args():
		if entry.begins_with("--") and entry.contains("="):
			var at:=entry.find("=");args[entry.substr(2,at-2)]=entry.substr(at+1)
	var source:=str(args.get("source",""));var output:=str(args.get("output",""))
	if not source.is_absolute_path() or not output.is_absolute_path() or not output.to_lower().ends_with(".bic") or not FileAccess.file_exists(source):fail("Private level-up BIC paths unavailable");return
	var original:=FileAccess.get_file_as_bytes(source);var parsed:=Document.new().parse(original,"BIC ")
	if parsed.is_empty() or int(parsed.root.get("Experience",-1))!=105000 or parsed.root.get("ClassList",[]).size()!=1 or int(parsed.root.ClassList[0].get("ClassLevel",-1))!=15:fail("Installed fighter source is not the expected level-15 fixture");return
	var patch=Patch.new();var derived: PackedByteArray=patch.apply(original,{"Experience":{"type":4,"value":120000}})
	if derived.is_empty():fail("Godot byte-preserving XP patch failed: "+patch.failure);return
	var after:=Document.new().parse(derived,"BIC ")
	if after.is_empty() or int(after.root.get("Experience",-1))!=120000 or after.root.ClassList!=parsed.root.ClassList:fail("Derived BIC did not preserve class and threshold");return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:fail("Private derived BIC could not be opened");return
	file.store_buffer(derived);file.flush();file.close()
	print("NWN79 private Godot level-up BIC PASS: detached level-15 fighter at next XP threshold; bytes="+str(derived.size()))
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 private Godot level-up BIC failed: "+reason)
	quit(1)
