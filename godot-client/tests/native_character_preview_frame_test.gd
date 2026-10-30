extends "res://tests/native_quickbar_frame_test.gd"
const Lobby=preload("res://systems/character_lobby.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Digest=preload("res://systems/native_data/prepared_cache.gd")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Native character-preview UI mounts original resources read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.set_gameplay_visible(false)
	check(await wait_until(func():return ui.tables_ready),"Native active rule tables prepare before record projection")
	var classes: Dictionary=ui.text.tables.classes.duplicate(true); classes.orderedRows[10].Name="16777217"; ui.text.publish_table("classes",classes)
	ui.text.publish_table("ruleset",{"orderedRows":[{"Label":"CHARGEN_ABILITY_NEUTRAL_VALUE","Value":"8"}]}); ui.receive({"kind":"tlk-overrides","entries":[{"strRef":16777217,"text":"Server class one"},{"strRef":16777218,"text":"Server description one"},{"strRef":58349,"text":"Server resistance one: "}]},-1)
	var writer:=Writer.new(); var raw:=writer.write("BIC ",Writer.record({"FirstName":Writer.field(12,{"strRef":4294967295,"entries":[{"languageId":0,"text":"Native Café"}]}),"LastName":Writer.field(12,{"strRef":4294967295,"entries":[{"languageId":0,"text":"Preview"}]}),"Description":Writer.field(12,{"strRef":16777218,"entries":[]}),"Str":Writer.field(0,14),"HitPoints":Writer.field(3,18),"CurrentHitPoints":Writer.field(3,99),"MaxHitPoints":Writer.field(3,18),"PregameCurrent":Writer.field(3,13),"ArmorClass":Writer.field(3,16),"PortraitId":Writer.field(2,65534),"Portrait":Writer.field(11,"po_clsbard_"),"ClassList":Writer.field(15,[Writer.record({"Class":Writer.field(5,10),"ClassLevel":Writer.field(3,4)})]),"CombatInfo":Writer.field(14,Writer.record({"SpellResistance":Writer.field(0,5)})),"SkillList":Writer.field(15,[Writer.record({"Rank":Writer.field(0,7)})]),"FeatList":Writer.field(15,[Writer.record({"Feat":Writer.field(2,12)})])}))
	var directory:=output.trim_suffix(".json")+"-sources"; DirAccess.make_dir_recursive_absolute(directory); var digest:=Digest.digest(raw); var path:=directory.path_join(digest+".bic"); var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(raw); file.close()
	var lobby:=Lobby.new(); surface.add_child(lobby); lobby.request.connect(func(message):requests.append(message.duplicate(true))); lobby.configure_preview(directory); lobby.configure_native(ui.inventory.frame_skin,ui.text,catalog,ui.assets.cache_directory)
	var state:={"phase":"character-selection","connected":true,"canSelect":true,"canCreate":true,"selected":"installed:test","choices":[{"key":"installed:test","label":"Source preview","source":"installed","pregenerated":false}],"preview":{"format":"native-bic-file-v1","sha256":digest,"bytes":raw.size(),"path":path,"abilities":{"Str":99}}}
	lobby.apply_state({"connection":1,"state":JSON.parse_string(JSON.stringify(state))})
	check(await wait_until(func():return lobby.native_chooser.layout_ready and not lobby.native_preview.value.is_empty() and lobby.native_chooser.record_projection.get("ready",false) and lobby.native_chooser.record_labels.title.text==ui.text.raw({"strRef":0xf182})+", Native Café Preview"),"Actual native worker feeds the original character chooser's record controls and localized title")
	var native=lobby.native_chooser
	check(native.record_labels.strstat.text=="14" and native.record_labels.strmod.text=="3","Record values come from owned BIC bytes and native active rules, not injected JS display fields")
	check(native.record_labels.hitpoints.text=="13/18" and native.record_labels.armorclass.text=="16","Original typed PregameCurrent/maximum HP and serialized AC display independently of CurrentHitPoints")
	check(native.record_labels.classes.text.contains("Server class one (4)") and native.detail.get_parsed_text().contains("Server resistance one: 5") and not native.detail.get_parsed_text().contains("Server description one"),"Native BIC class and CombatInfo display through active server TLK rather than an interim description")
	check(lobby.record_preview().skills==[{"id":0,"rank":7}] and lobby.record_preview().feats==[12],"Native page data retains raw skill/feat identities")
	check(not ui.chat.is_visible_in_tree() and native.is_visible_in_tree(),"Native preview does not reveal gameplay UI during character selection")
	var decoded: int=lobby.native_preview.stats.decoded; state.serverInfo={"playerCount":3}; lobby.apply_state({"connection":1,"state":state}); await process_frame
	check(lobby.native_preview.stats.decoded==decoded and native.record_labels.title.text==ui.text.raw({"strRef":0xf182})+", Native Café Preview","Unrelated lobby metadata does not reparse or erase the current native record")
	ui.receive({"kind":"tlk-overrides","entries":[{"strRef":16777217,"text":"Server class two"},{"strRef":58349,"text":"Server resistance two: "},{"strRef":0xf182,"text":"Server record"}]},-1)
	check(await wait_until(func():return native.record_labels.classes.text.contains("Server class two (4)") and native.detail.get_parsed_text().contains("Server resistance two: 5") and native.record_labels.title.text=="Server record, Native Café Preview"),"Same-key TLK override updates the original title, class and generated detail text without another BIC or table-count change")
	check(lobby.native_preview.stats.decoded==decoded,"Late native text publication does not reread/redecode the unchanged BIC")
	if DisplayServer.get_name()!="headless":
		check(await wait_until(func():return ui.inventory.frame_skin.art.waiting.is_empty() and ui.inventory.frame_skin.art.models.pending.is_empty() and not ui.inventory.frame_skin.art.models.active and ui.inventory.frame_skin.fonts.pending.is_empty()),"Source record artwork and fonts finish for visual review")
		await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Original-resource native BIC record viewport saved for review")
	await click(native.buttons.playbutton.get_global_rect().get_center()); check(requests.any(func(message):return message.kind=="lobby-play" and message.key=="installed:test" and message.connection==1),"The visible native record's Play control retains the original scoped admission request")
	state.phase="playing"; state.canSelect=false; lobby.apply_state({"connection":1,"state":state}); await process_frame; check(lobby.native_preview.value.is_empty() and not native.is_visible_in_tree(),"World entry invalidates the pregame native preview owner")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	lobby.native_preview.close(); var preview_state: Dictionary=lobby.native_preview.snapshot(); lobby.close_native(); lobby.free(); ui.close(); ui.free(); await process_frame; await process_frame
	file=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"preview":preview_state,"publicConnections":0,"fullUiParity":false,"derivedCombatParity":false,"scope":"Real native BIC worker to source chooser controls, active server rule/TLK updates, actual pointer Play and phase/lifetime separation. Full derived record and remaining pages remain open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
