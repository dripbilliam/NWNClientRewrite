extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")
const RenderWorld=preload("res://systems/native_render/live_world_pending_appearances.gd")
var session: Node
var deadline:=0
var selected: Dictionary={}
var catalog_loaded:=false
var area_received: Dictionary={}
var render_catalog: RefCounted
var render_world: Node3D
var enter_area:=false
var admitted:=false
var presentation_staging:=false
var quickbar_received:=false

func _initialize()->void:
	enter_area=OS.get_cmdline_user_args().has("--enter-area")
	session=Session.new()
	root.add_child(session)
	session.character_list_ready.connect(on_character_list)
	session.character_preview_ready.connect(on_preview)
	session.area_state_ready.connect(on_area_state)
	session.catalog_ready.connect(on_catalog_ready)
	session.world_presentation_ready.connect(on_presentation)
	session.quickbar_ready.connect(on_quickbar)
	session.session_failed.connect(func(reason: String):fail(reason))
	var documents:=OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var profile:=documents.path_join("Neverwinter Nights.0")
	var install:=ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")
	if not session.start("145.239.204.29",5124,profile,install):fail(str(session.error));return
	deadline=Time.get_ticks_msec()+(35000 if enter_area else 30000)

func _process(_delta: float)->bool:
	if deadline>0 and Time.get_ticks_msec()>deadline:
		var terrain_state: Dictionary=render_world.terrain.snapshot() if render_world!=null and is_instance_valid(render_world.terrain) else {}
		fail("Godot session timed out at "+str(session.phase)+" catalog="+str(catalog_loaded)+" area="+str(not area_received.is_empty())+" admitted="+str(admitted)+" objects="+str(session.world_state.registry.size())+" terrain_done="+str(terrain_state.get("done",false))+" terrain_errors="+str(terrain_state.get("errors",[])))
	if enter_area and render_world!=null and not admitted and render_world.ready_for_admission():
		if not session.area_ready(render_world):fail("Godot rejected prepared-area acknowledgement")
		else:admitted=true;print("NWN79 prepared Arelith terrain admitted")
	return false

func on_character_list(rows: Array[Dictionary])->void:
	if rows.is_empty():fail("Arelith returned no server-vault characters");return
	selected={"source":int(rows[0].source),"resref":str(rows[0].resref)}
	if not session.request_preview(int(selected.source),str(selected.resref)):fail("Godot character preview request failed");return

func on_preview(preview: Dictionary)->void:
	var bytes: PackedByteArray=preview.bytes
	if bytes.is_empty() or bytes.size()<4 or bytes.slice(0,4).get_string_from_ascii()!="BIC ":fail("Server-vault preview BIC is unavailable");return
	if not session.play_character(int(selected.source),str(selected.resref)):fail("Godot character Play request failed");return

func on_area_state(entry: Dictionary)->void:
	if not session.module_ready_sent or entry.get("area",{}).get("tiles",[]).is_empty():fail("Godot did not decode native area state after module ready");return
	area_received=entry
	if enter_area:print("NWN79 Arelith area packet received")
	finish_if_ready()

func on_catalog_ready(prepared: RefCounted)->void:
	if prepared==null or session.object_rules==null:fail("Godot session catalog lacks object rules");return
	render_catalog=prepared
	catalog_loaded=true
	if enter_area:print("NWN79 Arelith catalog mounted")
	finish_if_ready()

func finish_if_ready()->void:
	if not catalog_loaded or area_received.is_empty():return
	if enter_area:
		if render_world!=null:return
		render_world=RenderWorld.new();root.add_child(render_world)
		render_world.minutes_per_hour=int(session.module_information.get("minutesPerHour",5))
		render_world.open(render_catalog,area_received.area,1,OS.get_temp_dir().path_join("nwn79-live-area-"+str(OS.get_process_id())),null,{"position":area_received.position,"facing":area_received.facing})
		return
	print("NWN79 Godot-owned session decoded Arelith area and mounted server catalog: tiles=",area_received.area.tiles.size()," static_placeables=",area_received.area.staticPlaceables.size())
	session.close();quit(0)

func on_presentation(data: Dictionary)->void:
	if not enter_area or presentation_staging:return
	if not admitted or data.has("error") or not data.get("objects") is Array or data.objects.is_empty() or int(data.get("controlledId",0))<0x80000000:fail("First native world presentation is incomplete");return
	presentation_staging=true
	if render_world==null or not render_world.begin_received_snapshot(data.objects,int(data.controlledId)):fail("Live Arelith world was rejected by the Godot renderer");return
	var result: Dictionary={"done":false}
	while not result.done and Time.get_ticks_msec()<deadline:
		result=render_world.advance_received_snapshot(Time.get_ticks_usec()+3000)
		if not result.done:await process_frame
	if not result.done or result.get("cancelled",false) or not render_world.desired.has(int(data.controlledId)):
		fail("Live Arelith controlled creature was not staged by the Godot renderer");return
	while not quickbar_received and Time.get_ticks_msec()<deadline:await process_frame
	if not quickbar_received:fail("Live Arelith quickbar was not decoded by Godot");return
	print("NWN79 Godot-owned Arelith area admitted and staged first world: objects=",data.objects.size()," controlled=",int(data.controlledId))
	if render_world!=null:render_world.close();render_world.queue_free()
	session.close();quit(0)

func on_quickbar(_message: Dictionary)->void:
	quickbar_received=true

func fail(reason: String)->void:
	printerr("NWN79 Godot-owned session failed: "+reason)
	if render_world!=null:render_world.close();render_world.queue_free()
	if session!=null:session.close()
	quit(1)
