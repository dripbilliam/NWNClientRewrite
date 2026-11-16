extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Art=preload("res://systems/native_ui_art.gd")
const TextOwner=preload("res://systems/native_data/talk_text.gd")
const ClassChoice=preload("res://systems/native_class_chooser.gd")
const SkillsChoice=preload("res://systems/native_skills_chooser.gd")
const FeatsChoice=preload("res://systems/native_feats_chooser.gd")
var failures: Array=[]
func check(value: bool,label: String) -> void:
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var install:="";var graphical:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="):install=arg.trim_prefix("--install=")
		elif arg=="--graphical":graphical=true
	if install.is_empty():quit(2);return
	if graphical:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		var primary:=DisplayServer.get_primary_screen()
		for screen in DisplayServer.get_screen_count():
			if screen!=primary:root.current_screen=screen;root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80);break
		root.size=Vector2i(1100,850)
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):quit(3);return
	catalog.build_resource_index()
	var painter:=Painter.new();root.add_child(painter);painter.configure_source(catalog,"")
	var art:=Art.new();root.add_child(art);art.configure(catalog,"")
	var text:=TextOwner.new();text.base.open_file(install.path_join("lang/en/data/dialog.tlk"))
	var host:=Control.new();root.add_child(host);host.size=root.size
	var class_choice:=ClassChoice.new();host.add_child(class_choice);class_choice.configure(painter,text,catalog,"");class_choice.start()
	var class_values:={"entries":[{"id":0,"name":"Original class","title":480,"description":484,"icon":"ir_moveto","enabled":true}],"recommended":{}}
	class_choice.set_context(class_values,true,text,art,[1,"class"]);class_choice.open()
	check(not class_choice.visible and class_choice.art_pending,"Cold class choice stays hidden")
	await wait_choice(class_choice,90000)
	var class_cold: Dictionary=class_choice.art_snapshot()
	check(class_choice.visible and class_cold.ready and class_choice.art_error.is_empty() and class_cold.images_expected==class_cold.images_ready,"Class original art and icon ready before reveal")
	class_choice.dismiss();class_choice.open()
	check(class_choice.visible and not class_choice.art_pending and class_choice.art_snapshot().ready,"Warm class choice reopens fully drawn")
	var first_icon: Texture2D=class_choice.row_icon_targets[0].target.texture
	var changed_values: Dictionary=class_values.duplicate(true);changed_values.entries[0].icon="ir_pickup"
	class_choice.set_context(changed_values,true,text,art,[1,"class"]);class_choice.open()
	await wait_choice(class_choice,10000)
	var changed_icon: TextureRect=class_choice.row_icon_targets[0].target
	var current_icon: Texture2D=changed_icon.texture
	changed_icon.texture=first_icon
	var stale_icon_rejected: bool=not class_choice.art_snapshot().ready
	changed_icon.texture=current_icon
	check(stale_icon_rejected and class_choice.art_snapshot().ready,"Changed class icon rejects stale displayed texture")
	class_choice.dismiss()
	var missing_values: Dictionary=class_values.duplicate(true);missing_values.entries[0].icon="nwn84_absent_icon"
	class_choice.set_context(missing_values,true,text,art,[2,"class"]);class_choice.open()
	await wait_choice(class_choice,10000)
	var missing_explicit: bool=class_choice.visible and not class_choice.art_error.is_empty() and class_choice.art_overlay.visible and class_choice.art_message.text.contains("nwn84_absent_icon")
	check(missing_explicit,"Missing class icon shows opaque explicit failure")
	var cancelled: Array=[]
	class_choice.art_cancel_requested.connect(func(scope):cancelled.append(scope))
	class_choice.art_overlay.get_child(1).pressed.emit()
	check(not class_choice.wanted and cancelled==[[2,"class"]],"Failure cancel preserves creator scope")
	var skills:=SkillsChoice.new();host.add_child(skills);skills.configure(painter,text,catalog,"");skills.start()
	var skill_model:={"ready":true,"entries":[{"id":0,"name":"Original skill","icon":"ir_pickup","enabled":true,"title":480,"description":484}],"details":{0:{"rank":0,"modifier":0,"value":0,"cost":1}},"points":2}
	skills.set_context(skill_model,true,text,art,[3,"skills"]);skills.open()
	check(not skills.visible and skills.art_pending,"Cold skills choice stays hidden")
	await wait_choice(skills,90000)
	var skill_cold: Dictionary=skills.art_snapshot()
	check(skills.visible and skill_cold.ready and skills.art_error.is_empty() and skill_cold.images_expected==skill_cold.images_ready,"Skills original art and icon ready before reveal")
	skills.dismiss();skills.open()
	check(skills.visible and not skills.art_pending and skills.art_snapshot().ready,"Warm skills choice reopens fully drawn")
	skills.dismiss()
	var feats:=FeatsChoice.new();host.add_child(feats);feats.configure(painter,text,catalog,"");feats.start()
	var feat_model:={"ready":true,"available":[{"id":1,"name":"Original feat","icon":"ir_moveto","enabled":true,"description":484}],"known":[],"remaining":1,"canAccept":true}
	feats.set_context(feat_model,true,text,art,[4,"feats"]);feats.open()
	check(not feats.visible and feats.art_pending,"Cold feats choice stays hidden")
	await wait_choice(feats,90000)
	var feat_cold: Dictionary=feats.art_snapshot()
	check(feats.visible and feat_cold.ready and feats.art_error.is_empty() and feat_cold.images_expected==feat_cold.images_ready,"Feats original art and icon ready before reveal")
	feats.dismiss();feats.open()
	check(feats.visible and not feats.art_pending and feats.art_snapshot().ready,"Warm feats choice reopens fully drawn")
	print(JSON.stringify({"success":graphical and failures.is_empty(),"failures":failures,"class":class_cold,"skills":skill_cold,"feats":feat_cold,"stale_icon_rejected":stale_icon_rejected,"missing_explicit":missing_explicit,"shared_rasters":catalog.ui_asset_owner().snapshot().images.get("raster",0)}))
	feats.close();feats.free();skills.close();skills.free();class_choice.close();class_choice.free();host.free();art.close();art.free();painter.close();painter.free();text.close()
	quit(0 if graphical and failures.is_empty() else 1)
func wait_choice(choice,timeout_ms: int) -> void:
	var deadline:=Time.get_ticks_msec()+timeout_ms
	while Time.get_ticks_msec()<deadline and not choice.visible and choice.art_error.is_empty():await process_frame
