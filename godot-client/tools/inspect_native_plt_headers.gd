extends SceneTree
# Read-only original resource metadata; no pixel/art export, GPU or game login.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""; var failures: Array=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
		if arg.begins_with("--install="): install=arg.trim_prefix("--install=")
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var rows: Array=[]; var attributes: Dictionary={}; var compression: Dictionary={}; var checks:=1
	if not catalog.mount_install(install): failures.append(catalog.failure)
	var names: Array=catalog.resource_names(6); names.sort()
	for name in names:
		var raw: PackedByteArray=catalog.read_resource(name,6); checks+=1
		if not catalog.failure.is_empty(): failures.append(str(name)+": "+catalog.failure); continue
		if raw.size()<24 or raw.slice(0,8).get_string_from_ascii()!="PLT V1  ": failures.append(str(name)+": header"); continue
		var attribute:=raw.decode_u32(8); var packed:=raw.decode_u32(12); var width:=raw.decode_u32(16); var height:=raw.decode_u32(20)
		attributes[str(attribute)]=int(attributes.get(str(attribute),0))+1; compression[str(packed)]=int(compression.get(str(packed),0))+1
		if attribute<1 or attribute>10 or packed!=0:
			var used: Dictionary={}
			if packed==0 and width>0 and height>0 and width*height<=16777216 and raw.size()>=24+width*height*2:
				for pixel in width*height:
					var layer:=str(raw[25+pixel*2]); used[layer]=int(used.get(layer,0))+1
			rows.append({"name":name,"sha256":Cache.digest(raw),"bytes":raw.size(),"attribute":attribute,"compression":packed,"width":width,"height":height,"header_hex":raw.slice(0,24).hex_encode(),"uncompressed_size":24+width*height*2,"pixel_layers":used})
		if checks%128==0: await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"resources":names.size(),"attributes":attributes,"compression":compression,"samples_outside_current_parser":rows,"scope":"Read-only installed PLT header inventory. Success means metadata scan completed, not parser/render parity. No original pixels exported."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
