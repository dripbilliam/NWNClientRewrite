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

func _initialize()->void: call_deferred("run")
func check(ok: bool,label: String)->void:
	if not ok: failures.append(label)
func hash_bytes(bytes: PackedByteArray)->String:
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); return hash.finish().hex_encode()
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
		elif arg=="--headless-structural": headless_structural=true
	if variant!="shifter" and variant!="split": quit(2); return
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
	var original_part:=3 if variant=="shifter" else 1
	check(original.appearance.equipment.any(func(entry): return int(entry.slot)==64 and int(entry.item.baseItem)==80 and int(entry.item.parts[0])==original_part),"original BIC wears installed cloak")
	if variant=="split":
		for entry in original.appearance.equipment:
			if int(entry.slot)==64: entry.item.parts[0]=2
		check(original.appearance.equipment.any(func(entry): return int(entry.slot)==64 and int(entry.item.parts[0])==2),"synthetic equip points to installed split row 2")
	var control: Dictionary=original.duplicate(true); control.id=83001
	control.appearance.equipment=control.appearance.equipment.filter(func(entry): return int(entry.slot)!=64)
	var cloaked: Dictionary=original.duplicate(true); cloaked.id=83002
	objects=[control,cloaked]
	source={"variant":variant,"bic_path":bic_path,"bic_sha256":hash_bytes(bic),"original_bic_equipment_slots":original.appearance.equipment.map(func(entry): return int(entry.slot)),"original_cloak_part":original_part,"tested_cloak_part":row_index,"cloak_baseitem":80,"cloak_slot":64,"cloakmodel_row":row,"baseitems_sha256":hash_bytes(catalog.get_resource("baseitems",2017)),"cloakmodel_sha256":hash_bytes(catalog.get_resource("cloakmodel",2017))}
	service=Assets.new(); root.add_child(service); service.configure(catalog); service.cache_directory=output.get_base_dir().path_join("asset-cache")
	scene=Node3D.new(); root.add_child(scene)
	pool=Pool.new(); pool.unshaded=true
	stream=Stream.new(); scene.add_child(stream); stream.configure(catalog,pool,objects,0,output.get_base_dir().path_join("actor-cache"),83001)
	var deadline:=Time.get_ticks_msec()+90000
	while not stream.done and Time.get_ticks_msec()<deadline: await process_frame
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
			source.cloak_asset_options=selected_specs[0].options
		check(cloaked_actor.model_names.has(piece.model) and not control_actor.model_names.has(piece.model),"equipping selected cloak admits its physical model")
	check(cloaked_actor.meshes.size()>control_actor.meshes.size(),"equipping selected cloak adds drawable actor geometry")
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
	finish()
func finish()->void:
	var source_hashes:={}
	for path in ["systems/native_data/creature_appearance.gd","systems/native_render/creature_stream.gd","systems/native_render/actor_instance.gd","systems/native_data/bic_visual.gd","systems/native_data/resource_catalog.gd"]: source_hashes[path]=FileAccess.get_sha256("res://"+path)
	var report:={"success":failures.is_empty(),"failures":failures,"source":source,"source_hashes":source_hashes,"captures":captures,"headless_structural":headless_structural,"secondary":root.current_screen!=DisplayServer.get_primary_screen() if not headless_structural else false,"no_focus":root.get_flag(Window.FLAG_NO_FOCUS) if not headless_structural else true,"scope":"Current production source, original shifter BIC row 3 or monk BIC with only cloak part changed to installed row 2. Control removes slot 64. Static and 24-step mapped walk. Headless structural mode omits pixel capture and makes no visual claim. No FPS or live Arelith."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify({"success":report.success,"failures":failures,"report":output,"captures":captures}))
	if is_instance_valid(stream): stream.close(); stream.queue_free()
	if is_instance_valid(service): service.close(); service.queue_free()
	if is_instance_valid(scene): scene.queue_free()
	await process_frame
	if pool!=null: pool.clear()
	quit(0 if report.success else 1)
