extends "res://tests/native_bridge_support_pixels_test.gd"
# Adds only GPU projection evidence to the existing27 functional FOV checks.
# Real original scenery is background; explicit colored landmarks calibrate
# screen positions independently from Camera3D.unproject_position().
const FovPolicy=preload("res://tools/native_parity/ui/camera_fov_projection.gd")
const FovBinding=preload("res://tools/native_parity/ui/camera_fov_binding.gd")
const Settings=preload("res://systems/native_render_settings.gd")
var fov_samples: Array=[]
var fov_markers: Array=[]
var fov_camera: Camera3D
func marker_color(color: Color,index: int) -> bool:
	match index:
		0:return color.r>0.8 and color.g<0.2 and color.b>0.8
		1:return color.r<0.2 and color.g>0.8 and color.b>0.8
		2:return color.r>0.8 and color.g>0.8 and color.b<0.2
		_:return color.r>0.8 and color.g<0.2 and color.b<0.2
func fov_capture(name: String,settings) -> Image:
	await render_wait()
	var image:=root.get_texture().get_image();image.save_png(output.trim_suffix(".json")+"-"+name+".png")
	var size:=root.size;var scale:=float(size.y)/(2.0*tan(deg_to_rad(fov_camera.fov)*0.5));var points: Array=[]
	for index in fov_markers.size():
		var marker: Node3D=fov_markers[index];var camera_point:=fov_camera.global_transform.affine_inverse()*marker.global_position
		var expected:=Vector2(float(size.x)*0.5+camera_point.x*scale/-camera_point.z,float(size.y)*0.5-camera_point.y*scale/-camera_point.z)
		var centroid:=Vector2.ZERO;var count:=0
		for y in range(maxi(0,int(expected.y)-10),mini(image.get_height(),int(expected.y)+11)):
			for x in range(maxi(0,int(expected.x)-10),mini(image.get_width(),int(expected.x)+11)):
				if marker_color(image.get_pixel(x,y),index):centroid+=Vector2(x+0.5,y+0.5);count+=1
		if count>0:centroid/=float(count)
		var error:=centroid.distance_to(expected) if count else INF
		check(count>=3 and error<1.5,"Actual GPU landmark matches native vertical-FOV/aspect construction "+name+"/"+str(index))
		points.append({"index":index,"pixels":count,"expected":[expected.x,expected.y],"centroid":[centroid.x,centroid.y],"error_pixels":error})
	check(root.current_screen!=DisplayServer.get_primary_screen() and not root.has_focus() and root.unfocusable and Input.get_mouse_mode()==Input.MOUSE_MODE_VISIBLE,"FOV capture stays nonprimary/unfocused/pointer visible "+name)
	fov_samples.append({"name":name,"viewport":[size.x,size.y],"fov":fov_camera.fov,"saved_slider":settings.fov_control.value,"keep_height":fov_camera.keep_aspect==Camera3D.KEEP_HEIGHT,"landmarks":points})
	return image
func run() -> void:
	var manifest_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--assets-manifest="):manifest_path=arg.substr(18)
	if output.is_empty() or manifest_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	var primary:=DisplayServer.get_primary_screen();var secondary:=-1
	for screen in DisplayServer.get_screen_count():
		if screen!=primary:secondary=screen;break
	if secondary<0:quit(3);return
	root.current_screen=secondary;root.size=Vector2i(640,480);await process_frame
	retained_extension=load("res://native/particle_kernel.gdextension");check(retained_extension!=null,"Pinned existing native model/geometry DLL loads")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path));var catalog:=Catalog.new()
	check(catalog.mount_install("C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall") and catalog.mount_directory(manifest.directory,10000000),"Read-only original scenery and installed texture catalogs mount")
	var assets:=Assets.new();root.add_child(assets);assets.configure(catalog);assets.maximum_workers=1;assets.cache_directory=output.get_base_dir().path_join("prepared");assets.completed.connect(func(id,result):completed[id]=result)
	var original: Dictionary=await ready_asset(assets,"twh_udbridge_mai","static-model")
	check(str(original.get("error","missing")).is_empty() and original.get("sha256")=="45a1ac41bac092fac5de7e3f3016331b7e0e1c167ec4b6a82dbe266595589311","Exact original bridge prepares with genuine installed fallback textures")
	if not str(original.get("error","")).is_empty():assets.close();assets.free();write_fov_result({});return
	var original_bytes:=var_to_bytes(original.value)
	var world=make_world(94,94);world.pool.native_lighting=true;world.pool.native_surface_output=true;world.set_meta("native_surface_output",true);preload("res://systems/native_render/native_surface_state.gd").bind(world)
	var template=world.pool.model_template(original);var bridge=template.create();world.terrain.add_child(bridge);bridge.position=Vector3(10,11,-10);world.terrain.instances["original-bridge"]=bridge;world.terrain.collision_index.put(bridge)
	var scene:=Node3D.new();root.add_child(scene);scene.add_child(Palette.new());Palette.ambient(Vector3(0.75,0.75,0.75))
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.025,0.035,0.055);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.BLACK;environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;scene.add_child(environment)
	fov_camera=Camera3D.new();scene.add_child(fov_camera);fov_camera.position=Vector3(20,20,5);fov_camera.look_at(Vector3(10,13,-10));fov_camera.current=true
	var gamma:=Gamma.new();scene.add_child(gamma);gamma.attach(fov_camera);gamma.effect.set_surface_output(true);gamma.set_gamma(1.2)
	var settings_path:=output.get_base_dir().path_join("private-fov-options.cfg");var settings:=Settings.new();root.add_child(settings);settings.setup(settings_path,"");settings.hide()
	var binding:=FovBinding.new();binding.configure(settings);check(binding.bind(fov_camera) and fov_camera.fov==45,"Fresh actual Settings/Binding selects source-confirmed vertical45")
	for index in 4:
		var marker:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=0.03;sphere.height=0.06;sphere.radial_segments=12;sphere.rings=6;marker.mesh=sphere
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=[Color.MAGENTA,Color.CYAN,Color.YELLOW,Color.RED][index];marker.material_override=material;scene.add_child(marker)
		marker.global_position=fov_camera.global_transform*Vector3([-0.75,0.75,-0.75,0.75][index],[0.5,0.5,-0.5,-0.5][index],-4.0);fov_markers.append(marker)
	var baseline:=await fov_capture("native45-4x3",settings)
	settings.fov_control.value=80;var wide:=await fov_capture("slider80-4x3",settings)
	binding.close();settings.free();settings=Settings.new();root.add_child(settings);settings.setup(settings_path,"");settings.hide();binding=FovBinding.new();binding.configure(settings);binding.bind(fov_camera)
	var reopened:=await fov_capture("reopened80-4x3",settings);check(reopened.get_data()==wide.get_data(),"Saved slider reopen restores exact actual perspective pixels")
	settings.fov_reset.pressed.emit();var reset:=await fov_capture("original-reset45-4x3",settings);check(reset.get_data()==baseline.get_data(),"Original reset restores exact native45 rendered pixels")
	for size_value in [Vector2i(960,540),Vector2i(480,720)]:
		root.size=size_value;await process_frame;await fov_capture("native45-"+str(size_value.x)+"x"+str(size_value.y),settings)
	root.size=Vector2i(640,480);await process_frame;fov_camera.fov=60;binding.bind(fov_camera);await fov_capture("same-camera-script60",settings)
	check(fov_camera.fov==60 and settings.fov_degrees==45,"Ordinary snapshot rebind preserves later scripted camera FOV in pixels")
	var replacement:=Camera3D.new();scene.add_child(replacement);replacement.global_transform=fov_camera.global_transform;replacement.current=true;gamma.attach(replacement);fov_camera.free();fov_camera=replacement;binding.bind(fov_camera)
	var recreated:=await fov_capture("recreated-native45",settings);check(recreated.get_data()==baseline.get_data(),"Replacement camera receives saved45 and restores exact native45 image")
	check(var_to_bytes(original.value)==original_bytes,"FOV controls never mutate original world scenery data")
	var gamma_state:=gamma.snapshot();check(gamma_state.failure.is_empty() and int(gamma_state.passes)>0,"Native surface compositor rendered actual stable world and landmarks")
	var details:={"samples":fov_samples,"model_sha256":original.sha256,"textures":original.get("dependencies",[]),"gamma":gamma_state,"screen":root.current_screen,"primary":primary,"settings_path":settings_path,"original_unchanged":true}
	binding.close();settings.free();world.close();await process_frame;await process_frame;world.free();scene.free();assets.close();assets.free();await process_frame;await process_frame;write_fov_result(details)
func write_fov_result(details: Dictionary) -> void:
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"details":details,"serverConnections":0,"nativeBuilds":0,"performanceClaim":false,"scope":"GPU supplement to existing27 functional FOV checks: actual Settings slider/reset/save/reopen and Binding on stable original bridge scenery; independent tan(vertical/2)*aspect landmark pixels at3viewports, script-preserving same-camera rebinding and replacement camera. Source-confirmed module default45;20–120slider range is client policy. Explicit calibration landmarks and installed trim fallback; no matched native screenshot/full-room/FPS claim."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  ")+"\n");print("CAMERA_FOV_PIXELS ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
