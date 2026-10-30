extends "res://tests/native_particle_schedule_test.gd"
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
func boundary_owner(value: Variant) -> Dictionary:
	return {"spawnType":value,"lifeExp":1.0,"chunkName":"","active188":{"records":[],"capacity":0},"free130":{"records":[],"capacity":0},"birthRate":8.0,"source50":null,"renderMode1a8":0,"particleRot":0.0,"blurLength":0.0}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(Kernel.available() and Schedule.compiled(),"Compiled backend required for dword adapter check")
	lifetime_tests(); frame_tests()
	update_tests("native-fountain-update-observations",165,"fountain")
	update_tests("native-burst-single-update-observations",647,"burst/single")
	update_tests("native-fountain-spawn-words-v1",224,"fountain")
	var providers:={"moveParticles":func(_owner,_delta):pass}
	for invalid in [-2147483649,4294967296,-0.5,0.5,INF,-INF,NAN]:
		var owner:=boundary_owner(invalid)
		var out:=Kernel.simulate("fountain",owner,0.1,providers)
		check(str(out.get("error","")).contains("dword field") and owner.active188.records.is_empty(),"Invalid spawn word remains an explicit failure: "+str(invalid))
	var signed_owner:=boundary_owner(1)
	signed_owner.renderMode1a8=4294967295
	var signed_result:=Kernel.simulate("fountain",signed_owner,0.1,providers)
	check(str(signed_result.get("error","")).contains("integer field") and str(signed_result.get("error","")).contains("renderMode1a8"),"Other signed adapter fields are not widened")
	providers.clear()
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"backend":"compiled","binarySha256":BINARY_SHA,"originalEvidence":evidence,"publicConnections":0,"scope":"Existing 1907 schedule checks plus 224 unchanged-original fountain dword cases and invalid adapter boundaries. Explicit lower helper responses; not full effects, complete world or performance acceptance."},"\t")); file.close()
	print("NATIVE_PARTICLE_SPAWN_WORDS ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
