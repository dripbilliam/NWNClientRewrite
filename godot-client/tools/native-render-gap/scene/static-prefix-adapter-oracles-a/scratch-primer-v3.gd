extends RefCounted
# SOURCE ONLY. This is the known actual Dictionary const[] scratch primer from
# light-member-read/fixture-base-safe.gd; GDScript get() is NOT a substitute.
const WRITER="extends Node3D\nvar native_properties: Dictionary={}\nvar native_state: Dictionary={}\nvar native_properties_revision: int=0\n"
func prime(parent: Node,shared: Dictionary)->Dictionary:
	if not ClassDB.class_exists("NwnBuiltinLightInputRegistry"):return {"pending":true,"reason":"Actual scratch-primer class unavailable"}
	var host:=Node3D.new();parent.add_child(host)
	var script:=GDScript.new();script.source_code=WRITER
	if script.reload()!=OK:host.free();return {"pending":true,"reason":"Exact known primer facade failed to compile"}
	var registry: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	var enrolled: Dictionary=registry.call("dispatch",6,{"script":script,"sha256":WRITER.sha256_text()})
	if not enrolled.get("accepted",false):registry.call("dispatch",8,{});host.free();return {"pending":true,"reason":"Known primer facade not accepted"}
	var node=script.new();host.add_child(node)
	node.native_properties=shared;node.native_state={"range":12.0};node.native_properties_revision=1
	node.set_meta("native_enhanced_light",true);node.set_meta("native_light_priority",0)
	registry.call("dispatch",0,{"id":node.get_instance_id(),"source":host.get_instance_id()})
	var result: Dictionary=registry.call("dispatch",1,{"planes":[],"view_changed":false})
	return {"pending":false,"primed":result.get("error","")=="Native particle value must be numeric","host":host,"registry":registry,"writer":script,"error":result.get("error","")}
func close(value: Dictionary)->void:
	if value.get("pending",true):return
	value.registry.call("dispatch",8,{})
	value.host.free()
	value.clear()
