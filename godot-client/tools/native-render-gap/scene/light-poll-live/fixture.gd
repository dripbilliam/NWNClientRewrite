extends SceneTree
const Point=preload("res://systems/native_render/model_point_light.gd")
var canonical_writer: GDScript=Point as GDScript
var output:=""
var checks:=0
var failures: Array=[]
var stages: Array=[]
var observations:=0
var canonical_source:=""
var canonical_hash:=""
var source_mutated:=false
class Inherited extends Point:
	pass
class Observed extends Node3D:
	var values: Dictionary={"radius":8.0,"color":[.2,.4,.6],"multiplier":1.0}
	var state_value: Dictionary={"range":12.0}
	var revision_value:=0
	var trace: Array=[]
	var callback: Callable
	var native_properties: Variant:
		get:
			trace.append("native_properties")
			if callback.is_valid():callback.call()
			return values
	var native_state: Variant:
		get:trace.append("native_state");return state_value
	var native_properties_revision: Variant:
		get:trace.append("native_properties_revision");return revision_value
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func peer(writer: Script=Point)->Dictionary:
	var host:=Node3D.new();host.name="Host";root.add_child(host)
	var source:=Node3D.new();source.name="Source";host.add_child(source)
	var lamp=writer.new();lamp.set_meta("native_enhanced_light",false)
	if lamp.has_method("configure"):lamp.configure({"color":[.8,.4,.2],"radius":8.0,"multiplier":1.0,"shadow":1,"ambientonly":0})
	source.add_child(lamp)
	lamp.set_meta("native_enhanced_light",true)
	if lamp.has_method("configure"):lamp.native_state={"range":12.0}
	var old: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	var fast: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	var enrolled: Dictionary=fast.call("dispatch",6,{"script":Point,"sha256":canonical_hash})
	check(enrolled.get("accepted",false),"Exact canonical plain schema enrolls cold")
	for registry in [old,fast]:registry.call("dispatch",0,{"id":lamp.get_instance_id(),"source":source.get_instance_id()})
	return {"host":host,"source":source,"lamp":lamp,"old":old,"fast":fast}
func poll(value: Dictionary,label: String,view_changed: bool=false,planes: Array=[])->Dictionary:
	var first: Dictionary=value.old.call("dispatch",1,{"planes":planes,"view_changed":view_changed})
	var second: Dictionary=value.fast.call("dispatch",1,{"planes":planes,"view_changed":view_changed})
	check(var_to_bytes(first)==var_to_bytes(second),label+": exact live rows/error/order/default types")
	stages.append(label);return second
func stats(value: Dictionary)->Dictionary:return value.fast.call("dispatch",9,{})
func close(value: Dictionary)->void:
	for registry in [value.old,value.fast]:registry.call("dispatch",8,{})
	value.host.free();value.clear()
func live_changes()->void:
	var value:=peer();poll(value,"Initial");poll(value,"Unchanged")
	check(int(stats(value).plain_field_reads)>=6,"Actual canonical live read path executes")
	check(var_to_bytes(value.old.call("dispatch",3,{}))==var_to_bytes(value.fast.call("dispatch",3,{})),"Legacy inspect unchanged by private diagnostics")
	var lamp=value.lamp
	lamp.native_state.range=4.5;poll(value,"State range alias mutation without revision",true)
	lamp.native_properties.color[1]=.91;poll(value,"Nested property alias mutation without revision")
	lamp.native_properties.radius=1000;poll(value,"Live authored radius eligibility change")
	lamp.native_properties.radius=9;poll(value,"Live authored radius eligibility restored")
	lamp.native_properties={};poll(value,"Direct empty Dictionary replacement")
	lamp.native_properties={"radius":6.0,"color":[.1,.2,.3],"multiplier":.8};poll(value,"Direct nonempty Dictionary replacement without revision")
	lamp.native_properties_revision+=1;poll(value,"Explicit revision replacement")
	lamp.native_state={"range":3.25};poll(value,"Direct state replacement")
	lamp.set_meta("native_light_priority",7);poll(value,"Live priority metadata")
	lamp.set_meta("native_enhanced_light",false);poll(value,"Live enhanced metadata suppression")
	lamp.set_meta("native_enhanced_light",true);poll(value,"Live enhanced metadata restored")
	value.source.hide();poll(value,"Live parent visibility suppression");value.source.show();poll(value,"Live parent visibility restored")
	lamp.position=Vector3(2,3,4);poll(value,"Live global position")
	lamp.native_properties.radius="bad";poll(value,"Malformed numeric property preserves error boundary")
	lamp.native_properties.radius=6.0;lamp.native_state.range="bad";poll(value,"Malformed state range preserves error boundary")
	lamp.native_state.range=3.25;lamp.set_meta("native_light_priority","bad");poll(value,"Malformed priority before revision")
	lamp.set_meta("native_light_priority",0);poll(value,"After malformed fields")
	var before_reads:=int(stats(value).plain_field_reads)
	value.source.remove_child(lamp);poll(value,"Tree exit eligibility");value.source.add_child(lamp);poll(value,"Tree reentry fields")
	check(int(stats(value).plain_field_reads)>before_reads,"Actual reentered canonical instance remains live")
	close(value)
func observed_fallback()->void:
	var value:=peer(Observed)
	var lamp=value.lamp
	lamp.trace=[];value.old.call("dispatch",1,{"planes":[],"view_changed":false});var first: Array=lamp.trace.duplicate()
	lamp.trace=[];value.fast.call("dispatch",1,{"planes":[],"view_changed":false});var second: Array=lamp.trace.duplicate()
	check(first==["native_properties","native_state","native_properties_revision"] and first==second,"Unknown getter facade retains exact getter order")
	check(int(stats(value).plain_rows)==0,"Unknown getter facade never claims canonical live reader")
	close(value)
	value=peer(Inherited);poll(value,"Inherited facade fallback")
	check(int(stats(value).plain_rows)==0,"Inherited canonical script retains original property path")
	close(value)
func callback_case(action: String)->void:
	var value:=peer(Observed);var lamp=value.lamp;var results: Array=[]
	for registry in [value.old,value.fast]:
		lamp.trace=[]
		lamp.callback=func():
			if action=="erase":registry.call("dispatch",2,{"id":lamp.get_instance_id()})
			elif action=="close":registry.call("dispatch",8,{})
			elif action=="reentrant":check(registry.call("dispatch",1,{"planes":[],"view_changed":false}).get("error","")=="Native light input registry poll is reentrant","Opaque getter retains reentrant rejection")
		results.append(registry.call("dispatch",1,{"planes":[],"view_changed":false}))
	check(var_to_bytes(results[0])==var_to_bytes(results[1]),"Opaque callback "+action+" preserves result/error")
	if action in ["erase","close"]:check(results[1].has("error"),"Opaque callback "+action+" remains rejected")
	lamp.callback=Callable();close(value)
func visibility_observation(value: Dictionary,nested: Dictionary)->void:
	observations+=1;poll(value,"Synchronous configure visibility partial state "+str(observations))
	if nested.get("pending",false):nested.pending=false;value.lamp.configure({"color":[.2,.7,.4],"radius":5,"multiplier":.9,"shadow":1})
func configure_callbacks()->void:
	var value:=peer();var lamp=value.lamp
	lamp.native_admitted=false;lamp.configure({"color":[.4,.3,.2],"radius":0,"multiplier":1})
	var nested:={"pending":false}
	lamp.visibility_changed.connect(visibility_observation.bind(value,nested))
	lamp.configure({"color":[.9,.7,.3],"radius":7,"multiplier":1,"shadow":1});poll(value,"After observed configure")
	nested.pending=true;lamp.configure({"color":[.8,.1,.6],"radius":9,"multiplier":.8,"shadow":1});poll(value,"After nested configure")
	check(observations>=4 and not nested.pending,"Mid-configure and nested writer polls actually execute")
	lamp.visibility_changed.disconnect(visibility_observation.bind(value,nested));close(value)
func instance_and_source_changes()->void:
	var value:=peer();poll(value,"Before same resource reattach")
	var lamp=value.lamp
	lamp.set_script(null);poll(value,"Script detached")
	lamp.set_script(Point);poll(value,"Same Script Resource new instance initial fields")
	lamp.configure({"color":[.3,.6,.2],"radius":4,"multiplier":1});poll(value,"Same Script Resource instance repopulated")
	var reads:=int(stats(value).plain_field_reads)
	var replacement:=GDScript.new();replacement.source_code=canonical_source
	check(replacement.reload()==OK,"Replacement script resource compiles")
	lamp.set_script(replacement);poll(value,"Byte-identical replacement Script Resource fallback")
	check(int(stats(value).plain_field_reads)==reads,"Different Resource identity never reuses capability")
	lamp.set_script(Point);lamp.configure({"color":[.3,.6,.2],"radius":4,"multiplier":1});poll(value,"Return to canonical resource")
	close(value)
	# The canonical resource is edited in memory only; frozen file bytes remain.
	value=peer();poll(value,"Before source edit")
	var modified:=canonical_source+"\n# typed-reader in-memory source mutation\n"
	canonical_writer.source_code=modified;source_mutated=true
	reads=int(stats(value).plain_field_reads);poll(value,"Same Resource changed source without reload")
	check(int(stats(value).plain_field_reads)==reads,"Changed COW source buffer falls back before authored reads")
	check(canonical_writer.reload(true)==OK,"Same Resource edited source reloads");poll(value,"Same Resource reload live fields")
	canonical_writer.source_code=canonical_source;check(canonical_writer.reload(true)==OK,"Canonical source restored");source_mutated=false;poll(value,"Restored source fields remain exact")
	close(value)
	value=peer()
	var getter_source:=canonical_source.replace("var native_properties: Dictionary={}","var native_properties: Dictionary={}:\n\tget:\n\t\tif has_meta(\"typed_getter_trace\"):get_meta(\"typed_getter_trace\").append(\"properties\")\n\t\treturn native_properties")
	check(getter_source!=canonical_source,"Current canonical getter-injection seam found")
	canonical_writer.source_code=getter_source;source_mutated=true;check(canonical_writer.reload(true)==OK,"Same Resource compiled getter schema reloads")
	value.lamp.set_meta("typed_getter_trace",[])
	reads=int(stats(value).plain_field_reads);poll(value,"Compiled getter schema uses original reflection")
	check(int(stats(value).plain_field_reads)==reads,"Compiled getter cannot use callback-free path")
	# Restore the retained exact source String without recompiling. The source
	# identity may match while the current compiled member still has a getter.
	canonical_writer.source_code=canonical_source
	var schema_rejections:=int(stats(value).plain_schema_rejections)
	poll(value,"Restored text before reload still rejects compiled getter schema")
	check(int(stats(value).plain_field_reads)==reads,"Current compiled getter check prevents text-only reactivation")
	check(int(stats(value).plain_schema_rejections)>schema_rejections,"Restored source COW identity reaches the compiled-schema rejection gate")
	check(value.lamp.get_meta("typed_getter_trace").size()==4,"Both original and candidate invoke real getter in both fallback states")
	check(canonical_writer.reload(true)==OK,"Compiled canonical schema restored");source_mutated=false;poll(value,"After compiled schema restore")
	close(value)
func schema_and_hash_claims()->void:
	var value:=peer()
	check(not value.fast.call("dispatch",6,{"script":Point,"sha256":"bad"}).get("accepted",false),"Wrong source hash cannot enroll")
	var getter_script:=GDScript.new()
	getter_script.source_code="extends Node3D\nvar native_properties: Dictionary:\n\tget: return {\"radius\":8}\nvar native_state: Dictionary={\"range\":8}\nvar native_properties_revision: int=0\n"
	check(getter_script.reload()==OK,"Getter schema fixture compiles")
	check(not value.fast.call("dispatch",6,{"script":getter_script,"sha256":getter_script.source_code.sha256_text()}).get("accepted",false),"Getter schema is rejected even with its exact hash")
	var bad_type:=GDScript.new();bad_type.source_code="extends Node3D\nvar native_properties: Variant={}\nvar native_state: Dictionary={}\nvar native_properties_revision: int=0\n"
	check(bad_type.reload()==OK,"Variant schema fixture compiles")
	check(not value.fast.call("dispatch",6,{"script":bad_type,"sha256":bad_type.source_code.sha256_text()}).get("accepted",false),"Untyped/wrong schema rejected")
	check(not value.fast.call("dispatch",6,{"script":Inherited,"sha256":(Inherited as GDScript).source_code.sha256_text()}).get("accepted",false),"Script inheritance rejected")
	poll(value,"Rejected enrollment preserves prior canonical claim")
	close(value)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	canonical_source=canonical_writer.source_code;canonical_hash=canonical_source.sha256_text()
	check(OS.get_cmdline_user_args().has("--light-input-read=typed"),"Explicit typed feature argument selected")
	check(ClassDB.class_exists("NwnBuiltinLightInputRegistry"),"Private optional builtin exists")
	if not failures.is_empty():finish();return
	live_changes();observed_fallback();callback_case("erase");callback_case("close");callback_case("reentrant");configure_callbacks();instance_and_source_changes();schema_and_hash_claims()
	await process_frame;finish()
func finish()->void:
	if source_mutated:canonical_writer.source_code=canonical_source;canonical_writer.reload(true)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"stages":stages,"visibility_observations":observations,"gpu":false,"scope":"Same builtin owner original reflected poll versus opt-in exact-source live plain GDScript fields; no pushed values or FPS claim."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
