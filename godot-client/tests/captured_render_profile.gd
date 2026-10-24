extends SceneTree
# Diagnostic only: complete existing captured geometry, frozen poses/legacy GLB.
# This is neither native asset-path acceptance nor moving-gameplay acceptance.
var args: Dictionary={}
var report: Dictionary={"passed":false,"accepted":false,"scope":"Existing full captured-room render-cost diagnosis; frozen legacy GLB input, not native asset-path or gameplay/FPS acceptance"}
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame; await RenderingServer.frame_post_draw
func distribution(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted:=values.duplicate(); sorted.sort(); var total:=0.0
	for value in values: total+=float(value)
	return {"mean":total/values.size(),"median":sorted[sorted.size()/2],"p95":sorted[mini(sorted.size()-1,ceili(sorted.size()*0.95)-1)],"maximum":sorted.back(),"samples":values.size()}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("profile-report") or not args.has("scene") or FileAccess.file_exists(args["profile-report"]) or DisplayServer.get_name()=="headless": quit(2); return
	var main=load("res://main.tscn").instantiate(); root.add_child(main)
	await frame()
	if main.report.has("failure") or main.camera==null:
		report.failure=main.report.get("failure","Captured room camera missing"); main.clear_room(); main.queue_free(); await frame(); write_report(); quit(1); return
	report.scene=main.report.duplicate(true)
	var meshes: Array=main.room_owner.find_children("*","MeshInstance3D",true,false)
	var unique_meshes: Dictionary={}; var unique_materials: Dictionary={}; var lights: Array=main.room_owner.find_children("*","Light3D",true,false); var shadow_lights:=0
	for mesh in meshes:
		if mesh.mesh!=null: unique_meshes[mesh.mesh.get_instance_id()]=true
		if mesh.material_override!=null: unique_materials[mesh.material_override.get_instance_id()]=true
		elif mesh.mesh!=null:
			for index in mesh.mesh.get_surface_count():
				var material=mesh.mesh.surface_get_material(index)
				if material!=null: unique_materials[material.get_instance_id()]=true
	for light in lights:
		if light.shadow_enabled: shadow_lights+=1
	report.resources={"mesh_nodes":meshes.size(),"unique_mesh_resources":unique_meshes.size(),"unique_material_resources":unique_materials.size(),"lights":lights.size(),"shadow_lights":shadow_lights}
	meshes.clear(); lights.clear()
	var viewport:=root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var deadline:=Time.get_ticks_msec()+16000
	while Time.get_ticks_msec()<deadline: await frame()
	var frames: Array=[]; var gpu: Array=[]; var cpu: Array=[]; var setup: Array=[]; var process: Array=[]; var physics: Array=[]; var draws: Array=[]
	for index in 240:
		var began:=Time.get_ticks_usec(); await frame()
		frames.append((Time.get_ticks_usec()-began)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport)); cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport)); setup.append(RenderingServer.get_frame_setup_time_cpu())
		process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000); physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000); draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	report.metrics={"frame_ms":distribution(frames),"render_gpu_ms":distribution(gpu),"render_cpu_ms":distribution(cpu),"frame_setup_cpu_ms":distribution(setup),"process_ms":distribution(process),"physics_ms":distribution(physics),"draw_calls":distribution(draws)}
	root.get_texture().get_image().save_png(str(args["profile-report"]).trim_suffix(".json")+".png")
	report.passed=int(main.report.source_inventory_objects)==898 and int(main.report.mesh_instances)==4145 and not main.report.has("failure")
	var room_ref: WeakRef=weakref(main.room_owner); main.clear_room(); await frame(); await frame(); main.queue_free(); await frame(); await frame()
	report.room_retired=room_ref.get_ref()==null; report.passed=report.passed and report.room_retired
	write_report(); quit(0 if report.passed else 1)
func write_report() -> void:
	var hashes: Dictionary={}
	for name in ["tests/captured_render_profile.gd","main.gd","main.tscn","project.godot"]: hashes[name]=FileAccess.get_sha256("res://"+name)
	report.sourceSha256=hashes
	var file:=FileAccess.open(args["profile-report"],FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
