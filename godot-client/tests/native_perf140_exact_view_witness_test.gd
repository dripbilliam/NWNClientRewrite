extends SceneTree
# Prepared, not executed while the user's other game is active.
const Witness=preload("res://tools/perf140/driver/exact_view_witness.gd")
var checks:=0
var failed:=false
func check(value: bool,reason: String)->void:
	checks+=1
	if not value:push_error(reason);failed=true
func _initialize()->void:
	_run.call_deferred()
func _run()->void:
	var outside:=Camera3D.new()
	var unavailable:=Witness.capture(outside,null,null,null)
	check(not unavailable.available and unavailable.reason=="camera outside tree","Live outside-tree camera must not fabricate a default transform")
	outside.free()
	var camera:=Camera3D.new();root.add_child(camera)
	var transform:=Transform3D(Basis(Vector3(0,1,0),Vector3(-1,0,0),Vector3(0,0,1)),Vector3(13.25,-0.0,-132.5))
	camera.global_transform=transform
	var result:=Witness.capture(camera,null,null,7)
	check(result.available,"Actual camera witness unavailable")
	check(result.format=="basis-columns-origin-f32le-v1","Word order declaration changed")
	var bytes: PackedByteArray=result.transform_hex.hex_decode()
	check(bytes.size()==48,"Transform must retain exactly twelve f32 words")
	var expected:=PackedFloat32Array([0,1,0,-1,0,0,0,0,1,13.25,-0.0,-132.5])
	for index in 12:
		var word:=PackedByteArray();word.resize(4);word.encode_float(0,expected[index])
		check(bytes.slice(index*4,index*4+4)==word,"Basis/origin word differs at %d"%index)
	check(not result.has("scope") and not result.has("controlled") and not result.has("follow"),"Unavailable owner data must be absent")
	var original:=result.transform_hex
	result.projection.fov=-1;result.transform_hex="mutated"
	check(camera.fov!=-1,"Detached data changed live camera")
	check(Witness.capture(camera,null,null,7).transform_hex==original,"Consumer mutation changed subsequent capture")
	camera.free()
	check(not Witness.capture(null,null,null,7).available,"Missing camera must be explicit")
	print(JSON.stringify({"checks":checks,"success":not failed,"scope":"Cold raw-transform word order and mutation isolation; not graphics or performance acceptance"}));quit(1 if failed else 0)
