extends "res://tests/native_particle_presentation_test.gd"
func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var expected: bool="--particle-key-survey" in OS.get_cmdline_user_args() and not "--particle-key-survey=off" in OS.get_cmdline_user_args()
	var probe: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var initial: Dictionary=probe.call("dispatch",23,{"reset":true})
	check(initial.enabled==expected and initial.frames==0 and initial.samples==0 and initial.clocks_per_frame==0,"Default off/on selection and empty TLS state")
	var frames: Dictionary=main_frames()
	var result: Dictionary=probe.call("dispatch",23,{})
	check(frames.frames==180,"Existing 180-frame state/geometry/RNG/callback oracle completed")
	if expected:
		check(result.frames==181 and result.samples==2 and result.stride==120,"Whole sampled attempts include closed-frame rejection at its original boundary")
		check(result.clip_lookups==16 and result.clip_hits==16,"Two sampled frames visit the eight existing native clip lookups")
		check(not result.global_keys.is_empty() and not result.private_fields.is_empty(),"Actual engine-key and private-field numeric bins activate")
		check(result.global_key_overflow==0 and result.field_overflow==0,"All numeric bins stay bounded without overflow")
		for row: Dictionary in result.global_keys:check(row.id>=0 and not row.name.is_empty() and row.reads>0,"Cold global names join retained registry IDs")
		for row: Dictionary in result.private_fields:check(row.id>=0 and not row.name.is_empty() and row.reads>=row.map_fallbacks,"Cold private field names join existing record schemas")
	else:
		check(result.frames==0 and result.samples==0 and result.clip_lookups==0 and result.global_keys.is_empty() and result.private_fields.is_empty(),"Disabled probe never touches TLS counters")
	var repeated: Dictionary=probe.call("dispatch",23,{})
	check(result==repeated,"Cold reporting neither counts itself nor changes live counter state")
	var tested: Dictionary=probe.call("dispatch",23,{"selftest":true})
	check(tested.selftest_success and tested.frames==result.frames and tested.samples==result.samples,"Two native worker TLS probes preserve main-thread state")
	probe=null;await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"initial":initial,"captured":result,"scope":"Existing actual180-frame semantic/RNG/geometry/lifetime oracle plus enabled/disabled sampled-counter and native TLS tests; no FPS/GPU claim"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
