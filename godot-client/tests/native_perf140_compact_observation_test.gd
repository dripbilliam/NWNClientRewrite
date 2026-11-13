extends SceneTree
const CounterFixture=preload("res://tests/native_perf140_presentation_counters_test.gd")
const Compact=preload("res://systems/native_render/compact_observation.gd")
class Owner extends CounterFixture.Owner:
	var hidden: Dictionary={}
	var references
	func snapshot(_details: bool=false) -> Dictionary:
		push_error("Compact observation must not request a detailed world snapshot")
		return {}
class References extends Node:
	var waiting: Array=[1,2]
	var jobs: Dictionary={3:true}
	var publication: Array=[4]
	func snapshot() -> Dictionary:
		push_error("Compact observation must not copy reference diagnostics")
		return {}
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:
	var owner:=Owner.new()
	var state:=Compact.capture(owner)
	check(state.playable_ms==null,"Unknown admission timing remains null")
	check(state.native_references.is_empty(),"Missing reference owner is explicit")
	owner.instances={55:{}};owner.hidden={56:true};owner.desired={55:{},56:{}}
	owner.controlled=true;owner.admitted=true;owner.stats.playable_ms=12.25
	owner.references=References.new()
	state=Compact.capture(owner)
	check(state.object_visuals_complete,"Installed and hidden exact counts preserve host readiness")
	check(state.hidden==1 and state.ready and state.admission_ready,"Host readiness and hidden count contract")
	check(state.native_references=={"pending":4},"Reference pending count without snapshot or row traversal")
	check(state.playable_ms==12.25,"Diagnostic timing precision retained")
	for key in ["area_id","generation","controlled_id","entities","hidden","desired","pending_batches","object_visuals_complete","playable_ms","ready","native_references"]:check(state.has(key),"Host-required field: "+key)
	owner.stats.errors=[{"why":["failed"]}];owner.failed_objects={57:{"why":["missing"]}}
	var failed:=Compact.capture(owner)
	check(not failed.object_visuals_complete,"Errors and visual failures revoke completeness")
	failed.errors[0].why.append("consumer");failed.failed_objects[57].why.append("consumer")
	check(owner.stats.errors[0].why==["failed"] and owner.failed_objects[57].why==["missing"],"Detached error information")
	owner.references.waiting.clear();owner.references.jobs.clear();owner.references.publication.clear()
	check(state.native_references.pending==4 and Compact.capture(owner).native_references.pending==0,"Earlier view detached and current count fresh")
	owner.references.free()
	check(Compact.capture(owner).native_references.is_empty(),"Freed reference owner tolerated")
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Compact host-readiness data view only; profiled/full/final diagnostics remain separate; local gameplay and FPS pending"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(proof))
	print(JSON.stringify(proof));quit(0 if proof.success else 1)
