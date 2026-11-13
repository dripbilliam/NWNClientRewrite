extends SceneTree
const Output=preload("res://systems/native_render/native_scene_output.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Area=preload("res://systems/area_environment.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
var checks: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"name":label})
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	check(not Output.options({},false).enabled,"Ordinary launch does not activate the scene carrier")
	var args:={"native-surface-output":"true","native-lighting":"enhanced","native-postprocess-mask":"28","native-postprocess-intensity":".35","native-postprocess-vibrance":".7"}
	check(Output.options(args,false).has("error"),"Surface mode cannot silently use ordinary light admission")
	var invalid:=args.duplicate(); invalid["native-lighting"]="godot"; check(Output.options(invalid,true).has("error"),"Surface mode requires the compatible model material path")
	for mask in ["1","32","-1","4.5"]:
		invalid=args.duplicate(); invalid["native-postprocess-mask"]=mask; check(Output.options(invalid,true).has("error"),"Unsupported or malformed original stage mask rejects: "+mask)
	invalid=args.duplicate(); invalid["native-postprocess-intensity"]="nan"; check(Output.options(invalid,true).has("error"),"Non-finite contrast cannot enter GPU scene state")
	var settings:=Output.options(args,true); check(settings.enabled and settings.postprocess.mask==28,"Explicit full-scene mode selects the requested supported original tonal stages")
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original installed resources mount read-only")
	var world:=World.new(); world.catalog=catalog; world.set_meta("native_surface_output",true); world.set_meta("native_enhanced_lighting",true); root.add_child(world); world.set_process(false)
	world.focus_lighting.set_process(false); world.focus_lighting.enable_history(1)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.current=true
	var area:=Area.new(); world.add_child(area); area.configure({},world); area.camera=camera; area.set_process(false)
	var gamma:=Gamma.new(); root.add_child(gamma); gamma.attach(camera); gamma.effect.set_surface_output(true)
	var output:=Output.new(); root.add_child(output); output.bind(world,area,gamma,settings)
	for n in 4: await process_frame
	check(output.waiting_frames>0 and not output.configured,"Scene coordinator waits for actual area and admitted history rather than invented lighting")
	var fields:={"98":0x221133,"9c":0x331122,"a0":0x082040,"a4":28,"a8":false,"b8":0x110a08,"bc":0x050e18,"c0":0x664422,"c4":28,"c8":false,"d8":true,"dc":false,"e0":0,"104":0,"108":10}
	check(area.receive({"revision":1,"state":{"fields":fields,"time":{"timeOfDay":1,"transition":0},"minutesPerHour":1,"elapsed":0}}),"Actual native area state is accepted")
	area.advance(0); world.focus_lighting.history_frame(.1)
	for n in 12: await process_frame
	check(output.configured and not output.failed and output.error.is_empty(),"Coordinator binds the actual world/area/history to verified original postprocessing: "+output.error)
	check(gamma.snapshot().retail_surface_output and gamma.snapshot().postprocess.mask==28 and gamma.snapshot().passes>0,"The final GPU output chain is actually active")
	world.pool.native_lighting=true; world.pool.native_surface_output=true
	var material=world.pool.material({"mesh":{"diffuse":[.7,.5,.3]},"selfillum":[0,0,0]})
	var geometry:=MeshInstance3D.new(); geometry.mesh=QuadMesh.new(); geometry.material_override=material; world.add_child(geometry)
	var state:=Output.coverage(world); check(state.materials==1 and state.native==1 and state.unsupported.is_empty(),"Actual native model material reports its carrier contract")
	var regular:=StandardMaterial3D.new(); geometry.material_overlay=regular
	state=Output.coverage(world); check(state.unsupported.size()==1 and state.materials==2,"A regular Godot highlight/overlay is diagnosed instead of silently counted as native output")
	geometry.material_overlay=null; geometry.hide(); state=Output.coverage(world); check(state.geometry==0,"Hidden geometry does not inflate visible material coverage")
	geometry.show(); regular.set_meta("native_invisible_pick",true); geometry.material_override=regular
	state=Output.coverage(world); check(state.unsupported.is_empty(),"Explicit non-rendering pick proxies retain their separate contract")
	var viewport:=SubViewport.new(); world.add_child(viewport); var private_mesh:=MeshInstance3D.new(); private_mesh.mesh=QuadMesh.new(); private_mesh.material_override=StandardMaterial3D.new(); viewport.add_child(private_mesh)
	state=Output.coverage(world); check(state.private_viewports==1 and state.materials==1,"Private GUI 3D viewports are excluded from world-color acceptance")
	geometry.material_override=null; state=Output.coverage(world); check(state.unsupported.size()==1 and state.unsupported[0].get("class")=="EngineDefaultMaterial","An implicit Godot default material cannot be silently omitted from coverage")
	var final_state:=output.snapshot(); world.begin_retirement()
	for n in 3: await process_frame
	check(not output.is_processing() and not gamma.snapshot().scene_inputs.bound,"Retired world cannot retain a bound tonal scene")
	output.free(); gamma.free(); world.close(); world.free()
	for n in 3: await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"state":final_state,"publicConnections":0,"scope":"Explicit full-world research settings, actual native area/history/final compositor binding, visible material contract coverage and lifetime. Local session/replay and matched original rooms are separate acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
