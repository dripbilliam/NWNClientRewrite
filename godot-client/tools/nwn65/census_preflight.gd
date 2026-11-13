extends SceneTree
const Census=preload("res://tools/nwn65/final_native_run_census.gd")
const Rigs=preload("res://systems/model_rigs.gd")
const Pose=preload("res://systems/model_native_pose.gd")
class World extends Node3D:
	var instances: Dictionary={}
class FakePose extends RefCounted:
	var reads:=0
	var native_calls:=7
	var native_publish_calls:=9
	func storage_statistics()->Dictionary:
		reads+=1
		return {"apply_calls":7,"publish_calls":9,"snapshot_arrays":0,"read_arrays":0,"writes":0,"parts":1,"closed":false}
class Native extends RefCounted:
	var closed:=false
	var gob: Variant={"runsE0":[]}
	var pose: RefCounted
	func close()->void:
		if closed:return
		closed=true
		if pose!=null and pose.has_method("close"):pose.call("close")
var failures: Array=[]
var checks:=0
var library: Resource
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _init()->void:call_deferred("run")
func entry(owner: Node,native: RefCounted,ordinary: bool=false)->Dictionary:
	var pivot:=Node3D.new();owner.add_child(pivot)
	var models: Array=[{"player":null}] if ordinary else [{"native_owner":native,"player":null}]
	return {"root":pivot,"models":models,"skins":[],"attachments":[],"manual_poses":{}}
func primitive(value: Variant)->bool:
	if value is Object:return false
	if value is Dictionary:
		for key in value:
			if not primitive(key) or not primitive(value[key]):return false
	elif value is Array:
		for item in value:
			if not primitive(item):return false
	return true
func run()->void:
	library=load("res://native/particle_kernel.gdextension")
	check(library!=null and ClassDB.class_exists("NwnModelPoseStorage"),"accepted existing native storage class loads without rebuild")
	if library==null or not ClassDB.class_exists("NwnModelPoseStorage"):finish({});return
	var world:=World.new();root.add_child(world)
	var admitted:=Node3D.new();world.add_child(admitted);world.instances[100]=admitted
	var rigs:=Rigs.new();admitted.add_child(rigs)
	var other:=Rigs.new();world.add_child(other)
	var fake:=FakePose.new();var shared:=Native.new();shared.pose=fake
	shared.gob={"runsE0":[{"clip0":{"name":"blend_a"},"flagsC":0,"weight18":0.5,"time14":0.2,"speed8":1.0,"done24":0},{"clip0":{"name":"blend_b"},"flagsC":32,"weight18":0.5,"time14":0.1,"speed8":1.0,"done24":1}]}
	rigs.entities[1]=entry(rigs,shared)
	other.entities[2]=entry(other,shared)
	rigs.entities[3]=entry(rigs,null,true)
	var absent:=Native.new();absent.gob=null;rigs.entities[4]=entry(rigs,absent)
	var zero:=Native.new();zero.closed=true;rigs.entities[5]=entry(rigs,zero)
	# Real accepted NwnModelPoseStorage + actual script statistics() getter.
	# Prepare one dummy Part and one controller evaluation, then retain the
	# counter/transform state across census reads. No assets/GPU/benchmarks.
	var node:=Node3D.new();world.add_child(node)
	var view:=PackedByteArray();view.resize(0x240);view.fill(0);view.encode_float(28,1.0);view.encode_float(44,1.0)
	var record:={"object":node,"id30":0,"dirty60":0,"field8c":0,"view":view,"fields":{16:3,28:4,44:1},"materials":[],"source":{"type":"dummy","children":[]}}
	var context: RefCounted=ClassDB.instantiate("NwnModelPoseStorage")
	var configured: Dictionary=context.call("dispatch",0,{"parts":[record],"binding":[0],"root":0,"emitter_fields":{}})
	check(not configured.has("error"),"actual storage configured")
	var tree:={"id34":0,"flags98":0,"controllers78":[],"controllerCount80":0,"values88":PackedFloat32Array(),"children68":[],"childCount70":0}
	var plan: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_prepare",tree)
	check(not plan.has("error"),"actual numeric plan prepared outside census")
	if not plan.has("error"):
		var applied: Dictionary=context.call("dispatch",1,{"plan":plan.plan,"time":0.0,"weight":1.0,"scale":1.0,"manual":{},"scope":null,"profile":false})
		check(not applied.has("error"),"one actual evaluation/publication establishes nonzero counters")
	var actual_pose:=Pose.new();actual_pose.native_context=context
	var actual:=Native.new();actual.pose=actual_pose;rigs.entities[6]=entry(rigs,actual)
	var before: Dictionary=context.call("dispatch",7,{})
	var transform_before:=node.transform
	var gob_before: Dictionary=shared.gob.duplicate(true)
	var census: Dictionary=Census.collect(world)
	var after: Dictionary=context.call("dispatch",7,{})
	check(census.available and not census.scan_truncated,"actual ModelRigs tree census completes")
	check(census.rig_owners==2 and census.entries==6 and census.models==6,"actual rig owners/entries/models counted")
	check(census.ordinary_models==1 and census.native_model_references==5,"ordinary and native bindings separated")
	check(census.native_unique_owners==4 and census.native_owner_aliases==1,"native owner aliases deduplicated")
	check(census.current_run_histogram["2+"]==1 and census.current_run_histogram["0"]==2,"current actual run distribution literal")
	check(census.current_runs==2 and census.current_flag32_runs==1 and census.current_done_runs==1,"literal flag/done counts preserve pending semantics")
	check(census.native_unconfigured==1 and census.native_closed==1,"unconfigured and closed states explicit")
	check(census.native_model_reference_scopes.admitted==4 and census.native_model_reference_scopes.outside_admitted==1,"admitted versus outside bindings explicit even with alias")
	check(fake.reads==1,"statistics getter once for aliased native/pose owner")
	check(census.pose_storage_available==2,"fake and actual getter available separately")
	check(before==after and node.transform==transform_before,"actual getter/census leaves counters and transform unchanged")
	check(shared.gob==gob_before,"census never advances or mutates runs")
	check(int(census.storage_totals.apply_calls)==7+int(before.apply_calls) and int(census.storage_totals.publish_calls)==9+int(before.publish_calls),"existing cumulative counters summed once")
	check(primitive(census),"returned report contains primitive values only")
	var roundtrip: Variant=JSON.parse_string(JSON.stringify(census))
	check(roundtrip is Dictionary and roundtrip.native_unique_owners==4,"report serializes without scene ownership")
	var bounded: Dictionary=Census.collect(world,{"rows":1})
	check(bounded.rows.size()==1 and bounded.rows_omitted==3 and bounded.native_unique_owners==4,"row cap preserves aggregate counting")
	var limited: Dictionary=Census.collect(world,{"nodes":1})
	check(limited.scan_truncated and limited.truncation_reason=="nodes","node traversal cap explicit")
	var model_limited: Dictionary=Census.collect(world,{"models":1})
	check(model_limited.scan_truncated and model_limited.truncation_reason=="models","model traversal cap explicit")
	var run_limited: Dictionary=Census.collect(world,{"run_records":1})
	check(run_limited.run_records_inspected==1 and run_limited.run_records_omitted==1,"run metadata scan cap explicit while current array lengths remain known")
	check(not Census.collect(null).available,"missing/retired world cleanly unavailable")
	actual.close()
	var closed: Dictionary=context.call("dispatch",7,{})
	check(closed.closed and closed.parts==0 and actual_pose.native_context==null,"real owner retirement closes native state")
	var retired: Dictionary=Census.collect(world)
	check(retired.native_closed==2 and retired.pose_storage_available==1,"census after native retirement does not reopen or publish")
	check(context.call("dispatch",7,{})==closed,"closed getter remains read-only")
	var weak:=weakref(actual_pose)
	# Retain the primitive report across complete scene/native-owner teardown.
	for owner in [rigs,other]:owner.entities.clear()
	actual.pose=null;actual=null;actual_pose=null;context=null
	shared.pose=null;shared=null;fake=null;absent=null;zero=null
	world.free()
	check(weak.get_ref()==null,"census report does not retain native pose or scene owner")
	finish(census)
func finish(census: Dictionary)->void:
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"census":census,"scope":"Untimed actual ModelRigs/fake-run and accepted native storage getter lifecycle correctness only; no assets/FPS/GPU timing or per-advance ratio claim"}
	var output:="";for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
