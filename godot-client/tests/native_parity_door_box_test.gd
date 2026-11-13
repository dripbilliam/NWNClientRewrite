extends SceneTree
# Authored regression fixture, not original-instruction validation. Not run at
# authoring time. No assets, server, rendering or input automation is required.
const Box=preload("res://tools/native_parity/doors/native_box_hit.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func run() -> void:
	var low:=Vector3(-1,-1,-1);var high:=Vector3(1,1,1)
	var starts: Array=[Vector3(-2,0,0),Vector3(2,0,0),Vector3(0,-2,0),Vector3(0,2,0),Vector3(0,0,-2),Vector3(0,0,2)]
	for i in starts.size():
		var result:=Box.hit(starts[i],Vector3.ZERO,low,high)
		check(result.available and result.face==i+1 and result.written,"Original face numbering for each outside axis")
		check(result.point[ i/2 ]==(-1 if i%2==0 else 1),"Selected hit coordinate is the original box plane")
	for start in [Vector3.ZERO,low,high,Vector3(0,0,1)]:
		var result:=Box.hit(start,Vector3(9,9,9),low,high)
		check(result.face==-1 and not result.written and not result.has("point"),"Inside/inclusive boundary retains unwritten output")
	var rejected:=Box.hit(Vector3(-3,0,0),Vector3(-2,0,0),low,high)
	check(rejected.face==0 and not rejected.written,"Shared outcode rejects without fabricating a point")
	check(Box.hit(Vector3(-2,-2,-2),Vector3.ZERO,low,high).face==1,"Corner ties select X before Y and Z")
	check(Box.hit(Vector3(0,-2,-2),Vector3.ZERO,low,high).face==3,"Remaining corner tie selects Y before Z")
	var plane:=Box.hit(Vector3(-1,0,1),Vector3(1,0,1),Vector3(0,-2,0),Vector3(0,2,3))
	check(plane.face==1 and plane.written and plane.point.x==0,"Zero-thickness doorway remains a plane without an epsilon")
	var source:=Box.hit(Vector3(1,-1,1),Vector3(-1,-1,1),Vector3(-0.08,-2.02,0),Vector3(0,0.02,2.97))
	check(source.face==2 and source.point.x==0,"Installed t_door01 sam uses its authored maxX, not vertex maxX -0.08")
	check(not Box.hit(Vector3.ZERO,Vector3.ONE,Vector3.ONE,Vector3.ZERO).available,"Unordered bounds remain explicitly unavailable")
	check(not Box.hit(Vector3(NAN,0,0),Vector3.ONE,low,high).available,"Nonfinite inputs are outside the finite source-port coverage")
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--native-corpus="):continue
		var corpus: Variant=JSON.parse_string(FileAccess.get_file_as_string(arg.substr(16)))
		check(corpus is Dictionary and corpus.get("cases") is Array,"Original instruction corpus is available")
		if not corpus is Dictionary or not corpus.get("cases") is Array:continue
		for row in corpus.cases:
			var c: Dictionary=row.case
			var result:=Box.hit(Vector3(c.start[0],c.start[1],c.start[2]),Vector3(c.end[0],c.end[1],c.end[2]),Vector3(c.low[0],c.low[1],c.low[2]),Vector3(c.high[0],c.high[1],c.high[2]))
			check(result.available and result.face==int(row.face) and (int(corpus.get("arity",5))==4 or result.written==row.written),"Original leaf result and output-write contract")
			if int(corpus.get("arity",5))==5 and result.get("written",false):
				check(PackedFloat32Array([result.point.x,result.point.y,result.point.z]).to_byte_array().hex_encode()==row.output_hex,"Original output f32 words match exactly")
	print("NATIVE_PARITY_DOOR_BOX ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
