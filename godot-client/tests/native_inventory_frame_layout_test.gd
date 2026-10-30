extends "res://tests/native_particle_schedule_test.gd"
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Model=preload("res://systems/native_data/actor_model.gd")
const Layout=preload("res://systems/native_data/inventory_frame_layout.gd")
const Icons=preload("res://systems/native_item_icons.gd")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original inventory frame catalog mounts read-only")
	var layouts: Dictionary={}; var models: Dictionary={}; var names: Dictionary={"inv_box_10x6":true,"ctl_inv_btn_tab":true}
	for name in ["inv_panel","inv_container"]:
		var parser:=Gff.new(); var value:=parser.parse(catalog.get_resource(name,2047),"GUI "); check(parser.failure.is_empty(),"Original GUI "+name); layouts[name]=value.root; names[str(value.root.Obj_ResRef).to_lower()]=true
		for child in value.root.Obj_ChildList:
			if child.has("Obj_ResRef"): names[str(child.Obj_ResRef).to_lower()]=true
	for name in names:
		var parser:=Model.new(); models[name]=parser.parse(catalog.get_resource(name,2002)); check(parser.failure.is_empty(),"Original frame component "+name)
	var frame:=Layout.parse(layouts,models)
	check(str(frame.error).is_empty(),"Original frame and container attachments resolve")
	if not str(frame.error).is_empty(): push_error(str(frame.error)); quit(1); return
	check(frame.size.distance_to(Vector2(360,470))<0.001,"Original360×470 panel extent")
	check(frame.equipment.distance_to(Vector2(0,217))<0.001,"Original equipment attachment point")
	check(frame.repository.rect.position.distance_to(Vector2(4,219))<0.001 and frame.repository.rect.size==Vector2(330,198),"Original lower-left icon hook and33px10×6 grid")
	check(frame.tabs.size()==6 and frame.tabs[0].position.distance_to(Vector2(334,219))<0.001 and absf(frame.tabs[5].position.y-frame.tabs[0].position.y-165)<0.001,"Six original tabs chain through next hooks")
	check(frame.container.grid.rect.size==Vector2(231,165) and frame.container.entries.has("closebutton"),"Original7×5 container grid and close control")
	var changed: Dictionary=layouts.duplicate(true); changed.inv_panel.Obj_ChildList[1].Obj_X+=0.5
	var shifted:=Layout.parse(changed,models)
	check(absf(shifted.entries.xbutton.rect.position.x-frame.entries.xbutton.rect.position.x-50)<0.001,"Active GUI control offsets determine placement")
	var broken:=models.duplicate(true); broken.erase("ctl_inv_btn_tab"); check(not str(Layout.parse(layouts,broken).error).is_empty(),"Missing original tab model is rejected")
	var oracle_path:="res://../backups/animations/native-inventory-reposition-observations-v1.json"
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path)); check(oracle.target==BINARY_SHA and oracle.rows.size()==180,"Pinned unchanged original repository placement corpus")
	for row in oracle.rows:
		var c: Dictionary=row.case; var actual:=Layout.original_position(int(c.x),int(c.y),int(c.width),int(c.height))
		var bits: Array=actual.map(func(value):return PackedFloat32Array([value]).to_byte_array().decode_u32(0))
		check(same(bits,row.calls[0].bits).is_empty(),"Exact original transform bits "+JSON.stringify(c))
	check(Icons.raster_extent(0.170000001,100)==17 and Icons.raster_extent(0.169999999,100)==17,"Floating-point noise cannot stretch17px GUI art into18px rasters")
	check(Icons.raster_extent(0.340000003,100)==34 and Icons.raster_extent(0.3415,100)==35,"Raster bounds preserve real fractional coverage while removing integer noise")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(oracle_path),"container_grid":str(frame.container.grid.rect),"scope":"Installed original GUI/MDL frame, hooks and native33px repository plus180 unchanged original transform calls; no GPU/server result here."},"\t")); file.close()
	print("NATIVE_INVENTORY_FRAME_LAYOUT ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
