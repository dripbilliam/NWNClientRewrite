extends SceneTree

var checks:=0
var failures: Array=[]
var callbacks: Array=[]
var observed: Array=[]
var native

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func fallback(delta: float) -> void:callbacks.append(delta)
func frame(profile: bool) -> Dictionary:
	var planes:=PackedFloat32Array();planes.resize(24)
	var result: Dictionary=native.call("dispatch",1,{"delta":0.016,"profile":profile,"view":{"stamp":observed.size()+1,"position":[0,0,0],"camera":[1,0,0,0],"planes":planes.to_byte_array()}})
	check(not result.has("error"),"frame dispatch succeeds")
	observed.append(result.duplicate(true))
	if profile:
		var phases: Dictionary=result.get("phases",{})
		for name in ["particle_native_eligibility_clock_ms","particle_native_controls_ms","particle_native_pose_ms","particle_native_admission_ms","particle_native_simulation_ms","particle_native_geometry_ms","particle_native_pack_sort_ms","particle_native_counters_summary_ms","particle_native_eligibility_checks_ms","particle_native_source_checks_ms","particle_native_clock_boundary_ms","particle_native_other_loop_ms"]:
			check(phases.get(name) is float and is_finite(float(phases[name])),"finite phase: "+name)
		var split: float=float(phases.get("particle_native_eligibility_checks_ms",0))+float(phases.get("particle_native_source_checks_ms",0))+float(phases.get("particle_native_clock_boundary_ms",0))+float(phases.get("particle_native_other_loop_ms",0))
		check(absf(split-float(phases.get("particle_native_eligibility_clock_ms",INF)))<0.000001,"new split reconciles with unchanged loop residual")
	else:check(not result.has("phases"),"profile-off result has no phase instrumentation")
	return result
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(ClassDB.class_exists("NwnParticlePresentation") and ClassDB.can_instantiate("NwnParticlePresentation"),"native extension class is instantiable")
	var dispatch_abi:=false
	for method in ClassDB.class_get_method_list("NwnParticlePresentation",true):
		if method.name=="dispatch":dispatch_abi=method.args.size()==2
	check(dispatch_abi,"existing dispatch ABI retains two arguments")
	if failures.is_empty():
		native=ClassDB.instantiate("NwnParticlePresentation")
		var result:=frame(true)
		check(int(result.registered)==0 and int(result.prepared)==0 and int(result.vertices)==0,"empty native owner summary remains empty")
		var emitter:=Node3D.new();root.add_child(emitter);var id:=emitter.get_instance_id()
		result=native.call("dispatch",0,{"id":id,"fallback":fallback,"enabled":false})
		check(not result.has("error"),"register fallback through unchanged ABI")
		frame(true);check(callbacks.is_empty(),"disabled entry preserves eligibility short-circuit")
		native.call("dispatch",4,{"id":id,"enabled":true});result=frame(true)
		check(callbacks==[0.016] and int(result.fallbacks)==1,"eligible fallback executes once with original delta")
		emitter.hide();frame(true)
		check(callbacks.size()==1,"hidden entry cannot execute fallback")
		emitter.show();result=frame(false)
		check(callbacks==[0.016,0.016] and int(result.fallbacks)==1,"profile-off fallback call count and delta are unchanged")
		emitter.free();frame(true)
		check(callbacks.size()==2,"freed node identity remains ineligible")
		native.call("dispatch",3,{"id":id});result=native.call("dispatch",7,{})
		check(int(result.registered)==0,"existing removal ABI retires retained entry")
		native.call("dispatch",5,{});native=null
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"native_pid":OS.get_process_id(),"callbacks":callbacks,"frames":observed,"graphical_processes":0,"server_connections":0,"scope":"Current main DLL headless dispatch ABI, empty/fallback eligibility/lifetime and profile-on/off measurement schema only. No fast-emitter population, world, renderer, performance or semantic parity acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
