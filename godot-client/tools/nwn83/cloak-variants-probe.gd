extends SceneTree

const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Stream=preload("res://systems/native_render/creature_stream.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const BicVisual=preload("res://systems/native_data/bic_visual.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Appearance=preload("res://systems/native_data/creature_appearance.gd")
const LiveWorld=preload("res://systems/native_render/live_world.gd")

var failures: Array[String]=[]
var output:=""
var install:=""
var completed: Dictionary={}
var retained_extension: Resource
var scene: Node3D
var stream
var service
var pool
var camera: Camera3D
var catalog
var objects: Array=[]
var source: Dictionary={}
var captures: Dictionary={}
var variant:="shifter"
var headless_structural:=false
var custom_texture_depth:=0
var robe_part:=0
var enhanced_lighting:=false
var godot_lighting:=false
var named_environment:="default"

func _initialize()->void: call_deferred("run")
func check(ok: bool,label: String)->void:
	if not ok: failures.append(label)
func hash_bytes(bytes: PackedByteArray)->String:
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); return hash.finish().hex_encode()
func stage_cloak_raster(name: String)->void:
	var stride:=custom_texture_depth>>3
	var bytes:=PackedByteArray(); bytes.resize(18+4*stride)
	bytes[2]=2; bytes[12]=2; bytes[14]=2; bytes[16]=custom_texture_depth; bytes[17]=8 if stride==4 else 0
	for index in 4:
		var pos:=18+index*stride
		bytes[pos]=43; bytes[pos+1]=89; bytes[pos+2]=179
		if stride==4: bytes[pos+3]=[255,96,0,255][index]
	var folder:=output.get_base_dir().path_join("custom-cloak-raster")
	DirAccess.make_dir_recursive_absolute(folder)
	var file:=FileAccess.open(folder.path_join(name+".tga"),FileAccess.WRITE)
	check(file!=null,"custom cloak raster written")
	if file==null: return
	file.store_buffer(bytes); file.close()
	check(catalog.mount_directory(folder),"custom ordinary texture overlay mounts")
	check(catalog.has_resource(name,6) and catalog.has_resource(name,3),"same-name original PLT and custom TGA are both present")
func stage_environment(row_index: int)->void:
	var table: PackedByteArray=catalog.get_resource("cloakmodel",2017)
	var row_pattern:=RegEx.new()
	row_pattern.compile("(?im)^[ \\t]*"+str(row_index)+"[ \\t]+[^\\r\\n]*\\bdefault\\b[^\\r\\n]*")
	var text:=table.get_string_from_ascii()
	var selected:=row_pattern.search(text)
	check(selected!=null,"fixture located the installed default environment row")
	if selected==null: return
	var changed:=text.substr(0,selected.get_start())+selected.get_string().replace("default","cloak_env_probe")+text.substr(selected.get_end())
	var folder:=output.get_base_dir().path_join("custom-environment")
	DirAccess.make_dir_recursive_absolute(folder)
	var file:=FileAccess.open(folder.path_join("cloakmodel.2da"),FileAccess.WRITE)
	if file==null: check(false,"environment table overlay opened"); return
	file.store_string(changed); file.close()
	if named_environment in ["present","cube"]:
		var cube:=named_environment=="cube"
		var tga:=PackedByteArray(); tga.resize(18)
		tga[2]=2; tga[12]=2; tga[14]=12 if cube else 2; tga[16]=24
		for face in (6 if cube else 1):
			for pixel in 4: tga.append_array(PackedByteArray([23,211,100+face*22+pixel if cube else 43]))
		file=FileAccess.open(folder.path_join("cloak_env_probe.tga"),FileAccess.WRITE)
		if file==null: check(false,"named environment raster opened"); return
		file.store_buffer(tga); file.close()
		if cube:
			file=FileAccess.open(folder.path_join("cloak_env_probe.txi"),FileAccess.WRITE)
			if file==null: check(false,"cube texture attributes opened"); return
			file.store_string("cube 1\n"); file.close()
	check(catalog.mount_directory(folder),"mounted the custom environment declaration")
func verify_cube_texels(texture: Cubemap)->void:
	# Sample the cube on the GPU. The Compatibility layer readback routine
	# binds a 2D array and cannot verify a Cubemap through get_layer_data().
	var viewport:=SubViewport.new()
	viewport.disable_3d=true; viewport.size=Vector2i(24,4)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var panel:=ColorRect.new(); panel.size=Vector2(24,4); viewport.add_child(panel)
	var shader:=Shader.new()
	shader.code="""
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform samplerCube probe_cube : filter_nearest;
vec3 face_direction(int face, float s, float t){
 if(face==0)return vec3(1.0,-t,-s);
 if(face==1)return vec3(-1.0,-t,s);
 if(face==2)return vec3(s,1.0,t);
 if(face==3)return vec3(s,-1.0,-t);
 if(face==4)return vec3(s,-t,1.0);
 return vec3(-s,-t,-1.0);
}
void fragment(){
 int sample_index=int(UV.x*24.0);
 int pixel=sample_index%4;
 COLOR=textureLod(probe_cube,face_direction(sample_index/4,float(pixel%2)-0.5,float(pixel/2)-0.5),0.0);
}
"""
	var material:=ShaderMaterial.new(); material.shader=shader; material.set_shader_parameter("probe_cube",texture); panel.material=material
	await process_frame
	await RenderingServer.frame_post_draw
	var sample:=viewport.get_texture().get_image()
	var rotations:=[[2,0,3,1],[1,3,0,2],[0,1,2,3],[3,2,1,0],[3,2,1,0],[0,1,2,3]]
	var colors: Array[int]=[]
	for face in 6:
		var source_face: int=[1,0,2,3,4,5][face]
		for pixel in 4:
			var actual:=roundi(sample.get_pixel(face*4+pixel,1).r*255) if sample!=null and not sample.is_empty() else -1
			colors.append(actual)
			check(actual==100+source_face*22+rotations[face][pixel],"stock GPU cube face order and rotation %s %s"%[face,pixel])
	source.cube_gpu_texels=colors
	viewport.queue_free()
func original_table(name: String)->Dictionary:
	var bytes: PackedByteArray=catalog.get_resource(name,2017)
	var parser:=Table.new(); var value: Dictionary=parser.parse(Binary.new(bytes).text(0,bytes.size()))
	check(not bytes.is_empty() and parser.failure.is_empty(),"installed "+name+" table")
	return value
func capture(label: String)->PackedByteArray:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var path:=output.trim_suffix(".json")+"-"+label+".png"
	check(image.save_png(path)==OK,"save "+label+" image")
	var colors:={}
	for y in range(0,image.get_height(),8):
		for x in range(0,image.get_width(),8): colors[image.get_pixel(x,y).to_rgba32()]=true
	captures[label]={"path":path,"sha256":hash_bytes(image.get_data()),"sampled_colors":colors.size()}
	check(colors.size()>32,"original actor visibly rendered in "+label)
	return image.get_data()
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--install="): install=arg.substr(10)
		elif arg.begins_with("--variant="): variant=arg.substr(10)
		elif arg.begins_with("--custom-texture-depth="): custom_texture_depth=int(arg.get_slice("=",1))
		elif arg.begins_with("--robe-part="): robe_part=int(arg.get_slice("=",1))
		elif arg=="--enhanced-lighting": enhanced_lighting=true
		elif arg.begins_with("--named-environment="): named_environment=arg.get_slice("=",1)
		elif arg=="--headless-structural": headless_structural=true
	if variant!="shifter" and variant!="split": quit(2); return
	if custom_texture_depth not in [0,24,32]: quit(2); return
	if named_environment not in ["default","present","missing","cube"]: quit(2); return
	if output.is_empty() or not install.is_absolute_path() or FileAccess.file_exists(output): quit(2); return
	if not headless_structural:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		var secondary:=-1
		for index in DisplayServer.get_screen_count():
			if index!=DisplayServer.get_primary_screen(): secondary=index; break
		if secondary<0: quit(2); return
		root.current_screen=secondary; root.position=DisplayServer.screen_get_position(secondary)+Vector2i(100,100); root.size=Vector2i(960,720)
	retained_extension=load("res://native/particle_kernel.gdextension")
	check(retained_extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"current native pose extension loaded")
	catalog=Catalog.new(); check(catalog.mount_install(install),"installed original catalog mounted")
	var bic_path:=install.path_join("data/lcv/shifter.bic" if variant=="shifter" else "data/lcv/monk.bic")
	var bic:=FileAccess.get_file_as_bytes(bic_path)
	var parser:=Gff.new(); var document:=parser.parse(bic,"BIC ")
	var visual:=BicVisual.source(document)
	var baseitems:=original_table("baseitems")
	var cloakmodel:=original_table("cloakmodel")
	var original:=BicVisual.actor(visual,baseitems)
	check(parser.failure.is_empty() and not original.has("error"),"installed original BIC appearance parsed")
	var row_index:=3 if variant=="shifter" else 2
	var row: Dictionary=cloakmodel.get("orderedRows",[])[row_index]
	check((variant=="shifter" and str(row.get("LABEL",""))=="GreatCloak" and int(row.get("MODEL",0))==2 and int(row.get("TEXTURE",0))==2) or (variant=="split" and str(row.get("LABEL",""))=="Arcane" and int(row.get("MODEL",0))==1 and int(row.get("TEXTURE",0))==10),"installed selected cloak row")
	check(int(baseitems.get("orderedRows",[])[80].get("ModelType",-1))==1,"installed cloak baseitem 80 model type")
	if not failures.is_empty(): finish(); return
	if custom_texture_depth!=0: stage_cloak_raster("cloak_"+str(int(row.TEXTURE)).pad_zeros(3))
	if named_environment!="default": stage_environment(row_index)
	var original_part:=3 if variant=="shifter" else 1
	check(original.appearance.equipment.any(func(entry): return int(entry.slot)==64 and int(entry.item.baseItem)==80 and int(entry.item.parts[0])==original_part),"original BIC wears installed cloak")
	if variant=="split":
		for entry in original.appearance.equipment:
			if int(entry.slot)==64: entry.item.parts[0]=2
		check(original.appearance.equipment.any(func(entry): return int(entry.slot)==64 and int(entry.item.parts[0])==2),"synthetic equip points to installed split row 2")
	if robe_part>2:
		var equipped_armor: Dictionary=Appearance.new().equipped(original,2).get("item",{})
		check(equipped_armor.get("parts",[]).size()==19,"original actor has modular armour for the robe variant")
		if not failures.is_empty(): finish(); return
		equipped_armor.parts[18]=robe_part
	var control: Dictionary=original.duplicate(true); control.id=83001
	control.appearance.equipment=control.appearance.equipment.filter(func(entry): return int(entry.slot)!=64)
	var cloaked: Dictionary=original.duplicate(true); cloaked.id=83002
	objects=[control,cloaked]
	source={"variant":variant,"bic_path":bic_path,"bic_sha256":hash_bytes(bic),"original_bic_equipment_slots":original.appearance.equipment.map(func(entry): return int(entry.slot)),"original_cloak_part":original_part,"tested_cloak_part":row_index,"cloak_baseitem":80,"cloak_slot":64,"cloakmodel_row":row,"baseitems_sha256":hash_bytes(catalog.get_resource("baseitems",2017)),"cloakmodel_sha256":hash_bytes(catalog.get_resource("cloakmodel",2017))}
	service=Assets.new(); root.add_child(service); service.configure(catalog); service.cache_directory=output.get_base_dir().path_join("asset-cache")
	scene=Node3D.new(); root.add_child(scene)
	godot_lighting=OS.get_cmdline_user_args().has("--godot-lighting")
	pool=Pool.new(); pool.unshaded=not enhanced_lighting and not godot_lighting
	pool.native_lighting=enhanced_lighting; pool.native_standard=enhanced_lighting
	var scene_map: Node
	if godot_lighting:
		scene_map=preload("res://systems/native_render/model_environment.gd").new()
		scene.add_child(scene_map)
		scene_map.configure(catalog,pool)
	stream=Stream.new(); scene.add_child(stream); stream.configure(catalog,pool,objects,0,output.get_base_dir().path_join("actor-cache"),83001)
	var deadline:=Time.get_ticks_msec()+90000
	while not stream.done and Time.get_ticks_msec()<deadline: await process_frame
	if godot_lighting:
		while not scene_map.map_ready and scene_map.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		check(scene_map.map_ready and scene_map.selected=="chrome1" and not pool.native_standard,"Godot lighting publishes the original scene map without changing lighting mode")
	check(stream.done and stream.actors.size()==2 and stream.stats.errors.is_empty(),"current CreatureStream publishes both character variants")
	if stream.actors.size()!=2: finish(); return
	var control_actor=stream.actors[83001]; var cloaked_actor=stream.actors[83002]
	for bundle in stream.bundles.values():
		if str(bundle.get("error","" )).is_empty() and str(bundle.get("value",{}).get("name",""))==str(cloaked_actor.model_names[0]):
			source.root_node_names=bundle.value.nodes.map(func(node): return str(node.name))
			break
	control_actor.rigs.set_process(false); cloaked_actor.rigs.set_process(false)
	control_actor.position=Vector3.ZERO; cloaked_actor.position=Vector3.ZERO
	control_actor.rotation=Vector3.ZERO; cloaked_actor.rotation=Vector3.ZERO
	var appearance:=Appearance.new()
	var plan: Dictionary=appearance.plan(cloaked,stream.tables)
	var no_environment: Dictionary=stream.tables.duplicate()
	no_environment.cloakmodel=no_environment.cloakmodel.duplicate(true)
	no_environment.cloakmodel.orderedRows[row_index].ENVMAP="NULL"
	var unmapped_plan:=appearance.plan(cloaked,no_environment)
	check(unmapped_plan.attachments.any(func(piece): return int(piece.get("nativeVisualScope",-1))==243 and not piece.get("reflectionAlpha",true)),"authored NULL selects opacity alpha in the cloak request")
	if robe_part>2:
		var robe_pieces: Array=plan.parts.filter(func(part): return int(part.get("partIndex",-1))==18)
		check(robe_pieces.size()==1,"equipped robe is a distinct numbered body part")
		if robe_pieces.size()==1:
			var robe: Dictionary=robe_pieces[0]
			var resolved_robe: String=robe.model if catalog.has_resource(robe.model,2002) else robe.fallbackModel
			var robe_specs: Array=stream.model_specs.values().filter(func(spec): return str(spec.name)==resolved_robe)
			check(cloaked_actor.model_names.has(resolved_robe),"original robe model is published by the actor stream")
			check(robe_specs.size()==1 and robe_specs[0].options.get("metal_palette","")=="pal_armor01","robe asset request carries the worn palette bank")
			source.robe_model=resolved_robe
	var cloak_pieces: Array=plan.get("attachments",[]).filter(func(entry): return int(entry.get("nativeVisualScope",-1))==243)
	check(cloak_pieces.size()==1,"one cloak appearance attachment")
	if cloak_pieces.size()==1:
		var piece: Dictionary=cloak_pieces[0]
		var expected_texture:="cloak_"+str(int(row.TEXTURE)).pad_zeros(3)
		check(piece.get("pltCandidates",[])==[expected_texture],"selected installed TEXTURE row maps to expected PLT")
		check(str(piece.model).ends_with("_cloak_"+str(int(row.MODEL)).pad_zeros(3)),"selected installed MODEL row maps to expected MDL")
		source.cloak_piece={"model":piece.model,"pltCandidates":piece.pltCandidates,"node":piece.node,"nativeVisualScope":piece.nativeVisualScope}
		var selected_specs: Array=stream.model_specs.values().filter(func(spec): return str(spec.get("name",""))==str(piece.model))
		check(selected_specs.size()==1,"exact cloak model request in CreatureStream")
		if selected_specs.size()==1:
			check(selected_specs[0].options.get("plt_candidates",[])==[expected_texture],"actual cloak asset request carries installed TEXTURE PLT")
			check(selected_specs[0].options.get("metal_palette","")=="pal_armor01","cloak asset request names the stock worn metal palette bank")
			check(selected_specs[0].options.get("reflection_alpha",false),"cloak ENVMAP requests reflection alpha")
			check(selected_specs[0].options.get("reflection_map","")==("default" if named_environment=="default" else "cloak_env_probe"),"cloak asset request carries the model row's environment name")
			source.cloak_asset_options=selected_specs[0].options
		var cloak_index: int=cloaked_actor.model_names.find(piece.model)
		check(cloak_index>=0 and not control_actor.model_names.has(piece.model),"equipping selected cloak admits its physical model")
		check(cloak_index>=0 and cloaked_actor.meshes.any(func(mesh):return int(mesh.get_meta("native_source_model_index",-1))==cloak_index),"equipped cloak publishes drawable geometry")
		for bundle in stream.bundles.values():
			if str(bundle.get("value",{}).get("name",""))!=str(piece.model): continue
			var rasters: Array=bundle.get("textures",{}).values()
			check(not rasters.is_empty(),"cloak bundle has a surface texture")
			if rasters.is_empty(): break
			check(rasters[0].get("reflection_alpha",false),"drawable cloak carries stock reflection alpha into material publication")
			var reflection: Dictionary=rasters[0].get("reflection_map",{})
			if named_environment in ["present","cube"]:
				check(not reflection.is_empty(),"named texture resolves through the garment worker")
				if not reflection.is_empty():
					var cube:=named_environment=="cube"
					check(reflection.value.mips[0].data.slice(0,4)==PackedByteArray([100 if cube else 43,211,23,255]),"named reflection carries the mounted pixels")
					check(bool(reflection.get("cube",false))==cube,"TXI cube selects the six-face source")
					var named_pool:=Pool.new(); named_pool.native_lighting=not godot_lighting; named_pool.native_standard=not godot_lighting
					var material_part:={"alpha":1.0,"mesh":{}}
					var mapped: Material=named_pool.material(material_part,rasters[0])
					check(mapped.reflection_texture!=null and mapped.get_shader_parameter("native_reflection_map")==mapped.reflection_texture,"garment material binds the named sampler")
					check(mapped.godot_reflection==godot_lighting,"garment uses the selected lighting policy")
					if cube:
						check(mapped.reflection_texture is Cubemap,"cube texture uses a cube sampler")
						if mapped.reflection_texture is Cubemap and not headless_structural:
							await verify_cube_texels(mapped.reflection_texture)
					var default_raster: Dictionary=rasters[0].duplicate(); default_raster.erase("reflection_map")
					var scene_reflection: Material=named_pool.material(material_part,default_raster)
					check(scene_reflection!=mapped and scene_reflection.reflection_texture==null,"same diffuse pixels can retain distinct reflection material identities")
					named_pool.clear()
			else:
				check(reflection.is_empty(),"default or missing named source uses scene reflection")
			var texture: Dictionary=rasters[0].value
			if custom_texture_depth==0:
				check(int(texture.get("type",-1))==6,"stock cloak retains its layered texture")
			else:
				var pixels: PackedByteArray=texture.mips[0].data
				var alpha_values: Array=[]
				for index in range(3,pixels.size(),4): alpha_values.append(int(pixels[index]))
				alpha_values.sort()
				check(Vector2i(texture.width,texture.height)==Vector2i(2,2) and pixels.slice(0,3)==PackedByteArray([179,89,43]),"same-name custom cloak TGA supplies the published RGB")
				check(alpha_values==([0,96,255,255] if custom_texture_depth==32 else [255,255,255,255]),"custom texture retains its authored alpha or stays solid for RGB")
				source.cloak_raster={"alpha_values":alpha_values,"sha256":rasters[0].sha256}
				var material_part:={"alpha":1.0,"mesh":{"transparency_hint":true}}
				var reflective: Material=pool.material(material_part,rasters[0])
				if godot_lighting:
					var faded_part: Dictionary=material_part.duplicate(); faded_part.alpha=0.5
					var godot_fade: Material=pool.material(faded_part,rasters[0])
					check(godot_fade.godot_reflection and godot_fade.get_shader_parameter("native_alpha")==0.5 and str(godot_fade.shader.code).contains("ALPHA=native_alpha;"),"Godot lighting preserves independent reflection and fading")
				var unmapped: Dictionary=rasters[0].duplicate(); unmapped.erase("reflection_alpha")
				var transparent: Material=pool.material(material_part,unmapped)
				check(reflective.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and transparent.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"reflection alpha keeps cloth solid while unmapped authored alpha still blends")
				var enhanced:=Pool.new(); enhanced.native_lighting=true; enhanced.native_standard=true
				material_part.alpha=0.5
				var fading: Material=enhanced.material(material_part,rasters[0])
				check(fading.reflection_alpha and fading.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and str(fading.shader.code).contains("nwn_effective_alpha=native_alpha"),"reflective cloak can still fade with the independent Part opacity")
				enhanced.clear()
			break
	check(cloaked_actor.unattached_equipment.is_empty(),"root-mounted cloak has no unresolved equipment")
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(.04,.05,.07); scene.add_child(environment)
	var lamp:=DirectionalLight3D.new(); scene.add_child(lamp); lamp.rotation=Vector3(-.6,.3,0)
	camera=Camera3D.new(); scene.add_child(camera); camera.position=Vector3(0,1.8,4.); camera.look_at(Vector3(0,1.2,0)); camera.fov=40.; camera.near=.1; camera.current=true
	if not headless_structural:
		cloaked_actor.hide()
		var unarmed_pixels:=await capture(variant+"-no-cloak")
		control_actor.hide(); cloaked_actor.show()
		var equipped_pixels:=await capture(variant+"-cloak")
		source.pixel_exact_equal=unarmed_pixels==equipped_pixels
		check(not source.pixel_exact_equal,"equipped cloak visibly changes the rendered character")
	var actor_rows:={"control":{"models":control_actor.model_names,"meshes":control_actor.meshes.size(),"unattached_equipment":control_actor.unattached_equipment},"cloaked":{"models":cloaked_actor.model_names,"meshes":cloaked_actor.meshes.size(),"unattached_equipment":cloaked_actor.unattached_equipment}}
	source.actor_rows=actor_rows
	var clip_map: Dictionary=cloaked_actor.rigs.entities[83002].clip_map
	var walk_code:=-1; var walk_name:=""
	for code in clip_map:
		if "walk" in str(clip_map[code]): walk_code=int(code); walk_name=str(clip_map[code]); break
	check(walk_code>=0,"original monk has mapped walk animation")
	if walk_code>=0:
		cloaked_actor.set_animation(walk_code,1.,true)
		for frame in 24:
			cloaked_actor.rigs._update(1./60.)
			await process_frame
		if not headless_structural: await capture(variant+"-cloak-walk")
		source.walk_code=walk_code; source.walk_clip=walk_name
	var live:=LiveWorld.new()
	live.area_id=91; live.controlled_id=83001
	var bare: Dictionary=control.duplicate(true); bare.id=83001; bare.areaId=91
	var equipped: Dictionary=cloaked.duplicate(true); equipped.id=83001; equipped.areaId=91
	live.receive([bare],83001)
	var bare_key: String=live.signature(bare)
	live.installed[83001]=bare_key
	live.receive_delta([equipped],[],83001)
	var equipped_key: String=live.signature(equipped)
	check(equipped_key!=bare_key and live.pending_plan({}).actors.size()==1,"slot-64 equip delta schedules controlled actor replacement")
	live.installed[83001]=equipped_key
	live.receive_delta([bare],[],83001)
	check(live.desired[83001].key==bare_key and live.pending_plan({}).actors.size()==1,"slot-64 unequip delta schedules controlled actor replacement")
	source.live_delta={"bare_key":bare_key,"equipped_key":equipped_key,"equip_replaced":equipped_key!=bare_key,"unequip_returned":live.desired[83001].key==bare_key}
	live.close(); live.free()
	finish()
func finish()->void:
	var source_hashes:={}
	for path in ["systems/native_data/creature_appearance.gd","systems/native_data/asset_service.gd","systems/native_data/palette_texture.gd","systems/native_render/creature_stream.gd","systems/native_render/actor_instance.gd","systems/native_render/resource_pool.gd","systems/native_render/native_model_material.gd","systems/native_render/native_standard_light.gd","systems/native_data/bic_visual.gd","systems/native_data/resource_catalog.gd"]: source_hashes[path]=FileAccess.get_sha256("res://"+path)
	var report:={"success":failures.is_empty(),"failures":failures,"source":source,"source_hashes":source_hashes,"captures":captures,"headless_structural":headless_structural,"secondary":root.current_screen!=DisplayServer.get_primary_screen() if not headless_structural else false,"no_focus":root.get_flag(Window.FLAG_NO_FOCUS) if not headless_structural else true,"scope":"Installed shifter or monk character through CreatureStream and LiveWorld. Optional installed robe and same-name custom TGA exercise garment palette and material selection. Headless mode verifies resource and material properties."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify({"success":report.success,"failures":failures,"report":output,"captures":captures}))
	if is_instance_valid(stream): stream.close(); stream.queue_free()
	if is_instance_valid(service): service.close(); service.queue_free()
	if is_instance_valid(scene): scene.queue_free()
	await process_frame
	if pool!=null: pool.clear()
	quit(0 if report.success else 1)
