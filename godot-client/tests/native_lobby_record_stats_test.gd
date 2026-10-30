extends "res://tests/native_character_lobby_frame_test.gd"
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Digest=preload("res://systems/native_data/prepared_cache.gd")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original resources mount read-only for native Character input")
	var game:=Gameplay.new(); surface.add_child(game); game.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); game.set_gameplay_visible(false)
	check(await wait_until(func():return game.tables_ready),"Active rules load without admitting a world")
	var races: Dictionary=game.text.tables.racialtypes.duplicate(true); races.orderedRows[6].DexAdjust="2"; game.text.publish_table("racialtypes",races)
	var fields:={"FirstName":Writer.field(12,{"strRef":4294967295,"entries":[{"languageId":0,"text":"Native statistics preview"}]}),"Race":Writer.field(0,6),"Subrace":Writer.field(10,"Server bloodline"),"GoodEvil":Writer.field(0,85),"LawfulChaotic":Writer.field(0,15),"ClassList":Writer.field(15,[Writer.record({"Class":Writer.field(5,10),"ClassLevel":Writer.field(3,5)})]),"Str":Writer.field(0,14),"Dex":Writer.field(0,12),"Con":Writer.field(0,10),"Int":Writer.field(0,16),"Wis":Writer.field(0,10),"Cha":Writer.field(0,8),"ArmorClass":Writer.field(3,16),"HitPoints":Writer.field(3,20),"CurrentHitPoints":Writer.field(3,1),"MaxHitPoints":Writer.field(3,40),"PregameCurrent":Writer.field(3,17),"Experience":Writer.field(4,12000)}
	fields.FortSaveThrow=Writer.field(1,-2); fields.RefSaveThrow=Writer.field(1,7); fields.WillSaveThrow=Writer.field(1,4); fields.BaseAttackBonus=Writer.field(0,99)
	fields.CombatInfo=Writer.field(14,Writer.record({"SpellResistance":Writer.field(0,9),"ArcaneSpellFail":Writer.field(0,12),"ArmorCheckPen":Writer.field(0,3)}))
	fields.Description=Writer.field(12,{"strRef":4294967295,"entries":[{"languageId":0,"text":"Interim description must not replace generated statistics."}]})
	var raw:=Writer.new().write("BIC ",Writer.record(fields)); var directory:=output.trim_suffix(".json")+"-sources"; DirAccess.make_dir_recursive_absolute(directory); var digest:=Digest.digest(raw); var path:=directory.path_join(digest+".bic"); var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(raw); file.close()
	ui=Lobby.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_preview(directory); ui.configure_native(game.inventory.frame_skin,game.text,catalog,game.assets.cache_directory); native=ui.native_chooser
	state={"phase":"character-selection","connected":true,"canSelect":true,"canCreate":true,"selected":"installed:stats","choices":[{"key":"installed:stats","label":"Native statistics preview","source":"installed","pregenerated":false}],"preview":{"format":"native-bic-file-v1","sha256":digest,"bytes":raw.size(),"path":path}}
	await present()
	check(await wait_until(func():return native.layout_ready and ui.native_preview.stats.decoded==1 and native.record_projection.get("ready",false) and native.rule_jobs.is_empty()),"Typed native BIC and active XP/class dependencies prepare Character labels")
	if native.layout_ready and native.record_projection.get("ready",false):
		var before:=requests.size(); var decoded: int=ui.native_preview.stats.decoded
		check(native.record_labels.title.text==game.text.raw({"strRef":0xf182})+", Native statistics preview" and native.record_labels.dexstat.text=="14" and native.record_labels.dexmod.text=="2","Original Character attachments display the localized record title and active racial gains rather than raw BIC Dexterity")
		check(native.record_labels.hitpoints.text=="17/40" and native.record_labels.armorclass.text=="16","Original HP and AC labels use distinct typed preview fields")
		check(native.record_labels.classes.text.begins_with("Server bloodline, "+game.text.raw({"strRef":118})+"\n") and native.record_labels.classes.text.contains(native.rules.title("classes",10)+" (5)"),"Original heading uses the custom subrace, localized alignment and class level")
		check(native.record_labels.experience.text==game.text.raw({"strRef":314})+": 12000" and native.record_labels.nextlevel.text==game.text.raw({"strRef":315})+": "+str(native.record_projection.nextExperience),"Both XP controls resolve current native TLK and the active experience table")
		var detail_text: String=native.detail.get_parsed_text()
		check(detail_text.contains(game.text.raw({"strRef":317})+": -2") and detail_text.contains(game.text.raw({"strRef":318})+": 7") and detail_text.contains(game.text.raw({"strRef":319})+": 4"),"Actual lower Character list displays typed signed saving throws")
		check(detail_text.contains(game.text.raw({"strRef":40424})+"2") and detail_text.contains(game.text.raw({"strRef":58349})+"9") and detail_text.contains(game.text.raw({"strRef":58350})+"12%") and detail_text.contains(game.text.raw({"strRef":58351})+"-3"),"Original active wizard BAB and imported combat values replace the interim description")
		check(not detail_text.contains("Interim description") and detail_text.ends_with(game.text.raw({"strRef":58352})),"Pregame detail enumeration ends with the original Effects heading")
		check(native.detail.get_meta("native_font_resource","")=="ttf fnt_default 14" and is_equal_approx(native.detail_scroll.position.y+native.detail_scroll.size.y,native.page.size.y) and native.detail_bar.font_name.is_empty() and is_equal_approx(native.detail_bar.line_step,20),"Original detail font, source bottom extent and fixed20-pixel list scrollbar replace generic dimensions")
		check(await wait_until(func():return native.detail.get_meta("native_font_applied","")=="ttf fnt_default 14"),"Original Character dialog font becomes available")
		check(native.detail.get_theme_constant("line_separation")+ceili(native.detail.get_theme_font("normal_font").get_height(14))==20,"Original20-pixel detail row advance survives the dialog-font load")
		await click(native.record_tabs[1].get_global_rect().get_center()); await click(native.record_tabs[0].get_global_rect().get_center())
		check(native.record_index==0 and native.statistics.is_visible_in_tree() and native.record_labels.dexstat.text=="14","Original tab input returns to the typed statistics owner")
		ui.panel.scale=Vector2(1.25,1.25); ui.panel.position=Vector2(80,50); await process_frame
		await click(native.record_tabs[2].get_global_rect().get_center()); await click(native.record_tabs[0].get_global_rect().get_center())
		check(native.record_index==0 and native.record_labels.hitpoints.text=="17/40","Character tab input follows125-percent canvas transforms")
		game.receive({"kind":"tlk-overrides","entries":[{"strRef":314,"text":"Server XP"},{"strRef":315,"text":"Server next"}]},-1)
		check(await wait_until(func():return native.record_labels.experience.text=="Server XP: 12000" and native.record_labels.nextlevel.text.begins_with("Server next: ")),"Same-key TLK publication refreshes both original XP labels")
		races.orderedRows[6].DexAdjust="4"; game.text.publish_table("racialtypes",races)
		check(await wait_until(func():return native.record_labels.dexstat.text=="16" and native.record_labels.dexmod.text=="3"),"Active server racial-table changes refresh displayed scores and modifiers")
		var bab_name: String=native.rules.cell(native.rules.row("classes",10),"AttackBonusTable").to_lower(); var bab: Dictionary=game.text.tables[bab_name].duplicate(true); bab.orderedRows[4].BAB="11"; game.text.publish_table(bab_name,bab)
		check(await wait_until(func():return native.detail.get_parsed_text().contains(game.text.raw({"strRef":40424})+"11")),"Late active BAB-table publication refreshes the Character detail value")
		check(ui.native_preview.stats.decoded==decoded and requests.size()==before,"Display refresh neither reparses BIC bytes nor fabricates gameplay requests")
		game.receive({"kind":"tlk-overrides","entries":[{"strRef":317,"text":"Server Fortitude line\n".repeat(40)}]},-1)
		check(await wait_until(func():return native.detail.get_parsed_text().begins_with("Server Fortitude line\n") and native.detail_scroll.get_v_scroll_bar().max_value>native.detail_scroll.get_v_scroll_bar().page),"Late server detail text refreshes the actual native list and scroll range")
		var wheel:=InputEventMouseButton.new(); wheel.position=native.detail_scroll.get_global_rect().get_center(); wheel.global_position=wheel.position; wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true; wheel.factor=1; surface.push_input(wheel,true); await process_frame; await process_frame
		check(native.detail_scroll.scroll_vertical>0,"Wheel input over the detail body scrolls its original linked owner")
		var prior_scroll: int=native.detail_scroll.scroll_vertical
		await click(native.record_tabs[2].get_global_rect().get_center()); await click(native.record_tabs[0].get_global_rect().get_center())
		check(native.detail_scroll.scroll_vertical==prior_scroll,"Reopening the unchanged Character tab retains its detail position")
		if DisplayServer.get_name()!="headless":
			check(await wait_until(func():return game.inventory.frame_skin.art.waiting.is_empty() and game.inventory.frame_skin.art.models.pending.is_empty() and not game.inventory.frame_skin.art.models.active),"Original Character artwork settles before visual review")
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+"-125.png")==OK,"Character preview saved at125-percent scale")
			ui.panel.scale=Vector2.ONE; ui.panel.position=(Vector2(surface.size)-native.size)/2; await process_frame; await RenderingServer.frame_post_draw
			check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Character preview saved at source scale")
		state.preview=null; state.selected=null; await present(2)
		check(native.record_projection.is_empty() and native.record_labels.dexstat.text.is_empty() and native.record_labels.hitpoints.text.is_empty() and native.detail.get_parsed_text().is_empty(),"Replacing selection clears the previous typed statistics and detail text")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	var retired_bar=native.detail_bar; ui.close_native(); check(retired_bar.closed,"Closing the chooser retires the original Character detail scrollbar"); ui.free(); game.close(); game.free(); await process_frame; await process_frame
	check(DirAccess.remove_absolute(path)==OK and DirAccess.remove_absolute(directory)==OK,"Owned preview fixture bytes retire after the native worker closes")
	var out:=FileAccess.open(output,FileAccess.WRITE); out.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"headless":DisplayServer.get_name()=="headless","fullUiParity":false,"fullRecordParity":false,"scope":"Typed native BIC Character numbers/detail text, original controls/font/scroll ownership, active rules/TLK refresh, stale selection and lifetime. Headless checks do not accept rendered appearance or complete original input/state parity."},"  ")+"\n"); out.close(); quit(0 if failures.is_empty() else 1)
