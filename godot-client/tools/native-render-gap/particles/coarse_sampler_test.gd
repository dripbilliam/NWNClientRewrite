extends "res://tests/native_render_gap_scene_boundary_callbacks_test.gd"

func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var seed: Dictionary=make_owner(false,"fountain",0,false,false);seed.state.birthRate=240.0;seed.state.lifeExp=2.0;seed.state.spread=0.4;seed.state.deadspace=0.2
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":scene.get_instance_id(),"sourceId":scene.get_instance_id()},{ }).has("error"),"Counted simulation owner configures")
	seed.providers.clear()
	var native: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var calls: Array[int]=[0,0]
	var providers: Dictionary={"random":func():calls[0]+=1;return 1,"cosineDouble":func(_angle):calls[1]+=1;return 0.0}
	check(not native.call("dispatch",0,{"id":scene.get_instance_id(),"owner":owner,"providers":providers,"culling":false,"clock":func():return {"clip":"","time":0.0},"ready":func():return true}).has("error"),"Coarse sampler owner registers")
	check(not native.call("dispatch",15,{"enabled":true,"stride":1,"min_members":1,"coarse_phases":true,"reset":true}).has("error"),"Coarse sampler explicitly enables")
	var lighting: Dictionary={"lights":[{"position":[1.0,2.0,3.0],"color":[0.2,0.3,0.4],"radius":4.0,"fade":0.4},{"position":[5.0,6.0,7.0],"color":[0.1,0.2,0.3],"radius":8.0}]}
	check(not native.call("dispatch",1,{"delta":0.01,"view":view_packet(20000000,false),"native_surface_output":true,"lighting":lighting}).has("error"),"First unprofiled frame succeeds")
	var snapshot: Dictionary=native.call("dispatch",16,{})
	check(snapshot.samples==1 and snapshot.phase_success_samples==1 and snapshot.phase_clock_reads==4 and snapshot.coarse_phases,"One accepted frame records exactly four extra boundary reads")
	var row: Dictionary=snapshot.records[0];var sum:=0.0
	check(row.lighting_rows==2,"Parsed lighting row count comes from the actual local loaded snapshot")
	check(calls[0]>0 and calls[1]>0 and row.external_random_calls==calls[0] and row.external_cosine_calls==calls[1],"Measured random/cosine counts equal actual service callback observations")
	check(row.clock_provider_calls==1 and row.readiness_provider_calls==1 and row.fallback_provider_calls==0,"Clock/readiness/fallback call counts reflect actual selected frame boundaries")
	for key: String in ["input_parse_ms","entry_advance_ms","sort_geometry_pack_ms","counter_publish_ms","summary_ms"]:
		check(float(row[key])>=0.0 and float(snapshot.phase_success_means[key])==float(row[key]),"Finite nonnegative phase and exact one-sample mean "+key);sum+=float(row[key])
	check(row.phase_complete and absf(sum-float(row.wall_ms))<0.000000001,"Contiguous phase sum equals whole-frame wall sample")
	check(not native.call("dispatch",1,{"delta":0.01,"view":view_packet(20000001,false),"profile":true}).has("error"),"Detailed frame retains existing path")
	snapshot=native.call("dispatch",16,{})
	check(snapshot.samples==1 and snapshot.excluded_detailed_samples==1 and snapshot.phase_clock_reads==4,"Detailed frames are excluded without extra phase clocks")
	check(native.call("dispatch",1,{"delta":0.01}).has("error"),"Missing camera retains established error")
	snapshot=native.call("dispatch",16,{})
	check(snapshot.samples==2 and snapshot.errors==1 and snapshot.phase_success_samples==1 and snapshot.phase_clock_reads==4 and not snapshot.records[1].phase_complete,"Early error keeps whole error sample without fabricated complete phase data")
	check(not native.call("dispatch",15,{"enabled":true,"coarse_phases":false}).has("error"),"Phase clocks independently disable")
	check(not native.call("dispatch",1,{"delta":0.01,"view":view_packet(20000002,false)}).has("error"),"Whole-frame sampler continues without phase timing")
	snapshot=native.call("dispatch",16,{})
	check(snapshot.samples==3 and snapshot.successes==2 and snapshot.phase_success_samples==1 and snapshot.phase_clock_reads==4 and not snapshot.records[2].phase_complete,"Disabled phase mode preserves old history and ordinary whole-frame samples")
	native.call("dispatch",5,{});native=null;owner=null;providers.clear();scene.free()
	await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"sample":snapshot,"scope":"Optional contiguous sparse phase accounting, exclusions and unchanged errors; headless functional proof, no timing benefit claim"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
