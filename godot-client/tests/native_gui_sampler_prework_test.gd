extends "res://tests/native_asset_prework_test.gd"
const Info=preload("res://systems/native_data/gui_texture_info.gd")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	folder=ProjectSettings.globalize_path("user://gui-sampler-tests/"+output.get_file().get_basename())
	if DirAccess.dir_exists_absolute(folder): quit(2); return
	DirAccess.make_dir_recursive_absolute(folder.path_join("input")); write(folder.path_join("input/authored.mdl"),model()); write(folder.path_join("input/parent.mdl"),"newmodel parent\nbeginmodelgeom parent\nnode dummy root\nparent NULL\nendnode\nendmodelgeom parent\n".to_ascii_buffer())
	var tga:=PackedByteArray(); tga.resize(18); tga[2]=2; tga[12]=1; tga[14]=1; tga[16]=32; tga[17]=40; tga.append_array(PackedByteArray([20,120,240,255])); write(folder.path_join("input/paint.tga"),tga)
	var retired:=await request(make_catalog(),"actor-model",true,{"gui_texture_info":"original-gui-sampler-v2"})
	var options:={"gui_texture_info":Info.REVISION}; var catalog=make_catalog(); var cold:=await request(catalog,"actor-model",true,options)
	check(retired.prework_saved and not cold.get("prework_hit",false) and Info.REVISION!="original-gui-sampler-v2","The source-culling raster revision does not reuse an old double-sided GUI prework entry")
	check(cold.textures.paint.gui_sampler.filter and cold.textures.paint.gui_sampler.mipmap and cold.textures.paint.gui_sampler.clamp==0 and not cold.textures.paint.gui_sampler.present,"Absent TXI uses original texture-constructor defaults")
	check(cold.prework_saved and cold.prework_inputs.any(func(row):return row.operation=="exists" and row.name=="paint" and int(row.type)==2022 and not row.present),"Persistent GUI prework records an absent TXI lookup")
	var warm:=await request(make_catalog(),"actor-model",false,options); check(warm.get("prework_hit",false) and warm.textures.paint.gui_sampler==cold.textures.paint.gui_sampler,"Fresh-catalog prework restores the same original sampler")
	write(folder.path_join("input/paint.txi"),"filter 0\nmipmap 0\nclamp 1".to_ascii_buffer()); var added:=await request(make_catalog(),"actor-model",true,options)
	check(not added.get("prework_hit",false) and not added.textures.paint.gui_sampler.filter and not added.textures.paint.gui_sampler.mipmap and added.textures.paint.gui_sampler.clamp==1,"Adding an active TXI invalidates old prework and changes sampler flags")
	check(added.prework_inputs.any(func(row):return row.operation=="bytes" and row.name=="paint" and int(row.type)==2022),"Prepared GUI bundle includes the actual TXI byte dependency")
	warm=await request(make_catalog(),"actor-model",false,options); check(warm.get("prework_hit",false),"Unchanged TXI supports persistent GUI prework reuse")
	write(folder.path_join("input/paint.txi"),"filter 1\nmipmap 0\nclamp 2".to_ascii_buffer()); var changed:=await request(make_catalog(),"actor-model",true,options)
	check(not changed.get("prework_hit",false) and changed.textures.paint.gui_sampler.filter and changed.textures.paint.gui_sampler.clamp==2,"Changing TXI bytes invalidates old flags even when raster/model bytes are unchanged")
	DirAccess.remove_absolute(folder.path_join("input/paint.txi")); var removed:=await request(make_catalog(),"actor-model",true,options)
	check(not removed.get("prework_hit",false) and not removed.textures.paint.gui_sampler.present and removed.textures.paint.gui_sampler.clamp==0,"Removing TXI invalidates prework and restores original defaults")
	DirAccess.make_dir_recursive_absolute(folder.path_join("override")); write(folder.path_join("override/paint.txi"),"filter false\nmipmap false\nclamp 3".to_ascii_buffer()); catalog=make_catalog(); check(catalog.mount_directory(folder.path_join("override"),20000000),"Server-priority TXI layer mounts independently of model and raster")
	var overridden:=await request(catalog,"actor-model",false,options); check(overridden.textures.paint.gui_sampler.clamp==3 and not overridden.textures.paint.gui_sampler.filter,"Actual worker respects higher-priority server sampler metadata")
	var world_only:=await request(catalog,"actor-model",false); check(not world_only.textures.paint.has("gui_sampler"),"World model preparation does not acquire GUI sampler policy")
	await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"scope":"Real native worker and persistent prework across fresh catalogs: TXI absent/present/changed/removed and higher-priority overrides, unchanged pixel/model inputs and opt-in GUI-only policy."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
