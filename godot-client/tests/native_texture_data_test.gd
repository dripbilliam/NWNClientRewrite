extends SceneTree
const Raster = preload("res://systems/native_data/texture_data.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()
func run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var parser := Raster.new()
	for item in fixture.cases:
		var bytes := FileAccess.get_file_as_bytes(str(fixture.folder).path_join(item.name)); var value: Dictionary = parser.parse(bytes,int(item.type))
		check(parser.failure.is_empty() and not value.is_empty(), "Native raster parses: "+str(item.name)+" "+parser.failure)
		if value.is_empty(): continue
		check(int(value.width)==int(item.expected.width) and int(value.height)==int(item.expected.height) and value.format==item.expected.format, "Raster dimensions/format agree: "+str(item.name))
		check(value.mips.size()==item.expected.mips.size(), "Authored mip count retained: "+str(item.name))
		for index in mini(value.mips.size(),item.expected.mips.size()):
			var mip: Dictionary = value.mips[index]; var expected: Dictionary = item.expected.mips[index]
			check(int(mip.width)==int(expected.width) and int(mip.height)==int(expected.height) and digest(mip.data)==expected.sha256,"Exact original pixels/blocks: "+str(item.name)+" mip "+str(index))
		check(parser.parse(bytes.slice(0,17),int(item.type)).is_empty() and not parser.failure.is_empty(),"Truncated header rejects before allocation: "+str(item.name))
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":fixture.cases.size(),"scope":fixture.scope,"sourceSha256":FileAccess.get_sha256("res://systems/native_data/texture_data.gd")}
	var file := FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
