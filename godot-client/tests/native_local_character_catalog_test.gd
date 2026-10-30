extends "res://tests/native_character_lobby_frame_test.gd"
const LocalPolicy=preload("res://systems/native_data/local_character_metadata.gd")
const LocalCatalog=preload("res://systems/native_local_character_catalog.gd")
func run() -> void:
	var output:=""; var install:=""; var fixture_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--fixture="): fixture_path=arg.substr(10)
	if output.is_empty() or install.is_empty() or fixture_path.is_empty() or FileAccess.file_exists(output): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture_path)); var choices: Array=[]
	for row in fixture.rows:
		var item: Dictionary=row.duplicate(true); item.erase("expected"); choices.append(item)
	check(choices.size()==39,"Read-only original installation supplies39 actual BIC byte sources")
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original catalog mounts read-only for local row metadata")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Local metadata uses the installed TLK through native text")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	ui=Lobby.new(); surface.add_child(ui); ui.local_catalog.configure([fixture.directory]); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); native=ui.native_chooser
	state={"phase":"character-selection","connected":true,"canSelect":true,"selected":null,"choices":choices}; await present()
	check(await wait_until(func():return native.layout_ready and ui.can_select()),"Native worker and active Pregen/classes/portrait tables become ready without a world")
	check(ui.local_catalog.errors.is_empty() and ui.local_catalog.values.size()==39 and ui.local_catalog.decoded==39,"All39 real BIC records decode once natively with no metadata failures")
	var decoded: Array=ui.catalog_choices(text)
	var differences: Array=[]
	for source in fixture.rows:
		var matches: Array=decoded.filter(func(row):return row.key==source.key); var expected: Dictionary=source.expected
		var expected_classes: Array=[]
		for entry in expected.classes: expected_classes.append({"id":int(entry.id),"level":int(entry.level)})
		if differences.size()<3 and matches.size()==1: differences.append({"key":source.key,"expected":expected,"actual":{"name":matches[0].label,"classes":matches[0].classes,"portrait":matches[0].portrait,"firstName":matches[0].firstName}})
		check(matches.size()==1 and matches[0].label==expected.name and matches[0].native_only and expected.classes.all(func(entry):return entry.id==floor(entry.id) and entry.level==floor(entry.level)) and matches[0].classes==expected_classes and matches[0].portrait==expected.portrait and (matches[0].portrait<65534 or matches[0].portraitRef==str(expected.portraitRef).to_lower()),"Native name/classes/portrait match independently decoded raw BIC: "+str(source.key))
	check(decoded.all(func(row):return row.pregenerated) and native.row_keys.is_empty() and requests.is_empty() and not native.pregen.disabled,"Actual original Pregen.2DA hides all39 installed pregenerated characters by default without a Play or selection request")
	text.publish_table("pregen",{"columns":["LABEL","FILENAME"],"orderedCells":[["OnlyMage","wizard"]],"orderedRows":[{"LABEL":"OnlyMage","FILENAME":"wizard"}]}); await process_frame
	check(native.row_keys.size()==38 and not native.row_keys.has("installed:wizard.bic") and ui.local_catalog.decoded==39,"An active server table override refilters cached native metadata without decoding BICs again")
	await click(native.pregen.get_global_rect().get_center())
	check(native.show_pregenerated and native.row_keys.size()==39 and native.row_keys.has("installed:wizard.bic") and not ui.native_selection.activate,"Actual source checkbox reveals the typed native rows and reselects without Play")
	var before: int=ui.local_catalog.decoded
	var class_ref:=int(text.tables.classes.orderedRows[10].Name); text.overrides[class_ref]="Server Mage"; text.mark_changed(); await process_frame
	check(native.labels["row:classes:installed:wizard.bic"].text.contains("Server Mage") and ui.local_catalog.decoded==before,"Local class labels refresh from active custom TLK without rereading character bytes")
	check(LocalPolicy.pregenerated("wizard",text.tables.pregen) and not LocalPolicy.pregenerated("Wizard",text.tables.pregen) and not LocalPolicy.pregenerated("fighter",text.tables.pregen),"Pregenerated membership follows the original exact filename comparison and active physical column1")
	check(LocalPolicy.ordinal("character12")==12 and LocalPolicy.ordinal("character")==0 and LocalPolicy.ordinal("character0")==0,"Original ordinary filename suffix numbering is independent of character metadata")
	text.publish_table("pregen",{"error":"Owned unavailable-table fixture","orderedCells":[["Old","wizard"]]}); await process_frame
	check(ui.can_select() and ui.catalog_choices(text).all(func(row):return not row.pregenerated) and ui.local_catalog.decoded==before,"Original failed Pregen load keeps local selection available with no pregenerated matches, ignoring stale cells")
	text.publish_table("pregen",{"columns":["LABEL"],"orderedCells":[["NoFilenameColumn"]]}); await process_frame
	check(ui.can_select() and ui.catalog_choices(text).all(func(row):return not row.pregenerated),"An active table without a physical filename column supplies no matches without hard-locking local characters")
	if DisplayServer.get_name()!="headless":
		check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Native local row artwork and fonts settle")
		await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Actual native local list captured with original row and portrait artwork")
	state.choices=[{"key":"server:first","label":"stale transport label","source":"server","serverSource":2,"firstName":{"entries":[{"languageId":0,"text":"Alpha"}]},"lastName":{"strRef":16777219}},{"key":"server:second","label":"another transport label","source":"server","serverSource":2,"firstName":{"text":"Zulu"}}]; text.overrides[16777219]="Native Name"; await present(2)
	check(native.labels["row:name:server:first"].text=="Alpha Native Name" and native.labels["row:name:server:second"].text=="Zulu","Received server names resolve localized entries and active TLK natively instead of using transport labels")
	await row_down("server:second"); state.selected="server:second"; state.selectionAck={"key":"server:second","requestId":ui.native_selection.requestId}; await present(2); var count:=requests.size()
	text.overrides[16777219]="Refreshed Name"; text.mark_changed(); await process_frame
	check(native.labels["row:name:server:first"].text=="Alpha Refreshed Name" and requests.size()==count and ui.native_selection.is_empty() and ui.state.selected=="server:second","Late name localization repaints rows without resetting the user's acknowledged selection")
	var native_stats: Dictionary=ui.local_catalog.snapshot(); ui.close_native(); ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var reader:=LocalCatalog.new(); surface.add_child(reader); reader.configure([fixture.directory]); var bad: Array=[]
	for kind in ["root","digest","size"]:
		var row: Dictionary=choices[0].duplicate(true); row.key=kind
		if kind=="root": row.nativeFile.path=output.trim_suffix(".json")+".bic"
		elif kind=="digest": row.nativeFile.sha256="0".repeat(64)
		else: row.nativeFile.bytes=-1
		bad.append(row)
	reader.observe(10,bad); check(await wait_until(func():return reader.ready()),"Invalid local byte tickets retire with a completed native result")
	check(reader.values.is_empty() and reader.errors.size()==3,"Foreign roots, wrong digests and invalid sizes cannot produce character metadata")
	reader.observe(20,choices); check(await wait_until(func():return reader.ready()) and reader.values.size()==39,"Native metadata accepts the configured source roots")
	reader.configure([output.get_base_dir()]); reader.observe(20,choices)
	check(await wait_until(func():return reader.ready()) and reader.values.is_empty() and reader.errors.size()==39,"Changing allowed roots retires previously decoded rows even in the same connection")
	reader.configure([fixture.directory])
	reader.observe(11,choices); reader.observe(12,[]); check(await wait_until(func():return reader.task<0),"Replacing the connection joins and retires old native catalog work")
	check(reader.ready() and reader.values.is_empty() and reader.stale>=1,"A retired connection's decoded rows cannot replace the current empty catalog")
	reader.observe(13,choices); reader.close(); check(reader.closed and reader.task<0 and reader.active==null,"Closing a live metadata reader joins its worker and releases its private data")
	reader.free(); await process_frame
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"metadata":native_stats,"samples":differences,"publicConnections":0,"fullUiParity":false,"fullCharacterLobbyParity":false,"scope":"39 real installed BICs compared to independent diagnostic decoding, original active Pregen.2DA policy, custom TLK/classes/portrait data, actual source checkbox input and owned native worker integrity/connection/cleanup. Original user/workshop vault enumeration and Delete/Customize remain unfinished."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
