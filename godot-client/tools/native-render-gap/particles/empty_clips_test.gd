extends "res://tests/native_render_gap_hot_parameters_test.gd"

func configured_owner(scene: Node3D,clips: Dictionary,skip: bool) -> RefCounted:
	var seed: Dictionary=make_owner(false,"fountain",0,false,false)
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed.state,"parameters":{"sentinel":17},"clips":clips,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":scene.get_instance_id(),"sourceId":scene.get_instance_id(),"skipEmptyClipLookups":skip},{}).has("error"),"Actual owner configures with selected clip-lookup policy")
	seed.providers.clear();return owner

func compare_samples(owners: Array[RefCounted],clip: String,time: float,message: String) -> Array:
	var results: Array=[]
	for owner: RefCounted in owners:results.append(owner.call("dispatch",4,{"clip":clip,"time":time},{}))
	check(var_to_bytes(results[0])==var_to_bytes(results[1]),"Exact native sampled values/errors agree "+message)
	return results

func all_empty(scene: Node3D) -> void:
	for clips: Dictionary in [{},{"pause":{"channels":[]},"other":{"channels":[]}}]:
		var pair: Array[RefCounted]=[configured_owner(scene,clips,false),configured_owner(scene,clips,true)]
		for clip: String in ["pause","other","not-present",""]:
			var results: Array=compare_samples(pair,clip,NAN,"all copied clips empty / "+clip)
			check(not results[0].has("error") and results[0].sentinel==17,"All-empty sampling keeps the prior NaN/no-op behavior")
		var baseline: Dictionary=pair[0].call("dispatch",10,{},{});var candidate: Dictionary=pair[1].call("dispatch",10,{},{})
		check(candidate.configured and not candidate.has_any_channels and int(candidate.copied_channel_count)==0 and int(candidate.copied_clip_count)==clips.size(),"Cold proof inspects the exact copied native map")
		check(int(candidate.lookup_skips)==4 and int(candidate.lookup_calls)==0 and int(baseline.lookup_calls)==4 and int(baseline.lookup_skips)==0,"Only the all-empty private lookups are avoided")
		var before: Dictionary=candidate.duplicate(true)
		check(pair[1].call("dispatch",0,{},{}).has("error"),"Successful reconfigure still rejects first")
		check(var_to_bytes(before)==var_to_bytes(pair[1].call("dispatch",10,{},{})),"Rejected reconfigure preserves compiled guard and counters")
		var presenters: Array[RefCounted]=[]
		for index: int in pair.size():
			var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation");presenters.append(presentation)
			check(not presentation.call("dispatch",0,{"id":scene.get_instance_id(),"owner":pair[index],"providers":{},"culling":false}).has("error"),"Actual fast entry registers")
			check(not presentation.call("dispatch",1,{"delta":0.0,"view":view_packet(32000000+index,false)}).has("error"),"Fast frame still prepares current poses and simulation")
			var census: Dictionary=presentation.call("dispatch",22,{})
			check(census.owners.size()==1 and int(census.owners[0].sample_calls)==5,"Cold shared-path census proves actual sample boundary use")
			presentation.call("dispatch",5,{})
		check(var_to_bytes(without_ids(pair[0].call("dispatch",2,{},{})))==var_to_bytes(without_ids(pair[1].call("dispatch",2,{},{}))),"Empty-clip guard preserves actual typed frame state")
		presenters.clear();pair.clear()

func selected_empty_is_not_all_empty(scene: Node3D) -> void:
	var clips: Dictionary={"pause":{"channels":[]},"other":{"channels":[channel("sizemid",7.0)]}}
	var pair: Array[RefCounted]=[configured_owner(scene,clips,false),configured_owner(scene,clips,true)]
	check(not compare_samples(pair,"pause",NAN,"empty selected clip")[0].has("error"),"Empty selected clip still accepts NaN")
	check(not compare_samples(pair,"not-present",NAN,"missing selected clip")[0].has("error"),"Missing selected clip still accepts NaN")
	check(float(compare_samples(pair,"other",1.0,"nonempty selected clip")[0].sizemid)==7.0,"Other copied clip is still sampled")
	check(str(compare_samples(pair,"other",NAN,"nonempty clip invalid time")[0].get("error","")).contains("Invalid native emitter sampling clock"),"Nonempty clip still rejects NaN before cached constants")
	var info: Dictionary=pair[1].call("dispatch",10,{},{})
	check(info.has_any_channels and int(info.copied_clip_count)==2 and int(info.copied_channel_count)==1 and int(info.lookup_skips)==0,"Selected-empty is never misclassified as all-clips-empty")
	pair.clear()

func failed_configure(scene: Node3D) -> void:
	var pair: Array[RefCounted]=[]
	for skip: bool in [false,true]:
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner");pair.append(owner)
		check(not owner.call("dispatch",4,{"clip":"missing","time":NAN},{}).has("error"),"Preconfigure empty map retains its existing sample behavior")
		var seed: Dictionary=make_owner(false,"fountain",0,false,false)
		var invalid: Dictionary=channel("sizemid",9.0);invalid.components=2
		var config: Dictionary={"state":seed.state,"parameters":{},"clips":{"partial":{"channels":[channel("sizemid",4.0),invalid]}},"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":scene.get_instance_id(),"sourceId":scene.get_instance_id(),"skipEmptyClipLookups":skip}
		check(str(owner.call("dispatch",0,config,{}).get("error","")).contains("Unsupported native controller component width"),"Configure retains the original partial failure")
		var partial: Dictionary=owner.call("dispatch",10,{},{})
		check(not partial.configured and int(partial.copied_channel_count)==1,"Cold proof witnesses partial copied channel storage")
		seed.providers.clear()
	check(compare_samples(pair,"partial",NAN,"incomplete configure")[0].has("error"),"Incomplete owner never enables the empty shortcut")
	for index: int in pair.size():
		var seed: Dictionary=make_owner(false,"fountain",0,false,false)
		check(not pair[index].call("dispatch",0,{"state":seed.state,"parameters":{},"clips":{"empty":{"channels":[]}},"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":scene.get_instance_id(),"sourceId":scene.get_instance_id(),"skipEmptyClipLookups":index==1},{}).has("error"),"A later successful configure still works")
		var info: Dictionary=pair[index].call("dispatch",10,{},{})
		check(info.configured and info.has_any_channels and int(info.copied_channel_count)==1,"Success scans all retained private clips, including partial earlier storage")
		seed.providers.clear()
	check(float(compare_samples(pair,"partial",0.0,"retained partial clip after retry")[0].sizemid)==4.0,"Retry preserves its existing retained channel semantics")
	pair.clear()

func startup_selection(scene: Node3D) -> void:
	var seed: Dictionary=make_owner(false,"fountain",0,false,false)
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed.state,"clips":{"empty":{"channels":[]}},"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":scene.get_instance_id(),"sourceId":scene.get_instance_id()},{}).has("error"),"Owner without override configures from startup selection")
	var expected: bool="--particle-empty-clips=skip" in OS.get_cmdline_user_args() and not "--particle-empty-clips=legacy" in OS.get_cmdline_user_args()
	check(bool(owner.call("dispatch",10,{},{}).enabled)==expected,"Exact startup policy is observed in the actual native owner")
	check(not owner.call("dispatch",4,{"clip":"empty","time":NAN},{}).has("error"),"Startup mode keeps current empty-clip NaN behavior")
	var info: Dictionary=owner.call("dispatch",10,{},{})
	check(int(info.lookup_skips)==(1 if expected else 0) and int(info.lookup_calls)==(0 if expected else 1),"Startup policy actually selects the intended lookup branch")
	seed.providers.clear();owner=null

func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	all_empty(scene);selected_empty_is_not_all_empty(scene);failed_configure(scene);startup_selection(scene)
	scene.free();await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual private native copied clip maps: all-empty vs selected-empty, missing/empty/nonempty NaN order, shared Step state, successful-reconfigure rejection and failed-configure/retry retained vectors; no clocks/pose/simulation skipped"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
