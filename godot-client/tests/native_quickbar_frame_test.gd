extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
var checks:=0
var failures: Array=[]
var requests: Array=[]
var surface: SubViewport
class WorldInput extends Node:
	var clicks:=0
	var movement:=0
	var middle:=0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_LEFT: clicks+=1
			if event.button_index==MOUSE_BUTTON_MIDDLE: middle+=1
		if event is InputEventKey and event.pressed and event.keycode==KEY_W: movement+=1
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func wait_until(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+60000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func motion(point: Vector2,relative: Vector2=Vector2.ZERO,held: bool=false) -> void:
	var event:=InputEventMouseMotion.new(); event.position=point; event.global_position=point; event.relative=relative; event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0; surface.push_input(event,true); await process_frame
func mouse(point: Vector2,pressed: bool,button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=button; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and button==MOUSE_BUTTON_LEFT else 0; surface.push_input(event,true); await process_frame
func click(point: Vector2,button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	await motion(point); await mouse(point,true,button); await mouse(point,false,button)
func key(code: Key,pressed: bool=true,shift: bool=false,ctrl: bool=false) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; event.shift_pressed=shift; event.ctrl_pressed=ctrl; surface.push_input(event,true); await process_frame
func shot(output: String,suffix: String) -> void:
	for at in 3: await process_frame
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(output.trim_suffix(".json")+suffix+".png")
func settled(ui) -> bool:
	return ui.inventory.frame_skin.art.models.pending.is_empty() and not ui.inventory.frame_skin.art.models.active and ui.desktop.art.models.pending.is_empty() and not ui.desktop.art.models.active and ui.inventory.frame_skin.fonts.fonts.has("ttf fnt_default 14")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,800); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original installed quickbar resources mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.request.connect(func(m):requests.append(m.duplicate(true)))
	check(await wait_until(func():return ui.tables_ready and ui.inventory.frame_skin.fonts!=null),"Active original rules and native shared font owner prepare")
	var desktop=ui.desktop; var bar=desktop.quickbar; var skin=desktop.quickbar_frame
	check(skin.requested and not bar.visible,"Original quickbar layout starts preparing before world admission")
	var spell:=-1
	for id in ui.text.tables.spells.orderedRows.size():
		if desktop.rules.spell_level(id,10)==0: spell=id; break
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Quickbar test"},"position":[0,0,0],"hitPoints":{"current":10,"maximum":15},"stats":{"racialType":6,"classes":[{"id":10,"level":3}]}},"playerState":{"abilities":{"base":[10,12,10,16,11,8],"current":[10,12,10,16,11,8]},"combat":{"armorClass":12,"canLevelUp":false},"feats":[0],"spellbooks":{"0":{"known":[spell],"memorized":{"0":[{"spell":spell,"ready":true,"metamagic":0}]}}}}}
	var bindings: Array=[]
	for at in 36: bindings.append({"type":2,"intParam":spell,"classIndex":0} if at in [0,12,24] else {"type":0})
	ui.set_world(1,55,42,[actor],{},{"area":{"id":55},"ui":{"quickbar":bindings}})
	check(await wait_until(func():return skin.layout_ready or not skin.failure.is_empty()),"Original programmatic quickbar models finish bounded preparation")
	var diagnostic: Dictionary={"failure":skin.failure}
	if skin.layout_ready and skin.failure.is_empty():
		check(await wait_until(func():return bar.visible and skin.admission_ready()),"First quickbar view waits for frame art, font and all current shortcut icons")
		check(skin.art_prewarm_sealed and skin.art_keys.size()==11 and skin.resident_icons.size()>=skin.current_icons.size(),"Original quickbar frame art and current shortcut icon sources remain resident")
		check(await wait_until(func():return settled(ui)),"Original bank poses, end caps, icons and default dialog font publish")
		check(not bar.get_child(0).visible and bar.buttons.size()==12 and bar.rows.size()==36,"Generic page/navigation strip is replaced while all36 shortcut bindings remain owned")
		var expected:=[0,67,133,200,267,334,400,466,533,600,667,733]
		var offsets: Array=[]
		for at in 12:
			var entry: Dictionary=skin.definition.slots[at]; offsets.append(entry.offset.x)
			check(absf(entry.offset.x-float(expected[at]))<0.001,"Slot%d uses the original Slot attachment, independent of container spacing"%(at+1))
		check(bar.position.x==200 and absf(bar.position.y+skin.definition.origin.y-800)<0.001,"Original800px quickbar anchor is centered and flush to viewport bottom")
		check(skin.endcaps.visible and bar.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Original wider-screen end caps remain visual and cannot intercept world input")
		var first: Button=bar.buttons[0]; var data: Dictionary=ui.inventory.frame_skin.button_geometry[first.get_instance_id()]
		check(data.resource=="qb_but67" and ui.inventory.frame_skin.button_geometry[bar.buttons[1].get_instance_id()].resource=="qb_but66" and ui.inventory.frame_skin.button_geometry[bar.buttons[11].get_instance_id()].resource=="qb_but67end","Original alternating slot model table and rightmost end slot are used")
		check(first.image.size==Vector2(32,32) and first.secondary_image.size==Vector2(16,16) and first.image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Action icons use32px original sizing with preserved source aspect")
		check(skin.keys[0].text=="F1" and skin.keys[11].text=="F12" and skin.keys[0].get_meta("native_font_applied","")=="ttf fnt_default 14","Function labels use the original default dialog font")
		check(first.counter.text=="1" and first.counter.get_theme_color("font_color")==Color.WHITE and first.counter.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT,"Original count hooks carry actual uses in white and right alignment")
		await shot(output,"-normal")
		var point: Vector2=first.get_global_rect().get_center(); await motion(point); await shot(output,"-hover")
		check(ui.inventory.frame_skin.button_geometry[first.get_instance_id()].drawn.state=="hover","Actual isolated pointer hover selects original hilite pose")
		await mouse(point,true); await shot(output,"-pressed")
		check(ui.inventory.frame_skin.button_geometry[first.get_instance_id()].drawn.state=="pressed","Actual held pointer selects original down pose")
		var before: int=requests.size(); await mouse(point,false)
		check(not desktop.target.is_empty() or requests.slice(before).any(func(m):return m.kind=="native-cast"),"Native slot click still invokes server-compatible casting or its targeter")
		desktop.cancel_target()
		await key(KEY_SHIFT,true,true); check(bar.shown_page==1 and skin.keys[12].text==ui.text.raw({"strRef":0x10c50})+"F1","Shift holds the second bank and its original localized prefix")
		await key(KEY_CTRL,true,true,true); check(bar.shown_page==2 and skin.keys[24].text==ui.text.raw({"strRef":0x10c51})+"F1","Ctrl takes precedence and displays the third bank's original localized prefix")
		await key(KEY_CTRL,false,true,false); check(bar.shown_page==1,"Releasing Ctrl while Shift remains held restores its bank")
		await key(KEY_SHIFT,false); check(bar.shown_page==0,"Releasing modifiers restores the base bank")
		before=requests.size(); await key(KEY_F1); await key(KEY_F1,false)
		check(not desktop.target.is_empty() or requests.slice(before).any(func(m):return m.kind=="native-cast"),"F1 retains actual typed shortcut activation")
		desktop.cancel_target(); await click(bar.buttons[11].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
		check(desktop.radial.active and bar.selected_index==11,"Right-click on the original empty slot opens assignment for that physical destination")
		desktop.radial.reset()
		var source: Vector2=bar.buttons[0].get_global_rect().get_center(); var destination: Vector2=bar.buttons[2].get_global_rect().get_center(); before=requests.size()
		await motion(source); await mouse(source,true); await motion(source+Vector2(20,0),Vector2(20,0),true); await motion(destination,destination-source-Vector2(20,0),true)
		check(surface.gui_is_dragging(),"Original-sized slot can start an actual native private shortcut drag")
		await mouse(destination,false)
		check(not surface.gui_is_dragging() and requests.slice(before).any(func(m):return m.kind=="native-quickbar-assign" and int(m.index)==2 and m.button==bindings[0]) and requests.slice(before).any(func(m):return m.kind=="native-quickbar-assign" and int(m.index)==0 and int(m.button.type)==0),"Actual GUI drop routes the owned shortcut move without inventing a binding")
		var old: Button=bar.buttons[0]; var old_view: int=bar.quickbar_id; desktop.refresh_quickbar(); before=requests.size(); old.selected.emit()
		check(bar.quickbar_id!=old_view and requests.size()==before,"Retained old slot cannot activate a replacement quickbar owner")
		await process_frame; check(await wait_until(func():return settled(ui)),"Bank/page rebuilds reuse prepared original artwork")
		var registered: int=ui.inventory.frame_skin.button_geometry.size()
		for at in 8: bar.render(at%3); await process_frame
		check(ui.inventory.frame_skin.button_geometry.size()<=registered,"Rebuilding banks retires old original button registrations")
		bar.render(0); await process_frame
		ui.controls.scale=Vector2.ONE*1.25; bar.place(); await process_frame
		var scaled_anchor: Vector2=bar.get_global_transform_with_canvas()*skin.definition.origin; var scaled_spacing: float=bar.buttons[1].image.get_global_rect().get_center().x-bar.buttons[0].image.get_global_rect().get_center().x
		check(absf(scaled_anchor.y-800)<0.01 and absf(scaled_spacing-83.75)<0.01,"125percent GUI scale retains original slot spacing and bottom anchor")
		await shot(output,"-scaled"); ui.controls.scale=Vector2.ONE; bar.place()
		surface.size=Vector2i(800,800); bar.place(); await process_frame
		check(bar.position.x==0 and not skin.endcaps.visible,"Original800px viewport omits wider-screen end caps")
		surface.size=root.size; bar.place(); await process_frame
		var world:=WorldInput.new(); surface.add_child(world); await click(Vector2(30,785)); await key(KEY_W); await key(KEY_W,false); await click(Vector2(30,785),MOUSE_BUTTON_MIDDLE)
		check(world.clicks==1 and world.movement==1 and world.middle==1,"Visual end caps let outside clicks, WASD and middle-mouse reach world input")
		bar.render(2); bar.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT); check(bar.shown_page==bar.page,"Focus loss releases temporary modifier bank")
		var gate:={"ready":false}
		bar.admission_check=func(): return bool(gate.ready)
		bar.receive({"kind":"quickbar-view","quickbarId":bar.quickbar_id+1,"rows":bar.rows})
		check(not bar.visible and not skin.admission_ready(),"A refreshed quickbar stays hidden while an external icon family is pending")
		gate.ready=true; skin.try_admit()
		check(bar.visible and skin.admission_ready(),"The quickbar admits the completed external icon family without another view")
		bar.admission_check=Callable()
		diagnostic=skin.snapshot(); diagnostic.offsets=offsets; diagnostic.scaled_anchor=str(scaled_anchor); diagnostic.scaled_spacing=scaled_spacing; diagnostic.slot_size=str(bar.buttons[0].size); diagnostic.icon_size=str(bar.buttons[0].image.size); diagnostic.physicalMouseWarped=false; diagnostic.art_failure=ui.inventory.frame_skin.art.failed.keys()
		bar.reset(); check(skin.keys.is_empty() and bar.buttons.is_empty() and not bar.visible,"Disconnect retires all quickbar labels, slots and visibility")
	else:
		diagnostic=skin.snapshot()
		diagnostic.model_pending=ui.inventory.frame_skin.art.models.pending.size()
		diagnostic.model_queue=ui.inventory.frame_skin.art.models.queue.size()
		diagnostic.model_active=ui.inventory.frame_skin.art.models.active
		diagnostic.fonts=ui.inventory.frame_skin.fonts.snapshot()
		check(false,"Original quickbar layout activates without a generic fallback")
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"requests":requests,"publicConnections":0,"fullQuickbarParity":false,"scope":"Original model/layout frame and isolated native input. Full enabled/disabled/badge/tooltips/EE variants and original-client visual/input comparison remain open; server acceptance tested separately."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
