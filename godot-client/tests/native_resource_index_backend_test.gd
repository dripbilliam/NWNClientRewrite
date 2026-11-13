extends SceneTree
const Archive=preload("res://systems/native_data/archive_index.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Sync=preload("res://systems/native_data/nwsync_store.gd")
const Backend=preload("res://systems/native_data/resource_index_backend.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func write_name(bytes: PackedByteArray,at: int,value: PackedByteArray) -> void:
	for index in value.size(): bytes[at+index]=value[index]
func archive_result(kind: String,table: PackedByteArray,other: PackedByteArray,stride: int,mode: String) -> Dictionary:
	OS.set_environment("NWN_RESOURCE_INDEX",mode); var reader:=Archive.new(); reader.opened_size=1024
	var value: Dictionary
	if kind=="erf": value=reader.erf_entries("res://project.godot","V1.1" if stride==40 else "V1.0",table.size()/stride,stride,stride-8,Binary.new(table),Binary.new(other))
	elif kind=="key": value=reader.key_entries("V1.1" if stride==26 else "V1  ",table.size()/stride,stride,["data/a.bif","data/b.bif"],Binary.new(table))
	else: value=reader.bif_entries("res://project.godot","V1.1" if stride==20 else "V1  ",table.size()/stride,stride,Binary.new(table))
	return {"value":value,"error":reader.failure}
func compare_archive(kind: String,table: PackedByteArray,other: PackedByteArray,stride: int,label: String) -> void:
	var expected:=archive_result(kind,table,other,stride,"gd"); var actual:=archive_result(kind,table,other,stride,"compiled")
	check(expected==actual,label)
func compare_manifest(bytes: PackedByteArray,installed: bool,label: String) -> void:
	OS.set_environment("NWN_RESOURCE_INDEX","gd"); var expected:=Sync.decode_installed_manifest(bytes) if installed else Sync.decode_verified_manifest(bytes)
	OS.set_environment("NWN_RESOURCE_INDEX","compiled"); var actual:=Sync.decode_installed_manifest(bytes) if installed else Sync.decode_verified_manifest(bytes)
	check(expected.has("error")==actual.has("error") and (expected.has("error") or expected==actual),label)
func run() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var saved:=OS.get_environment("NWN_RESOURCE_INDEX"); OS.set_environment("NWN_RESOURCE_INDEX","compiled")
	check(Backend.available(),"Separate compiled metadata extension is actually loaded")
	for stride in [24,40]:
		var table:=PackedByteArray(); table.resize(3*stride); var locations:=PackedByteArray(); locations.resize(24)
		for index in 3:
			write_name(table,index*stride,PackedByteArray([0x8e,0xc0,0x41+index])); table.encode_u16(index*stride+stride-4,2002+index); locations.encode_u32(index*8,600+index*10); locations.encode_u32(index*8+4,index)
		compare_archive("erf",table,locations,stride,"ERF layout and CP1252 case match reference: "+str(stride))
		locations.encode_u32(4,1025); compare_archive("erf",table,locations,stride,"ERF payload bounds failure matches reference")
	for stride in [22,26]:
		var table:=PackedByteArray(); table.resize(2*stride)
		for index in 2:
			write_name(table,index*stride,("MODEL"+str(index)).to_ascii_buffer()); table.encode_u16(index*stride+16,2002); table.encode_u32(index*stride+18,5+index if stride==26 else (index<<20)+5)
			if stride==26: table.encode_u32(index*stride+22,index<<20)
		compare_archive("key",table,PackedByteArray(),stride,"KEY source identity, slots and layout match reference: "+str(stride))
		table.encode_u32(22 if stride==26 else 18,3<<20); compare_archive("key",table,PackedByteArray(),stride,"KEY missing archive failure matches reference")
	for stride in [16,20]:
		var table:=PackedByteArray(); table.resize(2*stride)
		for index in 2:
			var offset: int=index*stride+(8 if stride==20 else 4); table.encode_u32(offset,700); table.encode_u32(offset+4,index); table.encode_u32(offset+8,2033)
		compare_archive("bif",table,PackedByteArray(),stride,"BIF offsets/lengths/types/layout match reference: "+str(stride))
	var installed:=PackedByteArray(); installed.resize(4+2*58); installed.encode_u32(0,2)
	for index in 2:
		write_name(installed,4+index*58,("TEST"+str(index)).to_ascii_buffer()); installed.encode_u16(20+index*58,2017); write_name(installed,22+index*58,"1234567890abcdef1234567890abcdef12345678".to_ascii_buffer())
	compare_manifest(installed,true,"Installed manifest records exactly match reference")
	for length in [0,1,3,4,20,119]: compare_manifest(installed.slice(0,length),true,"Truncated installed manifests reject: "+str(length))
	var manifest:="NSYMV000".to_ascii_buffer(); manifest.resize(16+42+22); manifest.encode_u32(8,1); manifest.encode_u32(12,1); manifest.encode_u32(36,3); write_name(manifest,40,"TEST".to_ascii_buffer()); manifest.encode_u16(56,2017); write_name(manifest,62,"ALIAS".to_ascii_buffer()); manifest.encode_u16(78,3)
	compare_manifest(manifest,false,"Native manifest aliases and original hash/size match reference")
	var random:=RandomNumberGenerator.new(); random.seed=1020304
	for index in 100:
		var input: PackedByteArray=installed.duplicate() if index%2==0 else manifest.duplicate(); var offset:=random.randi_range(0,input.size()-1); input[offset]=random.randi_range(0,255)
		compare_manifest(input,index%2==0,"Deterministic mutated manifest acceptance/data matches: "+str(index))
	for length in [0,1,3,19]: check(Backend.parse("erf",PackedByteArray(),PackedByteArray(),{"count":1,"stride":24,"name_size":16,"size":length}).has("error"),"Native entry point checks table bounds before pointer reads")
	OS.set_environment("NWN_RESOURCE_INDEX",saved)
	var report:=FileAccess.open(output,FileAccess.WRITE); report.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Compiled versus reference KEY/BIF/ERF layouts, CP1252 case conversion, manifests/aliases and deterministic malformed-input corpus; no native-executable speed claim"})); report.close(); quit(0 if failures.is_empty() else 1)
func _initialize() -> void: call_deferred("run")
