extends "res://tests/native_physical_fog_endpoints_test.gd"
# Diagnostic only: separates factory construction from any BSP registration.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	trace_phase("factory-only-before-world")
	if OS.get_cmdline_user_args().has("--probe-kernel-load"):
		check(Resolver.Kernel.kernel_available(),"Existing BSP kernel loads without creating resolver state")
		trace_phase("factory-after-kernel-load")
	scene=WorldPort.new();root.add_child(scene);scene.pool.native_lighting=true;scene.pool.native_surface_output=true
	trace_phase("factory-only-before-template")
	var template=scene.pool.model_template(bundle())
	check(template!=null,"Actual static native template prepares without resolver")
	trace_phase("factory-only-before-placement")
	var model=template.create();scene.add_child(model)
	trace_phase("factory-only-after-placement")
	check(model.meshes.size()==1,"Actual static Placement contains original physical mesh")
	finish()
