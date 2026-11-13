extends SceneTree
const Support=preload("res://tests/native_popup_scene_support.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Hud=preload("res://systems/native_hud.gd")
const Speech=preload("res://systems/native_overhead_speech.gd")
const Registry=preload("res://systems/native_overhead_popup_registry.gd")
const Fonts=preload("res://systems/native_popup_fonts.gd")
const Resources=preload("res://systems/native_nameplate_resources.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const GuiProjection=preload("res://systems/native_data/gui_projection.gd")
const PortraitChoices=preload("res://systems/native_data/portrait_choices.gd")
const SessionGraph=preload("res://native_session_world.gd")
var checks:=0
var failures: Array=[]
var captures: Array=[]
var observations: Array=[]
var options: Dictionary={}
var connection:=3
var poses: Dictionary={42:Vector3.ZERO,43:Vector3.ZERO,44:Vector3(2.4,0,0)}
var current_ui
var current_hud
var current_speech
var current_registry
var camera: Camera3D
var anchor_trace: Array=[]
var startup_window: Dictionary={}
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label);print("FAIL: ",label)
func wait_for(predicate: Callable,ms: int=20000)->bool:
	var until:=Time.get_ticks_msec()+ms
	while not predicate.call() and Time.get_ticks_msec()<until:await process_frame
	return predicate.call()
func anchor(id: int,witness: Array,scope: Array)->Dictionary:
	if anchor_trace.size()<6:anchor_trace.append({"id":id,"witness":witness.duplicate(),"scope":scope.duplicate(),"expectedScope":[connection,current_ui.generation,current_ui.area_id] if is_instance_valid(current_ui) else [],"sourceWitness":preload("res://systems/native_data/overhead_speech_anchor.gd").witness(current_ui.text.objects.get(id,{})) if is_instance_valid(current_ui) else [],"poseKnown":poses.has(id)})
	if not is_instance_valid(current_ui) or scope!=[connection,current_ui.generation,current_ui.area_id] or not poses.has(id):return {"ready":false}
	var row_value: Dictionary=current_ui.text.objects.get(id,{})
	if preload("res://systems/native_data/overhead_speech_anchor.gd").witness(row_value)!=witness:return {"ready":false}
	return {"ready":true,"screen":camera.unproject_position(poses[id]+Vector3(0,1.5,0))}
func tick(delta: float=0.0,ids: Array=[42,43,44])->void:
	current_speech.frame_advance(delta)
	current_hud.labels(ids)
	current_registry.advance_clocks(delta)
	current_registry.frame_layout()
func state_snapshot(name: String)->void:
	var views: Array=[]
	for id in current_hud.nameplates:
		var plate=current_hud.nameplates[id]
		views.append({"id":id,"kind":"Tab","visible":plate.visible,"position":[plate.position.x,plate.position.y],"box":[plate.size.x,plate.size.y],"layout":plate.layouts,"text":plate.caption.get_parsed_text(),"backdrop":Support.backdrop_state(plate)})
	for id in current_speech.views:
		var view=current_speech.views[id]
		views.append({"id":id,"kind":"speech","visible":view.visible,"position":[view.position.x,view.position.y],"box":[view.size.x,view.size.y],"layout":view.layouts,"text":view.caption.get_parsed_text(),"backdrop":Support.backdrop_state(view)})
	observations.append({"name":name,"views":views,"registrySlots":current_registry.slots.size(),"ordinals":current_registry.slots.keys().map(func(id):return [id,current_registry.slots[id].ordinal])})
func capture(name: String)->void:
	var shown: Array=[]
	for plate in current_hud.nameplates.values():
		if plate.visible:shown.append(plate)
	for view in current_speech.views.values():
		if view.visible:shown.append(view)
	check(shown.all(func(view):return Support.raster_ready(view)),"Every shown popup uses its selected visible model and actual ready raster at "+name)
	state_snapshot(name)
	if options.get("graphical","false")!="true":return
	check(DisplayServer.get_name()!="headless","Graphical capture explicitly uses a real viewport renderer")
	check(root.unfocusable and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and root.current_screen!=DisplayServer.get_primary_screen(),"Capture remains unfocused on the secondary screen without mouse capture "+name)
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var path:=str(options.report).get_base_dir().path_join(name+".png")
	check(image!=null and not image.is_empty() and image.save_png(path)==OK,"Own viewport capture "+name)
	captures.append({"name":name,"path":path,"width":image.get_width(),"height":image.get_height(),"source":"Actual installed popup fonts, meshes, portraits and rasters in controlled presentation scene."})
func _initialize()->void:run.call_deferred()
func run()->void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	if not options.has_all(["report","install"]) or FileAccess.file_exists(options.report):quit(2);return
	if options.get("graphical","false")=="true":
		root.unfocusable=true
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		startup_window={"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"screens":DisplayServer.get_screen_count(),"unfocusable":root.unfocusable,"focused":root.has_focus(),"mouse_mode":Input.mouse_mode}
		check(options.has("screen") and root.current_screen==int(options.screen) and root.current_screen!=DisplayServer.get_primary_screen() and root.unfocusable and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Graphical startup is already secondary/unfocused with no mouse capture")
		if not failures.is_empty():
			var rejected:=FileAccess.open(options.report,FileAccess.WRITE);rejected.store_string(JSON.stringify({"success":false,"checks":checks,"failures":failures,"startup_window":startup_window,"captures":[]}));rejected.close();quit(2);return
	check(SessionGraph!=null,"Actual SessionWorld static graph compiles without constructing or running it")
	root.size=Vector2i(1280,720)
	var catalog:=Catalog.new();check(catalog.mount_install(str(options.install)),"Read-only original resource catalog mounts")
	var portrait_table: Dictionary=Table.new().parse(catalog.get_resource("portraits",2017).get_string_from_ascii())
	var portraits: Array=PortraitChoices.ordered(portrait_table.get("orderedRows",[]),0,0,catalog.has_resource,[],false)
	var portrait_base:="" if portraits.is_empty() else str(portraits[0])
	check(not portrait_base.is_empty(),"Fixture selects an actual installed portraits.2da resource rather than an authored missing image")
	observations.append({"installedPortraitBase":portrait_base})
	var stage:=Control.new();root.add_child(stage);stage.size=Vector2(1280,720)
	var background:=ColorRect.new();stage.add_child(background);background.size=stage.size;background.color=Color(0.07,0.10,0.09);background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var overlay:=Control.new();stage.add_child(overlay);overlay.size=stage.size;overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,3.5,10);camera.look_at(Vector3(0,1.5,0));camera.current=true
	var cache:=str(options.report).get_base_dir()
	var fonts:=Fonts.new();root.add_child(fonts);fonts.configure(catalog,cache.path_join("fonts"))
	var art:=Art.new();root.add_child(art);art.configure(catalog,cache.path_join("art"))
	var resources:=Resources.new();root.add_child(resources);resources.configure(catalog,cache.path_join("models"))
	var ui:=Gameplay.new();root.add_child(ui);current_ui=ui;ui.set_process(false);ui.set_process_unhandled_key_input(false);ui.catalog=catalog;ui.popup_fonts=fonts;ui.overhead_popup_source=resources;ui.generation=7;ui.area_id=91;ui.controlled_id=42
	ui.native_connection_query=func():return connection
	ui.overhead_anchor_query=anchor
	ui.text.base.open_file(str(options.install).path_join("lang/en/data/dialog.tlk"));ui.text.publish_table("damagelevels",Table.new().parse(catalog.get_resource("damagelevels",2017).get_string_from_ascii()))
	ui.text.objects={42:Support.row(42,"Nibs",8,13),43:Support.row(43,"Mira",9,14),44:Support.row(44,"Traveler",10,15)}
	for id in ui.text.objects:ui.text.objects[id].replicated.portraitRef=portrait_base
	var desktop:=Support.Desktop.new();ui.add_child(desktop);desktop.art=art;ui.desktop=desktop
	var speech_owner:=Speech.new();ui.add_child(speech_owner);current_speech=speech_owner;ui.overhead=speech_owner
	speech_owner.configure(overlay,ui.text,fonts,art,resources,ui.overhead_context,ui.overhead_source,ui.overhead_anchor,ui.popup_settings);speech_owner.configure_processing(false)
	var registry:=Registry.new();ui.add_child(registry);current_registry=registry;ui.overhead_popup_registry=registry;registry.automatic=false;registry.configure(ui.overhead_context,ui.overhead_source,ui.popup_settings,ui.popup_name_caption,ui.popup_restoration);speech_owner.bind_popup_registry(registry)
	var hud:=Hud.new();root.add_child(hud);current_hud=hud;hud.registry=Support.VisualRows.new()
	for id in [42,43,44]:hud.registry.entities[id]={"eligible":true,"type":5}
	hud.root=stage;hud.nameplate_root=Control.new();overlay.add_child(hud.nameplate_root);hud.bind_gameplay(ui);hud.labels([42,43,44])
	check(await wait_for(func():return hud.nameplates.size()==3 and hud.nameplates.values().all(func(p):return Support.raster_ready(p)) or not fonts.failed.is_empty() or not resources.failures.is_empty() or not art.failed.is_empty()),"Real asynchronous native font/model/portrait raster publications settle")
	check(fonts.failed.is_empty() and resources.failures.is_empty() and art.failed.is_empty(),"Actual installed assets publish without substitutes")
	check(hud.nameplates.size()==3 and hud.nameplates.values().all(func(p):return Support.raster_ready(p)),"All Tab controls have actual native rasters and corrected typography")
	observations.append({"initialContext":ui.overhead_context(),"initialVisibleIds":hud.nameplates.keys(),"anchorTrace":anchor_trace.duplicate(true),"fontState":fonts.snapshot(),"modelFailures":resources.failures.duplicate(),"artFailures":art.failed.duplicate()})
	if not fonts.failed.is_empty() or not resources.failures.is_empty() or not art.failed.is_empty():await finish(fonts,resources,art,stage);return
	if not hud.nameplates.has_all([42,43,44]):await finish(fonts,resources,art,stage);return
	tick()
	check(hud.nameplates[42].size.y==34 and hud.nameplates[43].size.y==34 and hud.nameplates[44].size.y==34,"Three actual large-font Tab controls use native34 logical height")
	var ordinary: Dictionary=Support.message(ui.text.objects[42],1,"Hello")
	var original:=ordinary.duplicate(true)
	check(speech_owner.receive(ordinary).get("ready",false),"Actual native speech owner accepts first exact scoped talk")
	check(speech_owner.receive(Support.message(ui.text.objects[43],2,"Hi")).get("ready",false),"Independent simultaneous speaker creates its own exact popup")
	check(await wait_for(func():return speech_owner.views.size()==2 and speech_owner.views.values().all(func(v):return Support.raster_ready(v))),"Both actual speech views reuse shared font/mesh/raster resources")
	tick()
	check(ordinary==original,"Event payload and exact witness remain detached/unmodified")
	check(not hud.nameplates[42].visible and not hud.nameplates[43].visible and hud.nameplates[44].visible,"Speech suppresses only matching Tab popup while third speaker's Tab remains visible")
	check(speech_owner.views[42].visible and speech_owner.views[43].visible and registry.slots.size()==3,"Shared registry contains one logical slot per visual across Tab and speech")
	check(registry.slots[42].ordinal<registry.slots[43].ordinal and registry.slots[43].ordinal<registry.slots[44].ordinal,"Construction ordinals survive hover-to-speech transitions")
	var a: Control=speech_owner.views[42];var b: Control=speech_owner.views[43]
	check(a.position.x==b.position.x and b.position.y==a.position.y-a.size.y,"Native overlap moves later same-anchor speaker upward by earlier logical height")
	await capture("short-tab-and-speech");await capture("overlap")
	var before:=Support.readings(fonts,resources,art,hud,speech_owner)
	var original_position:=a.position;var stable_id:=a.get_instance_id()
	for step in 16:
		poses[42]=Vector3(-0.5-float(step)*0.01,0,0);poses[43]=Vector3(0.5+float(step)*0.01,0,0);camera.position.x=float(step)*0.01;camera.look_at(Vector3(0,1.5,0));tick()
	check(a.get_instance_id()==stable_id and a.position!=original_position,"Real Camera3D projection and authored source movement update the existing view")
	check(Support.readings(fonts,resources,art,hud,speech_owner)==before,"Position-only movement performs no font preparation/layout/model/raster request or rebinding")
	var unmoved:=a.position;tick();check(a.position==unmoved,"Repeated identical camera/source frame is stable without accumulating overlap offsets")
	var raw: Dictionary=anchor(42,a.witness,[connection,7,91]);var mapped:=GuiProjection.screen_down(raw.screen,720)
	check(a.position==mapped.screen-Vector2(a.size.x*0.5,a.size.y),"Actual popup position equals one GUI-up projection round and fixed center-bottom alignment when separated")
	var first_view:=a.get_instance_id();var first_remaining: float=registry.slots[42].caption.remaining
	check(speech_owner.receive(Support.message(ui.text.objects[42],3,"Replacement")).get("ready",false),"Same-speaker replacement is accepted")
	tick();check(speech_owner.views[42].get_instance_id()==first_view and speech_owner.views.size()==2 and speech_owner.views[42].caption.get_parsed_text()=="Replacement","Replacement reuses one actual view and cannot queue duplicate speech")
	check(float(registry.slots[42].caption.remaining)>=first_remaining,"Replacement resets its one native text timer")
	# Literal native color commands are rendered by the existing span path.
	var long_text:="<c"+String.chr(1)+String.chr(255)+String.chr(1)+">A green traveler speaks across the old road and through the forest with another carefully wrapped sentence about the town beyond the hill.</c>"
	speech_owner.receive(Support.message(ui.text.objects[42],4,long_text));tick()
	check(speech_owner.views[42].displayed_rich.text.contains("\n") and speech_owner.views[42].displayed_rich.spans.any(func(s):return s.get("color","")=="#01ff01"),"Actual long colored speech wraps with preserved native spans")
	check(await wait_for(func():return Support.raster_ready(speech_owner.views[42])),"Long bubble's selected original mesh/raster is ready")
	tick();await capture("long-colored-wrap")
	speech_owner.receive(Support.message(ui.text.objects[42],5,"Done"));tick()
	var clock: float=registry.slots[42].caption.remaining;speech_owner.frame_advance(0.25);check(registry.slots[42].caption.remaining==clock,"Delegated ordinary owner does not double-advance shared Registry timer")
	registry.advance_clocks(0.25);check(registry.slots[42].caption.remaining==clock-0.25,"Registry consumes one explicit presentation delta")
	tick(4.0)
	var unknown_remote: Dictionary=registry.slots[43].caption
	var fresh_remote_bytes: PackedByteArray=hud.nameplate_values[43].caption.nativeRawBytes.duplicate()
	var prior_remote_signature: int=int(hud.nameplates[43].get_meta("hover_signature",-1))
	check(unknown_remote.writer=="cached-name" and not unknown_remote.currentRawKnown and unknown_remote.hidden and not unknown_remote.guiRegistered and not hud.nameplates[43].visible and not ui.popup_restoration(43,unknown_remote).get("ready",false),"Before a new explicit hover request, unknown remote CR restoration stays hidden without inventing a caption")
	var unknown_mode: Dictionary=unknown_remote.duplicate(true)
	var mode_result: Dictionary=preload("res://systems/native_data/popup_caption_state.gd").mode_changed(unknown_mode,1)
	check(not mode_result.get("ready",false) and not unknown_mode.currentRawKnown and unknown_mode.currentRaw.is_empty() and not unknown_mode.guiRegistered and unknown_mode.hidden,"Mode-only refit cannot replace unavailable cached restoration with expired speech or fresh hover")
	tick()
	check(hud.nameplates[43].visible and unknown_remote.writer=="hover" and unknown_remote.currentRawKnown and unknown_remote.currentRaw==fresh_remote_bytes and unknown_remote.timedFlag==0 and int(hud.nameplates[43].get_meta("hover_signature",-1))==prior_remote_signature,"Explicit steady-held Tab writes the available current hover bytes once without requiring CR restoration or a changed source signature")
	check(not speech_owner.views.has(42) and hud.nameplates[42].visible and hud.nameplates[42].caption.get_parsed_text().contains("Nibs"),"Expiry restores actual controlled-owner cached name through Gameplay and actual HUD")
	check(registry.slots[42].caption.timedFlag==0 and registry.slots[42].caption.currentRawKnown,"Expiry releases timed priority without reviving prior speech")
	await capture("after-expiry")
	var restored_revision: int=registry.slots[42].caption.revision
	var restored_layouts: int=hud.nameplates[42].layouts
	var restored_remaining: float=registry.slots[42].caption.remaining
	var remote_revision: int=unknown_remote.revision
	var remote_layouts: int=hud.nameplates[43].layouts
	var remote_remaining: float=unknown_remote.remaining
	var restored_resources:=Support.readings(fonts,resources,art,hud,speech_owner)
	for frame_index in 16:
		await process_frame
		tick(0.03125)
	check(hud.nameplates[42].visible and registry.slots[42].caption.revision==restored_revision and hud.nameplates[42].layouts==restored_layouts,"Sixteen steady frames keep restored hover visible without another write or relayout")
	check(registry.slots[42].caption.remaining==restored_remaining-0.5,"Sixteen steady frames consume one timer without resetting restored hover")
	check(Support.readings(fonts,resources,art,hud,speech_owner)==restored_resources,"Steady restored hover queues no font/model/raster work or image rebinding")
	check(hud.nameplates[43].visible and unknown_remote.revision==remote_revision and hud.nameplates[43].layouts==remote_layouts,"Sixteen held-Tab frames keep the fresh remote hover without rewriting or relayout")
	check(unknown_remote.remaining==remote_remaining-0.5,"Fresh remote hover keeps one decreasing timer rather than resetting on held Tab")
	check(not ui.popup_restoration(43,unknown_remote).get("ready",false),"Fresh current hover does not certify the still-unavailable remote CR-relative cache restoration")
	registry.advance_clocks(30.0)
	ui.text.objects[44].replicated.name={"text":"No native encoding "+String.chr(0x100)};ui.text.revision+=1
	hud.labels([44]);registry.frame_layout()
	var unavailable_caption: Dictionary=hud.nameplate_values[44].caption
	check(hud.nameplate_values[44].available and not unavailable_caption.has("nativeRawBytes") and not registry.slots[44].caption.currentRawKnown and registry.slots[44].caption.writer=="cached-name" and not hud.nameplates[44].visible,"A current unrepresentable hover caption cannot turn unknown cached restoration into a visible fresh write")
	# Positive lifetime replacement and stale callbacks cannot adopt an old view.
	speech_owner.receive(Support.message(ui.text.objects[42],6,"Old life"));tick();var stale_source: Dictionary=ui.text.objects[42].duplicate(true);var stale_scope: Array=[connection,7,91]
	ui.text.objects[42].clientKnownLifetime=20;registry.observe([42]);speech_owner.observe_sources([42]);ui.popup_visual_ready(42,stale_source,stale_scope)
	check(not speech_owner.views.has(42) and not speech_owner.state.speakers.has(42),"Redisclosure retires old speaker and rejects its late visual-ready callback")
	fonts.loaded.emit("ttf fnt_default_hr 16");resources.loaded.emit("but_popup_prtrt")
	check(not speech_owner.views.has(42),"Late font/model callbacks cannot revive retired speech")
	check(not speech_owner.receive(Support.message(stale_source,7,"Stale life")).get("ready",false) or not speech_owner.has_popup(42,ui.text.objects[42]),"Stale exact source cannot visibly bind to a reused numeric ID")
	ui.generation=8;registry.observe();speech_owner.observe_sources();check(registry.slots.is_empty() and speech_owner.views.is_empty(),"Area generation change retires shared slots and visible speech")
	var old_message:=Support.message(ui.text.objects[42],8,"Old connection",connection,8);connection=4;registry.observe();speech_owner.observe_sources();speech_owner.receive(old_message)
	check(registry.slots.is_empty() and speech_owner.views.is_empty() and speech_owner.pending.is_empty(),"Reconnect rejects embedded old connection without source retarget")
	speech_owner.configure_processing(true);registry.automatic=true;registry.update_processing()
	check(not speech_owner.is_processing() and not registry.is_processing(),"Empty owners stay idle when their actual automatic scheduling is enabled")
	var listeners:=fonts.loaded.get_connections().size();hud.clear_nameplates();speech_owner.close();registry.close()
	check(fonts.loaded.get_connections().size()<listeners and fonts.bindings.is_empty(),"Actual view retirement disconnects font listeners and releases weak bindings")
	observations.append({"unknownRestoration":"Other-creature CR-relative cache decoration remains unavailable. A separate explicit current Tab request writes only its available exact hover bytes; held-Tab native upstream cadence and CR suffix are not claimed."})
	await finish(fonts,resources,art,stage)
func finish(fonts,resources,art,stage)->void:
	current_hud.clear_nameplates();current_hud.release_nameplate_source();current_hud.queue_free();current_ui.popup_fonts=null;current_ui.overhead_popup_source=null;current_ui.close();current_ui.queue_free();fonts.close();resources.close();art.close();stage.queue_free();camera.queue_free();fonts.queue_free();resources.queue_free();art.queue_free()
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"captures":captures,"observations":observations,"startup_window":startup_window,"graphical":options.get("graphical","false")=="true","headless":DisplayServer.get_name()=="headless","gpuBenchmark":false,"serverConnections":0,"userInput":false,"scope":"Actual corrected Nameplate/OverheadBubble+shared Registry+Speech and actual HUD with installed font/model/raster owners; authored canonical rows/poses and actual Camera3D projection; manual presentation deltas. No live world, server, character-name authority, CR-relative restoration, native glyph pixel equivalence or FPS acceptance."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("NATIVE_POPUP_SCENE ",checks," checks; ",failures.size()," failures");quit(0 if result.success else 1)

