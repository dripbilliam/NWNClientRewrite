extends SceneTree

# The caller supplies the frozen V4 runtime/module and
# retains the registry deliberately while closing Focus inside a Point writer.
var report_path:=""
var checks:=0
var failures: Array=[]
var fixture: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func close_from_visibility() -> void:
	if fixture.close_requested:
		fixture.close_requested=false
		fixture.focus.close()
func make_case() -> Dictionary:
	var room:=Node3D.new();root.add_child(room);room.set_meta("native_enhanced_lighting",true)
	var focus=load("res://systems/native_render/focus_lighting_builtin_input_candidate.gd").new()
	room.add_child(focus);focus.configure(room);focus.set_process(false);focus.enable_history(2)
	var source:=Node3D.new();source.set_meta("native_light_source",true);room.add_child(source)
	var point=load("res://systems/native_render/model_point_light.gd").new()
	point.set_meta("native_enhanced_light",false)
	var properties:Dictionary={"color":[0.8,0.4,0.2],"radius":8.0,"multiplier":1.0,"isdynamic":1,"affectdynamic":1}
	point.configure(properties);source.add_child(point);point.set_meta("native_enhanced_light",true)
	point.native_admitted=false;point.native_fade=0.0;point.configure(properties)
	return {"room":room,"focus":focus,"source":source,"point":point,"properties":properties}
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report_path=argument.trim_prefix("--report=")
	if report_path.is_empty() or FileAccess.file_exists(report_path):quit(2);return
	check(ClassDB.class_exists("NwnBuiltinLightInputRegistry"),"Actual optional registry exists")
	if not failures.is_empty():finish();return
	var room:=Node3D.new();root.add_child(room);room.set_meta("native_enhanced_lighting",true)
	var focus=load("res://systems/native_render/focus_lighting_builtin_input_candidate.gd").new()
	room.add_child(focus);focus.configure(room);focus.set_process(false);focus.enable_history(2)
	var registry: RefCounted=focus.input_registry
	check(registry.get_class()=="NwnBuiltinLightInputRegistry","The retained actual registry is selected")
	var source:=Node3D.new();source.set_meta("native_light_source",true);room.add_child(source)
	var point=load("res://systems/native_render/model_point_light.gd").new()
	point.set_meta("native_enhanced_light",false)
	var properties: Dictionary={"color":[0.8,0.4,0.2],"radius":8.0,"multiplier":1.0,"isdynamic":1,"affectdynamic":1}
	point.configure(properties);source.add_child(point);point.set_meta("native_enhanced_light",true)
	point.native_admitted=false;point.native_fade=0.0;point.configure(properties)
	check(point._native_input_token>0,"Actual canonical Point is enrolled before the boundary")
	fixture={"focus":focus,"close_requested":true}
	point.visibility_changed.connect(close_from_visibility)
	point.configure(properties)
	check(not fixture.close_requested and focus.closed,"Focus closes synchronously from the original visibility setter")
	var retained_binding: WeakRef=point._native_input_registry
	check(retained_binding==null or not is_instance_valid(retained_binding.get_ref()) or point._native_input_token==0,"Closing Focus revokes Point binding even while an external registry Ref remains")
	check(bool(registry.call("dispatch",3,{}).closed),"Retained registry is closed")
	# Cleanup must not itself issue another publication to the closed registry.
	point.bind_native_input_registry(null)
	room.free();fixture.clear();registry=null
	var normal:=make_case();var retained:RefCounted=normal.focus.input_registry
	check(normal.point._native_input_token>0,"normal close has a live canonical claim")
	normal.focus.close()
	check(normal.point._native_input_registry==null and normal.point._native_input_token==0,"normal close revokes canonical capability before registry retirement")
	check(bool(retained.call("dispatch",3,{}).closed),"normal close retires the retained registry")
	normal.point.configure(normal.properties)
	check(normal.point._native_input_registry==null,"later writer does not republish after normal close")
	normal.focus.close()
	check(normal.focus.closed and normal.focus.input_registry==null,"repeated close remains idempotent")
	normal.point.bind_native_input_registry(null);normal.room.free();normal.clear();retained=null
	# A stale Focus membership must not revoke a newer claim made to another
	# registry. The ownership comparison is deliberately stricter than type alone.
	var rebound:=make_case();var former:RefCounted=rebound.focus.input_registry
	var foreign:RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	var id:int=rebound.point.get_instance_id()
	foreign.call("dispatch",0,{"id":id,"source":rebound.source.get_instance_id()})
	var writer:GDScript=rebound.point.get_script()
	var claim:Dictionary=foreign.call("dispatch",6,{"id":id,"writer":writer,"source_sha256":FileAccess.get_sha256(writer.resource_path)})
	check(claim.get("accepted",false),"new registry accepts its own canonical claim")
	if claim.get("accepted",false):
		rebound.point.bind_native_input_registry(foreign,int(claim.token))
		rebound.focus.close()
		var binding:WeakRef=rebound.point._native_input_registry
		check(binding!=null and binding.get_ref()==foreign and rebound.point._native_input_token==int(claim.token),"closing former owner preserves newer registry capability")
		rebound.point.configure(rebound.properties)
		var stats:Dictionary=foreign.call("dispatch",9,{})
		check(int(stats.publications)>1,"writer still publishes to its newer live registry")
		check(bool(former.call("dispatch",3,{}).closed),"former registry still closes normally")
	rebound.point.bind_native_input_registry(null);foreign.call("dispatch",8,{})
	rebound.room.free();rebound.clear();foreign=null;former=null;writer=null
	await process_frame;await process_frame
	finish()
func finish() -> void:
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"server_connections":0},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
