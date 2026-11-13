extends SceneTree
const Gff=preload("res://systems/native_data/gff_document.gd")
const BicVisual=preload("res://systems/native_data/bic_visual.gd")
func _initialize()->void: call_deferred("run")
func run()->void:
	var install:=""; var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		elif arg.begins_with("--report="): output=arg.substr(9)
	if install.is_empty() or output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var rows: Array=[]
	for folder in ["data/lcv","data/dmv"]:
		var base:=install.path_join(folder)
		for name in DirAccess.get_files_at(base):
			if not name.to_lower().ends_with(".bic"): continue
			var path:=base.path_join(name); var bytes:=FileAccess.get_file_as_bytes(path)
			var parser:=Gff.new(); var document:=parser.parse(bytes,"BIC ")
			var visual:=BicVisual.source(document)
			var slots: Array=[]; var cloak: Dictionary={}
			for entry in visual.get("equipment",[]):
				slots.append(int(entry.slot))
				if int(entry.slot)==64: cloak=entry.item
			rows.append({"file":folder+"/"+name,"sha256":FileAccess.get_sha256(path),"slots":slots,"cloak":cloak,"error":parser.failure if not parser.failure.is_empty() else visual.get("error","")})
	var outf:=FileAccess.open(output,FileAccess.WRITE); outf.store_string(JSON.stringify({"files":rows.size(),"cloaked":rows.filter(func(row): return not row.cloak.is_empty()),"errors":rows.filter(func(row): return not row.error.is_empty()),"scope":"Installed original BIC roster slot-64 census only; no model rendering or native-client parity."},"  ")); outf.close()
	print(JSON.stringify({"files":rows.size(),"cloaked":rows.filter(func(row): return not row.cloak.is_empty()).size(),"report":output}))
	quit(0)
