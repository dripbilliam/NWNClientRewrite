extends "res://tests/native_render_gap_scene_boundary_callbacks_test.gd"

func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var before: Dictionary=presentation.call("dispatch",21,{})
	var expected: bool="--particle-resident-text=borrow" in OS.get_cmdline_user_args() and not "--particle-resident-text=legacy" in OS.get_cmdline_user_args()
	check(before.borrowed==expected,"Actual private string startup mode is observed")
	var component: Dictionary=presentation.call("dispatch",20,{})
	check(component.success and int(component.checks)>=25,"Actual resident type/current-value/retirement equivalence passes")
	for row: Dictionary in component.cases:check(bool(row.success),"Resident string: "+str(row.message))
	check(var_to_bytes(before)==var_to_bytes(presentation.call("dispatch",21,{})),"Cold oracle restores selected mode and prior live counters")
	presentation=null
	var scene:=Node3D.new();root.add_child(scene)
	var owner: RefCounted=boundary_owner(scene,scene)
	presentation=ClassDB.instantiate("NwnParticlePresentation")
	check(not presentation.call("dispatch",0,{"id":scene.get_instance_id(),"owner":owner,"providers":{},"culling":false}).has("error"),"Actual typed owner registers")
	check(not presentation.call("dispatch",1,{"delta":0.0,"view":view_packet(31000000,false)}).has("error"),"Admitted empty actual owner runs its normal string boundary")
	var after: Dictionary=presentation.call("dispatch",21,{})
	check(int(after.borrowed_reads if expected else after.legacy_reads)>int(before.borrowed_reads if expected else before.legacy_reads),"Actual production Bridge/read_emitter branch use is witnessed")
	presentation.call("dispatch",5,{});presentation=null;owner=null;scene.free()
	await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"component":component,"before":before,"after":after,"scope":"Same-DLL resident private string type/error/current-value equivalence, real opaque-object retirement, selected startup route and actual typed owner boundary; no lazy hit ownership"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
