extends "res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture.gd"
# V1 stays immutable. Canonical positives cannot pass through MockIndex fallback.
const ActualSpatial=preload("res://systems/native_render/drive_spatial_index.gd")
func setup(candidate: bool,mode: String)->Dictionary:
	var value: Dictionary=super.setup(candidate,mode)
	if not mode.begins_with("canonical-"):return value
	var owner: Node=value.owner
	owner.static_groups={};owner.models={};owner.model_bounds={};owner.source_rows={}
	owner.retained_flat_control=mode=="canonical-flat-control"
	var count:=463 if mode=="canonical-463-groups" else 3
	for index in count:
		var key: String="canonical-%04d"%index
		var id:=1000+index;var witness: Array=[id+100,1]
		var center:=Vector3.ZERO if index==0 or mode!="canonical-463-groups" else Vector3(1000+index*4,1000,0)
		var spatial:=ActualSpatial.new()
		var ticket: Dictionary=spatial.begin([771,3,91])
		# An actual current canonical tree/group query, including source order,
		# row witness, own ticket and exact world-bounds downstream checks.
		var added: Dictionary=spatial.upsert_shape(ticket,id,witness,1,"pwk",center-Vector3.ONE,center+Vector3.ONE,false,index)
		check(added.accepted,mode+" canonical spatial source admitted "+str(index))
		owner.static_groups[key]={"bounds":{"min_x":float(center.x)-1.0,"min_y":float(center.y)-1.0,"max_x":float(center.x)+1.0,"max_y":float(center.y)+1.0},"index":spatial,"ticket":ticket}
		owner.models[key]={"states":[{}]};owner.model_bounds[key]=[state()]
		owner.source_rows[id]={"witness":witness,"spec":{"door":false,"state":0},"pose":{"position":center,"rotation":0.0},"bounds_signature":[]}
	if mode=="canonical-pending-after-admit":owner.model_bounds["canonical-0001"][0].pending=true
	return value
func exercise(mode: String,from: Vector3,to: Vector3,radius: float)->void:
	super.exercise(mode,from,to,radius)
	if not mode.begins_with("canonical-"):return
	var observed: Dictionary=cases[-1].actual_use
	check(int(observed.get("native_scanned",0))>0,mode+" actual native scanning required independently of fallback calls")
	check(int(observed.get("native_admit",0))>0,mode+" actual native admission required independently of fallback calls")
	check(int(observed.get("native_fallback",-1))==0,mode+" canonical positive must not silently use fallback")
	if mode=="canonical-463-groups":
		check(int(observed.get("native_scanned",0))==463,"Large canonical case actually scans463 groups natively")
		check(int(observed.get("native_admit",0))==1,"Large canonical case admits only near group")
		check(cases[-1].candidate.result.ready and cases[-1].candidate.result.rows.size()==1,"Large canonical full owner has one final collision row")
func run()->void:
	var candidate_script:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.substr(9)
		elif argument.begins_with("--candidate-script="):candidate_script=argument.substr(19)
		elif argument=="--baseline-self-check":self_check=true
	if output.is_empty():quit(2);return
	if candidate_script.is_empty():
		var missing:=FileAccess.open(output,FileAccess.WRITE);missing.store_string(JSON.stringify({"success":false,"pending":true,"reason":"Actual adapter factory required; canonical native counters cannot be substituted"}));missing.close();quit(2);return
	var source=load(candidate_script)
	if source==null:quit(2);return
	factory=source.new()
	if not factory.has_method("create_owner") or not factory.has_method("oracle_statistics"):quit(2);return
	for mode in ["ordinary","flat-control","empty-bounds-before-pending","early-query-unready","witness-failure-before-later-query","door-state-out-of-range","pending-model","replace-live-models","replace-live-bounds","nested-same-alias-pending","later-group-now-distant","replace-live-groups-retain-original-iterator","source-witness-mutated-in-query","source-pose-mutated-in-query","unknown-key","stringname-key"]:
		exercise(mode,Vector3.ZERO,Vector3.ONE,0.5)
	for radius in [-1.0,0.0,-0.0,INF,-INF,NAN]:exercise("ordinary",Vector3.ZERO,Vector3.ONE,radius)
	for mode in ["canonical-admitted","canonical-flat-control","canonical-pending-after-admit","canonical-463-groups"]:
		exercise(mode,Vector3.ZERO,Vector3.ONE,0.5)
	await process_frame;await process_frame
	var report:={"success":failures.is_empty() and not self_check,"self_check_only":self_check,"checks":checks,"failures":failures,"cases":cases,"scope":"Source-prepared V2 full-owner differential:22 opaque/mutation cases plus4 actual canonical Spatial positives including463 groups. No candidate/execution/acceptance claimed by source preparation."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close();factory=null
	quit(0 if failures.is_empty() else 1)
