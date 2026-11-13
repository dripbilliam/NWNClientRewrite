extends "res://tests/native_skill_description_source_test.gd"
# Actual native admission/input/receive/completion paths. Only unrelated rule
# projection is authored; no game renderer or original-pixel acceptance.
const Access=preload("res://systems/native_gui_panel_access.gd")
const Journal=preload("res://systems/server_journal.gd")
const Players=preload("res://systems/server_players.gd")
const Book=preload("res://systems/server_spellbook.gd")
const JournalFrame=preload("res://systems/native_journal_frame.gd")
const JournalPlan=preload("res://systems/native_data/journal_layout.gd")
class ProjectionDesktop extends Desktop:
	var projection_calls:=0
	func refresh_sheet() -> void: projection_calls+=1
	func refresh_book() -> void: projection_calls+=1
	func refresh_players() -> void: projection_calls+=1
class InventoryFrameOwner extends Node:
	var frame_skin
	func close() -> void: pass
func key_input(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; surface.push_input(event,true); await process_frame
func messages(panel: String) -> Array: return requests.filter(func(v):return v.get("kind")=="native-panel" and v.get("panel")==panel)
func receive_event(value: Dictionary) -> void: ui.receive({"kind":"gui-panel-access-event","event":value},ui.generation)
func empty_tlk() -> PackedByteArray:
	var bytes:="TLK V3.0".to_ascii_buffer(); bytes.resize(20); bytes.encode_u32(16,20); return bytes
func run() -> void:
	var options: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: options[pair[0]]=pair[1]
	if not options.has_all(["report","install","fixture"]) or FileAccess.file_exists(options.report): quit(2); return
	var diagnostic:=await exercise_access(options)
	if is_instance_valid(ui): ui.close(); ui.free()
	if is_instance_valid(painter): painter.close()
	check(is_instance_valid(art) and art.closed and is_instance_valid(fonts) and fonts.closed,"Controlled raster/font owners complete close lifecycle")
	if is_instance_valid(surface): surface.free()
	await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"headless":true,"gpu":false,"gameServerConnections":0,"publicConnections":0,"nativeBuilds":0,"scope":"Actual GameplayUi receive/prepared, Desktop J/C input, native Journal/Players/Book/Sheet logical owners and installed Journal14-model frame/close geometry. Controlled8px rasters/fallback font; unrelated sheet/book/player projection is authored. Production World/host JSON fixture; no original pixels or live-server/window claim."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); print("GUI_ACCESS_SOURCE_RESULT ",JSON.stringify(result)); quit(0 if result.success else 1)
func exercise_access(options: Dictionary) -> Dictionary:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(options.fixture)); var catalog:=Catalog.new()
	if not check(catalog.mount_install(options.install),"Installed resource catalog mounts read-only"): return {}
	root.size=Vector2i(1440,960); surface=SubViewport.new(); surface.size=root.size; surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; surface.handle_input_locally=true; surface.gui_disable_input=false; root.add_child(surface); surface.notify_mouse_entered()
	painter=Painter.new(); art=ControlledArt.new(); fonts=ControlledFonts.new(); painter.art=art; painter.fonts=fonts; painter.owns_art=true; painter.add_child(art); painter.add_child(fonts); art.loaded.connect(painter.art_loaded); surface.add_child(painter)
	ui=Gameplay.new(); surface.add_child(ui); ui.set_process(false); ui.set_process_input(false); ui.set_process_unhandled_key_input(false); ui.generation=1; ui.area_id=int(source.actor.areaId); ui.controlled_id=int(source.actor.id); ui.tables_ready=true
	ui.controls=Control.new(); ui.controls.size=Vector2(surface.size); ui.add_child(ui.controls)
	var inventory:=InventoryFrameOwner.new(); inventory.frame_skin=painter; ui.add_child(inventory); ui.inventory=inventory
	if not check(ui.text.base.open_file(str(options.install).path_join("lang/en/data/dialog.tlk")),"Installed TLK opens through native Talk owner"): return {}
	var desktop:=ProjectionDesktop.new(); ui.add_child(desktop); desktop.set_process(false); desktop.owner_ui=ui; desktop.rules.text=ui.text; ui.desktop=desktop
	desktop.journal=Journal.new(); desktop.players=Players.new(); desktop.book=Book.new(); desktop.sheet=Sheet.new()
	for node in [desktop.journal,desktop.players,desktop.book,desktop.sheet]: ui.controls.add_child(node); node.setup(str(options.report)+".layout.cfg"); node.request.connect(desktop.input_request)
	desktop.request.connect(func(message):requests.append(message.duplicate(true)))
	var skin:=JournalFrame.new(); desktop.add_child(skin); desktop.journal_frame=skin; skin.configure(desktop,catalog,str(options.report).get_base_dir().path_join("model-cache"))
	var actor: Dictionary={"id":int(source.actor.id),"areaId":int(source.actor.areaId),"objectType":5,"replicated":{"name":{"text":"Access fixture"}}}
	desktop.actor_id=actor.id; desktop.area_id=actor.areaId; desktop.generation=1; desktop.objects={actor.id:actor}; ui.text.objects=desktop.objects; desktop.state={"journal":{"entries":[],"worldEntries":[],"loaded":true},"module":{"minutesPerHour":5}}
	ui.gui_panel_access=Access.new(); ui.add_child(ui.gui_panel_access); ui.gui_panel_access.configure(ui); var access=ui.gui_panel_access
	access.observe_header(source.seed)
	await key_input(KEY_J); await key_input(KEY_J); await key_input(KEY_C)
	check(not desktop.journal.wanted and not desktop.sheet.wanted and messages("blocked-attempt").size()==3,"Actual J/J/C presses are blocked and each produces an independent intent")
	check(messages("blocked-attempt")[0].targetId==2130706432 and messages("blocked-attempt")[2].targetId==actor.id,"Original Journal INVALID and displayed-character high-bit target survive JSON")
	var samples: Array=[]; var calls: int=desktop.projection_calls; var art_calls: int=art.calls
	for index in 1000:
		var began:=Time.get_ticks_usec(); desktop.panel("journal"); samples.append((Time.get_ticks_usec()-began)/1000.0)
	samples.sort()
	check(messages("blocked-attempt").size()==1003 and desktop.projection_calls==calls and art.calls==art_calls and samples[949]<8.0,"1000 blocked attempts emit once each without projection/art work below8ms p95")
	ui.tables_ready=false; ui.hud_ready=true; ui.tlk_jobs[700]=false
	receive_event(source.events[4]); receive_event(source.events[5]); receive_event(source.events[6]); receive_event(source.events[7])
	check(not desktop.journal.wanted and access.pending.size()==4 and messages("journal").is_empty(),"Forced popup remains pending with later close/enable while selected TLK dependency is unavailable")
	ui.prepared(700,{"error":"","bytes":empty_tlk()})
	check(not desktop.journal.wanted and access.pending.is_empty() and messages("journal").size()==2 and messages("journal")[0].open and not messages("journal")[1].open,"Actual TLK completion drains disable/popup/idempotent-popup/disable/enable in order without another header")
	await key_input(KEY_J)
	check(desktop.journal.wanted and messages("journal").size()==3,"Server enable permits a later actual J press to open a new logical Journal")
	var deadline:=Time.get_ticks_msec()+20000
	while not skin.layout_ready and skin.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	if not check(skin.layout_ready and skin.failure.is_empty(),"Native asset service decodes all installed journal models: "+skin.failure): return {"skin":skin.snapshot()}
	await frames(5)
	check(skin.models.size()==JournalPlan.RESOURCES.size()+4 and painter.button_geometry.has(desktop.journal.close_button.get_instance_id()),"Journal binds14 installed models and its source-sized close hitbox")
	await click(desktop.journal.close_button)
	check(not desktop.journal.wanted and messages("journal").size()==4,"Actual installed close button preserves the normal journal close intent")
	# Only selected-panel readiness is required: Sheet remains pending until its
	# existing all-table readiness contract, while Journal already opened above.
	receive_event(source.events[8]); check(not desktop.sheet.wanted and access.pending.size()==1,"Sheet popup waits for its own rules readiness")
	ui.tables_ready=true; access.drain(); check(desktop.sheet.wanted,"Selected Sheet opens once its native rules condition is ready")
	ui.tables_ready=false; ui.tlk_jobs[701]=false; receive_event(source.events[9]); check(desktop.sheet.wanted,"Unrelated-target disable does not close displayed character")
	receive_event(source.events[10]); check(not desktop.sheet.wanted,"Exact displayed-target disable closes the native sheet")
	ui.tables_ready=true
	# Existing wanted owner must consume an idempotent force even while unready.
	var before: int=desktop.projection_calls; ui.tables_ready=false
	# Same wanted Journal is tested by a fresh explicitly scoped event below.
	desktop.journal.open(); var journal_count:=messages("journal").size()
	var same: Dictionary=source.events[11].duplicate(true); same.sequence=12; same.scope=source.seed.control.duplicate(true); receive_event(same)
	check(access.effects_seen==12 and messages("journal").size()==journal_count,"A wanted Journal force is consumed idempotently despite pending text readiness")
	# Retire the authored replacement event consumed above; continue new scope at13.
	receive_event(source.events[12]); check(not desktop.journal.wanted,"Received repeated disable closes Journal even before resources are ready")
	for node in [desktop.journal,desktop.players,desktop.book,desktop.sheet]: node.reset()
	desktop.actor_id=int(source.replacement.id); desktop.area_id=int(source.replacement.areaId); desktop.generation=2; desktop.objects={desktop.actor_id:{"id":desktop.actor_id,"objectType":5,"areaId":desktop.area_id}}; ui.text.objects=desktop.objects; ui.generation=2; ui.area_id=desktop.area_id; ui.controlled_id=desktop.actor_id
	access.observe_header(source.reused); check(not desktop.journal.wanted and access.effects_seen==14,"Same-ID replaced control lifetime retires the previous popup")
	access.observe_header(source.reused); check(not desktop.journal.wanted and messages("journal").size()==journal_count+1,"Repeated initial headers never replay consumed commands")
	ui.tables_ready=true
	for base in [14,17]:
		var node=desktop.players if base==14 else desktop.book; var prior: int=desktop.projection_calls
		receive_event(source.events[base]); receive_event(source.events[base+1])
		check(node.wanted and desktop.projection_calls==prior+1,"Forced Players/Book display is idempotent while retained globally disabled")
		receive_event(source.events[base+2]); check(not node.wanted,"Received Players/Book disable closes regardless of unrelated target")
	ui.tables_ready=false; ui.hud_ready=false
	var waiting: Dictionary=source.events[20].duplicate(true); receive_event(waiting)
	ui.prepared(701,{"error":"Authored missing custom TLK","bytes":PackedByteArray()})
	check(not desktop.journal.wanted and access.pending.size()==1,"Failed selected dependency cannot fabricate readiness for an actual pending popup")
	ui.generation=3; desktop.generation=3; access.drain()
	check(access.pending.is_empty() and not desktop.journal.wanted,"Scope retirement consumes the failed-dependency popup without opening it")
	# More than32 pending future commands are explicitly retired, never accumulated.
	var flood: Dictionary=source.flood.duplicate(true)
	for value in flood.events: value.scope.areaGeneration=4
	access.observe_header(flood)
	check(access.pending.size()==32 and access.effects_seen==68,"Pending future-scope effects are bounded32 with explicit retirement floor")
	var detached: Dictionary=access.snapshot(); detached.pending.clear(); detached.policy.disabled.clear(); check(access.pending.size()==32 and access.policy.matches(8,2130706432),"Returned native access views cannot mutate pending commands or canonical memberships")
	# An unsuccessful required dependency never opens a queued owner and teardown
	# retires it. No renderer-ready wait or retries are introduced.
	check(not desktop.journal.wanted and access.pending.size()==32,"Future-scope commands do not replay into the current owner")
	access.close(); check(access.pending.is_empty() and not access.ordinary("journal"),"Connection close retires pending commands and rejects late bound opens")
	return {"models":skin.models.keys(),"skin":skin.snapshot(),"attempt_ms":{"count":samples.size(),"p50":samples[499],"p95":samples[949],"max":samples.back()},"physical_J_C":true,"physical_journal_close":true,"projection_fixture_calls":desktop.projection_calls,"unrelated_projection_delta":desktop.projection_calls-before}
