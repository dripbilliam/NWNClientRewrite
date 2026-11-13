extends SceneTree
# Source-prepared full-owner differential. No candidate is implemented here.
# Candidate factory: create_owner()->Node derived from current Collision;
# oracle_statistics(owner)->Dictionary including actual native_cursor_calls.
const Collision=preload("res://systems/native_render/drive_collision_indexed.gd")
class QuerySpy extends RefCounted:
	var owner: WeakRef
	var label: String
	var events: Array
	var rows: Array=[]
	var ready:=true
	var mutation: Callable
	func query(ticket: Dictionary,a: Vector3,b: Vector3,radius: float,exclude: int,creatures: bool)->Dictionary:
		events.append([label,"query",ticket.duplicate(true),a,b,radius,exclude,creatures])
		if mutation.is_valid():mutation.call(owner.get_ref())
		return {"ready":ready,"rows":rows.duplicate(true)}
	func query_flat_control(ticket: Dictionary,a: Vector3,b: Vector3,radius: float,exclude: int,creatures: bool)->Dictionary:
		events.append([label,"flat",ticket.duplicate(true),a,b,radius,exclude,creatures])
		if mutation.is_valid():mutation.call(owner.get_ref())
		return {"ready":ready,"rows":rows.duplicate(true)}
var checks:=0
var failures: Array=[]
var cases: Array=[]
var factory
var self_check:=false
var output:=""
func check(value: bool,label: String)->void:
	checks+=1
	if not value and failures.size()<32:failures.append(label)
func state(radius: Variant=1.0)->Dictionary:return {"min":Vector3(-1,-1,-1),"max":Vector3(1,1,1),"radius":radius}
func setup(candidate: bool,mode: String)->Dictionary:
	var owner: Node=factory.create_owner() if candidate else Collision.new()
	owner.set_process(false)
	var events: Array=[];var spies: Dictionary={}
	var keys: Array=["first","second","third"]
	if mode=="unknown-key":keys[1]=42
	if mode=="stringname-key":keys[1]=StringName("second")
	for i in keys.size():
		var key: Variant=keys[i];var id:=101+i
		var spy:=QuerySpy.new();spy.owner=weakref(owner);spy.label=str(key);spy.events=events;spy.rows=[{"id":id,"witness":[id+100,1],"kind":"pwk"}];spies[key]=spy
		owner.static_groups[key]={"bounds":{"min_x":-1.0,"min_y":-1.0,"max_x":1.0,"max_y":1.0},"index":spy,"ticket":{"key":key}}
		owner.models[key]={"states":[{}]};owner.model_bounds[key]=[state()]
		owner.source_rows[id]={"witness":[id+100,1],"spec":{"door":false,"state":0},"pose":{"position":Vector3.ZERO,"rotation":0.0},"bounds_signature":[]}
	owner.retained_flat_control=mode=="flat-control"
	if mode=="empty-bounds-before-pending":
		owner.static_groups.first.bounds={};owner.model_bounds.first=[{"pending":true}]
	elif mode=="early-query-unready":
		spies.first.ready=false;owner.model_bounds.third=[{"pending":true}]
	elif mode=="witness-failure-before-later-query":spies.second.rows[0].witness=[999,1]
	elif mode=="door-state-out-of-range":owner.source_rows[102].spec={"door":true,"state":99}
	elif mode=="pending-model":
		owner.models.erase("second");owner.model_bounds.second=[{"pending":true}]
	elif mode=="replace-live-models":
		spies.first.mutation=func(current):current.models={"first":{"states":[{}]},"second":{"error":"arrived failure"},"third":{"states":[{}]}}
	elif mode=="replace-live-bounds":
		spies.first.mutation=func(current):current.model_bounds={"first":[state()],"second":[{"pending":true}],"third":[state()]}
	elif mode=="nested-same-alias-pending":
		spies.first.mutation=func(current):current.model_bounds.second[0].pending=true
	elif mode=="later-group-now-distant":
		spies.first.mutation=func(current):current.static_groups.second.bounds={"min_x":1000.0,"min_y":1000.0,"max_x":1001.0,"max_y":1001.0}
	elif mode=="replace-live-groups-retain-original-iterator":
		spies.first.mutation=func(current):
			var original: Dictionary=current.static_groups
			# Reverse LIVE dictionary order and add a new key. Original iteration
			# must continue its captured container; lookup uses replacement values.
			current.static_groups={"third":original.third,"second":original.second,"first":original.first,"not-in-original-iterator":original.first}
	elif mode=="source-witness-mutated-in-query":
		spies.first.mutation=func(current):current.source_rows[101].witness=[999,1]
	elif mode=="source-pose-mutated-in-query":
		spies.first.mutation=func(current):current.source_rows[102].pose.position=Vector3(100,0,0)
	return {"owner":owner,"events":events,"spies":spies}
func snapshot(owner: Node,result: Dictionary,events: Array)->Dictionary:
	var bindings: Array=[]
	for id in owner.source_rows:
		var binding: Dictionary=owner.source_rows[id]
		bindings.append([id,binding.get("witness"),binding.get("bounds_signature"),binding.get("world_bounds",{})])
	return {"result":result,"events":events,"bindings":bindings,"group_keys":owner.static_groups.keys(),"model_keys":owner.models.keys()}
func exercise(mode: String,from: Vector3,to: Vector3,radius: float)->void:
	var baseline:=setup(false,mode);var candidate:=setup(true,mode)
	var expected: Dictionary=baseline.owner.static_candidates(from,to,radius,77)
	var actual: Dictionary=candidate.owner.static_candidates(from,to,radius,77)
	var a:=snapshot(baseline.owner,expected,baseline.events);var b:=snapshot(candidate.owner,actual,candidate.events)
	check(var_to_bytes(a)==var_to_bytes(b),mode+" exact result/query order/expansion/witness/post-state")
	var use: Dictionary=factory.oracle_statistics(candidate.owner)
	check(int(use.get("native_cursor_calls",0))>0 or self_check,mode+" actual cursor used (baseline mirror cannot claim acceptance)")
	cases.append({"name":mode,"same":var_to_bytes(a)==var_to_bytes(b),"baseline":a,"candidate":b,"actual_use":use})
	baseline.owner.free();candidate.owner.free()
func _initialize()->void:call_deferred("run")
func run()->void:
	var candidate_script:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.substr(9)
		elif argument.begins_with("--candidate-script="):candidate_script=argument.substr(19)
		elif argument=="--baseline-self-check":self_check=true
	if output.is_empty():quit(2);return
	if candidate_script.is_empty():
		var pending:=FileAccess.open(output,FileAccess.WRITE);pending.store_string(JSON.stringify({"success":false,"pending":true,"reason":"Actual adapter factory is required; no baseline substitution","runtime_tests_claimed":false}));pending.close();quit(2);return
	var source=load(candidate_script)
	if source==null:quit(2);return
	factory=source.new()
	if not factory.has_method("create_owner") or not factory.has_method("oracle_statistics"):quit(2);return
	for mode in ["ordinary","flat-control","empty-bounds-before-pending","early-query-unready","witness-failure-before-later-query","door-state-out-of-range","pending-model","replace-live-models","replace-live-bounds","nested-same-alias-pending","later-group-now-distant","replace-live-groups-retain-original-iterator","source-witness-mutated-in-query","source-pose-mutated-in-query","unknown-key","stringname-key"]:
		exercise(mode,Vector3.ZERO,Vector3.ONE,0.5)
	for radius in [-1.0,0.0,-0.0,INF,-INF,NAN]:exercise("ordinary",Vector3.ZERO,Vector3.ONE,radius)
	await process_frame;await process_frame
	var report:={"success":failures.is_empty() and not self_check,"self_check_only":self_check,"checks":checks,"failures":failures,"cases":cases,"scope":"Source-prepared full static_candidates differential with observable index mutations. No candidate is supplied here. Runtime/engine/source pins and clean logs must be supplied by future runner; no performance claim."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close();factory=null
	quit(0 if failures.is_empty() else 1)
