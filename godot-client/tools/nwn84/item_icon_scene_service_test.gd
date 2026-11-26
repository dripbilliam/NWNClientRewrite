extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Service=preload("res://systems/native_item_icon_scene_service.gd")
const Host=preload("res://systems/native_item_icon_panel_host.gd")
var replies: Dictionary={}
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<30: failures.append(label)
func on_prepared(key: String,bundle: Dictionary,error: String) -> void:
	replies[key]={"bundle":bundle,"error":error}
func canonical(value: Variant) -> Variant:
	if value is float: return int(value) if value==floor(value) else value
	if value is Array: return value.map(canonical)
	if value is Dictionary:
		var answer: Dictionary={}; var keys: Array=value.keys(); keys.sort()
		for key in keys: answer[key]=canonical(value[key])
		return answer
	return value
func equal(a: Variant,b: Variant) -> bool: return JSON.stringify(canonical(a))==JSON.stringify(canonical(b))
func tga(width: int,red: bool) -> PackedByteArray:
	var bytes:=PackedByteArray(); bytes.resize(18+width*16*4)
	bytes[2]=2; bytes[12]=width&255; bytes[13]=width>>8; bytes[14]=16; bytes[16]=32; bytes[17]=8
	for pixel in width*16:
		var at:=18+pixel*4
		bytes[at]=0 if red else 255 # Blue channel
		bytes[at+1]=0
		bytes[at+2]=255 if red else 0 # Red channel
		bytes[at+3]=255
	return bytes
func raster_bytes(bundle: Dictionary) -> PackedByteArray:
	return bundle.get("textures",{}).get("gui_replace01",{}).get("value",{}).get("mips",[{}])[0].get("data",PackedByteArray())
func material_texture(material: Material) -> Texture2D:
	if material is StandardMaterial3D: return material.albedo_texture
	if material is ShaderMaterial: return material.get_shader_parameter("original_texture")
	return null
func wait_key(service,key: String) -> Dictionary:
	var deadline:=Time.get_ticks_msec()+20000
	while not service.bundles.has(key) and not replies.has(key) and Time.get_ticks_msec()<deadline: await process_frame
	return replies.get(key,{"bundle":service.bundles.get(key,{}),"error":"timeout" if not service.bundles.has(key) else ""})
func verify_bundle(service,key: String,expected: Dictionary,presentation: String,label: String) -> void:
	var bundle: Dictionary=service.bundles.get(key,{})
	check(not bundle.is_empty(),label+" retained model bundle")
	if bundle.is_empty(): return
	check(str(bundle.icon_scene.presentation)==presentation,label+" presentation")
	var expected_model:=Service.presentation_model(expected,presentation)
	if str(bundle.icon_scene.model)!=expected_model: print("MODEL_MISMATCH ",label," actual=",bundle.icon_scene.model," expected=",expected_model)
	check(str(bundle.icon_scene.model)==expected_model,label+" native GUI_ICON model")
	check(equal(bundle.icon_scene.selected,expected),label+" original layer selection")
	check(not bundle.has("prework_icon") and bundle.has("value") and bundle.has("textures"),label+" model and replacements, no finished pixels")
	var replacements: Dictionary=bundle.get("textures",{})
	check(replacements.size()==expected.layers.size(),label+" replacement count")
	for index in expected.layers.size():
		check(replacements.has("gui_replace"+str(index+1).pad_zeros(2)),label+" named replacement "+str(index+1))
	for node in bundle.value.get("nodes",[]):
		if not node.get("mesh",{}).get("render",false): continue
		for name in node.mesh.get("textures",[]):
			if str(name) not in ["","null"]: check(replacements.has(str(name).to_lower()),label+" authored mesh texture "+str(name))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["fixture","report"]): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.fixture)))
	var catalog:=Catalog.new()
	check(catalog.mount_install(str(oracle.install)),"Installed original catalog")
	check(catalog.mount_erf(str(oracle.install).path_join("data/nwm/Prelude.nwm"),100000000),"Prelude original resources")
	var tables: Dictionary={}
	for name in ["baseitems","capart","parts_robe","cloakmodel","iprp_spells"]:
		var parser:=Table.new(); tables[name]=parser.parse(catalog.get_resource(name,2017).get_string_from_ascii())
		check(parser.failure.is_empty(),"Original table "+name)
	var service:=Service.new(); root.add_child(service); service.configure(catalog,"")
	service.prepared.connect(on_prepared)
	var valid:=0; var invalid:=0; var first_valid: Dictionary={}; var flat: Dictionary={}; var composite: Dictionary={}; var layered: Dictionary={}; var armor: Dictionary={}
	for index in oracle.cases.size():
		var row: Dictionary=oracle.cases[index]
		var key: String=service.request(row.item,tables,int(row.gender))
		if row.error:
			invalid+=1; check(key.is_empty() and not service.last_request_error.is_empty(),"Expected original rejection "+str(index)); continue
		valid+=1
		if first_valid.is_empty(): first_valid=row
		match str(row.selected.kind):
			"flat": if flat.is_empty(): flat=row
			"composite": if composite.is_empty(): composite=row
			"layered": if layered.is_empty(): layered=row
			"armor": if armor.is_empty(): armor=row
		check(not key.is_empty(),"Accepted original case "+str(index))
		if key.is_empty(): continue
		var reply: Dictionary=await wait_key(service,key)
		check(str(reply.error).is_empty(),"Prepared original case "+str(index)+": "+str(reply.error))
		if not str(reply.error).is_empty(): continue
		verify_bundle(service,key,row.selected,"normal","Oracle "+str(index))
	check(valid==188 and invalid==4,"192-case native oracle coverage")
	for entry in [{"row":flat,"presentation":"small_r"},{"row":composite,"presentation":"small_s"},{"row":armor,"presentation":"small_s"}]:
		if entry.row.is_empty(): check(false,"Small template sample unavailable"); continue
		var key: String=service.request(entry.row.item,tables,int(entry.row.gender),str(entry.presentation))
		check(not key.is_empty(),"Small item request "+str(entry.presentation))
		if key.is_empty(): continue
		var reply: Dictionary=await wait_key(service,key)
		check(str(reply.error).is_empty(),"Small item preparation "+str(entry.presentation)+": "+str(reply.error))
		if str(reply.error).is_empty(): verify_bundle(service,key,entry.row.selected,str(entry.presentation),"Small "+str(entry.row.selected.kind))
	for row in [flat,composite,layered,armor]:
		if row.is_empty(): check(false,"Auto small sample unavailable"); continue
		var expected: String=Service.small_presentation(row.item,tables,int(row.gender))
		check(expected in ["small_r","small_s"],"Native auto small selector "+str(row.selected.kind))
		var key: String=service.request(row.item,tables,int(row.gender),"small")
		check(not key.is_empty(),"Native auto small request "+str(row.selected.kind))
		if key.is_empty(): continue
		var reply: Dictionary=await wait_key(service,key)
		check(str(reply.error).is_empty(),"Native auto small preparation "+str(row.selected.kind))
		if str(reply.error).is_empty(): verify_bundle(service,key,row.selected,expected,"Auto "+str(row.selected.kind))
	if not first_valid.is_empty():
		var before: String=service.request(first_valid.item,tables,int(first_valid.gender))
		check(service.bundles.has(before) and not service.pending.has(before),"Retained bundle reused on repeat request")
		check(catalog.mount_erf(str(oracle.install).path_join("data/nwm/Prelude.nwm"),100000001),"Additional binding mounted")
		var after: String=service.request(first_valid.item,tables,int(first_valid.gender))
		check(not after.is_empty() and after!=before,"Binding identity invalidates old public key")
		if not after.is_empty():
			var reply: Dictionary=await wait_key(service,after)
			check(str(reply.error).is_empty(),"Changed binding prepares a new model bundle")
		var epoch_before: String=after
		catalog.invalidate() # A same-mount source refresh must retire retained identity.
		var epoch_after: String=service.request(first_valid.item,tables,int(first_valid.gender))
		check(not epoch_after.is_empty() and epoch_after!=epoch_before,"Same-mount source refresh changes retained key")
		if not epoch_after.is_empty():
			var refreshed: Dictionary=await wait_key(service,epoch_after)
			check(str(refreshed.error).is_empty(),"Same-mount source refresh prepares a new bundle")
	if not flat.is_empty():
		var folder: String=str(args.report).get_base_dir().path_join("item-icon-loose-override")
		check(DirAccess.make_dir_recursive_absolute(folder)==OK,"Loose override test directory")
		var name:=str(flat.selected.layers[0].name)
		var path:=folder.path_join(name+".tga")
		var initial:=tga(16,true)
		var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(initial); file.close()
		check(catalog.mount_directory(folder,200000000,[3]),"Loose icon source overrides installed resource")
		# Exercise the normal on-demand source store before refreshing the mount.
		var original_epoch: int=catalog.source_store.get_instance_id()
		check(catalog.get_resource(name,3)==initial,"Catalog reads the selected loose replacement")
		var reads_after_first: int=catalog.stats.reads
		var hits_after_first: int=catalog.stats.source_memory_hits
		check(catalog.get_resource(name,3)==initial and int(catalog.stats.reads)==reads_after_first and int(catalog.stats.source_memory_hits)>hits_after_first,"Catalog reuses resident bytes for the same loose replacement")
		var first_key: String=service.request(flat.item,tables,int(flat.gender))
		var first_reply: Dictionary=await wait_key(service,first_key)
		check(str(first_reply.error).is_empty(),"First loose replacement prepared")
		var before_bundle: Dictionary=service.bundles.get(first_key,{})
		check(raster_bytes(before_bundle).size()==16*16*4 and raster_bytes(before_bundle)[0]==255,"First loose replacement is red")
		var panel:=Control.new(); panel.size=Vector2(80,80); root.add_child(panel)
		var host:=Host.new(); host.size=panel.size; panel.add_child(host)
		check(host.configure(service.pool) and host.bind_slot("item",first_key,before_bundle,Vector2(40,40)),"Panel holds first replacement model")
		var original_texture: Texture2D=material_texture(host.slots.item.model.meshes[0].material_override)
		check(original_texture!=null and original_texture.get_width()==16,"Open panel uses first replacement texture")
		var updated:=tga(17,false)
		file=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(updated); file.close()
		catalog.invalidate()
		check(catalog.source_store.get_instance_id()!=original_epoch and catalog.get_resource(name,3)==updated,"Catalog invalidation selects updated bytes from the same mounted file")
		var second_key: String=service.request(flat.item,tables,int(flat.gender))
		check(second_key!=first_key and not second_key.is_empty(),"Same mounted loose source change invalidates retained key")
		var second_reply: Dictionary=await wait_key(service,second_key)
		check(str(second_reply.error).is_empty(),"Changed loose replacement prepared")
		var after_bundle: Dictionary=service.bundles.get(second_key,{})
		check(raster_bytes(after_bundle).size()==17*16*4 and raster_bytes(after_bundle)[0]==0 and raster_bytes(after_bundle)[2]==255,"Changed loose replacement uses blue source bytes")
		check(host.bind_slot("item",second_key,after_bundle,Vector2(40,40)) and str(host.slots.item.key)==second_key,"Open panel replaces model with refreshed binding")
		var replacement_texture: Texture2D=material_texture(host.slots.item.model.meshes[0].material_override)
		check(replacement_texture!=null and replacement_texture!=original_texture and replacement_texture.get_width()==17,"Open panel binds the changed GPU texture")
		panel.free()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"valid":valid,"invalid":invalid,"bundles":service.bundles.size(),"scope":"Original model and named replacements only; headless, no viewport/icon bitmap, live server or FPS measurement."}
	service.close(); service.free(); await process_frame
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
