extends SceneTree
# WRITTEN, NOT YET EXECUTED. No socket/server APIs. Production never imports this.
const Scope=preload("res://experiments/area_layer_scope.gd")
var failures: Array=[]
var checks:=0
var output:=""
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL ",reason)
func cube(parent: Node3D,at: Vector3,color: Color,size_value: Vector3=Vector3.ONE) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=size_value; mesh.mesh=box; mesh.position=at
	var material:=StandardMaterial3D.new(); material.albedo_color=color; material.roughness=0.9; mesh.material_override=material; parent.add_child(mesh); return mesh
func picture() -> Image:
	# Readback is correctness-only and outside the measured property-operation
	# spans. These frame times must never be reported as steady FPS evidence.
	for frame in 4: await process_frame; await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func same_pixels(a: Image,b: Image) -> bool:
	return a.get_size()==b.get_size() and a.get_format()==b.get_format() and a.get_data()==b.get_data()
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		failures.append("Graphical pixel/lighting/shadow correctness probe requires a real renderer"); finish(); return
	root.size=Vector2i(640,480)
	var holder:=Node3D.new(); root.add_child(holder)
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.025,0.03,0.04); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.15; holder.add_child(environment)
	var camera:=Camera3D.new(); camera.position=Vector3(6,5,9); holder.add_child(camera); camera.look_at(Vector3(0,0.5,0)); camera.current=true
	var old:=Node3D.new(); holder.add_child(old)
	var current:=Node3D.new(); holder.add_child(current)
	var old_mesh:=cube(old,Vector3(-1,1.8,0),Color.RED,Vector3(1.2,3.6,1.2))
	var old_light:=OmniLight3D.new(); old_light.position=Vector3(0,2,1); old_light.light_color=Color.GREEN; old_light.light_energy=8; old_light.omni_range=12; old_light.shadow_enabled=true; old.add_child(old_light)
	var floor_mesh:=cube(current,Vector3(0,-0.15,0),Color(0.65,0.65,0.7),Vector3(9,0.3,9))
	var current_mesh:=cube(current,Vector3(1,0.75,0),Color(0.2,0.4,0.95),Vector3(1,1.5,1))
	var second_layer:=cube(current,Vector3(-2.5,0.5,1.5),Color(0.7,0.7,0.7)); second_layer.layers=2
	var restricted_light:=OmniLight3D.new(); restricted_light.position=Vector3(-1,2,2); restricted_light.light_color=Color.BLUE; restricted_light.light_energy=4; restricted_light.omni_range=10; restricted_light.light_cull_mask=2; restricted_light.shadow_enabled=true; current.add_child(restricted_light)
	var sun:=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-55,-25,0); sun.light_energy=1.0; sun.shadow_enabled=true; current.add_child(sun)
	var body:=StaticBody3D.new(); body.collision_layer=7; body.collision_mask=5; old.add_child(body)
	var shape:=CollisionShape3D.new(); shape.shape=BoxShape3D.new(); body.add_child(shape)
	# A wrapper-heavy authored hierarchy isolates traversal from real asset
	# loading. It does not establish timings for the captured server content.
	for index in 1000:
		var owner:=Node3D.new(); old.add_child(owner)
		for part in 24: owner.add_child(Node3D.new())
	await physics_frame; await physics_frame
	var query:=PhysicsRayQueryParameters3D.create(Vector3(0,3,0),Vector3(0,-3,0),7)
	check(holder.get_world_3d().direct_space_state.intersect_ray(query).get("collider")==body,"Original old-area physics participates before retirement")
	var began:=Time.get_ticks_usec(); old.hide(); old.process_mode=Node.PROCESS_MODE_DISABLED; var baseline_ms:=(Time.get_ticks_usec()-began)/1000.0
	var baseline: Image=await picture(); baseline.save_png(output.trim_suffix(".json")+".baseline.png")
	camera.cull_mask=1; var baseline_one_layer: Image=await picture(); camera.cull_mask=0xfffff
	old.process_mode=Node.PROCESS_MODE_INHERIT; old.show()
	var old_scope:=Scope.new(); var new_scope:=Scope.new()
	began=Time.get_ticks_usec(); var a:=old_scope.bind(old,2); var b:=new_scope.bind(current,3); var setup_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(a and b,"Both independent scopes bind known original layers")
	check(old_mesh.layers==(1<<4) and current_mesh.layers==(1<<6) and floor_mesh.layers==(1<<6),"Original geometry gets independent area lanes")
	began=Time.get_ticks_usec(); var activated:=new_scope.activate(camera,0xfffff); var retired:=old_scope.retire(); var candidate_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(activated and retired and old.visible and old.process_mode==Node.PROCESS_MODE_DISABLED,"Candidate switches camera and disables processing without root hide")
	check(holder.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Old physics is absent synchronously before another frame")
	var candidate: Image=await picture(); candidate.save_png(output.trim_suffix(".json")+".candidate.png")
	check(same_pixels(baseline,candidate),"Exact authored pixels preserve lighting/shadows while old geometry/light stays retained")
	new_scope.activate(camera,1); var candidate_one_layer: Image=await picture()
	check(same_pixels(baseline_one_layer,candidate_one_layer),"Original camera exclusion of the second render layer remains exact")
	check(second_layer.layers==(2<<6) and restricted_light.light_cull_mask==(2<<6),"Original layer-specific light membership is remapped independently")
	new_scope.activate(camera,0xfffff)
	check(old_scope.bindings.size()==2 and old_light.light_cull_mask==old_scope.mask and old_light.shadow_caster_mask==old_scope.mask,"Old light contribution and shadow masks stay scoped")
	var late:=cube(current,Vector3(2.5,0.5,1.5),Color.YELLOW)
	check(new_scope.admit(late) and late.layers==(1<<6),"Explicit late visual admission inherits the current lane")
	var unknown:=cube(current,Vector3.ZERO,Color.WHITE); unknown.layers=4
	var before:=unknown.layers; check(not new_scope.admit(unknown) and unknown.layers==before,"Unsupported existing layer fails without mutating the visual")
	unknown.queue_free(); await process_frame
	new_scope.restore(); old_scope.restore(); camera.cull_mask=0xfffff
	check(old_mesh.layers==1 and current_mesh.layers==1 and late.layers==1 and sun.light_cull_mask==0xfffff and old_light.light_cull_mask==0xfffff,"Restore preserves original private mesh and light state")
	check(old.process_mode==Node.PROCESS_MODE_INHERIT,"Restore preserves original process ownership")
	holder.queue_free(); await process_frame; await process_frame
	finish({"baseline_hide_and_disable_ms":baseline_ms,"candidate_camera_and_disable_ms":candidate_ms,"candidate_initial_mask_setup_ms":setup_ms,"authored_wrapper_nodes":25000})
func finish(observations: Dictionary={}) -> void:
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"production_modified":false,"performance_accepted":false,"game_network_connections":0,"scope":"Isolated authored known-layer fixture only: exact pixels/light/shadows, immediate physics disable, late admission, reject/restore. Single timings are not a real-area, steady-FPS or native parity comparison."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
