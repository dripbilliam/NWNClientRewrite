extends "res://tests/native_skill_description_source_test.gd"
# Reuse controlled rasters/fonts/pointer helpers only; actual journal owners below.
const Journal=preload("res://systems/server_journal.gd")
const JournalFrame=preload("res://systems/native_journal_frame.gd")
const JournalPlan=preload("res://systems/native_data/journal_layout.gd")
class InventoryFrameOwner extends Node:
	var frame_skin
	func close() -> void: pass
var journal
func journal_requests() -> Array:
	return requests.filter(func(message):return message.get("kind")=="native-panel" and message.get("panel")=="journal")
func key_input(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; surface.push_input(event,true); await process_frame
func run() -> void:
	var options: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: options[pair[0]]=pair[1]
	if not options.has_all(["report","install"]) or FileAccess.file_exists(options.report): quit(2); return
	var diagnostic:=await exercise_journal(options)
	if is_instance_valid(ui): ui.close(); ui.free()
	if is_instance_valid(painter): painter.close()
	check(is_instance_valid(art) and art.closed and is_instance_valid(fonts) and fonts.closed,"Controlled raster/font owners complete their real close lifecycle")
	if is_instance_valid(surface): surface.free()
	await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"headless":true,"gpu":false,"publicConnections":0,"gameServerConnections":0,"nativeBuilds":0,"scope":"Actual NativeDesktop key input and source journal/frame/painter controls with installed MDL/GUI geometry. Controlled8px rasters/Godot fallback font; no original pixel/glyph or live game-window claim. Authored world/journal data; original-server callback is separate."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); print("NATIVE_JOURNAL_EVENTS_SOURCE_RESULT ",JSON.stringify(result)); quit(0 if result.success else 1)
func exercise_journal(options: Dictionary) -> Dictionary:
	var catalog:=Catalog.new()
	if not check(catalog.mount_install(options.install),"Installed journal resource catalog mounts read-only"): return {}
	root.size=Vector2i(1440,960); surface=SubViewport.new(); surface.size=root.size; surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; surface.handle_input_locally=true; surface.gui_disable_input=false; root.add_child(surface); surface.notify_mouse_entered()
	painter=Painter.new(); art=ControlledArt.new(); fonts=ControlledFonts.new(); painter.art=art; painter.fonts=fonts; painter.owns_art=true; painter.add_child(art); painter.add_child(fonts); art.loaded.connect(painter.art_loaded); surface.add_child(painter)
	ui=Gameplay.new(); surface.add_child(ui); ui.set_process(false); ui.set_process_input(false); ui.set_process_unhandled_key_input(false); ui.generation=1; ui.area_id=55; ui.controlled_id=42; ui.tables_ready=true
	ui.controls=Control.new(); ui.controls.size=Vector2(surface.size); ui.add_child(ui.controls)
	var inventory:=InventoryFrameOwner.new(); inventory.frame_skin=painter; ui.add_child(inventory); ui.inventory=inventory
	if not check(ui.text.base.open_file(str(options.install).path_join("lang/en/data/dialog.tlk")),"Installed journal TLK opens through the native talk owner"): return {}
	var desktop:=Desktop.new(); ui.add_child(desktop); desktop.set_process(false); desktop.owner_ui=ui; desktop.rules.text=ui.text; ui.desktop=desktop
	journal=Journal.new(); ui.controls.add_child(journal); journal.setup(str(options.report)+".layout.cfg"); desktop.journal=journal; journal.request.connect(desktop.input_request); desktop.request.connect(func(message):requests.append(message.duplicate(true)))
	var skin:=JournalFrame.new(); desktop.add_child(skin); desktop.journal_frame=skin; skin.configure(desktop,catalog,str(options.report).get_base_dir().path_join("model-cache"))
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Source journal fixture"}}}
	var data:={"entries":[["quest",{"tag":"quest","title":{"text":"Received quest"},"description":{"text":"Current journal body"},"date":450270,"time":420000,"priority":5,"completed":false,"isQuest":true}]],"worldEntries":[],"loaded":true}
	var original:=data.duplicate(true); desktop.objects={42:actor}; desktop.generation=1; desktop.area_id=55; desktop.actor_id=42; desktop.state={"journal":data,"module":{"minutesPerHour":5}}; ui.text.objects=desktop.objects
	await key_input(KEY_J)
	if not check(journal.wanted and journal_requests().size()==1,"Real J key opens the native journal with one logical transition"): return {}
	var first_lifetime: int=journal.journal_lifetime
	check(journal_requests().back()=={"kind":"native-panel","panel":"journal","open":true,"journalLifetime":first_lifetime,"actorId":42,"areaId":55,"generation":1},"Native open forwards the real safe owner lifetime and current actor/area scope")
	var deadline:=Time.get_ticks_msec()+20000
	while not skin.layout_ready and skin.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	if not check(skin.layout_ready and skin.failure.is_empty(),"Native asset service decodes installed journal models/GUI: "+skin.failure): return {"skin":skin.snapshot()}
	await frames(5)
	check(not journal.window_column.visible and journal.size.distance_to(Vector2(360,460))<0.01,"Actual original journal geometry replaces the prototype control layout")
	check(skin.models.size()==JournalPlan.RESOURCES.size()+4 and skin.row_controls.size()==1,"Original journal components, utility and scroll models create the real row controls")
	check(skin.title.get_meta("native_font_applied","")==JournalPlan.FONT and art.calls>0,"Controlled fonts/rasters bind through the actual source painter")
	check(painter.button_geometry.has(journal.close_button.get_instance_id()),"Journal close uses its installed source button geometry")
	var count:=journal_requests().size(); var view: int=journal.view_id
	journal.open(); journal.hide(); journal.open(); desktop.refresh_journal(0); await frames()
	check(journal_requests().size()==count and journal.journal_lifetime==first_lifetime and journal.view_id>view,"Repeated open/show and journal refresh preserve the logical owner without another GUI transition")
	await click(journal.tabs[1]); await click(journal.tabs[0])
	check(journal.page==0 and journal_requests().size()==count,"Actual original page tabs do not notify journal open/close")
	await click(journal.close_button)
	check(not journal.wanted and not journal.visible and journal_requests().size()==count+1 and not journal_requests().back().open,"Physical installed close button emits one close after retiring visibility")
	check(journal_requests().back().journalLifetime==first_lifetime,"Close carries the same logical lifetime as its matching open")
	journal.close_journal(); check(journal_requests().size()==count+1,"Repeated close has no second transition")
	await key_input(KEY_J); var next_lifetime: int=journal.journal_lifetime
	check(journal.wanted and next_lifetime>first_lifetime and journal_requests().size()==count+2,"A later real J press opens a new monotonic logical owner")
	count=journal_requests().size()
	for value in [null,false,0,"%s"%next_lifetime,first_lifetime]:
		desktop.input_request({"kind":"journal-close","journalLifetime":value}); desktop.input_request({"kind":"journal-open","journalLifetime":value})
	check(journal_requests().size()==count,"Missing/malformed or retired lifetime callbacks cannot issue new native intents")
	journal.reset(); var reset_lifetime: int=journal.journal_lifetime
	desktop.input_request({"kind":"journal-close","journalLifetime":next_lifetime}); desktop.input_request({"kind":"journal-open","journalLifetime":next_lifetime})
	check(reset_lifetime>next_lifetime and journal_requests().size()==count and journal.view_id==-1,"Actual reset retires private journal handles without sending into the previous scope")
	desktop.generation=2; desktop.area_id=56; desktop.actor_id=43; var replacement:={"id":43,"objectType":5,"areaId":56,"replicated":{"name":{"text":"Replacement owner"}}}; desktop.objects={43:replacement}; ui.text.objects=desktop.objects
	await key_input(KEY_J)
	check(journal_requests().back().actorId==43 and journal_requests().back().areaId==56 and journal_requests().back().generation==2 and journal_requests().back().journalLifetime>reset_lifetime,"Authored area/control replacement forwards its current scope and a new lifetime")
	count=journal_requests().size(); desktop.objects.clear(); desktop.input_request({"kind":"journal-open","journalLifetime":journal.journal_lifetime}); check(journal_requests().size()==count,"A journal callback cannot publish after its actor disappears")
	desktop.objects={43:replacement}; ui.text.objects=desktop.objects
	var samples: Array=[]
	for iteration in 200:
		var began:=Time.get_ticks_usec(); journal.close_journal(); journal.open(); samples.append((Time.get_ticks_usec()-began)/1000.0)
	samples.sort()
	check(journal_requests().size()==count+400 and samples[189]<8.0,"200 warm logical close/open pairs notify exactly once each below8ms p95")
	check(data==original,"Journal notifications never mutate received quest/world data")
	count=journal_requests().size(); desktop.closed=true; journal.close_journal(); journal.open(); check(journal_requests().size()==count,"Closed Desktop command owner rejects late journal boundaries"); desktop.closed=false
	var model_hashes: Dictionary={}
	for name in JournalPlan.RESOURCES: model_hashes[name]=digest(catalog.read_resource(name,2002))
	return {"models":model_hashes,"physical_keyboard":true,"physical_close_pointer":true,"raster":"Controlled8x8RGBA8","font":"Godot fallback; original named bindings preserved","pair_ms":{"p50":samples[99],"p95":samples[189],"max":samples.back(),"count":samples.size()},"skin":skin.snapshot()}
