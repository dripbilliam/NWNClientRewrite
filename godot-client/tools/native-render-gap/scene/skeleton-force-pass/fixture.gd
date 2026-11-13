extends SceneTree
# Same binary in two fresh processes, flag absent/present. The runner compares
# the serialized public state and synchronous signal trace byte for byte.
var checks: Array=[]
var observations: Array=[]
var report_path:=""

class PoseModifier extends SkeletonModifier3D:
	var visits:=0
	func _process_modification_with_delta(_delta: float)->void:
		visits+=1
		var skeleton:=get_skeleton()
		skeleton.set_bone_pose_position(0,Vector3(.125,-.25,.5))
		# Updating=true must retain its original pose_updated suppression.
		skeleton.force_update_all_bone_transforms()

func check(ok: bool,label: String)->void:checks.append({"ok":ok,"label":label})
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.substr(9)
	call_deferred("run")
func pose(index: int,variant: int=0)->Transform3D:
	return Transform3D(Basis(Quaternion(Vector3(1,2,3).normalized(),float(index+variant)*.017)),Vector3(float(index)*.03125,float(variant)*-.0625,float(index%3)*.125))
func snapshot(skeleton: Skeleton3D)->Dictionary:
	var rows: Array=[]
	for index in skeleton.get_bone_count():
		rows.append({"name":skeleton.get_bone_name(index),"parent":skeleton.get_bone_parent(index),"enabled":skeleton.is_bone_enabled(index),"rest":skeleton.get_bone_rest(index),"global_rest":skeleton.get_bone_global_rest(index),"position":skeleton.get_bone_pose_position(index),"rotation":skeleton.get_bone_pose_rotation(index),"scale":skeleton.get_bone_pose_scale(index),"pose":skeleton.get_bone_pose(index),"global":skeleton.get_bone_global_pose(index),"no_override":skeleton.get_bone_global_pose_no_override(index),"override":skeleton.get_bone_global_pose_override(index)})
	return {"version":skeleton.get_version(),"roots":skeleton.get_parentless_bones(),"show_rest":skeleton.is_show_rest_only(),"rows":rows}
func make(parents: Array)->Skeleton3D:
	var skeleton:=Skeleton3D.new();skeleton.name="FixtureSkeleton"
	skeleton.modifier_callback_mode_process=Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	root.add_child(skeleton)
	for index in parents.size():skeleton.add_bone("bone"+str(index))
	for index in parents.size():
		skeleton.set_bone_parent(index,int(parents[index]))
		skeleton.set_bone_rest(index,pose(index,1))
		skeleton.set_bone_pose_position(index,pose(index).origin)
		skeleton.set_bone_pose_rotation(index,pose(index).basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(index,Vector3.ONE)
	skeleton.force_update_all_bone_transforms()
	return skeleton
func record(label: String,skeleton: Skeleton3D,trace: Array)->void:
	observations.append({"label":label,"state":snapshot(skeleton),"trace":trace.duplicate(true)})
func connect_trace(skeleton: Skeleton3D,context: Dictionary)->void:
	skeleton.skeleton_updated.connect(func():context.trace.append({"signal":"skeleton","state":snapshot(skeleton)}))
	skeleton.pose_updated.connect(func():
		context.trace.append({"signal":"pose","state":snapshot(skeleton)})
		if context.get("pose_mutation",false) and not context.get("pose_done",false):
			context.pose_done=true
			skeleton.set_bone_pose_position(0,Vector3(.75,-0.0,-.5));skeleton.force_update_all_bone_transforms())
	skeleton.rest_updated.connect(func():
		context.trace.append({"signal":"rest","state":snapshot(skeleton)})
		if context.get("rest_mutation",false) and not context.get("rest_done",false):
			context.rest_done=true
			skeleton.set_bone_pose_position(0,Vector3(-.25,.5,-.75));skeleton.force_update_all_bone_transforms())
	skeleton.bone_list_changed.connect(func():
		context.trace.append({"signal":"list","version":skeleton.get_version(),"count":skeleton.get_bone_count()})
		if context.get("list_mutation",false) and not context.get("list_done",false):
			context.list_done=true;skeleton.set_bone_parent(1,0)
			if context.get("list_reentry",false):skeleton.force_update_all_bone_transforms())
func ordinary_cases()->void:
	var flat: Array=[]
	for index in 65:flat.append(-1)
	var cases: Array=[{"name":"empty","parents":[]},{"name":"one","parents":[-1]},{"name":"flat65","parents":flat},{"name":"forest","parents":[-1,0,-1,2,3,-1,5,5,6]},{"name":"shuffled","parents":[3,-1,1,-1,0]}]
	for row in cases:
		var skeleton:=make(row.parents);var context:={"trace":[]};connect_trace(skeleton,context)
		var before_version:=skeleton.get_version()
		skeleton.force_update_all_bone_transforms();skeleton.force_update_all_bone_transforms()
		check(context.trace.size()==2 and context.trace[0]["signal"]=="pose" and context.trace[1]["signal"]=="pose",row.name+" emits both explicit clean forces")
		record(row.name+"-clean",skeleton,context.trace)
		if skeleton.get_bone_count()>0:
			context.trace.clear()
			skeleton.set_bone_pose_position(0,Vector3(-0.0,.375,-.125))
			skeleton.set_bone_pose_rotation(0,Quaternion(Vector3.UP,.27))
			skeleton.set_bone_pose_scale(0,Vector3(1,.875,1.125));skeleton.force_update_all_bone_transforms()
			record(row.name+"-changed",skeleton,context.trace)
			context.trace.clear();skeleton.force_update_bone_child_transform(skeleton.get_bone_count()-1)
			check(context.trace.is_empty(),row.name+" public child force keeps no pose signal")
			record(row.name+"-child-api",skeleton,context.trace)
			skeleton.set_show_rest_only(true);skeleton.force_update_all_bone_transforms();record(row.name+"-rest-only",skeleton,context.trace)
			skeleton.set_show_rest_only(false);skeleton.set_bone_enabled(0,false);skeleton.force_update_all_bone_transforms();record(row.name+"-disabled",skeleton,context.trace)
			skeleton.set_bone_enabled(0,true);skeleton.set_bone_rest(0,pose(0,4));skeleton.force_update_all_bone_transforms();record(row.name+"-rest-changed",skeleton,context.trace)
			skeleton.set_bone_global_pose_override(0,pose(0,7),.5,false);skeleton.force_update_all_bone_transforms();record(row.name+"-override-once",skeleton,context.trace)
			skeleton.set_bone_pose_position(0,Vector3(.125,.25,.375));skeleton.force_update_all_bone_transforms();record(row.name+"-override-reset",skeleton,context.trace)
			var bindings: Array=[]
			for named in [false,true]:
				var skin:=Skin.new()
				for index in skeleton.get_bone_count():
					if named:skin.add_named_bind(skeleton.get_bone_name(index),pose(index,2))
					else:skin.add_bind(index,pose(index,2))
				bindings.append(skeleton.register_skin(skin))
			skeleton.set_bone_pose_position(0,Vector3(.5,.25,-.125));skeleton.force_update_all_bone_transforms()
			skeleton.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
			check(bindings.size()==2,row.name+" two index/name skin bindings retained")
			record(row.name+"-bindings",skeleton,context.trace);bindings.clear()
		check(skeleton.get_version()==before_version,row.name+" pose/rest/force does not change topology version")
		skeleton.free()
func callback_cases()->void:
	for reentry in [false,true]:
		var skeleton:=make([-1,-1,-1,-1]);var context:={"trace":[],"list_mutation":true,"list_reentry":reentry};connect_trace(skeleton,context)
		skeleton.set_bone_parent(3,2);skeleton.force_update_all_bone_transforms()
		check(context.get("list_done",false),"Topology mutation callback exercised "+str(reentry))
		record("list-mutation-"+str(reentry),skeleton,context.trace);skeleton.free()
	for signal_kind in ["pose","rest"]:
		var skeleton:=make([-1,-1,0,-1]);var context:={"trace":[]};context[signal_kind+"_mutation"]=true;connect_trace(skeleton,context)
		if signal_kind=="rest":skeleton.set_bone_rest(0,pose(0,5))
		else:skeleton.set_bone_pose_position(0,Vector3(.125,0,0))
		skeleton.force_update_all_bone_transforms()
		check(context.get(signal_kind+"_done",false),signal_kind+" reentrant mutation exercised")
		record(signal_kind+"-mutation",skeleton,context.trace);skeleton.free()
func modifier_case()->void:
	var skeleton:=make([-1,-1,0,-1]);var context:={"trace":[]};connect_trace(skeleton,context)
	var modifier:=PoseModifier.new();skeleton.add_child(modifier);modifier.influence=.5
	modifier.modification_processed.connect(func():context.trace.append({"signal":"modifier","state":snapshot(skeleton)}))
	skeleton.advance(.125);skeleton.set_bone_pose_position(0,Vector3(.75,.5,.25))
	skeleton.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
	check(modifier.visits==1,"Modifier called once within updating context")
	record("modifier-half-influence",skeleton,context.trace);skeleton.free()
func run()->void:
	ordinary_cases();callback_cases();modifier_case()
	var metrics: Dictionary=ClassDB.class_call_static("NwnFrameProbe","feature_totals") if ClassDB.class_exists("NwnFrameProbe") else {}
	var report:={"success":checks.all(func(row):return row.ok),"checks":checks,"observations":observations.size(),"payload":Marshalls.raw_to_base64(var_to_bytes(observations)),"metrics":metrics,"scope":"Constructed real Skeleton3D public-state/synchronous-signal differential; no live game, GPU, visual or FPS result"}
	if not report_path.is_empty():
		var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
	print(JSON.stringify({"success":report.success,"checks":checks.size(),"observations":observations.size()}));quit(0 if report.success else 1)
