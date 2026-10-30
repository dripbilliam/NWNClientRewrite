extends SceneTree
# Original catalog metadata only; never reads a user's keymapping profile.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const TwoDA=preload("res://systems/native_data/two_da.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var text:=Talk.new(); var failures: Array=[]; var table: Dictionary={}; var rows: Array=[]; var captions: Dictionary={}; var digest:=""
	if not catalog.mount_install(install): failures.append(catalog.failure)
	if not text.base.open_file(install.path_join("lang/en/data/dialog.tlk")): failures.append(text.base.failure)
	if failures.is_empty():
		var bytes: PackedByteArray=catalog.get_resource("keymap",2017); digest=Cache.digest(bytes); var parser:=TwoDA.new(); table=parser.parse(Binary.new(bytes).text(0,bytes.size()))
		if not parser.failure.is_empty(): failures.append(parser.failure)
		else:
			for index in table.rowLabels.size():
				var row: Dictionary=table.orderedRows[index].duplicate(); row.row_name=table.rowLabels[index]
				if str(row.get("ActionStrRef","")).is_valid_int(): row.caption=text.raw({"strRef":int(row.ActionStrRef)})
				rows.append(row)
		for ref in range(0x2979,0x29bc): captions[str(ref)]=text.raw({"strRef":ref})
		for ref in [10408,10409,10410,10411,0xceb7,0xceb5]: captions[str(ref)]=text.raw({"strRef":ref})
	text.base.close(); var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":1,"failures":failures,"sha256":digest,"columns":table.get("columns",[]),"rows":rows,"captions":captions,"publicConnections":0,"scope":"Read-only installed Keymap.2DA and requested original TLK captions. No profile, key capture, live input or complete UI parity accepted."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
