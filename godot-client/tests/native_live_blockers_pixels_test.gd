extends SceneTree
# Offline original server resources through ObjectStream and the unchanged V3
# World adoption. Only area scheduling is scaffolded: no area/server is opened.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
const Settings=preload("res://systems/native_render_settings.gd")
const Walkmesh=preload("res://systems/native_data/object_surface.gd")
const Collision=preload("res://systems/native_render/drive_collision.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
var checks:=0
var failures: Array=[]
var observations: Array=[]
var output:=""
var retained_extension: Resource
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func draw() -> void:
	Palette.flush()
	for frame in 6:await process_frame
	await RenderingServer.frame_post_draw
func collision_hit(shape: Dictionary) -> bool:
	for triangle in shape.get("triangles",[]):
		var middle: Vector3=(triangle.a+triangle.b+triangle.c)/3.0
		var normal:=Vector2(triangle.b.y-triangle.a.y,triangle.a.x-triangle.b.x).normalized()
		if normal.length_squared()>0.0 and Collision.hits(Vector2(middle.x,middle.y)-normal,Vector2(middle.x,middle.y)+normal,triangle,0.05,shape.min.z-0.1,shape.max.z+0.1):return true
	return false
func white_pixels(image: Image,point: Vector2) -> int:
	var count:=0
	for y in range(int(point.y)-3,int(point.y)+4):
		for x in range(int(point.x)-3,int(point.x)+4):
			if x<0 or y<0 or x>=image.get_width() or y>=image.get_height():continue
			var color:=image.get_pixel(x,y)
			if minf(color.r,minf(color.g,color.b))>0.7:count+=1
	return count
func run() -> void:
	var manifest_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--assets-manifest="):manifest_path=arg.substr(18)
	if output.is_empty() or manifest_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	var primary:=DisplayServer.get_primary_screen();var secondary:=-1
	for screen in DisplayServer.get_screen_count():
		if screen!=primary:secondary=screen;break
	if secondary>=0 and root.current_screen!=secondary:root.current_screen=secondary
	await process_frame
	var window:={"screen":root.current_screen,"primary":primary,"first_nonprimary":secondary,"focused":root.has_focus(),"unfocusable":root.unfocusable,"mouse":Input.get_mouse_mode()}
	check(secondary>=0 and root.current_screen==secondary and not root.has_focus() and root.unfocusable and Input.get_mouse_mode()==Input.MOUSE_MODE_VISIBLE,"Graphical fixture uses first nonprimary monitor unfocused with visible pointer")
	if secondary<0:quit(2);return
	retained_extension=load("res://native/particle_kernel.gdextension")
	check(retained_extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"Pinned existing native storage DLL loads without rebuild")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var catalog:=Catalog.new()
	check(catalog.mount_install("C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall") and catalog.mount_directory(manifest.files[0].file.get_base_dir(),10000000),"Read-only installed providers and exact retained server assets mount")
	var scene:=Node3D.new();root.add_child(scene);scene.add_child(Palette.new())
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.025,0.035,0.055);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.BLACK;environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;scene.add_child(environment)
	var camera:=Camera3D.new();scene.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12.0;camera.current=true
	var gamma:=Gamma.new();scene.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true);gamma.set_gamma(1.2)
	Palette.ambient(Vector3.ONE)
	var preferences:=output.get_base_dir().path_join("fixture-options.cfg")
	var settings:=Settings.new();root.add_child(settings);settings.setup(preferences,"");settings.hide()
	check(not settings.show_blockers_enabled,"Fresh saved diagnostic preference defaults off")
	for entry in manifest.selected:
		var model: String=entry.model;var id:=int(entry.observed[0].id)
		var state: Dictionary=entry.observed[0].duplicate(true);state.appearance=entry.appearance;state.erase("id");state.erase("name")
		var object:={"id":id,"objectType":9,"areaId":777,"nativeLifetime":1,"replicated":state}
		var original:=var_to_bytes(object)
		var world:=World.new();world.set_meta("native_surface_output",true);world.set_meta("native_enhanced_lighting",true);world.pool.native_lighting=true;world.pool.native_surface_output=true;scene.add_child(world);world.set_process(false);world.area_id=777;world.generation=1;world.opened_at=Time.get_ticks_usec()
		world.receive([object],-1)
		settings.show_blockers_changed.connect(world.set_show_blockers)
		world.set_show_blockers(settings.show_blockers_enabled)
		var stream:=Objects.new();stream.admission_parent=world;world.add_child(stream);stream.configure(catalog,world.pool,[object],777,output.get_base_dir().path_join("prepared-"+model))
		world.batches.append({"owner":stream,"actors":false,"keys":{id:world.desired[id].key}})
		var deadline:=Time.get_ticks_msec()+30000
		while not world.instances.has(id) and Time.get_ticks_msec()<deadline:
			world._profile_process(0.0);await process_frame
		check(world.instances.has(id) and world.stats.errors.is_empty() and world.stats.object_errors.is_empty(),model+": real table-selected ObjectStream adopts into production World")
		if not world.instances.has(id):settings.show_blockers_changed.disconnect(world.set_show_blockers);world.close();world.queue_free();continue
		var instance=world.instances[id];instance.rigs.set_process(false);instance.rigs._update(0.0)
		var part: Node3D=instance.rigs.node_for(id,0,"visible")
		check(is_instance_valid(part) and instance.identified_blocker and instance.received_animation==74 and absf(part.position.y+10.95)<0.00001,model+": adopted original OFF74 Part remains authored below scene")
		var base: Vector3=instance.global_position
		camera.position=base+Vector3(9,7,14);camera.look_at(base+Vector3(0,2.0,0))
		# A deliberately ordinary white/untextured control has no helper metadata.
		# It shares the world and render path but is not an original server asset.
		var control:=MeshInstance3D.new();control.mesh=BoxMesh.new();control.mesh.size=Vector3(0.8,0.8,0.8);var white:=StandardMaterial3D.new();white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;white.albedo_color=Color.WHITE;control.material_override=white;world.add_child(control);control.global_position=base+camera.global_basis.x*4.0+Vector3(0,2.0,0)
		var control_pixel:=camera.unproject_position(control.global_position)
		var collision:=Collision.new();world.add_child(collision);collision.set_process(false)
		var pwk_path:=""
		for file in manifest.files:
			if file.name==model and int(file.type)==2053:pwk_path=file.file
		var parser:=Walkmesh.new();var pwk:=parser.parse(FileAccess.get_file_as_bytes(pwk_path));var pwk_bytes:=var_to_bytes(pwk)
		collision.models[model+":placeable"]=pwk
		var spec:={"model":model,"door":false,"state":0};var shape:=collision.obstacle(id,object,spec);var shape_bytes:=var_to_bytes(shape)
		check(not shape.is_empty() and collision_hit(shape),model+": actual independent PWK blocks while received OFF helper is below scene")
		await draw();var off:=root.get_texture().get_image();off.save_png(output.trim_suffix(".json")+"-"+model+"-off.png")
		settings.show_blockers_toggle.button_pressed=true;instance.rigs._update(0.0)
		await draw();var on:=root.get_texture().get_image();on.save_png(output.trim_suffix(".json")+"-"+model+"-on.png")
		var changed:=0
		for y in on.get_height():
			for x in on.get_width():
				var before:=off.get_pixel(x,y);var after:=on.get_pixel(x,y)
				if maxf(absf(before.r-after.r),maxf(absf(before.g-after.g),absf(before.b-after.b)))>0.05:changed+=1
		var config:=ConfigFile.new();config.load(preferences)
		check(config.get_value("rendering","show_blockers",false)==true and world.show_blockers_enabled and instance.show_blocker and absf(part.position.y-0.05)<0.00001,model+": real saved toggle reaches World and original ON73 presentation")
		check(changed>100,model+": diagnostic produces actual changed helper pixels")
		check(white_pixels(off,control_pixel)==49 and white_pixels(on,control_pixel)==49,model+": ordinary unrelated white control remains visible in both captures")
		check(is_same(shape,collision.obstacle(id,object,spec)) and var_to_bytes(shape)==shape_bytes and collision_hit(shape),model+": exact same PWK collision object still blocks after diagnostic reveal")
		settings.show_blockers_toggle.button_pressed=false;instance.rigs._update(0.0)
		await draw();var restored:=root.get_texture().get_image();restored.save_png(output.trim_suffix(".json")+"-"+model+"-restored.png")
		check(restored.get_data()==off.get_data() and absf(part.position.y+10.95)<0.00001,model+": diagnostic off restores exact baseline pixels and authored OFF pose")
		check(var_to_bytes(object)==original and var_to_bytes(pwk)==pwk_bytes and instance.received_animation==74 and collision_hit(shape),model+": received bytes and original PWK remain unchanged throughout toggles")
		observations.append({"model":model,"sha256":entry.model_sha256,"received_id":id,"received_animation":instance.received_animation,"changed_pixels":changed,"white_off":white_pixels(off,control_pixel),"white_on":white_pixels(on,control_pixel),"pwk_triangles":shape.triangles.size(),"adopted":world.stats.replacements,"baseline_restored":restored.get_data()==off.get_data(),"source_position":state.position})
		settings.show_blockers_changed.disconnect(world.set_show_blockers)
		world.close();await process_frame;await process_frame;world.free();await process_frame;await process_frame
	var saved:=Settings.new();root.add_child(saved);saved.setup(preferences,"");saved.hide();check(not saved.show_blockers_enabled,"Final saved OFF preference reloads through real Settings")
	var gamma_state:=gamma.snapshot();check(gamma_state.failure.is_empty() and int(gamma_state.passes)>0,"Pinned native surface output compositor executes successfully")
	settings.free();saved.free();scene.free();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window,"observations":observations,"gamma":gamma_state,"server_connections":0,"native_builds":0,"performance_claim":false,"scope":"Original retained server MDL/PWKs selected through original placeables.2da, actual ObjectStream and immutable V3 World adoption, saved Settings to World diagnostic pixels, exact baseline restoration and unchanged PWK collision. Area scheduling only is scaffolded; ordinary white cube is an authored negative control. No public login, loaded full area, live Claddath comparison or FPS claim."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("LIVE_BLOCKERS_PIXELS ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
