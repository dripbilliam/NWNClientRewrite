extends RefCounted
# PRIVATE, final-report-only census. Never advances a clock, samples geometry,
# changes process flags, or retains scene/native owners in the returned data.
const Rigs=preload("res://systems/model_rigs.gd")
const MAX_NODES:=100000
const MAX_ENTRIES:=32768
const MAX_MODELS:=32768
const MAX_MODEL_ROWS:=128
const MAX_RUN_ROWS:=8
const MAX_RUN_RECORDS:=262144
const COUNTERS:=["apply_calls","publish_calls","snapshot_arrays","read_arrays","writes","parts"]

static func _has_property(owner: Object,name: String)->bool:
	for row in owner.get_property_list():
		if str(row.name)==name:return true
	return false
static func _counter_snapshot(pose: Object)->Dictionary:
	var result:={"available":false,"script_apply_calls":0,"script_publish_calls":0}
	if not is_instance_valid(pose):return result
	if _has_property(pose,"native_calls"):result.script_apply_calls=int(pose.get("native_calls"))
	if _has_property(pose,"native_publish_calls"):result.script_publish_calls=int(pose.get("native_publish_calls"))
	if not pose.has_method("storage_statistics"):return result
	var raw: Variant=pose.call("storage_statistics")
	if not raw is Dictionary:return result
	if raw.has("error"):result["error"]=str(raw.error);return result
	if not raw.has("apply_calls") or not raw.has("publish_calls"):return result
	result.available=true
	result["closed"]=bool(raw.get("closed",false))
	for key in COUNTERS:result[key]=int(raw.get(key,0))
	# Extra explicit flushes/configuration are not automatically redundant work.
	result["publish_per_apply"]=float(result.publish_calls)/int(result.apply_calls) if int(result.apply_calls)>0 else null
	result["extra_publish_calls"]=int(result.publish_calls)-int(result.apply_calls)
	return result
static func collect(world: Node,limits: Dictionary={})->Dictionary:
	var node_limit:=clampi(int(limits.get("nodes",MAX_NODES)),1,MAX_NODES)
	var entry_limit:=clampi(int(limits.get("entries",MAX_ENTRIES)),1,MAX_ENTRIES)
	var model_limit:=clampi(int(limits.get("models",MAX_MODELS)),1,MAX_MODELS)
	var row_limit:=clampi(int(limits.get("rows",MAX_MODEL_ROWS)),0,MAX_MODEL_ROWS)
	var run_limit:=clampi(int(limits.get("run_records",MAX_RUN_RECORDS)),1,MAX_RUN_RECORDS)
	var result:={"version":1,"available":is_instance_valid(world),"visited_nodes":0,"rig_owners":0,"entries":0,"models":0,"ordinary_models":0,"native_model_references":0,"native_owner_aliases":0,"native_unique_owners":0,"native_closed":0,"native_unconfigured":0,"pose_unique_owners":0,"pose_aliases":0,"pose_storage_available":0,"invalid_run_records":0,"current_runs":0,"current_run_histogram":{"0":0,"1":0,"2+":0},"current_nonflag32_runs":0,"current_flag32_runs":0,"current_done_runs":0,"native_scopes":{"admitted":0,"outside_admitted":0,"unknown":0},"native_tree_visible":0,"script_calls":{"apply":0,"publish":0},"storage_totals":{},"rows":[],"rows_omitted":0,"scan_truncated":false,"truncation_reason":"","limits":{"nodes":node_limit,"entries":entry_limit,"models":model_limit,"rows":row_limit,"runs_per_row":MAX_RUN_ROWS},"scope":"PRIVATE final-only actual rig/run snapshot. Raw cumulative apply/publish counts are not per-advance ratios or measured CPU cost. Tree visibility is not camera-frustum visibility; no clocks/evaluation/publication/process changes.","limitations":["No existing per-model NativeAnimation.advance_calls denominator; owner pose_frames includes different lifetimes/entities/initial sampling.","Current run histogram can miss transient combat/FX blends; flag32/done rows are literal state, not predicted next-step eligibility.","publish_calls includes explicit/configuration flushes; publish/apply ratio does not prove duplicate or safely removable publication.","Bounded source/row truncation is explicit. No original asset completeness, visual/FPS or live-Arelith acceptance."]}
	result["run_records_inspected"]=0;result["run_records_omitted"]=0
	result.limits["run_records"]=run_limit
	result["native_model_reference_scopes"]={"admitted":0,"outside_admitted":0,"unknown":0}
	result["scope_semantics"]="Reference scopes count every binding; native_scopes and rows use the first binding of each deduplicated native owner, with aliases reported separately."
	for key in COUNTERS:result.storage_totals[key]=0
	if not is_instance_valid(world):return result
	var has_admission: bool=_has_property(world,"instances") and world.get("instances") is Dictionary
	var admitted: Dictionary={}
	if has_admission:
		for instance in world.get("instances").values():
			if is_instance_valid(instance) and instance is Node:admitted[instance.get_instance_id()]=true
	var stack: Array=[world]
	var scopes: Dictionary={world.get_instance_id():"unknown" if not has_admission else "outside_admitted"}
	var seen_rigs: Dictionary={};var seen_native: Dictionary={};var poses: Dictionary={}
	while not stack.is_empty():
		if int(result.visited_nodes)>=node_limit:result.scan_truncated=true;result.truncation_reason="nodes";break
		var node: Node=stack.pop_back()
		if not is_instance_valid(node):continue
		result.visited_nodes+=1
		var scope:=str(scopes[node.get_instance_id()])
		if admitted.has(node.get_instance_id()):scope="admitted"
		for child in node.get_children():scopes[child.get_instance_id()]=scope;stack.append(child)
		if not node is Rigs or seen_rigs.has(node.get_instance_id()):continue
		seen_rigs[node.get_instance_id()]=true;result.rig_owners+=1
		for id in node.entities:
			if int(result.entries)>=entry_limit:result.scan_truncated=true;result.truncation_reason="entries";break
			result.entries+=1
			var entry: Dictionary=node.entities[id]
			var models: Array=entry.get("models",[])
			for model_index in models.size():
				if int(result.models)>=model_limit:result.scan_truncated=true;result.truncation_reason="models";break
				result.models+=1
				var model: Dictionary=models[model_index]
				if not model.has("native_owner") or not is_instance_valid(model.native_owner):result.ordinary_models+=1;continue
				result.native_model_references+=1
				result.native_model_reference_scopes[scope]+=1
				var native: Object=model.native_owner
				var native_id: int=native.get_instance_id()
				if seen_native.has(native_id):result.native_owner_aliases+=1;continue
				seen_native[native_id]=true;result.native_unique_owners+=1;result.native_scopes[scope]+=1
				var tree_visible: bool=is_instance_valid(entry.get("root")) and entry.root is Node3D and entry.root.is_visible_in_tree()
				if tree_visible:result.native_tree_visible+=1
				var closed: bool=_has_property(native,"closed") and native.get("closed")==true
				if closed:result.native_closed+=1
				var row:={"rig_owner_id":node.get_instance_id(),"entity_id":int(id),"model_index":model_index,"native_owner_id":native_id,"scope":scope,"tree_visible":tree_visible,"closed":closed,"rig_owner_pose_frames":int(node.stats.get("pose_frames",0)),"runs":[],"runs_omitted":0}
				var gob: Variant=native.get("gob") if _has_property(native,"gob") else null
				var runs: Variant=gob.get("runsE0") if gob is Dictionary else null
				if runs is Array:
					var count: int=runs.size();result.current_runs+=count
					result.current_run_histogram["2+" if count>=2 else str(count)]+=1;row["current_runs"]=count
					var inspect_count:=mini(count,maxi(0,run_limit-int(result.run_records_inspected)))
					result.run_records_omitted+=count-inspect_count
					row["run_records_inspected"]=inspect_count;row["run_records_omitted"]=count-inspect_count
					for run_index in inspect_count:
						var run: Variant=runs[run_index];result.run_records_inspected+=1
						if not run is Dictionary:result.invalid_run_records+=1;continue
						var flags:=int(run.get("flagsC",0))
						if flags&32:result.current_flag32_runs+=1
						else:result.current_nonflag32_runs+=1
						if int(run.get("done24",0))!=0:result.current_done_runs+=1
						if row.runs.size()<MAX_RUN_ROWS:
							var clip: Variant=run.get("clip0",{})
							row.runs.append({"clip":str(clip.get("name","")) if clip is Dictionary else "","flags":flags,"weight":float(run.get("weight18",0.0)),"time":float(run.get("time14",0.0)),"speed":float(run.get("speed8",0.0)),"done":int(run.get("done24",0))})
						else:row.runs_omitted+=1
				else:result.native_unconfigured+=1;row["current_runs"]=null
				var pose: Variant=native.get("pose") if _has_property(native,"pose") else null
				if pose is Object and is_instance_valid(pose):
					var pose_id: int=pose.get_instance_id();row["pose_owner_id"]=pose_id
					if poses.has(pose_id):result.pose_aliases+=1;row["pose_alias"]=true
					else:
						var counters: Dictionary=_counter_snapshot(pose);poses[pose_id]=counters;result.pose_unique_owners+=1
						result.script_calls.apply+=int(counters.script_apply_calls);result.script_calls.publish+=int(counters.script_publish_calls)
						if counters.available:
							result.pose_storage_available+=1
							for key in COUNTERS:result.storage_totals[key]+=int(counters[key])
					row["pose"]=poses[pose_id].duplicate(true)
				else:row["pose"]={"available":false}
				if result.rows.size()<row_limit:result.rows.append(row)
				else:result.rows_omitted+=1
			if result.scan_truncated:break
		if result.scan_truncated:break
	return result
