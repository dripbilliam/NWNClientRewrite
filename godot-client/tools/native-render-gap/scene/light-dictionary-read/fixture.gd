extends SceneTree
var checks: Array=[]
var observations: Array=[]
var output:=""
class Fields extends Node3D:
	var properties: Variant={"radius":8.0,"color":[.2,.4,.6]}
	var state: Variant={"range":12.0}
	var revision: Variant=0
	var trace: Array=[]
	var property_action: Callable
	var state_action: Callable
	var native_properties: Variant:
		get:
			trace.append("props")
			if property_action.is_valid():property_action.call()
			return properties
	var native_state: Variant:
		get:
			trace.append("state")
			if state_action.is_valid():state_action.call()
			return state
	var native_properties_revision: Variant:
		get:trace.append("revision");return revision
class HasFacade extends RefCounted:
	var trace: Array=[]
	var answer: Variant=false
	var action: Callable
	func has(key: Variant)->Variant:
		trace.append("has:"+str(key))
		if action.is_valid():action.call()
		return answer
class Tracker extends RefCounted:
	var events: Array=[]
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE:events.append("tracker_deleted")
func check(ok: bool,label: String)->void:checks.append({"ok":ok,"label":label})
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	call_deferred("run")
func context(properties: Variant,state: Variant)->Dictionary:
	var node:=Fields.new();node.properties=properties;node.state=state;node.set_meta("native_enhanced_light",true);root.add_child(node)
	var registry: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	check(not registry.call("dispatch",0,{"id":node.get_instance_id(),"source":0}).has("error"),"Real native registry binds current node")
	return {"node":node,"registry":registry,"trace":node.trace}
func poll(c: Dictionary,label: String,planes: Array=[])->Dictionary:
	c.trace.clear()
	var result: Dictionary=c.registry.call("dispatch",1,{"planes":planes,"view_changed":true})
	var normalized: Dictionary=result.duplicate(true)
	for row in normalized.get("rows",[]):row.id=1;row.owner=0
	for key in ["removed","retired"]:
		if normalized.has(key):normalized[key]=normalized[key].map(func(_value):return 1)
	observations.append({"label":label,"payload":var_to_bytes(normalized).hex_encode(),"trace":c.trace.duplicate()})
	return result
func close(c: Dictionary)->void:
	c.registry.call("dispatch",8,{})
	if is_instance_valid(c.node):c.node.free()
	c.clear()
func run()->void:
	check(ClassDB.class_exists("NwnBuiltinLightInputRegistry"),"Built-in registry exists")
	var all: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	var first: Dictionary=all.call("dispatch",9,{})
	check(first.has("dictionary_single_requested"),"Actual new module exposes cold dictionary diagnostic")
	var selected: bool=OS.get_cmdline_user_args().has("--light-dictionary-read=single")
	check(bool(first.dictionary_single_requested)==selected,"Actual requested one-read mode observed")
	all.call("dispatch",8,{});all=null
	for pair in [[0,0.0],[8,12.0],[true,false],[false,true],[-0.0,-0.0],[1.25,2.5],[NAN,NAN],[-INF,INF],[999.999,INF],[1000.0,12.0]]:
		var c:=context({"radius":pair[0],"color":[.1,.2,.3]},{"range":pair[1]})
		var result:=poll(c,"numeric:"+str(observations.size()))
		check(not result.has("error"),"Existing numeric/bool/NaN/infinite conversion policy retained")
		close(c)
	var c:=context({"color":[0,0,0]},{});check(not poll(c,"missing").has("error"),"Missing numeric fields retain zero defaults");close(c)
	c=context({"radius":8.0},{"range":12.0})
	check(poll(c,"live:first").rows.size()==1,"Initial row publishes")
	c.node.properties.radius=1000.0;check(poll(c,"live:removed").removed.size()==1,"Current radius mutation affects eligibility without a new cache")
	c.node.properties.radius=7.0;c.node.state.range=4.0;check(poll(c,"live:readded").rows.size()==1,"Current radius/range re-admission retained")
	var alias: Dictionary={}
	c.node.revision+=1;alias=poll(c,"alias:published").rows[0];alias.erase("override")
	check(poll(c,"alias:erase").rows.size()==1,"External published-row alias erase remains observable")
	close(c)
	for value in ["8",null,Vector3.ONE,[],{}]:
		c=context({"radius":value},{"range":12.0});check(poll(c,"invalid-radius:"+str(observations.size())).get("error","")=="Native particle value must be numeric","Existing nonnumeric radius error retained");close(c)
	var typed_props: Dictionary[String,Variant]={"radius":8.0};var typed_state: Dictionary[String,Variant]={"range":12.0}
	c=context(typed_props,typed_state);check(not poll(c,"typed-keys").has("error"),"Typed String-key Dictionary retains original validation path");close(c)
	var value_typed: Dictionary[Variant,float]={"radius":8.0};c=context(value_typed,{"range":12.0});check(not poll(c,"typed-values").has("error"),"Untyped key with typed value remains exact");close(c)
	var events: Array=[];var tracker:=Tracker.new();tracker.events=events
	var shared: Dictionary={"radius":tracker,"range":3.0};shared.make_read_only()
	c=context(shared,{"range":12.0});var before_refs:=tracker.get_reference_count()
	check(poll(c,"readonly:scratch-object").has("error"),"Read-only object numeric failure retains old error")
	check(tracker.get_reference_count()==before_refs+1,"Old nonconst read-only scratch retains its object reference")
	c.node.properties={"radius":5.0};c.node.state=shared
	check(not poll(c,"readonly:scratch-number").has("error"),"Read-only numeric lookup succeeds")
	check(tracker.get_reference_count()==before_refs,"Next read-only field overwrites scratch and releases prior object")
	close(c);shared={};tracker=null;check(events==["tracker_deleted"],"Read-only tracker lifetime ends exactly once")
	for answer in [false,0,true,1,"invalid"]:
		var facade:=HasFacade.new();facade.answer=answer
		c=context({"radius":8.0},facade);var result:=poll(c,"dynamic-has:"+str(observations.size()))
		check(facade.trace==["has:range"],"Dynamic has executes once in original order")
		var absent: bool=(answer is bool and not answer) or (answer is int and answer==0)
		check(not result.has("error") if absent else result.has("error"),"Dynamic facade fallback/error retained")
		observations.append({"label":"dynamic-trace","trace":facade.trace.duplicate()});close(c);facade=null
	c=context({"radius":8.0},{"range":12.0});c.node.property_action=func():c.registry.call("dispatch",8,{})
	check(poll(c,"callback-close").get("error","")=="Native light input registry is closed","Opaque property callback still closes before numeric work");c.node.property_action=Callable();close(c)
	all=ClassDB.instantiate("NwnBuiltinLightInputRegistry");var final: Dictionary=all.call("dispatch",9,{})
	check(int(final.dictionary_single_reads)>0 if selected else int(final.dictionary_single_reads)==0,"Actual writable Dictionary one-read coverage/default-OFF witness")
	check(int(final.dictionary_single_missing)>0 if selected else int(final.dictionary_single_missing)==0,"Missing-field branch witnessed")
	check(int(final.dictionary_single_read_only_fallbacks)>0 if selected else int(final.dictionary_single_read_only_fallbacks)==0,"Read-only original fallback witnessed")
	check(int(final.dictionary_single_typed_key_fallbacks)>0 if selected else int(final.dictionary_single_typed_key_fallbacks)==0,"Typed-key original fallback witnessed")
	all.call("dispatch",8,{});all=null;await process_frame
	var success:=checks.all(func(row):return row.ok)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":success,"checks":checks,"observations":observations,"diagnostics":final,"scope":"Actual engine Dictionary/current node/dynamic getter/read-only scratch/refcount/alias semantics; headless only, no FPS claim"}));file.close();quit(0 if success else 1)
