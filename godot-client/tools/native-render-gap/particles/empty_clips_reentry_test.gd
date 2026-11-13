extends "res://tests/native_render_gap_hot_parameters_test.gd"

class ConfigureOnRetire:
	extends RefCounted
	var target: WeakRef
	var configuration: Dictionary
	var events: Array
	func _notification(what: int) -> void:
		if what!=NOTIFICATION_PREDELETE:return
		var owner: RefCounted=target.get_ref()
		if owner==null:events.append("missing owner");return
		var result: Dictionary=owner.call("dispatch",0,configuration,{})
		events.append(result.get("error","nested configure success"))

func scenario(scene: Node3D,skip: bool) -> Dictionary:
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	var nested: Dictionary=make_owner(false,"fountain",0,false,false)
	var events: Array=[]
	var trigger: ConfigureOnRetire=ConfigureOnRetire.new();trigger.target=weakref(owner);trigger.events=events
	trigger.configuration={"state":nested.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":scene.get_instance_id(),"sourceId":scene.get_instance_id(),"skipEmptyClipLookups":skip}
	var initial: Dictionary=make_owner(false,"fountain",0,false,false);initial.state.configure_trigger=trigger
	var first: Dictionary=owner.call("dispatch",0,{"state":initial.state,"update":"invalid"},{})
	check(first.has("error"),"Initial failed configure retains a private opaque object")
	initial.state.erase("configure_trigger");trigger=null
	check(events.is_empty(),"Private state is the last owner until the retry replacement")
	var outer: Dictionary=make_owner(false,"fountain",0,false,false)
	var invalid: Dictionary=channel("sizemid",9.0);invalid.components=2
	var output: Dictionary=owner.call("dispatch",0,{"state":outer.state,"parameters":{},"clips":{"partial":{"channels":[channel("sizemid",4.0),invalid]}},"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":scene.get_instance_id(),"sourceId":scene.get_instance_id(),"skipEmptyClipLookups":skip},{})
	check(events==["nested configure success"],"Actual predelete callback reenters configure exactly once")
	check(str(output.get("error","")).contains("Unsupported native controller component width"),"Outer configure retains its later original failure")
	var before: Dictionary=owner.call("dispatch",10,{},{})
	check(before.configured and int(before.copied_channel_count)==1,"Nested success and outer partial vector are both observable")
	var sampled: Dictionary=owner.call("dispatch",4,{"clip":"partial","time":0.0},{})
	var after: Dictionary=owner.call("dispatch",10,{},{})
	initial.providers.clear();nested.providers.clear();outer.providers.clear();owner=null
	return {"sampled":sampled,"before":before,"after":after,"events":events}

func run() -> void:
	var report: String="";var expect_divergence: bool=false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg=="--expect-divergence":expect_divergence=true
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var baseline: Dictionary=scenario(scene,false);var candidate: Dictionary=scenario(scene,true)
	var equivalent: bool=var_to_bytes(baseline.sampled)==var_to_bytes(candidate.sampled)
	check(float(baseline.sampled.get("sizemid",-1.0))==4.0,"Legacy route still samples the retained actual channel")
	if expect_divergence:check(not equivalent,"Earlier candidate is rejected by the observed nested-configure divergence")
	else:
		check(equivalent and float(candidate.sampled.get("sizemid",-1.0))==4.0,"Unsealed nested configuration retains the exact legacy lookup")
		check(not bool(candidate.after.map_sealed) and int(candidate.after.configure_depth)==0 and int(candidate.after.lookup_skips)==0,"Failed outer configuration stays unsealed and takes its fresh lookup")
	scene.free();await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"expect_divergence":expect_divergence,"equivalent":equivalent,"baseline":baseline,"candidate":candidate,"scope":"Real RefCounted predelete callback: nested configure succeeds, outer configure appends a channel and fails; cached emptiness must remain unsealed"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
