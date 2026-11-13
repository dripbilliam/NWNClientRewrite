extends "res://tests/native_particle_schedule_test.gd"
const State=preload("res://systems/native_data/portrait_chooser_state.gd")
const Layout=preload("res://systems/native_data/portrait_chooser_layout.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Chooser=preload("res://systems/native_portrait_chooser.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
var surface: SubViewport
class HeadlessFonts extends Node:
	signal loaded(name: String)
	var metrics: Dictionary={}
	var fonts: Dictionary={}
	func bind(target: Control,_name: String) -> void: target.set_meta("native_font_applied",true)
	func close() -> void: pass
class HeadlessArt extends Node:
	signal loaded(key: String,texture: Texture2D,bounds: Dictionary)
	const models=preload("res://systems/native_item_icons.gd")
	var textures: Dictionary={}
	var bounds: Dictionary={}
	var failed: Dictionary={}
	var bindings: Dictionary={}
	var calls: Array=[]
	func bind(target: Object,resource: String,property: String="texture",model: bool=false,clip: String="up",_portrait: bool=false,overrides: Dictionary={},region: Rect2=Rect2()) -> void:
		bindings[str(target.get_instance_id())+":"+property]=resource; calls.append([resource,model,clip,overrides,region])
	func unbind(target: Object,property: String="texture") -> void: bindings.erase(str(target.get_instance_id())+":"+property)
	func request_model(name: String,clip: String="up",overrides: Dictionary={},turn: int=0,layer: String="",poses: Array=[],region: Rect2=Rect2()) -> String:
		return models.model_key(name,clip,overrides,turn,layer,poses,region)
func choices(count: int) -> Array:
	var result: Array=[]
	for index in count: result.append("p%03d_"%index)
	return result
func frames(count: int=3) -> void:
	for index in count: await process_frame
func mouse(button: Button,pressed: bool) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=button.get_global_transform_with_canvas()*(button.size*0.5); event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.global_position=event.position
	if pressed:
		var motion:=InputEventMouseMotion.new(); motion.position=event.position; motion.global_position=event.position; surface.push_input(motion,true); await process_frame
	surface.push_input(event,true); await process_frame
func click(button: Button) -> void:
	await mouse(button,true); await mouse(button,false); await frames()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); check(oracle.target==BINARY_SHA,"Pinned original instruction corpus")
	var state:=State.new()
	for row in oracle.scroll:
		state.reset(choices(int(row.count)),""); state.selected=str(row.selected); state.scroll(int(row.position)); var slots:=state.slots(); var images: Array=[]; var selected:=-1
		for index in slots.size():
			images.append([index,"black" if str(slots[index].base).is_empty() else str(slots[index].base)+"m"])
			if slots[index].selected: selected=index
		check(same(images,row.images).is_empty() and same(row.tabs,[selected]).is_empty() and state.position/107==int(row.firstRow),"Unchanged original scroll mapping "+str([row.count,row.position,row.selected]))
	for row in oracle.reveal:
		var result:=state.reset(choices(int(row.count)),str(row.selected))
		check(int(result)==int(row.result) and (not result or same(row.scrolls,[state.position]).is_empty()),"Unchanged original current-portrait reveal "+str([row.count,row.selected]))
	check(State.scroll_range(17)==1 and State.scroll_range(18)==322 and State.scroll_range(36)==643,"Original exact page boundaries retain the extra scroll range, including full pages")
	state.reset(choices(18),"p000_"); state.scroll(321)
	check(not state.choose(0) and not state.choose(-1) and not state.choose(24) and state.selected=="p000_","Blank or out-of-pool cells cannot create an invalid portrait selection")
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Read-only installed source catalog")
	surface=SubViewport.new(); surface.size=Vector2i(1100,800); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface); surface.notify_mouse_entered()
	var painter:=Painter.new(); var art:=HeadlessArt.new(); var fonts:=HeadlessFonts.new(); painter.art=art; painter.fonts=fonts; painter.add_child(art); painter.add_child(fonts); art.loaded.connect(painter.art_loaded); surface.add_child(painter)
	var image_art:=HeadlessArt.new(); surface.add_child(image_art)
	var text:=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original caption table")
	var pane:=Chooser.new(); surface.add_child(pane); pane.configure(painter,text,catalog,""); pane.set_context(choices(71),"p020_",["draft",1],image_art,catalog); pane.open(); pane.start()
	var deadline:=Time.get_ticks_msec()+20000
	while not pane.layout_ready and pane.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(pane.layout_ready and pane.failure.is_empty(),"Actual native asset-service portrait pane builds from the installed GUI/MDL: "+pane.failure)
	if pane.layout_ready:
		await frames(5)
		check(pane.cells.size()==24 and pane.state.selected=="p020_" and pane.state.position==321 and not pane.range_pending,"Original current portrait is revealed after Godot container layout settles")
		check(not pane.art_ready(),"Layout readiness does not claim that the non-rendering artwork double produced finished UI")
		check(pane.bar.visible_units()==321,"The original portrait slider uses its 321 logical visible units")
		pane.bar.visible_units_override=-1
		check(pane.bar.visible_units()==roundi(pane.scroll.get_v_scroll_bar().page),"Ordinary shared scrollbars retain their actual native container page")
		pane.bar.visible_units_override=321
		check(pane.plan.grid.viewport.size.distance_to(Vector2(429,400))<0.001 and pane.plan.grid.button.size.distance_to(Vector2(66,102))<0.001,"Source viewport and checked button footprint exclude the inactive flipped border")
		check(pane.plan.grid.photo.rect.size.distance_to(Vector2(64,100))<0.001 and pane.plan.preview.rect.size.distance_to(Vector2(254.5,398.5))<0.001,"Original small and large portrait planes retain their authored dimensions")
		check(pane.plan.grid.photo.uv[0].distance_to(Vector2(0,1))<0.001 and pane.plan.preview.uv[0].distance_to(Vector2(0.00292993,0.99853498))<0.00001,"Exact source portrait UV crops are retained, including the huge image's fractional inset")
		var damaged:=pane.models.duplicate(); damaged.erase("ctl_cg_mportrait")
		check(not str(Layout.parse(pane.source,damaged).error).is_empty(),"Missing required original component fails explicitly")
		var identities:=pane.cells.map(func(cell):return cell.button.get_instance_id())
		pane.scroll.get_v_scroll_bar().value=0; await frames(); await click(pane.cells[0].button)
		check(pane.state.selected=="p000_" and not pane.buttons.okbutton.disabled,"Actual Godot mouse press selects the base portrait and enables original OK")
		await mouse(pane.cells[1].button,true); pane.scroll.get_v_scroll_bar().value=107; await frames(); await mouse(pane.cells[1].button,false); await frames()
		check(pane.state.selected=="p000_","A held click cannot choose a different portrait after its pooled button is rebound by scrolling")
		check(identities==pane.cells.map(func(cell):return cell.button.get_instance_id()),"Scrolling reuses the 24 real controls")
		var results: Array=[]; pane.finished.connect(func(accepted,portrait,result_scope):results.append([accepted,portrait,result_scope]))
		await click(pane.cells[0].button); await click(pane.buttons.okbutton)
		check(results==[[true,"p006_",["draft",1]]] and not pane.visible,"Original OK returns the chosen base and scope once; the pane does not save or send a character")
		pane.set_context(choices(25),"absent_",["draft",2],image_art,catalog); pane.open(); await frames(5)
		check(pane.state.preview()=="gui_po_nwnlogo_" and pane.buttons.okbutton.disabled,"Absent current portrait uses the original logo and disables OK")
		await click(pane.buttons.cancelbutton)
		check(results.size()==2 and results[1]==[false,"",["draft",2]],"Actual Cancel returns without committing a portrait")
		pane.set_context(choices(25),"p000_",["draft",3],image_art,catalog); pane.open(); await frames(5); await mouse(pane.buttons.okbutton,true)
		pane.set_context(choices(25),"p001_",["draft",4],image_art,catalog); await frames(5); await mouse(pane.buttons.okbutton,false); await frames()
		check(results.size()==2,"An OK press held across draft replacement cannot submit the next draft")
		var replacement_art:=HeadlessArt.new(); surface.add_child(replacement_art); pane.set_context(choices(25),"p001_",["draft",5],replacement_art,catalog); await frames(5)
		check(not image_art.bindings.has(str(pane.preview.get_instance_id())+":texture") and replacement_art.bindings.get(str(pane.preview.get_instance_id())+":texture","")=="p001_h","Catalog replacement rebinds even the same portrait name and retires the old owner's delayed preview")
		pane.set_context(choices(1),"",["draft",6],replacement_art,catalog); await frames(5)
		check(pane.cells.size()==24 and pane.cells.filter(func(cell):return cell.button.visible).size()==1,"A smaller ruleset retires unused cells without rebuilding the pool")
		pane.close(); check(replacement_art.bindings.is_empty(),"Close retires pending dynamic bitmap bindings")
		replacement_art.queue_free()
	var pane_snapshot:=pane.snapshot(); pane.queue_free(); image_art.queue_free(); painter.close(); painter.queue_free(); await frames(5); surface.queue_free(); await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scroll_cases":oracle.scroll.size(),"reveal_cases":oracle.reveal.size(),"pane":pane_snapshot,"graphical":false,"publicConnections":0,"scope":"Unchanged original grid/reveal instructions, real native source loading and source dimensions/UVs, real Godot headless mouse input, pooled rebinding and scope/cancel/lifetime behavior. Artwork provider is a non-rendering test double; no raster/visual, full CG_MAIN/Customize integration, save or public-server acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
