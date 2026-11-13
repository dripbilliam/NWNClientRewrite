extends "res://tests/native_standard_light_pixels_test.gd"
const EnvironmentOwner=preload("res://systems/native_render/model_environment.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
class UnknownCatalog:
	extends RefCounted
	var reads:=0
	func get_resource(_name: String,_type: int) -> PackedByteArray: reads+=1; return PackedByteArray([1])
func wait_ready(owner) -> bool:
	var end:=Time.get_ticks_msec()+15000
	while not owner.map_ready and owner.failure.is_empty() and Time.get_ticks_msec()<end: await process_frame
	return owner.map_ready
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256)
	var world:=Node3D.new(); root.add_child(world); world.add_child(Palette.new())
	var unknown:=UnknownCatalog.new(); var legacy:=Pool.new(); var absent:=EnvironmentOwner.new(); world.add_child(absent); absent.configure(unknown,legacy)
	check(not absent.enabled and unknown.reads==0,"Ordinary rendering performs no native shader probe or environment work")
	var rejected:=Pool.new(); rejected.native_lighting=true; var unmapped:=EnvironmentOwner.new(); world.add_child(unmapped); unmapped.configure(unknown,rejected)
	check(not unmapped.enabled and not rejected.native_standard and not unmapped.failure.is_empty(),"An unknown active shader profile is diagnosed rather than treated as the mapped revision")
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original native environment catalog mounts read-only")
	var pool:=Pool.new(); pool.native_lighting=true; var owner:=EnvironmentOwner.new(); world.add_child(owner); owner.configure(catalog,pool)
	check(owner.enabled and pool.native_standard and owner.hashes==EnvironmentOwner.RETAIL_SHADERS.merged(EnvironmentOwner.RETAIL_PROGRAMS),"Active native catalog selects the exact verified retail shader revision")
	check(await wait_ready(owner),"Original chrome1 fallback prepares on native workers: "+owner.failure)
	if not owner.map_ready: owner.close(); world.free(); quit(1); return
	check(owner.selected=="chrome1" and Palette.environment_texture!=Palette.empty_environment,"Real native fallback texture binds the world sampler")
	var image:=Palette.environment_texture.get_image()
	if image.is_compressed(): check(image.decompress()==OK,"Original fallback raster can be inspected in the fixture")
	image.convert(Image.FORMAT_RGBA8)
	var offset:=image.get_mipmap_offset(image.get_mipmap_count()); var bytes:=image.get_data(); var last:=Image.create_from_data(1,1,false,Image.FORMAT_RGBA8,bytes.slice(offset,offset+4)); var sample:=last.get_pixel(0,0); var reflection:=Policy.linear_rgb([sample.r,sample.g,sample.b])
	var env:=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color.BLACK; env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color.BLACK; env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR; world.add_child(env)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4; camera.make_current()
	var surface:=MeshInstance3D.new(); surface.mesh=QuadMesh.new(); world.add_child(surface)
	var material=pool.material({"mesh":{"diffuse":[.6,.4,.2],"ambient":[.3,.5,.7]},"selfillum":[0.0,0.0,0.0]}); surface.material_override=material
	check(material.standard_specular and material.standard_quality==2,"Real native pool binds standard material terms for the verified profile")
	var area_ambient:=[.6,.4,.2]; Palette.ambient(Policy.linear_rgb(area_ambient))
	var original:=Original.new(); var expected:=original.execute(catalog,2,inputs(Vector3.ONE,[.6,.4,.2],[.3,.5,.7],[0,0,0],1.0,3,[0,0,0],Vector3.ZERO,{},reflection,Vector3(0,0,1),area_ambient))
	check(expected.size()==4 and original.failure.is_empty(),"Original retail shader executes against the actual fallback mip")
	close_color(await capture(),Vector3(expected[0],expected[1],expected[2]),"Real chrome1 native sampler and pool material match original shader equations",.008)
	check(EnvironmentOwner.selected_name({"tileset":{"sections":{"GENERAL":{"EnvMap":"CUSTOM_SKY"}}}})=="custom_sky","SET environment selection is resource-driven and normalized")
	owner.receive_definition({"tileset":{"sections":{"GENERAL":{"EnvMap":"not_present_in_fixture"}}}})
	check(owner.requested=="chrome1" and owner.selected=="chrome1","Missing SET map selects original fallback")
	var successor:=EnvironmentOwner.new(); world.add_child(successor); successor.configure(catalog,pool)
	check(await wait_ready(successor),"Successor area prepares its own environment")
	var retained_texture:=Palette.environment_texture
	owner.close(); owner.completed(-1,{})
	check(Palette.environment_texture==retained_texture and EnvironmentOwner.active_id==successor.get_instance_id(),"Retired older area cannot replace or clear successor sampler")
	var snapshot: Dictionary=successor.snapshot(); successor.close(); check(Palette.environment_texture==Palette.empty_environment and successor.closed,"Final area retirement releases the global sampler binding")
	original.close(); world.free(); material=null; pool.clear(); legacy.clear(); rejected.clear()
	for frame in 4: await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"environment":snapshot,"fallback":{"size":[image.get_width(),image.get_height()],"mips":image.get_mipmap_count(),"last":[sample.r,sample.g,sample.b]},"publicConnections":0,"scope":"Installed active shader profile, actual chrome1 bitmap/mip through native workers and pool, original shader GPU reference, SET resource selection and multi-area retirement. 2D ordinary material path only; mapped/cube, vertex mode and full-room acceptance remain open."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
