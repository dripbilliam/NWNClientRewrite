extends SceneTree
const Anchor=preload("res://systems/native_data/overhead_speech_anchor.gd")
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const NativeAnchor=preload("res://systems/native_data/nameplate_anchor.gd")
var checks:=0
var failures: Array=[]
class Model extends Node3D:
	var parts: Array=[]
	var rigs
	var failure:=""
	var retired:=false
	var body_model_scopes: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var host:=Node3D.new();root.add_child(host)
	var view:=Camera3D.new();host.add_child(view);view.position=Vector3(0,14,15);view.look_at(Vector3(0,1,0))
	var model:=Model.new();host.add_child(model);model.position=Vector3(2,0,-3);model.set_meta("native_nameplate_height",1.8)
	var row:={"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13}
	var context:=Scope.context(3,7,91);var identity:=Anchor.witness(row);var scope:=[3,7,91]
	check(not Anchor.project(model,row,identity,scope,context,view).ready,"Unstamped visual cannot borrow received source identity")
	Anchor.stamp(model,row,context)
	var positioned:=Anchor.project(model,row,identity,scope,context,view)
	check(positioned.ready,"Actual visual outside any interaction registry can anchor speech")
	var wanted:=NativeAnchor.lift(model.to_global(Vector3(0,1.8,0)),view.global_position)
	check(positioned.point.is_equal_approx(wanted) and positioned.screen==view.unproject_position(wanted),"Uses authored head height, current visual pose and original lift; view owns the one screen truncation")
	model.position.x+=4;var moved:=Anchor.project(model,row,identity,scope,context,view)
	check(moved.ready and moved.point.x!=positioned.point.x,"New actual interpolated visual pose is projected without rebuilding entity data")
	check(not Anchor.project(model,row,[42,8,14],scope,context,view).ready,"Redisclosed known lifetime cannot bind old visual")
	check(not Anchor.project(model,row,[42,9,13],scope,context,view).ready,"New native lifetime cannot bind old visual")
	check(Anchor.project(model,row,identity,scope,Scope.context(4,7,91),view).get("retired",false),"Reconnect retires old reference")
	check(Anchor.project(model,row,identity,scope,Scope.context(3,8,91),view).get("retired",false),"Same-area transition generation retires old reference")
	check(not Anchor.project(null,row,identity,scope,context,view).ready,"Unloaded model remains explicitly unavailable")
	check(not Anchor.project(model,row,identity,scope,context,null).ready,"Missing camera does not fabricate a screen position")
	model.remove_meta("native_nameplate_height")
	check(not Anchor.project(model,row,identity,scope,context,view).ready,"Missing creature hook metadata never becomes height zero")
	row.objectType=9;model.set_meta("native_model_name","plc_test")
	var hook:=Node3D.new();model.add_child(hook);hook.position=Vector3(0,3.25,0);hook.set_meta("native_part_name","test_head_hit");model.parts=[hook]
	Anchor.stamp(model,row,context)
	check(model.get_meta("native_speech_height")==3.25,"Placeable hook drops first four model bytes and uses model-local authored Z height")
	check(Anchor.project(model,row,identity,scope,context,view).ready,"Placeable uses cached hook height without an AABB")
	hook.position.y=9;Anchor.stamp(model,row,context)
	check(model.get_meta("native_speech_height")==3.25,"Animation/update does not rescan or expand cached hook height")
	var fallback:=Model.new();host.add_child(fallback);fallback.set_meta("native_model_name","plc_other");Anchor.stamp(fallback,row,context)
	check(fallback.get_meta("native_speech_height")==1.5,"Successful placeable without hook uses original 1.5 fallback")
	row.objectType=10;Anchor.stamp(fallback,row,context)
	var door:=Anchor.project(fallback,row,identity,scope,context,view)
	check(door.ready and door.point.is_equal_approx(NativeAnchor.lift(fallback.to_global(Vector3(0,2.1,0)),view.global_position)),"Door uses native constructor 2.1 height")
	check(Anchor.witness({"id":42}).is_empty() and Anchor.witness({"id":42,"nativeLifetime":0,"clientKnownLifetime":13}).is_empty(),"Absent/nonpositive lifetimes stay unavailable")
	row.objectType=5;model.set_meta("native_nameplate_height",1.8);model.position=view.position+Vector3(0,0,10);Anchor.stamp(model,row,context)
	check(Anchor.project(model,row,identity,scope,context,view).ready,"No invented behind-camera/viewport rejection in the native anchor")
	row.objectType=6;row.item={"visualTransform":null}
	Anchor.stamp(model,row,context)
	check(not Anchor.project(model,row,identity,scope,context,view).ready,"Item cannot borrow creature height before main model is ready")
	model.rigs=RefCounted.new();model.body_model_scopes={254:true};Anchor.stamp(model,row,context)
	check(not model.has_meta("native_item_popup_height"),"Secondary item scope does not establish main-item readiness")
	model.body_model_scopes[255]=true;model.scale=Vector3(2,3,4);model.rotation=Vector3(0.3,0.2,0.1);Anchor.stamp(model,row,context)
	var item:=Anchor.project(model,row,identity,scope,context,view)
	wanted=NativeAnchor.lift(model.global_position+Vector3(0,0.5,0),view.global_position)
	check(item.ready and item.point.is_equal_approx(wanted),"Ready identity item uses native world-space .5 independently of model scale or tilt")
	check(model.get_meta("native_nameplate_height")==1.8 and model.get_meta("native_item_popup_height")==0.5,"Item height is separate from existing creature metadata")
	row.item.visualTransform={"legacy":true}
	check(not Anchor.project(model,row,identity,scope,context,view).ready,"Current nonidentity transform rejects an old identity stamp before any visual update")
	Anchor.stamp(model,row,context)
	check(not model.has_meta("native_item_popup_height"),"Nonidentity visual update clears cached item height")
	row.item={};Anchor.stamp(model,row,context)
	check(not Anchor.project(model,row,identity,scope,context,view).ready,"Missing canonical item transform remains unknown")
	row.erase("item");row.replicated={"item":{"visualTransform":{"entries":[],"keys":[]}}};Anchor.stamp(model,row,context)
	check(Anchor.project(model,row,identity,scope,context,view).ready,"Replicated canonical item fallback accepts the native empty map default")
	for rejected in ["failure","retired","rigs"]:
		model.set(rejected,"Main load failed" if rejected=="failure" else true if rejected=="retired" else null)
		check(not Anchor.project(model,row,identity,scope,context,view).ready,"Invalidated main item owner rejects cached anchor: "+rejected)
		model.failure="";model.retired=false;model.rigs=RefCounted.new()
	Anchor.stamp(model,row,context)
	check(not Anchor.project(model,row,[42,8,14],scope,context,view).ready,"World item lifetime reuse cannot bind the old anchor")
	host.free()
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Current native visual provenance and source-backed anchor policy only; isolated headless CPU, no world/server/pixel validation."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
