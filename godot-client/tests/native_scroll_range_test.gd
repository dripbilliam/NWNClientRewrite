extends SceneTree
const ThumbRange=preload("res://systems/native_data/gui_scroll_range.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func bits(value: float) -> int:
	var bytes:=PackedByteArray(); bytes.resize(4); bytes.encode_float(0,value); return bytes.decode_u32(0)
func run() -> void:
	var output:=""; var fixture:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--fixture="): fixture=arg.substr(10)
	if output.is_empty() or fixture.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(original.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Scrollbar range oracle pins the original client binary")
	for row in original.rows:
		var value:=ThumbRange.thumb(int(row.range),int(row.visible),float(row.length))
		check(value.range==int(row.clampedRange) and bits(value.model_units)==bits(float(row.thumbModelUnits)) and bits(value.time)==bits(float(row.animationTime)),"Original range clamp/float/animation arithmetic matches "+str([row.range,row.visible,row.length]))
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalRows":original.rows.size(),"fixtureSha256":FileAccess.get_sha256(fixture),"publicConnections":0,"scope":"Original scrollbar range/thumb arithmetic only. Shared native UI integration, viewport coordinate mapping and full scrollbar parity are not accepted by this test."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
