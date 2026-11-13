extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Template=preload("res://systems/native_render/model_template.gd")
var failures: Array[String]=[]
var results: Dictionary={}
func _initialize()->void: call_deferred("run")
func check(ok: bool,label: String)->void:
	if not ok: failures.append(label)
func run()->void:
	var install:=""; var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		elif arg.begins_with("--report="): output=arg.substr(9)
	if install.is_empty() or output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	var secondary:=-1
	for index in DisplayServer.get_screen_count():
		if index!=DisplayServer.get_primary_screen(): secondary=index; break
	if secondary<0: quit(2); return
	root.current_screen=secondary; root.position=DisplayServer.screen_get_position(secondary)+Vector2i(100,100); root.size=Vector2i(960,720)
	var retained_extension=load("res://native/particle_kernel.gdextension")
	check(retained_extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"native pose storage loaded")
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"original catalog mounted")
	var name:="pfh0_cloak_001"
	check(catalog.has_resource(name,2002),"source-backed monk cloak model exists")
	var bytes: PackedByteArray=catalog.get_resource(name,2002)
	var service:=Assets.new(); root.add_child(service); service.configure(catalog); service.cache_directory=output.get_base_dir().path_join("cloak-model-cache"); service.completed.connect(func(id,result):results[id]=result)
	var palette: Array=[]
	for channel in 10: palette.append(0)
	var id:=service.request(name,2002,"actor-model",{"relevant_tracks":true,"palette_colors":palette})
	var deadline:=Time.get_ticks_msec()+30000
	while not results.has(id) and Time.get_ticks_msec()<deadline: await process_frame
	var bundle: Dictionary=results.get(id,{})
	check(not bundle.is_empty() and str(bundle.get("error","unfinished")).is_empty(),"original cloak asset prepares through current service")
	var pool:=Pool.new(); pool.unshaded=true
	var template:=Template.new(); var instance
	if not bundle.is_empty() and str(bundle.get("error","unfinished")).is_empty():
		check(template.build(bundle,pool),"original cloak template builds: "+template.failure)
		if template.scene!=null: instance=template.create()
	var scene:=Node3D.new(); root.add_child(scene)
	if instance!=null: scene.add_child(instance)
	var meshes:=0; var bounds:=AABB(); var has_bounds:=false
	if instance!=null:
		meshes=instance.meshes.size()
		for mesh in instance.meshes:
			var region: AABB=mesh.global_transform*mesh.get_aabb()
			bounds=region if not has_bounds else bounds.merge(region); has_bounds=true
	check(meshes>0 and has_bounds,"original cloak contains drawable geometry")
	var env:=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color(.04,.05,.07); scene.add_child(env)
	var lamp:=DirectionalLight3D.new(); scene.add_child(lamp); lamp.rotation=Vector3(-.6,.3,0)
	var camera:=Camera3D.new(); scene.add_child(camera); camera.near=.01; camera.far=100; camera.fov=45.; camera.position=bounds.get_center()+Vector3(0,0,1)*maxf(2.,bounds.size.length()*2.); camera.look_at(bounds.get_center()); camera.current=true
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image(); var path:=output.trim_suffix(".json")+".png"; check(image.save_png(path)==OK,"cloak model image saved")
	var colors:={}
	for y in range(0,image.get_height(),8):
		for x in range(0,image.get_width(),8): colors[image.get_pixel(x,y).to_rgba32()]=true
	check(colors.size()>32,"cloak model pixels visible")
	var report:={"success":failures.is_empty(),"failures":failures,"name":name,"model_sha256":FileAccess.get_sha256(install.path_join("data/nwn_base.key")),"resource_bytes":bytes.size(),"bundle_sha256":bundle.get("sha256",""),"bundle_error":bundle.get("error","unfinished"),"bundle_keys":bundle.keys(),"meshes":meshes,"bounds":{"position":bounds.position,"size":bounds.size},"sampled_colors":colors.size(),"image":path,"source_hashes":{"model_template":FileAccess.get_sha256("res://systems/native_render/model_template.gd"),"resource_catalog":FileAccess.get_sha256("res://systems/native_data/resource_catalog.gd")},"scope":"Source-backed installed monk cloak MDL standalone current-service/template graphical publication. Its native body attachment transform and material/texture override remain to verify; no production edit or FPS."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify({"success":report.success,"failures":failures,"meshes":meshes,"sampled_colors":colors.size(),"report":output}))
	if instance!=null: instance.retire()
	service.close(); service.queue_free(); scene.queue_free(); await process_frame; pool.clear()
	quit(0 if report.success else 1)
