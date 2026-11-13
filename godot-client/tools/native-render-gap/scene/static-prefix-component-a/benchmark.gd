extends SceneTree
const Collision=preload("res://systems/native_render/drive_collision_indexed.gd")
const Spatial=preload("res://systems/native_render/drive_spatial_index.gd")
const Factory=preload("res://tools/native-render-gap/scene/static-prefix-candidate-b7/candidate_factory.gd")
var component_output:=""
var component_role:=""
var component_checks: Array=[]
func component_check(ok: bool,label: String)->void:component_checks.append({"ok":ok,"label":label})
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):component_output=arg.trim_prefix("--report=")
		elif arg.begins_with("--component-role="):component_role=arg.trim_prefix("--component-role=")
	call_deferred("run")
func run()->void:
	if component_role not in ["baseline","candidate"] or component_output.is_empty() or FileAccess.file_exists(component_output):quit(2);return
	var factory:=Factory.new()
	var owner: Node=Collision.new() if component_role=="baseline" else factory.create_owner()
	owner.set_process(false)
	var expected_script: String="res://systems/native_render/drive_collision_indexed.gd" if component_role=="baseline" else "res://tools/native-render-gap/scene/static-prefix-candidate-b7/candidate_owner.gd"
	component_check(owner.get_script().resource_path==expected_script,"Actual selected owner class")
	for index in 463:
		var key: String="canonical-%04d"%index
		var id:=1000+index;var witness: Array=[id+100,1]
		var center:=Vector3.ZERO if index==0 else Vector3(1000+index*4,1000,0)
		var spatial:=Spatial.new();var ticket: Dictionary=spatial.begin([771,3,91])
		var added: Dictionary=spatial.upsert_shape(ticket,id,witness,1,"pwk",center-Vector3.ONE,center+Vector3.ONE,false,index)
		component_check(added.get("accepted",false),"Actual spatial shape "+str(index))
		owner.static_groups[key]={"bounds":{"min_x":float(center.x)-1.0,"min_y":float(center.y)-1.0,"max_x":float(center.x)+1.0,"max_y":float(center.y)+1.0},"index":spatial,"ticket":ticket}
		owner.models[key]={"states":[{}]};owner.model_bounds[key]=[{"min":Vector3(-1,-1,-1),"max":Vector3(1,1,1),"radius":1.0}]
		owner.source_rows[id]={"witness":witness,"spec":{"door":false,"state":0},"pose":{"position":center,"rotation":0.0},"bounds_signature":[]}
	var expected: PackedByteArray
	for warm in 16:
		var result: Dictionary=owner.static_candidates(Vector3.ZERO,Vector3.ONE,0.5,77)
		component_check(result.get("ready",false) and result.get("rows",[]).size()==1,"Warm canonical result "+str(warm))
		var bits: PackedByteArray=var_to_bytes(result)
		if warm==0:expected=bits
		else:component_check(bits==expected,"Warm exact result bytes "+str(warm))
	var batches: Array=[]
	for batch in 8:
		var results: Array=[];results.resize(64)
		var begin_usec:=Time.get_ticks_usec()
		for query in 64:results[query]=owner.static_candidates(Vector3.ZERO,Vector3.ONE,0.5,77)
		var elapsed_usec:=Time.get_ticks_usec()-begin_usec
		# Encoding, equality, report construction and counter reads are OUTSIDE timers.
		for query in 64:component_check(var_to_bytes(results[query])==expected,"Measured exact result bytes "+str(batch)+"/"+str(query))
		batches.append({"batch":batch,"queries":64,"elapsed_usec":elapsed_usec})
		results.clear()
	var use: Dictionary={} if component_role=="baseline" else factory.oracle_statistics(owner)
	if component_role=="candidate":
		component_check(use.get("failures",[1]).is_empty(),"Candidate no unsupported wrapper failure")
		component_check(int(use.get("native_scanned",0))==463*528 and int(use.get("native_admit",0))==528 and int(use.get("native_fallback",-1))==0,"Actual native canonical coverage all528 queries")
		component_check(int(use.get("fast_terminal_scans",0))==528 and int(use.get("rollback_count",-1))==0,"Actual conditional terminal all528 queries")
	var owner_script: String=owner.get_script().resource_path
	owner.free();factory=null
	await process_frame;await process_frame
	var report:={"success":component_checks.all(func(row):return row.ok),"checks":component_checks,"role":component_role,"owner_script":owner_script,"groups":463,"warm_queries":16,"timed_batches":8,"queries_per_batch":64,"batches":batches,"result_bytes":expected.hex_encode(),"actual_use":use,"scope":"Synthetic canonical463 component only. Batch duration includes direct calls plus fixed results-slot assignment; exact bytes checked outside timers. No rendered-world, actual movement call cost or FPS claim."}
	var file:=FileAccess.open(component_output,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close();quit(0 if report.success else 1)
