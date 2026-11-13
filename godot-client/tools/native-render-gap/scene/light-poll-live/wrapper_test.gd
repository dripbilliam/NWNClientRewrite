extends SceneTree
const Registry=preload("res://systems/native_render/native_light_input_registry.gd")
const Point=preload("res://systems/native_render/model_point_light.gd")
var output:=""
var checks:=0
var failures: Array=[]
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	var arguments:=PackedStringArray(["--light-input-registry=builtin","--light-input-read=typed"])
	var owner:=Registry.new();check(owner.configure(arguments),"Actual staged wrapper enrolls cold during configure")
	check(owner.effective=="builtin" and owner.native!=null,"Wrapper owns real builtin before first poll")
	var diagnostic: Dictionary=owner.native.call("dispatch",9,{})
	check(int(diagnostic.plain_claims)==1,"Wrapper sends exactly one source/schema claim")
	var host:=Node3D.new();root.add_child(host);var lamp:=Point.new();host.add_child(lamp);lamp.set_meta("native_enhanced_light",true);lamp.native_properties={"radius":8,"color":[.2,.3,.4]};lamp.native_state={"range":8}
	check(not owner.register_light(lamp.get_instance_id(),host.get_instance_id()).has("error"),"Actual wrapper registration")
	var value:=owner.poll([],true);check(not value.has("error") and value.rows.size()==1,"Actual wrapper polling publishes light")
	diagnostic=owner.native.call("dispatch",9,{});check(int(diagnostic.plain_field_reads)==3,"Actual wrapper's selected reader executes three live field reads")
	check(owner.snapshot().effective=="builtin","Existing wrapper snapshot contract retained")
	owner.close();host.free();check(owner.closed and owner.native==null,"Wrapper close releases registry and claim")
	var script_owner:=Registry.new();check(script_owner.configure(PackedStringArray(["--light-input-read=typed"])),"Ordinary script selection remains valid with optional engine flag")
	check(script_owner.effective=="script" and script_owner.native==null,"No hidden builtin enrollment for script selector");script_owner.close()
	var bad:=GDScript.new();bad.source_code=(Registry as GDScript).source_code.replace(Registry.CANONICAL_WRITER_SHA,"0".repeat(64));check(bad.reload()==OK,"Wrong source-pin wrapper compiles")
	var rejected=bad.new();check(not rejected.configure(arguments),"Explicit typed claim with wrong source pin rejected")
	check(rejected.native==null and rejected.effective=="unavailable" and "enrollment rejected" in rejected.failure,"Rejected enrollment closes owner and retains reason");rejected.close()
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false}));file.close();quit(0 if failures.is_empty() else 1)
