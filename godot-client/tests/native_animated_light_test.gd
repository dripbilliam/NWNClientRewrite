extends "res://tests/native_enhanced_lighting_pixels_test.gd"
const Pose=preload("res://systems/model_native_pose.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const OriginalModel=preload("res://systems/native_render/effect_model.gd")
var install_path:=""
func source(values: Array) -> Dictionary:
	var controllers: Array=[]; var data:=PackedFloat32Array([0.0])
	for field in [[104,3],[116,1],[124,1],[128,1],[168,1]]:
		controllers.append({"displacement0":field[0],"rows4":1,"timeIndex6":0,"valueIndex8":data.size(),"columnsA":field[1]})
		for n in field[1]: data.append(values.pop_front())
	return {"id34":1,"flags98":3,"controllers78":controllers,"controllerCount80":controllers.size(),"values88":data,"children68":[],"childCount70":0}
func rig_case(world: Node3D,mode: int) -> void:
	var part:=Node3D.new(); world.add_child(part); part.position=Vector3(0,0,2)
	var lamp:=PointLight.new(); lamp.set_meta("native_enhanced_light",true); lamp.configure({"color":[1.0,1.0,1.0],"radius":2.0,"ambientonly":1,"shadow":1,"isdynamic":1}); part.add_child(lamp)
	var pose:=Pose.new(); pose.native_storage=mode==3; pose.compiled_controls=mode>=2; pose.bulk_evaluation=mode>=2; pose.direct_flush=mode!=0; pose.prepared_plan=true; pose.root_hierarchy=true
	var node:=source([.2,.3,.4,4.0,6.0,.25,1.0])
	pose.configure({"root":0,"emitterFields":{},"parts":[{"type":"light","node":node,"properties":{"isdynamic":1},"children":[]}]},{"parts":[0]},[part])
	if mode==3: check(pose.native_context!=null,"Compiled native light Part storage configures")
	# Pose owns Part transforms; set the canonical position through its storage.
	pose.write(pose.parts[0],16,[0.0,-2.0,0.0]); pose.flush()
	var original: Dictionary=lamp.get_meta("native_model_light_properties").duplicate(true)
	check(original.color==[float(node.values88[1]),float(node.values88[2]),float(node.values88[3])] and original.radius==4.0 and original.shadowradius==6.0 and original.verticaldisplacement==.25 and original.multiplier==1.0,"All original animated light scalar fields publish mode "+str(mode))
	var dark:=await capture(); var publications:=lamp.animation_publications
	pose.flush(); check(lamp.animation_publications==publications,"Unchanged animated light publication performs no configuration mode "+str(mode))
	var next:=source([.8,.6,.4,8.0,10.0,.5,1.5]); pose.apply(next,0,0,1,1,{})
	pose.write(pose.parts[0],16,[0.0,-2.0,0.0]); pose.flush()
	var properties: Dictionary=lamp.get_meta("native_model_light_properties"); var expected:=Policy.point(properties)
	check(properties.radius==8 and properties.shadowradius==10 and properties.verticaldisplacement==.5 and properties.multiplier==1.5,"Updated light radius/multiplier reach native policy mode "+str(mode))
	var lit:=await capture(); close_color(lit,expected.color*Policy.attenuation(2,expected),"Animated light changes actual pixels mode "+str(mode),.009)
	check(lit.r>dark.r*2 and lamp.native_slot>=0,"Animated lamp remains admitted with its native metadata mode "+str(mode))
	lamp.shadow_enabled=true; pose.write(pose.parts[0],116,[9.0]); pose.flush()
	# Ambient-only fixtures have no requested shadows; use ordinary light below.
	check(not lamp.shadow_enabled,"Ambient-only publication retains the no-shadow rule")
	var configured: Dictionary=properties.duplicate(true); configured.ambientonly=0; lamp.configure(configured); lamp.shadow_enabled=true
	pose.write(pose.parts[0],116,[10.0]); pose.flush(); check(lamp.shadow_enabled,"Animated values preserve the independent selected shadow mode "+str(mode))
	var manual_color:=lamp.light_color; pose.write(pose.parts[0],104,[0.0,0.0,0.0]); pose.flush({0:true}); check(lamp.light_color==manual_color,"Manual Part publication is skipped mode "+str(mode))
	lamp.free(); pose.flush(); check(pose.diagnostics.has("native animated-light renderer binding unavailable"),"Retired weak light binding is diagnosed safely mode "+str(mode))
	pose.close(); part.free(); await process_frame
func actual_model(world: Node3D) -> void:
	var catalog:=Catalog.new(); check(catalog.mount_install(install_path),"Original vision model catalog mounts read-only: "+catalog.failure)
	var assets:=Assets.new(); world.add_child(assets); assets.configure(catalog); var results: Dictionary={}; assets.completed.connect(func(id,result):results[id]=result)
	var job:=assets.request("fx_light_clr",2002,"actor-model"); var deadline:=Time.get_ticks_msec()+15000
	while not results.has(job) and Time.get_ticks_msec()<deadline: await process_frame
	check(results.has(job) and str(results.get(job,{}).get("error","pending")).is_empty(),"Actual original vision model prepares through native workers")
	if not results.has(job) or not str(results[job].get("error","")).is_empty(): assets.close(); return
	var pool:=Pool.new(); pool.native_lighting=true
	var model:=OriginalModel.new(); world.add_child(model); check(model.load_model(results[job],pool),"Actual private vision model installs")
	model.rigs.set_process(false)
	check(model.play_effect_clip("Dark_Vision",1.0,3,0.0),"Original Dark_Vision native clip starts")
	var lights:=model.find_children("*","OmniLight3D",true,false)
	check(not lights.is_empty() and lights.all(func(light):return light.native_slot>=0),"Actor/effect lamps use the selected native lighting policy")
	var animation=model.rigs.entities[0].models[0].native_owner
	var before: Array=lights.map(func(light):return light.get_meta("native_model_light_properties").duplicate(true))
	var dark:=await capture(); animation.advance(.25); animation.advance(.25); var bright:=await capture()
	var after: Array=lights.map(func(light):return light.get_meta("native_model_light_properties").duplicate(true))
	check(before!=after,"Original Dark_Vision keys change rendered lamp state")
	check(bright.r>dark.r+.02 or bright.g>dark.g+.02 or bright.b>dark.b+.02,"Original Dark_Vision visibly illuminates the fixture")
	check(not animation.pose.diagnostics.has("native animated-light renderer binding unavailable"),"Actual vision model has no missing animated-light publication")
	model.retire(); model.free(); assets.close(); assets.free(); pool.clear(); await process_frame
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
		if arg.begins_with("--install="): install_path=arg.substr(10)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	root.size=Vector2i(256,256)
	var world:=Node3D.new(); root.add_child(world); world.add_child(Palette.new()); Palette.ambient(Vector3.ZERO)
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color.BLACK; environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.BLACK; environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR; world.add_child(environment)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4; camera.current=true
	var surface:=MeshInstance3D.new(); surface.mesh=QuadMesh.new(); world.add_child(surface); var base:=StandardMaterial3D.new(); var material:=NativeMaterial.new(); material.configure(base,[1.0,1.0,1.0],[0.0,0.0,0.0]); surface.material_override=material
	for mode in 4: await rig_case(world,mode)
	surface.position.z=-2; await actual_model(world)
	world.free(); await process_frame; await process_frame; check(Palette.active.is_empty(),"All private animated lamp slots retire")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"scope":"Actual native light Part field publication across scripted arrays/direct and compiled views/storage, actual GPU pixels, shadow/manual/weak ownership and installed fx_light_clr Dark_Vision playback. Vision gate/admission history and full-room parity are separate."}
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
