extends "res://tests/native_model_plan_test.gd"
var allocation_evidence: Dictionary={}
func rejects_and_owner() -> void:
	super.rejects_and_owner()
	var node:=source_node();node.controllers78=[{"rows4":1,"columnsA":1,"timeIndex6":0,"valueIndex8":1,"displacement0":44}];node.controllerCount80=1;node.values88=PackedFloat32Array([0,2])
	var prepared:=prepare(node);var bytes:=PackedByteArray();bytes.resize(0x240);bytes.fill(0)
	var a:=leaf(bytes.duplicate(),{44:1});var b:=leaf(bytes.duplicate(),{44:1});var c:=leaf(bytes.duplicate(),{44:1})
	var normal: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_hierarchy",a,node,0.0,0.0,1.0,1.0,{"depth":0},{})
	var dynamic: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_hierarchy",b,node,0.0,0.0,1.0,1.0,{"depth":0},{"allocations":true})
	var planned: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_hierarchy",c,node,0.0,0.0,1.0,1.0,{"depth":0},{"plan":prepared.plan,"allocations":true})
	expect(normal.has("error") or dynamic.has("error") or planned.has("error"),false,"Actual allocation-meter branches accept the same native Part")
	expect(a.view==b.view and b.view==c.view,true,"Constructor instrumentation does not alter exact Part output")
	expect(normal.has("part_arrays"),false,"Disabled allocation meter exports no per-Part diagnostic payload")
	expect([dynamic.part_arrays,dynamic.part_bytes,dynamic.part_result_dictionaries],[1,0x240,1],"Dynamic meter observes actual engine output storage and result-dictionary constructors")
	expect([planned.part_arrays,planned.part_bytes,planned.part_result_dictionaries],[1,0x240,0],"Prepared meter observes its actual output storage and absence of intermediate result dictionaries")
	allocation_evidence={"dynamic":[dynamic.part_arrays,dynamic.part_bytes,dynamic.part_result_dictionaries],"prepared":[planned.part_arrays,planned.part_bytes,planned.part_result_dictionaries],"scope":"Counters increment at the actual native helper constructors. Counts Part output-array objects, requested data bytes and intermediate helper dictionaries; not all Godot/CRT/OS allocations or peak memory."}
func extra_evidence() -> Dictionary:
	var result:=super.extra_evidence();result.actual_constructor_evidence=allocation_evidence;return result
