extends "res://tests/native_surface_output_pixels_test.gd"
const LiveWorld=preload("res://systems/native_render/live_world.gd")
const Area=preload("res://systems/area_environment.gd")
const SurfaceState=preload("res://systems/native_render/native_surface_state.gd")
class CameraState extends RefCounted:
	var distance:=20.0
	var follow_state=null
	var target:=Vector3.ZERO
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256); selected_catalog=Catalog.new()
	check(selected_catalog.mount_install(install),"Original shader catalog mounts read-only")
	var world:=LiveWorld.new(); world.set_meta("native_surface_output",true); world.set_meta("native_enhanced_lighting",true); root.add_child(world); world.set_process(false)
	world.pool.native_lighting=true; world.pool.native_standard=true; world.pool.native_surface_output=true
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4; camera.make_current()
	var area:=Area.new(); world.add_child(area); area.configure({},world); area.camera=camera; area.controller=CameraState.new(); area.set_process(false)
	var gamma:=Gamma.new(); root.add_child(gamma); gamma.attach(camera); gamma.effect.set_surface_output(true)
	var fields:={"98":0x332211,"9c":0x664422,"a0":0x554433,"a4":25,"a8":false,"ac":0,"b0":-1,"b4":0,"b8":0xbbccdd,"bc":0x99aabb,"c0":0x8899aa,"c4":5,"c8":false,"cc":0,"d0":-1,"d4":0,"d8":true,"dc":false,"e0":0,"104":60,"108":45}
	var state:={"fields":fields,"time":{"timeOfDay":1,"transition":0},"minutesPerHour":1,"elapsed":0}
	var part:={"mesh":{"diffuse":[.7,.5,.3],"ambient":[.4,.6,.8]},"selfillum":[.03,.02,.01]}
	var material=world.pool.material(part)
	check(material is NativeMaterial and material.native_surface_output and material.native_world_fog,"Actual model pool selects native surface and world-fog carriers")
	check(world.pool.material(part)==material,"Repeated material preparation retains the native carrier cache identity")
	world.pool.native_surface_output=false; var rollback=world.pool.material(part); world.pool.native_surface_output=true
	check(rollback!=material and not rollback.native_surface_output and not rollback.native_world_fog,"Rollback uses a separate ordinary material cache identity")
	var copied=material.duplicate()
	check(copied.native_surface_output and copied.native_world_fog,"Private pose material copies retain native world fog")
	var surface:=MeshInstance3D.new(); surface.mesh=QuadMesh.new(); surface.material_override=copied; world.add_child(surface)
	var original:=Original.new(); var revision:=0; var periods: Array=[]
	for period in [1,2,3,4]:
		state.time.timeOfDay=period; state.elapsed=30 if period in [3,4] else 0
		for distance in [20.0,-15.0]:
			area.controller.distance=distance; revision+=1
			check(area.receive({"revision":revision,"state":state}),"Actual area owner admits native period and camera range")
			check(not area.environment.fog_enabled and SurfaceState.authoritative(world),"Native world owns fog while Godot's linear fog is disabled")
			var packet: Array=SurfaceState.packet(world); var fog_values: Array=area.sample.fog
			var fog:=Vector3(fog_values[0],fog_values[1],fog_values[2]); var amount: float=(5.0-float(packet[4]))*float(packet[6])
			check(packet.size()==8 and packet[7]==3.0 and area.range_state.start==packet[4],"Raw native fog and negative range retain their published float32 values")
			var linear: PackedFloat32Array=original.execute(selected_catalog,2,inputs(Vector3.ONE,part.mesh.diffuse,part.mesh.ambient,part.selfillum,1.0,3,[0,0,0],Vector3.ZERO,{},Vector3.ZERO,Vector3(0,0,1),area.sample.ambient,area.sample.diffuse))
			check(linear.size()==4 and original.failure.is_empty(),"Original material functions execute for actual area channels: "+original.failure)
			if linear.size()!=4: break
			for value in [2.2,1.2]:
				gamma.set_gamma(value); surface.hide()
				await compare_output(Policy.linear_rgb(fog_values),1.0,Vector3.ZERO,0.0,Vector3.ZERO,value,"Actual area background period/distance/gamma "+str([period,distance,value]))
				surface.show()
				await compare_output(Vector3(linear[0],linear[1],linear[2]),1.0,fog,amount,fog,value,"Actual pool material, area light and world fog "+str([period,distance,value]))
			periods.append({"period":period,"distance":distance,"sample":area.sample.duplicate(true),"fog":packet})
	check(area.range_state.start<0,"Camera-relative fog supports a negative start")
	check(gamma.snapshot().failure.is_empty() and gamma.snapshot().passes>0,"Actual final native output pass executes for both area and models")
	var before:=SurfaceState.packet(world)
	check(not SurfaceState.publish(world,Vector3.ONE,true,1.0e100,2.0e100) and SurfaceState.packet(world)==before,"Float32-overflow fog ranges cannot poison the active GPU state")
	check(SurfaceState.publish(world,Vector3(before[0],before[1],before[2]),true,before[4],before[5]),"A valid publication clears the rejected-range diagnostic")
	SurfaceState.publish_camera(world,[1,0,0,0,0,1,1,3])
	check(SurfaceState.packet(world)==before,"Particle camera fallback cannot replace authoritative raw area fog")
	var next:=LiveWorld.new(); next.set_meta("native_surface_output",true); root.add_child(next); next.set_process(false)
	check(SurfaceState.publish(next,Vector3(.1,.2,.3),true,2,20),"A successor native world owns its own fog publication")
	var successor:=SurfaceState.packet(next); area.advance(0); world.close()
	check(SurfaceState.packet(next)==successor and SurfaceState.owns(next),"An old area's callback and retirement cannot rewrite or clear successor fog")
	var native_state: Dictionary=gamma.snapshot(); gamma.free(); world.free(); original.close(); output_original.close(); next.close(); next.free(); copied=null; material=null; rollback=null
	for frame in 3: await process_frame
	check(SurfaceState.snapshot().owner==0 and SurfaceState.snapshot().packet.is_empty() and Palette.active.is_empty(),"Native area, material and fog owners retire cleanly")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":output_samples,"periods":periods,"gamma":native_state,"publicConnections":0,"scope":"Real GPU actual LiveWorld, AreaEnvironment, model-pool and private-material native-output integration versus unchanged original material/output functions: day/night/dawn/dusk, negative camera-relative fog, raw background, Gamma, cache rollback and generation retirement. No sky/weather/mapped material or matched dense-room acceptance; research mode only."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
