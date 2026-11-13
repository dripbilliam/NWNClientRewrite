extends SceneTree
const Census=preload("res://tools/perf140/particles/rig_owner_identity_census.gd")
class LightOwner:
	extends Node3D
	var configurations: Dictionary={7:{"dynamic":true}}
class Model:
	extends Node3D
	var model_names: Array=["fx_placeable01"]
	var object_id:=0
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scope:=Node3D.new();root.add_child(scope)
	var light:=LightOwner.new();scope.add_child(light)
	var model:=Model.new();light.add_child(model);model.set_meta("native_model_name","fx_placeable01");model.set_meta("native_generated_placeable_id",7)
	var rig:=Node.new();model.add_child(rig)
	var row:={"node_id":rig.get_instance_id(),"animated_models":0,"attachments":0,"entities":1,"manual_poses":1,"models":1,"native_owners":0,"playing_players":0,"processing":true,"skins":0}
	var original:=row.duplicate(true)
	check(not Census.capture(scope,[row]).errors.is_empty(),"A frame-loop/default invocation is rejected")
	var captured: Dictionary=Census.capture(scope,[row],true)
	check(captured.errors.is_empty() and captured.summary.resolved==1,"Explicit current-scope one-shot resolves the full ID")
	var value: Dictionary=captured.rows[0]
	check(value.parent_id==model.get_instance_id() and value.parent_object_id==0,"Parent identity and legitimate zero object ID remain distinct from missing data")
	check(value.native_generated_placeable_id==7 and value.generated_meta_present and value.native_model_name=="fx_placeable01","Safe has_meta guarded scalar identity joins")
	check(value.model_names==["fx_placeable01"] and value.generated_plan_dynamic==true,"Model and live plan identity are detached primitives")
	check(value.generated_light_manual_candidate and captured.summary.generated_light_manual_candidates==1,"Strict generated manual-light predicate is explicit")
	value.model_names.append("external");check(model.model_names.size()==1 and row==original,"Export mutation cannot change model or source census")
	var outside:=Node.new();root.add_child(outside)
	var absent: Dictionary=Census.capture(scope,[{"node_id":outside.get_instance_id()},{}],true)
	check(absent.summary.unresolved==2 and absent.rows[0].parent_id==null and absent.rows[1].parent_id==null,"Outside scope and missing identity retain explicit unavailable fields")
	model.remove_meta("native_model_name");model.remove_meta("native_generated_placeable_id")
	var missing: Dictionary=Census.capture(scope,[row],true)
	check(missing.rows[0].native_generated_placeable_id==null and not missing.rows[0].generated_meta_present,"Absent metadata is not fetched or invented as zero")
	row.untrusted=rig
	check(not Census.capture(scope,[row],true).rows[0].has("untrusted"),"Only known primitive census fields can enter the export")
	outside.free();scope.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"network":false}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
