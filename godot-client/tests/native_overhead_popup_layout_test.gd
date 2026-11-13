extends SceneTree
# QUEUED: pure native-GDScript equality against unchanged original-x64 scenes.
# No renderer/world/received speech ownership assertion belongs to this case.
const Layout=preload("res://systems/native_data/overhead_popup_layout.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func bits(value: float) -> String:
	return PackedFloat32Array([value]).to_byte_array().hex_encode()
func run() -> void:
	var report:="";var oracle_path:="res://reports/native-overhead-popup-layout-original-v1.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
		if argument.begins_with("--oracle="):oracle_path=argument.trim_prefix("--oracle=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	if not oracle is Dictionary or oracle.get("cases",[]).size()!=64:quit(3);return
	check(oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Pinned original instruction oracle identity")
	for observation in oracle.cases:
		var input: Dictionary=observation.case
		var before: Dictionary=input.duplicate(true)
		var result: Dictionary=Layout.arrange(input.rows,int(input.mode),bool(input.enabled))
		check(result.get("ready",false),str(input.name)+" ready")
		if not result.get("ready",false):continue
		check(input==before,str(input.name)+" leaves caller values unchanged")
		for index in observation.result.size():
			for key in ["x","y","z"]:
				check(bits(float(result.rows[index][key]))==bits(float(observation.result[index][key])),str(input.name)+"/"+str(index)+"/"+key)
		check(result.placed.size()==observation.placed.size(),str(input.name)+" native setter count")
		if result.placed.size()==observation.placed.size():
			for index in result.placed.size():
				var placed: Dictionary=result.placed[index];var expected: Dictionary=observation.placed[index]
				check(int(placed.index)==int(expected.index),str(input.name)+" setter order")
				for component in 3:
					check(bits(float(placed[["x","y","z"][component]]))==expected.bits[component],str(input.name)+" native setter float bits")
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file==null:quit(4);return
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Pure GDScript versus original x64 ordered popup arithmetic only; no render/visibility/receiver/pixel acceptance."},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
