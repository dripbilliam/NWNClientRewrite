extends "res://tests/native_particle_schedule_test.gd"
const PlateState=preload("res://systems/native_data/nameplate_state.gd")
const Hud=preload("res://systems/native_hud.gd")
const Registry=preload("res://systems/entity_registry.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const InputOwner=preload("res://systems/world_input.gd")
const LiveWorld=preload("res://native_live_world.gd")
var clicks:=0
class Ui extends Node:
	var catalog
	var text=preload("res://systems/native_data/talk_text.gd").new()
	var area_id:=55
	var controlled_id:=42
	var closed:=false
	var presentation_enabled:=true
	var desktop: Dictionary={}
	var inventory: Dictionary={}
class QueuedAssets extends Node:
	var serial:=0
	func request(_name: String,_type: int,_decoder: String) -> int: serial+=1; return serial
	func close() -> void: pass
class PortraitCatalog extends RefCounted:
	func has_resource(_name: String,_type: int) -> bool: return true
	func raster_location(_name: String) -> Dictionary: return {"type":3}
class InputProbe extends Node:
	var movement_keys:=0
	var middle_presses:=0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.keycode==KEY_W and event.pressed: movement_keys+=1
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE and event.pressed: middle_presses+=1
func creature(id: int=42) -> Dictionary:
	return {"id":id,"objectType":5,"areaId":55,"replicated":{"name":{"firstName":{"text":"Nibs"},"lastName":{"text":"Test"}},"portrait":65534,"portraitRef":"first_","reaction":1,"damageLevel":0}}
func frames(count: int=2) -> void:
	for index in count: await process_frame
func data_checks(text) -> void:
	var object:=creature(); var state: Dictionary=object.replicated
	for entry in [[95,0],[94,1],[75,1],[74,2],[50,2],[49,3],[25,3],[24,4],[1,4],[0,5],[-1,5],[150,0]]:
		check(PlateState.damage_level({"hitPoints":{"current":entry[0],"maximum":100}})==int(entry[1]),"Original damage category at HP%d"%entry[0])
	check(PlateState.damage_level({"hitPoints":{"current":19,"maximum":20}})==0,"Original binary32 threshold95 percent")
	check(PlateState.damage_level({"hitPoints":{"current":50,"fieldE8":45,"maximum":100}})==0,"Original current HP getter includes temporary HP")
	check(PlateState.damage_level({"hitPoints":{"current":25000,"fieldE8":10000,"maximum":30000}})==5,"Original current HP getter retains its signed-short return semantics")
	check(PlateState.damage_level({"hitPoints":{"current":2.5,"maximum":10}})==-1,"A fractional value cannot impersonate the received short HP fields")
	check(PlateState.damage_level({"damageLevel":3,"hitPoints":{"current":100,"maximum":100}})==3,"Server-disclosed damage category takes priority over any exact HP")
	for data in [{},{"hitPoints":{"current":1}},{"hitPoints":{"current":1,"maximum":0}},{"hitPoints":{"current":NAN,"maximum":10}},{"damageLevel":1.5},{"damageLevel":6}]:
		check(PlateState.damage_level(data)==-1,"Undisclosed/invalid HP cannot fabricate an injury category "+str(data))
	text.overrides[700001]="Active custom condition"; text.publish_table("damagelevels",{"orderedRows":[{"STRING_REF":700001}]})
	var projected:=PlateState.project(object,42,text)
	check(projected.available and projected.name.text=="Nibs Test" and projected.condition.text=="Active custom condition" and projected.portrait=="first_t","Name, custom server damage table and custom portrait reference project from received fields")
	state.name={"firstName":{"strRef":700001},"lastName":{"text":"<CUSTOM12>"}}; text.custom_tokens[12]="Native Token"; text.mark_changed()
	check(PlateState.project(object,42,text).name.text=="Active custom condition Native Token","Localized names and server custom tokens use the active native text owner")
	state.name={"firstName":{"text":"Nibs"},"lastName":{"text":"Test"}}
	var other:=Talk.new(); other.overrides[700001]="Other server condition"; other.publish_table("damagelevels",{"orderedRows":[{"STRING_REF":700001}]})
	check(PlateState.project(object,42,other).condition.text=="Other server condition" and PlateState.project(object,42,text).condition.text=="Active custom condition","Independent active text owners never share resolved injury strings")
	other.close()
	state.erase("damageLevel"); check(PlateState.project(object,42,text).condition.text.is_empty(),"Unknown injury remains undisclosed")
	state.damageLevel=0; var old:=PlateState.signature(object,42,text.revision)
	state.name.firstName.text="Changed"; check(old!=PlateState.signature(object,42,text.revision),"In-place received name edits invalidate the compact content signature")
	old=PlateState.signature(object,42,text.revision); state.position=[10,20,30]
	check(old==PlateState.signature(object,42,text.revision),"Movement alone does not rebuild text or request portrait resources")
	for reaction in [0,1,2]:
		state.reaction=reaction; var row:=PlateState.project(object,99,text)
		check(row.color==Color(["#8080ff","#80ff80","#ff5040"][reaction]),"Original relationship name color "+str(reaction))
	object.replicationRemoved=true; check(not PlateState.project(object,42,text).available,"Retired creature cannot retain a visible nameplate")
	var rows:={42:{"type":5,"eligible":true},43:{"type":9,"eligible":true},44:{"type":5,"eligible":false},45:{"type":7,"eligible":true}}
	check(PlateState.visible_ids([42,43,44,45,42],rows)==[42] and PlateState.visible_ids([42,43,44,45],rows,43)==[42,43],"Tab labels creatures only, while the hovered interactable can show its name")
	check(PlateState.visible_ids([45],rows,45).is_empty(),"Original trigger no-op caption does not remove its separate highlight eligibility")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var source:=Catalog.new(); check(source.mount_install(args.install),"Read-only original resource catalog")
	var ui:=Ui.new(); root.add_child(ui); ui.catalog=source
	check(ui.text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual original TLK opened natively")
	data_checks(ui.text)
	for name in ["portraits","damagelevels"]: ui.text.publish_table(name,Table.new().parse(source.read_resource(name,2017).get_string_from_ascii()))
	var actor:=creature(); actor.replicated.erase("portraitRef"); ui.text.objects={42:actor}
	var rules:=Rules.new(); rules.text=ui.text
	for index in ui.text.tables.portraits.get("orderedRows",[]).size():
		var base: String=str(Rules.cell(rules.row("portraits",index),"BaseResRef",""))
		if not base.is_empty() and base!="****": actor.replicated.portrait=index; break
	check(not rules.portrait(actor,1).is_empty() and PlateState.project(actor,42,ui.text).condition.text==ui.text.raw({"strRef":6409}),"Installed stock portrait row and injury text use actual active native tables")
	var fonts:=Fonts.new(); root.add_child(fonts); fonts.configure(source,str(args.report).get_base_dir().path_join("font-cache"))
	# Use the actual asynchronous binding/delivery owner with controlled rasters.
	# Native font decoding remains real; no private icon viewport is rendered.
	var art:=Art.new(); root.add_child(art); art.catalog=PortraitCatalog.new(); art.assets=QueuedAssets.new(); art.add_child(art.assets)
	ui.desktop={"art":art,"state":{"players":[]}}; ui.inventory={"frame_skin":{"fonts":fonts}}
	var surface:=SubViewport.new(); surface.size=Vector2i(1000,700); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface); surface.notify_mouse_entered()
	var under:=Button.new(); surface.add_child(under); under.position=Vector2.ZERO; under.size=Vector2(1000,700); under.focus_mode=Control.FOCUS_NONE; under.pressed.connect(func():clicks+=1)
	var probe:=InputProbe.new(); surface.add_child(probe)
	var camera:=Camera3D.new(); surface.add_child(camera); camera.position=Vector3(0,6,9); camera.look_at(Vector3.ZERO); camera.current=true
	var registry:=Registry.new(); surface.add_child(registry); registry.entities={42:{"id":42,"type":5,"name":"Fallback must not replace server text","eligible":true},43:{"id":43,"type":9,"name":"Barrel","eligible":true}}; registry.bounds={42:AABB(Vector3(-0.5,0,-0.5),Vector3(1,2,1)),43:AABB(Vector3(1,0,0),Vector3(1,1,1))}
	var hud:=Hud.new(); surface.add_child(hud); hud.configure(registry,camera,str(args.report)+".layout"); hud.enable_live_mode(); hud.bind_gameplay(ui)
	var controls:=InputOwner.new(); surface.add_child(controls); controls.configure(registry,camera,hud); controls.set_physics_process(false)
	var until:=Time.get_ticks_msec()+20000
	hud.labels([42,43]); await frames()
	while (not fonts.fonts.has("ttf fnt_default 14") or hud.nameplates[42].portrait==null or hud.nameplates[42].backdrop.plan.is_empty()) and fonts.failed.is_empty() and hud.nameplate_source.failures.is_empty() and Time.get_ticks_msec()<until: await process_frame
	hud.labels([42,43]); await frames()
	check(hud.nameplates.has(42) and not hud.nameplates.has(43),"Actual native HUD follows Tab creature-only label policy")
	var plate=hud.nameplates[42]
	check(hud.nameplate_source.failures.is_empty() and plate.portrait!=null and not plate.backdrop.plan.is_empty(),"Actual shared native workers prepare the original backdrop and popup portrait models")
	if plate.portrait==null: hud.queue_free(); await frames(); quit(1); return
	check(plate.visible and plate.data.name.text=="Nibs Test" and not plate.data.condition.text.is_empty() and plate.portrait_frame.visible,"Actual native HUD presents a complete received creature plate")
	check(fonts.fonts.has("ttf fnt_default 14") and plate.caption.get_meta("native_font_applied","")=="ttf fnt_default 14","Actual original font decoded and bound to the native plate")
	check(plate.caption.size.y>0 and plate.caption.get_parsed_text()==plate.data.name.text+"\n"+plate.data.condition.text and is_equal_approx(plate.portrait.size.x/plate.portrait.size.y,0.64),"One original caption preserves the name/injury newline and portrait aspect after native font publication")
	source_checks(plate,source)
	var identity: int=plate.get_instance_id(); var layouts: int=plate.layouts; var reads: int=ui.text.base.reads; var serial: int=art.binding_serial
	registry.entities[44]={"id":44,"type":5,"name":"Offscreen","eligible":true}; registry.bounds[44]=AABB(Vector3(10000,0,0),Vector3(1,2,1)); ui.text.objects[44]=creature(44); hud.labels([42,44])
	check(not hud.nameplates.has(44) and art.binding_serial==serial,"Offscreen creatures are culled before controls, text and portrait requests are created")
	for index in 120: hud.labels([42])
	check(plate.get_instance_id()==identity and plate.layouts==layouts and ui.text.base.reads==reads and art.binding_serial==serial,"Repeated position updates reuse controls, text, font and portrait bindings without new TLK/art work")
	var anchor:=camera.unproject_position(registry.label_position(42)); var press:=InputEventMouseButton.new(); press.position=anchor-Vector2(0,plate.size.y*0.5); press.global_position=press.position; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.button_mask=MOUSE_BUTTON_MASK_LEFT
	var motion:=InputEventMouseMotion.new(); motion.position=press.position; motion.global_position=press.position; surface.push_input(motion,true); await frames(); surface.push_input(press,true); await frames(); press.pressed=false; press.button_mask=0; surface.push_input(press,true); await frames()
	check(clicks==1 and not hud.blocks_pointer(press.position),"Real headless pointer press passes through portrait/text/background to the world surface")
	var key:=InputEventKey.new(); key.keycode=KEY_W; key.physical_keycode=KEY_W; key.pressed=true; surface.push_input(key,true); await frames(); key.pressed=false; surface.push_input(key,true)
	check(probe.movement_keys==1,"World movement keys pass through the nameplate layer")
	under.mouse_filter=Control.MOUSE_FILTER_IGNORE
	press.button_index=MOUSE_BUTTON_MIDDLE; press.pressed=true; press.button_mask=MOUSE_BUTTON_MASK_MIDDLE; surface.push_input(press,true); await frames(); press.pressed=false; press.button_mask=0; surface.push_input(press,true)
	check(probe.middle_presses==1,"Middle-mouse camera input passes through the complete plate")
	key.keycode=KEY_TAB; key.physical_keycode=KEY_TAB; key.pressed=true; surface.push_input(key,true); await frames()
	check(controls.tab,"Actual unhandled Tab press enables world highlights")
	var edit:=LineEdit.new(); surface.add_child(edit); edit.position=Vector2(10,650); edit.size=Vector2(180,30); edit.grab_focus(); await frames()
	check(not controls.tab,"Entering a text field clears held world highlights")
	controls.tab=true; key.pressed=false; surface.push_input(key,true); await frames()
	check(not controls.tab,"A GUI-consumed Tab release cannot leave highlights stuck")
	edit.release_focus(); edit.queue_free(); await frames()
	actor.replicated.name.firstName.text="Updated"; actor.replicated.damageLevel=3; hud.labels([42])
	check(plate.get_instance_id()==identity and plate.data.name.text=="Updated Test" and plate.data.damage_level==3,"Received name/injury update preserves the existing control")
	var first_key: String=plate.portrait_key; actor.replicated.portrait=65534; actor.replicated.portraitRef="replacement_"; hud.labels([42]); var latest: String=plate.portrait_key
	var raster:=ImageTexture.create_from_image(Image.create(32,64,false,Image.FORMAT_RGBA8))
	art.deliver(first_key,raster); check(plate.portrait.texture==null and art.stale_bindings>0,"Late portrait from a previous creature appearance cannot overwrite the current binding")
	art.deliver(latest,raster); check(plate.portrait.texture==raster and Array(plate.portrait.faces[0].uv).any(func(value):return is_equal_approx(value.y,0.21875)),"Current raw portrait uses its original UV padding crop without another atlas crop or flip")
	ui.text.publish_table("damagelevels",{"orderedRows":[{},{},{},{"STRING_REF":700001}]}); hud.labels([42])
	check(plate.data.condition.text=="Active custom condition","Native HUD invalidates resolved text when the active server table changes")
	actor.replicated.erase("name"); actor.replicated.erase("portrait"); actor.replicated.erase("portraitRef"); ui.desktop.state.players=[{"objectId":42,"character":{"firstName":{"text":"Player"},"lastName":{"text":"List"},"portrait":65534,"portraitRef":"player_"}}]; hud.labels([42])
	check(plate.data.name.text=="Player List" and plate.data.portrait=="player_t","Player-list identity fills undisclosed creature name/portrait fields using the shared native projector")
	actor.replicated.portraitRef="new_"; hud.labels([42]); var retired_portrait: String=plate.portrait_key
	ui.text.objects[43]={"id":43,"objectType":9,"areaId":55,"replicated":{"name":{"text":"Barrel"}}}; hud.labels([42,43],43)
	check(hud.nameplates[43].visible and hud.nameplates[43].caption.get_parsed_text()=="Barrel" and not hud.nameplates[43].portrait_frame.visible,"Hovered object gets a single-line plate without fabricated creature details")
	hud.labels([42]); check(not hud.nameplates[43].visible,"Leaving an object removes its hover plate while Tab creature plates remain")
	surface.size=Vector2i(1600,900); await frames(); hud.labels([42]); var resized_anchor:=camera.unproject_position(registry.label_position(42))
	check(absf(plate.get_global_rect().get_center().x-resized_anchor.x)<1 and absf(plate.get_global_rect().end.y-resized_anchor.y)<1,"Viewport resize keeps the plate anchored to its actual projected creature")
	plate.place(Vector2(1,1),Rect2(0,0,1000,700)); check(plate.position.x>=0 and plate.position.y>=0,"Viewport edge keeps visible plate contents on screen")
	plate.place(Vector2(-1,100),Rect2(0,0,1000,700)); check(not plate.visible,"Offscreen anchors do not leave detached labels on the screen edge")
	camera.look_at(Vector3(0,6,20)); hud.labels([42]); check(not plate.visible,"Behind-camera creatures have no visible plate"); camera.look_at(Vector3.ZERO)
	ui.presentation_enabled=false; hud.labels([42]); check(not plate.visible,"Loading/pregame presentation guard hides plates")
	ui.presentation_enabled=true; hud.labels([42]); check(plate.visible,"Admitted gameplay restores its plate without reconstruction")
	registry.forget_entity(42); hud.refresh_entities(); check(not hud.nameplates.has(42),"Registry retirement removes the plate and its resource bindings")
	art.deliver(retired_portrait,raster); check(plate.portrait==null,"Portrait completion after entity retirement cannot repopulate a queued plate")
	ui.area_id=56; hud.labels([43],43); check(not hud.nameplates[43].visible,"A stale entity from the previous area cannot keep a label")
	ui.closed=true; hud.labels([43],43); check(hud.nameplates.is_empty() and art.bindings.is_empty() and fonts.bindings.is_empty(),"Closing the native UI releases all borrowed bindings and plates")
	controls.queue_free(); hud.queue_free(); registry.queue_free(); surface.queue_free(); await frames(); art.close(); art.queue_free(); fonts.close(); fonts.queue_free(); ui.text.close(); ui.queue_free(); source=null; await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"graphical":false,"publicConnections":0,"scope":"Native data projection, actual installed text/font decoding, actual HUD and asynchronous art binding lifecycle, headless pointer/key input and area/UI retirement. Controlled raster delivery; no source-pixel, live-world or complete original nameplate/HUD acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); print("NATIVE_NAMEPLATES ",checks," checks, ",failures.size()," failures"); quit(0 if result.success else 1)
func source_checks(_plate,_catalog) -> void: pass
