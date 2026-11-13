extends SceneTree
# The corpus executes unchanged original972840. Its legacy harness term
# 'model' is the AsNWCObject cast result, NOT a rendered mesh-ready predicate.
const Frame=preload("res://systems/native_data/script_floating_frame.gd")
const F=preload("res://systems/native_render/particle_math.gd")
const ORIGINAL="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<20:failures.append(label)
func word(value: float) -> String:return PackedFloat32Array([value]).to_byte_array().hex_encode()
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.target==ORIGINAL and oracle.cases.size()==576,"Pinned full original floaty frame corpus has576 cases")
	for index in oracle.cases.size():
		var row: Dictionary=oracle.cases[index];var input: Dictionary=row.case
		var step:=Frame.frame(float(input.remaining),float(input.delta));var calls: Array=[]
		if step.get("destroy",false):calls.append(["destroy",1])
		elif step.get("active",false):
			calls.append(["object",4294967295])
			if input.actor:
				calls.append(["model"])
				if input.model:
					calls.append(["world"])
					if input.world:
						calls.append(["project",[3.0,4.0,F.f(5.0+float(step.height))]])
						calls.append(["color","foreground",0.25,0.5,1.0,float(step.alpha)])
						if input.shadow:calls.append(["color","background",0.0,0.0,0.0,float(step.alpha)])
						var screen:=Frame.native_screen(Vector2(float(input.screen[0]),float(input.screen[1])))
						calls.append(["position",[screen.x,screen.y,screen.z]])
		var expected: Array=row.calls.duplicate(true)
		for call in expected:
			if call[0] in ["destroy","object"]:call[1]=int(call[1])
			elif call[0] in ["project","position"]:call[1]=call[1].map(func(value):return F.f(float(value)))
			elif call[0]=="color":
				for component in range(2,call.size()):call[component]=F.f(float(call[component]))
		check(row.error==null and step.get("ready",false) and calls==expected,"Complete original call order/color/rise/rounding "+str(index))
		check(word(float(step.remaining))==word(float(row.remaining)),"Original binary32 remaining timer "+str(index))
	var reflected:=Frame.screen_down(Vector2(-2.6,1003.4),1000.0)
	check(reflected.ready and reflected.point==Vector2(-2,1002),"Negative offscreen native GUI-up rounding reflects once without clamp")
	check(Frame.screen_down(Vector2(12.5,999.5),1000).point==Vector2(13,999),"GUI-up half-pixel rounding precedes Godot screen-down conversion")
	check(Frame.frame(0.0,0.0).destroy and Frame.frame(0.1,0.1).destroy,"Floaty expires at delta>=remaining before object/world work")
	check(not Frame.frame(1.5,-0.1).ready and not Frame.frame(1.5,NAN).ready,"Unavailable GUI delta does not fabricate a frame")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"576 unchanged-original972840 frame outputs/call ordering and binary32 arithmetic; source GUI-up screen rounding adapter only. No formatting, font/art/widget/world/server acceptance.","gpu":false,"serverConnections":0}
	var output:=FileAccess.open(args.report,FileAccess.WRITE);output.store_string(JSON.stringify(result,"\t"));output.close();quit(0 if failures.is_empty() else 1)
