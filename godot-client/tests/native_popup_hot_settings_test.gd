extends SceneTree
# Authored received rows/scopes and GUI deltas; actual settings controls,
# Gameplay adapters, registry/Owner/HUD, fonts and passive popup views.
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const SessionGraph=preload("res://native_session_world.gd")
const Registry=preload("res://systems/native_overhead_popup_registry.gd")
const Owner=preload("res://systems/native_overhead_speech.gd")
const CaptionState=preload("res://systems/native_data/popup_caption_state.gd")
const SpeechRules=preload("res://systems/native_data/overhead_speech_rules.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const Preferences=preload("res://systems/native_data/chat_preferences.gd")
const Options=preload("res://systems/native_chat_options.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
const Resources=preload("res://systems/native_nameplate_resources.gd")
const Hud=preload("res://systems/native_hud.gd")
const PlateState=preload("res://systems/native_data/nameplate_state.gd")
class RasterArt extends Node:
	var image: Texture2D
	func bind(target: Object,_name: String)->void:target.texture=image
	func unbind(_target: Object)->void:pass
	func portrait_resource(name: String)->String:return name
class Desktop extends Node:
	var art
	var state:={"players":[]}
	func close()->void:pass
class Inventory extends Node:
	var frame_skin
	func close()->void:pass
class FrameSkin extends RefCounted:
	var fonts
class VisualRows extends RefCounted:
	var entities: Dictionary={}
	func nameplate_position(_id: int,_camera: Vector3)->Vector3:return Vector3.ZERO
var checks:=0
var failures: Array=[]
var current:={"connection":3,"generation":7,"areaId":91,"enabled":true}
var ui
var settings
var changed_order: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func frames(count: int=2)->void:
	for _index in count:await process_frame
func click(control: Control)->void:
	var point:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await frames()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;root.push_input(event,true);await frames()
func key(code: Key)->void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;root.push_input(event,true);await frames()
func choose(id: int)->bool:
	var choice: OptionButton=settings.fields["ui.text-bubble-mode"]
	await click(choice)
	var popup:=choice.get_popup()
	if not popup.visible:return false
	for _attempt in choice.item_count+1:
		if popup.get_focused_item()==choice.get_item_index(id):break
		await key(KEY_DOWN)
	await key(KEY_ENTER)
	return not popup.visible and choice.get_selected_id()==id
func source(id: int=42)->Dictionary:
	return {"id":id,"objectType":5,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13,"replicated":{"name":{"text":"Owner Name "+str(id)},"portraitRef":"po_hu_m_01","reaction":1,"damageLevel":0}}
func packet(serial: int,id: int=42,body: String="Native speech")->Dictionary:
	return {"kind":"server-speech","channel":1,"objectId":id,"text":{"text":body},"nativeTextEvent":{"version":1,"serial":serial,"connection":3,"generation":7,"areaId":91,"source":{"id":id,"objectType":5,"areaId":91,"nativeLifetime":8,"knownLifetime":13}}}
func context()->Dictionary:return current
func row(id: int)->Dictionary:return ui.text.objects.get(id,{})
func anchor(_id: int,_witness: Array,_scope: Array)->Dictionary:return {"ready":true,"screen":Vector2(400,300)}
func layout_ready(view: Control)->bool:
	var deadline:=Time.get_ticks_msec()+15000
	while is_instance_valid(view) and not view.layout_ready and Time.get_ticks_msec()<deadline:await process_frame
	return is_instance_valid(view) and view.layout_ready
func run()->void:
	var report:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
		if arg.begins_with("--install="):install=arg.trim_prefix("--install=")
	if report.is_empty() or install.is_empty() or FileAccess.file_exists(report):quit(2);return
	root.size=Vector2i(1300,1400);root.gui_embed_subwindows=true
	check(SessionGraph!=null,"Current actual SessionWorld/Gameplay graph parses without session instantiation")
	var catalog:=Catalog.new();check(catalog.mount_install(install),"Read-only installed native font/popup resource catalog")
	var fonts:=Fonts.new();root.add_child(fonts);fonts.configure(catalog,report.get_base_dir().path_join("fonts"))
	var resources:=Resources.new();root.add_child(resources);resources.configure(catalog,report.get_base_dir().path_join("popups"))
	var art:=RasterArt.new();root.add_child(art);art.image=ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_RGBA8))
	ui=Gameplay.new();root.add_child(ui);ui.set_process(false);ui.set_process_unhandled_key_input(false);ui.generation=7;ui.area_id=91;ui.controlled_id=42;ui.native_connection_query=func():return current.connection
	ui.overhead_anchor_query=anchor
	ui.text.objects={42:source(),43:source(43)}
	var desktop:=Desktop.new();ui.add_child(desktop);desktop.art=art;ui.desktop=desktop
	var inventory:=Inventory.new();ui.add_child(inventory);inventory.frame_skin=FrameSkin.new();inventory.frame_skin.fonts=fonts;ui.inventory=inventory
	settings=Options.acquire(root,report+".settings.cfg");ui.popup_options=settings;ui.popup_preferences=ui.popup_settings_from(settings.values);settings.settings_changed.connect(ui.popup_preferences_changed)
	var overlay:=Control.new();root.add_child(overlay);overlay.size=Vector2(800,600)
	var registry:=Registry.new();root.add_child(registry);registry.automatic=false;registry.configure(context,row,ui.popup_settings,ui.popup_name_caption,ui.popup_restoration);ui.overhead_popup_registry=registry
	var owner:=Owner.new();root.add_child(owner);owner.configure(overlay,ui.text,fonts,art,resources,context,row,ui.overhead_anchor,ui.popup_settings);owner.configure_processing(false);owner.bind_popup_registry(registry);ui.overhead=owner;ui.overhead_popup_source=resources
	check(ui.popup_settings()=={"mode":2,"largeFont":true} and registry.preference==ui.popup_settings(),"Canonical persisted defaults2/true reach popup admission before first speech")
	var marked:="<c"+String.chr(255)+String.chr(1)+String.chr(2)+">A  B</c>\nNext line."
	owner.receive(packet(1,42,marked))
	check(owner.state.speakers.has(42) and is_same(owner.state.speakers[42].popup,registry.slots[42].caption),"Speech and logical popup delegate to one authoritative caption/clock record")
	var record: Dictionary=registry.slots[42].caption;var view: Control=owner.views[42]
	check(await layout_ready(view) and view.font_resource=="ttf fnt_default_hr 16","Actual large native font prepares for the persisted default")
	check(record.timedFlag==1 and record.forceVisible==1 and record.portrait!="" and record.currentRaw==CaptionState.encoded(marked).bytes,"Normal wrapper captures current raw markup/whitespace, portrait, timed flag and explicit ForceVisible")
	var before: float=record.remaining;owner.frame_advance(0.25);check(record.remaining==before,"Delegated Owner frame does not advance the registry-owned clock")
	registry.advance_clocks(0.25);owner.frame_advance(0.0);check(record.remaining==before-0.25,"One registry delta decrements the same record once")
	var unchanged: Dictionary=record.duplicate(true);var layout_count: int=view.layouts
	var other: Dictionary=settings.values.duplicate();other.width=640;ui.popup_preferences_changed(other);registry.apply_preferences(ui.popup_settings())
	check(record==unchanged and view.layouts==layout_count,"Unrelated chat preference and same popup settings perform no timer/refit work")
	settings.open_settings();await frames(3)
	var old_size: Vector2=view.size;var old_rich: Dictionary=view.displayed_rich.duplicate(true);var old_raw: PackedByteArray=record.currentRaw.duplicate();before=record.remaining
	await click(settings.fields["ui.large-font"])
	check(not settings.values["ui.large-font"] and await layout_ready(view),"Actual Large dialog font control updates the existing popup through current settings_changed")
	check(record.remaining==before and record.currentRaw==old_raw and view.layouts==layout_count and view.size==old_size and view.displayed_rich==old_rich and view.font_resource=="ttf fnt_default 14","Font-only rebind preserves timer/current bytes/wrapped display/choice and bubble bounds")
	registry.register(43,ui.text.objects[43]);var inactive: Dictionary=registry.slots[43].caption;CaptionState.write(inactive,"inactive current",Rich.parse("inactive current"),"hover","",1.0,0,false);inactive.sceneActive=false;inactive.guiRegistered=false
	registry.popup_changed.connect(func(id,_witness,_record,mode_changed,_font_changed):
		if mode_changed:changed_order.append(id))
	check(await choose(0),"Actual mode control selects Off")
	check(record.mode==0 and record.timedFlag==1 and not record.sceneActive and not record.guiRegistered and not view.visible and changed_order==[42,43],"Off walks active and inactive constructions in original ordinal order, preserving source marker and hiding active view")
	before=record.remaining;registry.advance_clocks(20.0);owner.frame_advance(20.0);check(record.remaining==before and not owner.is_processing() and not registry.is_processing(),"Off unregisters GUI updates and leaves no active timer/idle processing")
	check(await choose(1) and not record.sceneActive and not inactive.sceneActive,"Enabling refits all current captions but does not Activate inactive slots inside callback")
	check(record.currentRaw==old_raw and record.remaining==SpeechRules.duration(record.currentRaw.size(),1).seconds and record.forceVisible==0 and inactive.remaining==4.0,"Mode refit uses complete raw current byte stream and exact native clamp without reviving an older caption")
	owner.frame_advance(0.0)
	check(record.sceneActive and record.hidden and record.guiRegistered,"Subsequent eligible owner projection activates then applies pinned native ToggleOff default independently of source marker")
	owner.receive(packet(2,42,"Replacement after Off"));view=owner.views[42];await layout_ready(view)
	check(not record.hidden and record.timedFlag==1 and record.forceVisible==1,"New actual wrapper ForceVisible clears panel hidden state after Off without changing constructor identity")
	check(registry.hover_blocked(42,ui.text.objects[42]),"Timed source flag blocks hover regardless popup visibility")
	ui.text.objects[42].replicated.name={"text":"Latest Owner Cache"};registry.observe([42]);var current_bytes: PackedByteArray=record.currentRaw.duplicate()
	check(CaptionState.decoded(record.cachedRaw)=="Latest Owner Cache" and record.currentRaw==current_bytes,"Owner name cache updates independently of current speech")
	record.remaining=0.0;registry.advance_clocks(0.0);check(record.timedFlag==1,"Exact-zero GUI tick does not restore the cache early")
	registry.advance_clocks(0.01)
	check(not owner.state.speakers.has(42) and record.timedFlag==0 and record.currentRawKnown and CaptionState.decoded(record.currentRaw)=="Latest Owner Cache" and record.remaining==0.0,"Strict-negative expiry restores exact controlled-owner cache, clears source marker and removes speech view without losing logical slot")
	# Actual HUD path; only the received visual registry position is authored.
	var stage:=Node3D.new();root.add_child(stage);var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,0,5);camera.look_at(Vector3.ZERO);camera.make_current()
	var visual:=VisualRows.new();visual.entities={42:{"type":5,"eligible":true}}
	var hud:=Hud.new();root.add_child(hud);hud.registry=visual;hud.camera=camera;hud.root=Control.new();hud.add_child(hud.root);hud.nameplate_root=Control.new();hud.root.add_child(hud.nameplate_root);hud.bind_gameplay(ui)
	hud.labels([42],42);await frames();hud.labels([42],42)
	check(hud.nameplates.has(42) and registry.view_for(42,"hover")==hud.nameplates[42],"Actual HUD binds hover and speech to the same exact-lifetime registry slot")
	var hover= hud.nameplates.get(42)
	check(is_instance_valid(hover) and await layout_ready(hover) and record.writer=="hover" and record.timedFlag==0 and record.currentRaw!=record.cachedRaw,"Actual hover writer owns current decorated tooltip raw; basic owner cache stays separate")
	var hover_raw: PackedByteArray=record.currentRaw.duplicate();before=record.remaining;registry.advance_clocks(0.25)
	check(record.remaining==before-0.25 and record.timedFlag==0,"Hover zero source marker still uses the same registered GUI clock")
	var hover_size: Vector2=hover.size;var hover_lines: Dictionary=hover.displayed_rich.duplicate(true);var hover_layouts: int=hover.layouts;before=record.remaining
	await click(settings.fields["ui.large-font"]);await layout_ready(hover)
	check(record.currentRaw==hover_raw and record.remaining==before and hover.size==hover_size and hover.layouts==hover_layouts and hover.displayed_rich==hover_lines,"Existing hover font-only refresh preserves exact current lines/shape/clock")
	check(await choose(2) and record.currentRaw==hover_raw and record.timedFlag==0 and record.remaining>=4.0,"Mode change after hover refits CURRENT hover caption instead of cached name or prior speech")
	hud.labels([]);check(record.remaining==0.0,"Actual hover leave clears remaining only for the zero source marker")
	registry.advance_clocks(0.01);check(record.hidden and record.timedFlag==0 and record.remaining==0.0,"Hover expires through the same strict-negative restoration/ToggleOff path")
	# No unproved CR/stats provider may resurrect old remote speech.
	var remote: Dictionary=registry.slots[43].caption;CaptionState.write(remote,"old remote speech",Rich.parse("old remote speech"),"speech","",0.0,1,true,1);registry.track_clock(43);registry.advance_clocks(0.01)
	check(not remote.currentRawKnown and remote.currentRaw.is_empty() and remote.timedFlag==0,"Unmapped remote CR restoration becomes explicit unavailable current raw, never old speech or guessed plain cache")
	registry.apply_preferences({"mode":0,"largeFont":true});registry.apply_preferences({"mode":2,"largeFont":true});registry.project_speech(43,ui.text.objects[43],true)
	check(not remote.guiRegistered and not remote.currentRawKnown and not registry.diagnostics.is_empty(),"Unsupported restoration remains dormant across later mode refits/projections")
	# Weak view scope/known-life fencing also blocks late resource completion.
	ui.text.objects[42].clientKnownLifetime=14;registry.observe([42]);fonts.loaded.emit("ttf fnt_default_hr 16");resources.loaded.emit("but_popup_prtrt")
	check(not registry.slots.has(42) and not hover.visible,"ID reuse retires old view/caption; late font/model callback cannot reactivate it")
	hud.clear_nameplates();hud.release_nameplate_source();hud.queue_free();stage.queue_free()
	owner.reset();registry.reset();check(not owner.is_processing() and not registry.is_processing() and registry.clocks.is_empty(),"All inactive/reset owners disable frame work without per-frame world scans")
	# Preferences received before any area are retained for later construction.
	current.generation=-1;current.areaId=-1;registry.apply_preferences({"mode":1,"largeFont":false});current.generation=7;current.areaId=91;registry.register(43,ui.text.objects[43])
	check(registry.slots[43].caption.mode==1 and registry.slots[43].caption.font=="ttf fnt_default 14","Pre-firstarea settings retain preference without adopting scope or stale popup state")
	ui.close();ui.queue_free();owner.queue_free();registry.queue_free();overlay.queue_free();resources.queue_free();fonts.close();fonts.queue_free();art.queue_free();settings.get_parent().queue_free();await frames(4)
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Authored received rows/scopes and GUI deltas; actual embedded ChatOptions controls, Gameplay settings/cache adapters, registry/Owner/HUD, passive Bubble/Nameplate and installed dialog fonts/native popup assets with controlled raster. Current SessionWorld graph compiles. Native92 field equality has separate proof. No original-server/live actor, rendered pixels, complete CR restoration, lower native activation/font-shaping equivalence or original profile/key/GPU/OS input."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
