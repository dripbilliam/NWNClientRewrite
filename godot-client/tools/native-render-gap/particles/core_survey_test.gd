extends "res://tests/native_particle_presentation_test.gd"
func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var expected: bool="--particle-core-survey" in OS.get_cmdline_user_args() and not "--particle-core-survey=off" in OS.get_cmdline_user_args()
	var owner: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var initial: Dictionary=owner.call("dispatch",24,{"reset":true})
	check(bool(initial.enabled)==expected,"Default-off/startup/explicit-off selection is observed")
	check(initial.frame_calls==0 and initial.samples==0 and initial.clocks_per_frame==0,"Empty TLS state and no per-frame clocks")
	check(initial.process_id>0 and initial.report_thread_id>0 and initial.process_creation_100ns>0 and initial.report_thread_creation_100ns>0,"Actual Windows process/thread lifetime identities are available")
	check(initial.topology.error==0 and not initial.topology.rows.is_empty(),"Cold Windows CPU-set topology is available")
	var map: Dictionary={}
	for row: Dictionary in initial.topology.rows:
		map[str(row.group)+":"+str(row.logical_processor_index)]=row
		check(row.core_index>=0 and row.efficiency_class>=0,"OS core/efficiency values remain raw")
	var all_frames_ok: bool=true;var last: Dictionary={}
	for index: int in 240:
		last=owner.call("dispatch",1,{"delta":0.0,"view":view_packet(34000000+index,false)})
		all_frames_ok=all_frames_ok and not last.has("error")
	check(all_frames_ok and int(last.generation)==240 and int(last.registered)==0,"Actual presentation frames keep their normal output")
	var captured: Dictionary=owner.call("dispatch",24,{"topology":false})
	if expected:
		check(captured.frame_calls==240 and captured.samples==2 and captured.records.size()==2,"Actual frames take exactly one sample per120 calls")
		check(captured.records[0].frame==1 and captured.records[1].frame==121,"Stride has a documented deterministic entry phase")
		check(captured.frame_thread_id==captured.report_thread_id,"Actual Windows frame TID matches this main-thread fixture")
		var total: int=0
		for row: Dictionary in captured.histogram:
			total+=int(row.count);check(map.has(str(row.group)+":"+str(row.number)),"Every sampled logical CPU joins the OS topology")
		check(total==2 and captured.dropped_distinct_cores==0,"Fixed histogram accounts for all samples")
	else:check(captured.frame_calls==0 and captured.samples==0 and captured.records.is_empty() and captured.histogram.is_empty() and captured.frame_thread_id==0,"Disabled path never touches frame/TLS processor counters")
	var tested: Dictionary=owner.call("dispatch",24,{"topology":false,"selftest":true})
	check(tested.selftest.success and tested.selftest.main_tls_unchanged and tested.selftest.workers.size()==2,"Real native workers prove TLS isolation and bounded ring overwrite")
	check(tested.frame_calls==captured.frame_calls and tested.samples==captured.samples,"Cold worker oracle does not change actual frame statistics")
	owner.call("dispatch",5,{})
	check(owner.call("dispatch",24,{"topology":false}).samples==captured.samples,"Cold samples survive presentation closure without Node retention")
	owner=null;await process_frame;await process_frame
	# Preserve64-bit Windows creation times as strings before JSON/JS conversion.
	initial.process_creation_100ns_exact=str(initial.process_creation_100ns);initial.report_thread_creation_100ns_exact=str(initial.report_thread_creation_100ns)
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"initial":initial,"captured":captured,"selftest":tested.selftest,"scope":"Actual off/on presentation frame calls, Windows IDs/topology joins, fixed stride/histogram/ring and two native TLS workers; no affinity/priority/power or GPU changes"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
