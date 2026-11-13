extends "res://tests/native_character_cancel_navigation_test.gd"
# Actual entry owners and installed Controls. Replies are authored, no peer is
# connected and no protected profile or server is opened by this fixture.
const MenuDoubles=preload("res://tests/native_modal_owner_input_test.gd")
const SourceDoubles=preload("res://tests/native_skill_description_source_test.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
var entry_source_ready:=false
var source_failure:=""
var event_costs: Array=[]
var event_samples: Array=[]
var retired_creation_scope: Array=[]
func browser_intents(operation: String="") -> Array:
	return requests.filter(func(message):return message.get("kind")=="browser-input" and (operation.is_empty() or message.get("operation")==operation))
func last_browser_intent() -> Dictionary:
	var intents:=browser_intents()
	return {} if intents.is_empty() else intents.back()
func ui_frames(count: int=2) -> void:
	for _index in count:await process_frame
func event_label(button: Control) -> String:
	var owners: Array=[["main",render_menu.pregame.main.buttons],["multiplayer",server_browser.entry_menu.buttons],["direct",server_browser.direct_dialog.buttons]]
	if is_instance_valid(character_lobby.native_chooser):owners.append(["picker",character_lobby.native_chooser.buttons])
	if is_instance_valid(server_browser.native_browser):
		for tab in server_browser.native_browser.pages:owners.append(["browser_"+str(tab),server_browser.native_browser.pages[tab].buttons])
	if is_instance_valid(gameplay_ui) and is_instance_valid(gameplay_ui.creator.source_frontend):
		owners.append(["creation",gameplay_ui.creator.source_frontend.main.buttons]);owners.append(["gender",gameplay_ui.creator.source_frontend.gender.buttons])
	for entry in owners:
		var key: Variant=entry[1].find_key(button)
		if key!=null:return str(entry[0])+":"+str(key)
	return button.get_class()
func click(button: Control) -> void:
	var label: String=event_label(button)
	var point:=button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await ui_frames()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		var creator_phase: String=gameplay_ui.creator.phase if is_instance_valid(gameplay_ui) else "unavailable"
		var source_ready: bool=is_instance_valid(gameplay_ui) and is_instance_valid(gameplay_ui.creator.source_frontend) and gameplay_ui.creator.source_frontend.main.layout_ready
		var began:=Time.get_ticks_usec();root.push_input(event,true);var elapsed:=Time.get_ticks_usec()-began;event_costs.append(elapsed);event_samples.append({"control":label,"pressed":pressed,"usec":elapsed,"creator_phase":creator_phase,"source_parent_ready":source_ready});await ui_frames()
func await_flow(predicate: Callable,milliseconds: int=15000) -> bool:
	var deadline:=Time.get_ticks_msec()+milliseconds
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		if is_instance_valid(gameplay_ui):gameplay_ui._profile_process(0)
		_profile_tick()
		await process_frame
	return predicate.call()
func source_prepared(painter,text,base_catalog,cache_path: String) -> void:
	# Keep the real catalog/model workers, supplying only controlled rasters and
	# fonts at the actual publication boundary before any source pages are built.
	var old_art=painter.art;var old_fonts=painter.fonts
	old_art.close();old_fonts.close();old_art.queue_free();old_fonts.queue_free()
	painter.art=SourceDoubles.ControlledArt.new();painter.fonts=MenuDoubles.ReadyFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);painter.art.loaded.connect(painter.art_loaded)
	server_browser.configure_native(painter,text,base_catalog,cache_path)
	character_lobby.prepare_native_frontend(painter,text,base_catalog,cache_path)
	entry_source_ready=true
func selection_view(allow_create: bool=true,creating: bool=false) -> Dictionary:
	return {"kind":"lobby","connection":session_connection,"state":{"phase":"character-selection","connected":true,"canSelect":true,"canCreate":allow_create,"busy":false,"creating":creating,"choices":[]}}
func actual_gameplay_owner() -> void:
	catalog=render_menu.pregame.catalog
	gameplay_ui=Gameplay.new();gameplay_ui.process_mode=Node.PROCESS_MODE_DISABLED;host.add_child(gameplay_ui)
	gameplay_ui.configure(catalog,str(args.install),str(args.report)+".active",str(args.report)+".game-layout.cfg")
	gameplay_ui.assets.process_mode=Node.PROCESS_MODE_ALWAYS;gameplay_ui.creator.process_mode=Node.PROCESS_MODE_ALWAYS
	gameplay_ui.request.connect(send)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	root.size=Vector2i(1280,900)
	host=Node3D.new();root.add_child(host);label=Label.new();host.add_child(label)
	world_retirement=WorldRetirement.new();host.add_child(world_retirement);catalog_retirement=WorldRetirement.new();host.add_child(catalog_retirement)
	loading_screen=preload("res://systems/native_loading_screen.gd").new();host.add_child(loading_screen)
	render_menu=MainMenu.new();render_menu.layout_path=str(args.report)+".menu-layout.cfg";host.add_child(render_menu)
	server_browser=Browser.new();host.add_child(server_browser);server_browser.request.connect(send);server_browser.closed.connect(server_browser_closed)
	character_lobby=Lobby.new();host.add_child(character_lobby);character_lobby.native_frontend=true;character_lobby.preferences.open_file("");character_lobby.request.connect(lobby_request);character_lobby.creation_requested.connect(request_creation)
	render_menu.multiplayer_requested.connect(func():server_browser.open(true,true))
	receive({"kind":"lobby","connection":1,"state":{"phase":"menu","connected":false,"canJoin":true,"busy":false,"choices":[]}})
	render_menu.configure_pregame({"install":str(args.install),"archives":[],"language":"en"},str(args.report)+".pregame")
	render_menu.pregame.source_ready.connect(source_prepared)
	render_menu.open(false)
	var entry_ready:=check(await await_flow(func():return entry_source_ready and is_instance_valid(render_menu.pregame.main) and render_menu.pregame.main.art_ready() and is_instance_valid(server_browser.entry_menu) and server_browser.entry_menu.art_ready() and is_instance_valid(character_lobby.native_chooser) and character_lobby.native_chooser.art_ready()),"Actual PRE_MAIN, Multiplayer, browser and character chooser prepare without any connection")
	if entry_ready:
		if not check(render_menu.pregame.main.visible and not server_browser.wanted and not character_lobby.panel.visible,"Main is the sole original entry surface before a user action"):await finish_case();return
		await click(render_menu.pregame.main.buttons.multibutton);receive(list_view(1,1,"Direct"));await ui_frames()
		if not check(server_browser.entry_menu.visible and not render_menu.pregame.wanted and not server_browser.panel.visible,"Physical Main Multiplayer opens the original native entry owner"):await finish_case();return
		await click(server_browser.entry_menu.buttons.intjoinbutton);receive(list_view(1,2,"Internet"));await ui_frames()
		if not check(server_browser.native_browser.visible and not server_browser.entry_menu.visible and not character_lobby.panel.visible,"Physical Internet action reaches native list using an authored received view"):await finish_case();return
		await click(server_browser.native_browser.pages.Internet.buttons.cancelbutton);receive(list_view(1,3,"Direct"));await ui_frames()
		if not check(server_browser.entry_menu.visible and server_browser.entry_stage=="entry" and last_browser_intent().get("operation")=="return-menu","Physical server-list Back returns to original Multiplayer"):await finish_case();return
		await click(server_browser.entry_menu.buttons.cancelbutton);await ui_frames()
		if not check(not server_browser.wanted and render_menu.pregame.main.visible and not character_lobby.panel.visible,"Physical Multiplayer Cancel returns to actual PRE_MAIN"):await finish_case();return
		await click(render_menu.pregame.main.buttons.multibutton);receive(list_view(1,4,"Direct"));await ui_frames()
		await click(server_browser.entry_menu.buttons.dirconnectbutton);await ui_frames()
		var direct_ready:=check(server_browser.direct_dialog.visible,"Physical Direct Connect opens the actual native dialog")
		if not direct_ready:await finish_case();return
		if direct_ready:
			var joins_before:=browser_intents("join").size()
			server_browser.direct_dialog.edits.ipeditbox.text="127.0.0.1:5127";await click(server_browser.direct_dialog.buttons.okbutton)
			if not check(last_browser_intent().get("operation")=="join" and browser_intents("join").size()==joins_before+1,"Physical original Direct OK emits one join intent into the fixture recorder only"):await finish_case();return
		receive({"kind":"browser-closed","connection":1});receive(selection_view());await ui_frames()
		if not check(character_lobby.panel.visible and character_lobby.native_chooser.visible and not character_lobby.window_column.visible,"Authoritative fixture selection activates the original character chooser"):await finish_case();return
		await click(character_lobby.native_chooser.buttons.newcharbutton)
		if not check(not pending_creator.is_empty() and pending_creator.connection==1 and not character_lobby.panel.visible,"Physical New captures a bounded connection-scoped creation request while resources are unavailable"):await finish_case();return
		receive(selection_view(false));actual_gameplay_owner();open_pending_creation()
		if not check(pending_creator.is_empty() and gameplay_ui.creator.phase=="closed","Revoked accepted eligibility retires a pending entry before later UI readiness can open it"):await finish_case();return
		receive(selection_view());await ui_frames();await click(character_lobby.native_chooser.buttons.newcharbutton)
		if not check(pending_creator.is_empty() and gameplay_ui.creator.phase!="closed" and requests.any(func(message):return message.get("kind")=="native-creation-begin"),"Physical New reaches the actual creator through the production session entry boundary"):await finish_case();return
		var source_entry:=check(await await_flow(func():return gameplay_ui.creator.phase=="editing" and is_instance_valid(gameplay_ui.creator.source_frontend) and gameplay_ui.creator.source_frontend.wanted and gameplay_ui.creator.source_frontend.main.visible,25000),"Production entry automatically reaches current original CG_MAIN without manually calling frontend.begin")
		if not source_entry:await finish_case();return
		if source_entry:
			var creator=gameplay_ui.creator;var front=creator.source_frontend
			var old_draft: int=creator.draft_scope
			if not check(not creator.view.panel.visible and not character_lobby.panel.visible,"Original CG_MAIN replaces the generic wizard and previous picker"):await finish_case();return
			await click(front.main.buttons.genderbutton);var gender_ready:=check(await await_flow(func():return front.gender.available()),"Physical parent Gender opens the currently scoped source child")
			if not gender_ready:await finish_case();return
			if gender_ready:
				var before_gender: int=creator.rules.draft.gender;await click(front.gender.buttons.femalebutton if before_gender==0 else front.gender.buttons.malebutton);await click(front.gender.buttons.okbutton)
				if not check(creator.rules.draft.gender!=before_gender and front.wanted and front.child.is_empty() and front.main.visible,"Actual source child OK commits the active draft and returns to its current parent"):await finish_case();return
			retired_creation_scope=creator.summary_identity();var cancels_before:=requests.filter(func(message):return message.get("kind")=="native-creation-cancel").size();await click(front.main.buttons.cancelbutton)
			if not check(creator.phase=="closed" and not front.wanted and requests.filter(func(message):return message.get("kind")=="native-creation-cancel").size()==cancels_before+1,"Physical original CG_MAIN Cancel reaches the current creator once and retires its child/input scope"):await finish_case();return
			receive(selection_view());await ui_frames();check(character_lobby.native_chooser.visible and character_lobby.panel.visible and not creator.view.panel.visible,"Accepted creation cancellation returns to the original current character chooser")
			await click(character_lobby.native_chooser.buttons.newcharbutton)
			var reopened:=check(await await_flow(func():return creator.phase=="editing" and front.wanted and front.main.visible),"Physical New reopens a fresh original parent scope through the same production entry")
			if not reopened:await finish_case();return
			var current_scope: Array=creator.summary_identity();var old_status: String=creator.status
			receive({"kind":"native-creation-result","connection":1,"draft":old_draft,"operation":"native-creation-begin","accepted":false,"text":"Old authored refusal"});front.finished.emit(true,retired_creation_scope)
			if not check(creator.summary_identity()==current_scope and creator.phase=="editing" and creator.status==old_status and front.wanted,"Late old-draft refusal and retired parent callback cannot alter or cancel the reopened current creation"):await finish_case();return
			await click(front.main.buttons.cancelbutton);receive(selection_view());await ui_frames()
		await click(character_lobby.native_chooser.buttons.cancelbutton)
		if not check(cancelled_connection==1 and not character_lobby.panel.visible,"Physical picker Cancel retires the current connection immediately"):await finish_case();return
		receive({"kind":"lobby","connection":2,"state":{"phase":"disconnecting","connected":true,"busy":true,"choices":[]}});receive({"kind":"lobby","connection":2,"state":{"phase":"menu","connected":false,"busy":false,"canJoin":true,"choices":[]}})
		receive(list_view(2,5,"Internet"));await ui_frames();check(server_browser.native_browser.visible and not character_lobby.panel.visible,"Authoritative disconnect returns to the previous native list on the new connection")
		receive(list_view(1,99,"Direct"));check(server_browser.view_id==5 and not character_lobby.panel.visible,"A late old-connection browser completion cannot resurrect a retired surface")
		await click(server_browser.native_browser.pages.Internet.buttons.cancelbutton);receive(list_view(2,6,"Direct"));await ui_frames();await click(server_browser.entry_menu.buttons.cancelbutton);await ui_frames()
		if not check(render_menu.pregame.main.visible and not server_browser.wanted and pending_creator.is_empty(),"Final Back and Cancel return to the original Main with no pending creation request"):await finish_case();return
	await finish_case()
func finish_case() -> void:
	if is_instance_valid(gameplay_ui):gameplay_ui.close()
	character_lobby.close_native();character_lobby.native_preview.close();character_lobby.local_catalog.close();server_browser.close_native();render_menu.close_pregame();world_retirement.close();catalog_retirement.close();host.free();await ui_frames(4)
	var cost_max:=0
	for sample in event_costs:cost_max=maxi(cost_max,int(sample))
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"event_cpu_max_usec":cost_max,"event_samples":event_samples,"recorded_intents":requests.map(func(message):return {"kind":message.get("kind"),"connection":message.get("connection"),"operation":message.get("operation")}),"publicConnections":0,"gameServerConnections":0,"scope":"Actual native Main/Browser/Picker/Creator input and session navigation with installed geometry/active local catalog, authored received views and controlled raster/fonts. No login/server/user-client/GPU/pixel or full creation completion acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("PREGAME_FLOW ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
