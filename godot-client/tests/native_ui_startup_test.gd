extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
class Barrier:
	extends RefCounted
	var mutex:=Mutex.new()
	var wake:=Semaphore.new()
	var released:=false
	var blocked:=0
	func hold() -> void:
		mutex.lock(); var wait:=not released
		if wait: blocked+=1
		mutex.unlock()
		if wait: wake.wait()
	func release() -> void:
		mutex.lock(); released=true; var count:=blocked; mutex.unlock()
		for index in count: wake.post()
	func waiting() -> bool:
		mutex.lock(); var value:=blocked>0 and not released; mutex.unlock(); return value
class HeldCatalog:
	extends RefCounted
	var source
	var barrier
	var failure:=""
	var stats: Dictionary:
		get: return source.stats
	func fork():
		var reader:=HeldCatalog.new(); reader.source=source.fork(); reader.barrier=barrier; return reader
	func get_resource(name: String,type: int) -> PackedByteArray:
		if name=="feat" and type==2017: barrier.hold()
		var data: PackedByteArray=source.get_resource(name,type); failure=source.failure; return data
	func has_resource(name: String,type: int) -> bool: return source.has_resource(name,type)
	func raster_location(name: String) -> Dictionary: return source.raster_location(name)
	func preparation_cache(): return source.preparation_cache()
	func decoded_cache(): return source.decoded_cache()
	func recorded_texture_miss(_name: String) -> bool: return false
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func wait_until(test: Callable,seconds: int=30) -> bool:
	var deadline:=Time.get_ticks_msec()+seconds*1000
	while not test.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(test.call())
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1280,800)
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original UI source mounts read-only"); catalog.build_resource_index()
	var held:=HeldCatalog.new(); held.source=catalog; held.barrier=Barrier.new()
	var cache:=OS.get_temp_dir().path_join("nwn-ui-startup-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var ui:=Gameplay.new(); root.add_child(ui); ui.configure(held,install,cache,output+".layout.cfg")
	var requests: Array=[]; ui.request.connect(func(message):requests.append(message))
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"position":[5,5,0],"orientation":{"yaw":90},"name":{"text":"HUD before feat data"},"portraitRef":"po_clswiz_","hitPoints":{"current":12,"maximum":15},"stats":{"classes":[{"id":10,"level":3}]}},"playerState":{"combat":{},"spellbooks":{"0":{"known":[0],"memorized":{"0":[{"spell":0,"ready":true,"metamagic":0}]}}}}}
	ui.set_world(1,55,42,[actor],{},{"area":{"id":55},"ui":{"party":[],"quickbar":[{"type":2,"intParam":0,"classIndex":0}]}})
	check(await wait_until(func():return held.barrier.waiting() and ui.hud_ready and ui.key_bindings.bindings_ready and ui.desktop.party_frame.layout_ready and ui.desktop.quickbar_frame.layout_ready),"Original HUD geometry and movement bindings become ready with the feat read still blocked")
	check(not ui.tables_ready and ui.table_jobs.values().has("feat"),"The injected slow rule table remains genuinely incomplete")
	check(ui.desktop.party.visible and ui.desktop.party.rows.size()==1 and ui.desktop.party.rows[0].health.current==12,"Early HUD shows received character identity and authoritative HP")
	check(ui.desktop.quickbar.visible and ui.desktop.quickbar.rows.size()==36 and ui.desktop.quickbar.rows.all(func(row):return not row.enabled),"Original quickbar geometry appears without guessing usable shortcut actions")
	check(await wait_until(func():return ui.desktop.art.waiting.is_empty() and ui.desktop.art.models.pending.is_empty() and not ui.desktop.art.models.active and ui.inventory.frame_skin.art.waiting.is_empty() and ui.inventory.frame_skin.art.models.pending.is_empty() and not ui.inventory.frame_skin.art.models.active),"Original HUD artwork finishes native rendering while the unrelated feat read stays blocked")
	var key:=InputEventKey.new(); key.physical_keycode=KEY_W; key.keycode=KEY_W; key.pressed=true
	check(ui.key_bindings.action(key,[90],true)==90,"W movement binding is available without waiting for feat/spell completion")
	ui.desktop.quickbar.activate(0); ui.desktop.input_request({"kind":"quickbar-clear","quickbarId":ui.desktop.quickbar.quickbar_id,"index":0}); ui.desktop.shortcut_menu(0,Vector2(500,500))
	check(requests.is_empty() and not ui.desktop.radial.active,"Pending shortcut clicks, assignment and clear cannot send fabricated actions")
	var before:=ui.startup_snapshot(); await RenderingServer.frame_post_draw; var screen:=root.get_texture().get_image(); screen.save_png(output.trim_suffix(".json")+"-held.png")
	var painted:=0
	for y in range(4,180,3):
		for x in range(root.size.x-78,root.size.x-2,3):
			var color:=screen.get_pixel(x,y)
			if color.r>0.2 and color.g>0.1: painted+=1
	check(painted>40 and not ui.tables_ready and held.barrier.waiting(),"Actual original party HUD pixels are visible before completing the held feat data")
	ui.desktop.panel("inventory")
	check(ui.desktop.party.action_buttons[1].disabled and not ui.desktop.party.action_buttons[0].disabled and not ui.desktop.party.action_buttons[4].disabled and not ui.desktop.party.action_buttons[6].disabled and not ui.inventory.ui.wanted,"Only rule-dependent menus stay unavailable; Map, Rest and Options do not wait for feat data")
	check(ui.desktop.startup_notice.visible and not ui.desktop.blocks_pointer(Vector2(20,45)),"Startup feedback remains visible without swallowing world pointer input")
	held.barrier.release()
	check(await wait_until(func():return ui.tables_ready and ui.desktop.quick_bindings.size()==1 and not ui.desktop.quickbar.rows[0].empty),"Completing rules replaces pending slots with the received shortcut bindings")
	var ready:=ui.startup_snapshot()
	check(not ui.desktop.party.action_buttons[1].disabled and not ui.desktop.startup_notice.visible,"Full rule readiness enables menu actions and removes the startup notice")
	check(ready.completed_tables==32 and ready.pending_tables.is_empty() and ready.slowest_tables.size()==6 and ready.hud_presented_ms<=ready.all_rules_ready_ms and ready.bindings_ready_ms<=ready.all_rules_ready_ms,"Per-resource timings distinguish HUD/binding readiness from full table completion")
	# This UI borrows read-only graphs; mutable decoders still receive private
	# copies, preserving the active catalog's named/physical rows.
	var service:=Gameplay.Assets.new(); root.add_child(service)
	var bytes: PackedByteArray=catalog.get_resource("spells",2017)
	var shared: Dictionary=service.decode(bytes,2017,"2da","",catalog.decoded_cache(),true)
	check(shared.memory_decode_hit and is_same(shared.value,ui.text.tables.spells),"UI projection consumes the existing immutable decoder graph without duplicated row views")
	var original_label: Variant=ui.text.tables.spells.rowLabels[0]
	var mutable: Dictionary=service.decode(bytes,2017,"2da","",catalog.decoded_cache())
	mutable.value.rowLabels[0]="private mutable test"
	check(ui.text.tables.spells.rowLabels[0]==original_label,"Other mutable consumers cannot overwrite the UI's shared rule source")
	service.close(); service.free(); ui.close(); ui.free(); held=null; catalog=null; await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"held":before,"ready":ready,"temporary_cache":cache,"publicConnections":0,"scope":"Original native HUD/bindings while a real worker feat read is blocked; unavailable shortcut guards, complete-rule handoff, immutable source/copy isolation and per-table startup telemetry. Not an Arelith load-time or full UI parity acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
