extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
var checks:=0
var failures: Array=[]
var requests: Array=[]
var surface: SubViewport
var pointer:=Vector2.ZERO
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label)
	return value
func wait_for(predicate: Callable,seconds: float=40) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func mouse(point: Vector2,down: bool) -> void:
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.pressed=down; event.button_index=MOUSE_BUTTON_LEFT; event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0; surface.push_input(event,true); await process_frame
func motion(point: Vector2,held: bool=false) -> void:
	var event:=InputEventMouseMotion.new(); event.position=point; event.global_position=point; event.relative=point-pointer; pointer=point; event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0; surface.push_input(event,true); await process_frame
func click(point: Vector2) -> void:
	await motion(point); await mouse(point,true); await mouse(point,false)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	root.size=Vector2i(1424,921); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.notify_mouse_entered()
	var image:=TextureRect.new(); root.add_child(image); image.texture=surface.get_texture(); image.mouse_filter=Control.MOUSE_FILTER_IGNORE; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.size=root.size
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original merchant resources mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg"); ui.request.connect(func(message):requests.append(message.duplicate(true)))
	check(await wait_for(func():return ui.tables_ready and ui.inventory.frame_skin.layout_ready and ui.inventory.store_skin.layout_ready or not ui.inventory.store_skin.failure.is_empty()),"Original merchant GUI, dynamic tabs and confirmation models prepare natively")
	var skin=ui.inventory.store_skin
	if not check(skin.layout_ready and skin.failure.is_empty(),"Original merchant layout validates: "+skin.failure):
		var failed:=FileAccess.open(args.report,FileAccess.WRITE); failed.store_string(JSON.stringify({"success":false,"checks":checks,"failures":failures,"merchant":skin.snapshot()},"\t")); failed.close(); ui.close(); ui.free(); quit(1); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-item-icon-oracle-v1.json")); var item: Dictionary=oracle.cases.filter(func(row):return not row.error and int(row.item.baseItem)==0)[0].item.duplicate(true)
	item.name={"text":"Native test sword"}; item.cost=100; item.stackSize=1; item.identified=true
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"firstName":{"text":"Native"},"lastName":{"text":"Merchant Test"}}},"playerState":{"combat":{"field898":1000}}}
	var stock:={"id":11,"objectType":6,"item":item.duplicate(true),"inventoryLocation":{"channel":"M","ownerId":77,"x":2,"y":0}}
	var carried:={"id":12,"objectType":6,"item":item.duplicate(true),"inventoryLocation":{"channel":"R","ownerId":42,"x":0,"y":0}}
	var objects: Array=[actor,stock,carried]
	var store:={"open":true,"generation":7,"ownerId":77,"panel":0,"page":0,"gold":100000,"identifyPrice":100,"sellRate":125,"buyRate":50,"blackMarketRate":25,"maxBuyPrice":10000,"navigationPending":false}
	var raw:={"store":store,"inventories":[["R",{"entries":[{"id":12,"x":0,"y":0}]}],["I",{"entries":[]}],["M",{"entries":[{"id":11,"x":2,"y":0}],"pageCount":3}]],"containers":[]}
	ui.set_world(1,55,42,objects,raw,{"ui":{}})
	check(await wait_for(func():return is_instance_valid(ui.inventory.ui.store_panel) and skin.built() and ui.inventory.ui.buttons.has(11) and ui.inventory.ui.buttons[11].image.texture!=null),"Native merchant and player inventory display actual original item icons")
	var panel=ui.inventory.ui.store_panel
	check(await wait_for(func():return is_instance_valid(skin.confirmation_bar) and (skin.confirmation_bar.art_ready or not skin.confirmation_bar.failure.is_empty())),"Original confirmation scrollbar finishes native model rendering")
	check(is_instance_valid(skin.confirmation_bar) and skin.confirmation_bar.art_ready and skin.confirmation_bar.failure.is_empty() and skin.confirmation_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER,"Buy/Sell confirmation uses original arrows, rail and thumb instead of a generic scrollbar")
	check(not panel.window_column.visible and panel.size.distance_to(skin.definition.size)<0.001,"Original panel bounds replace generic merchant chrome")
	check(panel.repository.size==Vector2(330,330) and panel.repository.cell_size==33 and panel.repository.bottom_origin and panel.repository.native_art,"Original merchant grid has10×10 bottom-origin33px cells")
	var button=ui.inventory.ui.buttons[11]
	check(button.position.distance_to(Vector2(66,(10-int(button.row.height))*33))<0.001,"Server row zero anchors the original icon at the bottom of the merchant grid")
	check(button.image.size==button.image.texture.get_size() and button.native_icon_center!=null,"Original item icon retains its own raster proportions and attachment center")
	var before:=requests.size(); await click(panel.tabs[2].get_global_rect().get_center())
	check(requests.size()==before+1 and requests.back().kind=="native-store" and requests.back().operation=="panel" and requests.back().panel==2 and int(store.panel)==0,"Actual category click requests the server panel without predicting selection")
	store.panel=2; ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	check(panel.tabs[2].button_pressed and not panel.tabs[0].button_pressed and panel.pager.text.contains(ui.text.raw({"strRef":0xf85e})),"Received category selects original radio art and active-scope localized page label")
	await click(panel.next.get_global_rect().get_center()); check(requests.back().operation=="page" and requests.back().page==1 and int(store.page)==0,"Original Next arrow requests the next merchant page without prediction")
	store.page=1; ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	check(panel.pager.text.ends_with("2/3"),"Original page label follows the server acknowledgement")
	await click(panel.previous.get_global_rect().get_center()); check(requests.back().operation=="page" and requests.back().page==0,"Original Previous arrow requests the earlier page")
	store.page=0; ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	await click(panel.examine.get_global_rect().get_center()); await click(ui.inventory.ui.buttons[11].get_global_rect().get_center())
	check(requests.back().kind=="examine" and requests.back().targetId==11 and not panel.selection.visible,"Original eye mode examines actual merchant stock without a buy prompt")
	var tokens_before: Dictionary=ui.text.custom_tokens.duplicate(true)
	await motion(ui.inventory.ui.buttons[11].get_global_rect().get_center())
	check(panel.gold.text.contains("125") and panel.gold.text.contains("Native test sword"),"Original merchant hover label shows the server-scoped item name and price")
	await click(ui.inventory.ui.buttons[11].get_global_rect().get_center())
	check(panel.selection.visible and panel.prompt.text.contains("125") and panel.confirm.text.is_empty(),"Stock click opens original buy/sell confirmation artwork with received-context price")
	var expected: String=ui.text.resolve({"strRef":0xf0b4},42,{"localCustomTokens":{0:"Native test sword",1:"125"}})
	check(panel.prompt.get_parsed_text()==ui.Rich.parse(expected).text and ui.text.custom_tokens==tokens_before,"Original confirmation TLK uses scoped name/price substitutions without changing server custom tokens")
	var fonts=ui.inventory.frame_skin.fonts
	check(await wait_for(func():return fonts.fonts.has("fnt_galahad14")),"Original merchant bitmap font finishes native preparation")
	check(panel.prompt.get_meta("native_font_applied","")=="fnt_galahad14" and panel.prompt.get_theme_font("normal_font")==fonts.fonts.get("fnt_galahad14") and panel.prompt.get_theme_font_size("normal_font_size")==17,"Merchant confirmation uses source bitmap glyphs and metrics rather than generic font rendering")
	check(ui.inventory.blocks_pointer(panel.selection.get_global_rect().get_center()) and not ui.inventory.blocks_pointer(Vector2(1200,500)),"Detached confirmation consumes its own pointer area while outside world movement remains available")
	await wait_for(func():return ui.inventory.equipment_skin.art.waiting.is_empty()); await RenderingServer.frame_post_draw
	var aspect: Array=[]
	for control in [skin.stage,skin.modal]:
		for picture in control.find_children("*","TextureRect",true,false):
			if picture.texture!=null and picture.is_visible_in_tree() and picture.stretch_mode==TextureRect.STRETCH_SCALE:
				var scale: Vector2=picture.size/picture.texture.get_size(); aspect.append({"size":str(picture.size),"raster":str(picture.texture.get_size()),"error":absf(scale.x-scale.y)/maxf(scale.x,scale.y)})
	check(not aspect.is_empty() and aspect.all(func(row):return row.error<0.02),"Visible merchant and confirmation model rasters preserve uniform axis scale")
	surface.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+"-buy.png")
	before=requests.size(); await click(panel.confirm.get_global_rect().get_center())
	check(requests.size()==before+1 and requests.back().operation=="buy" and requests.back().itemId==11 and ui.inventory.pending.has(11) and stock.inventoryLocation.channel=="M" and actor.playerState.combat.field898==1000,"Actual original OK button sends one buy request and waits for authoritative ownership/gold")
	panel.select_item(11); panel.confirm.pressed.emit(); check(requests.size()==before+1,"Pending purchase cannot send another request")
	ui.inventory.receive({"kind":"store-transaction","itemId":11}); ui.inventory.signature=""; ui.inventory.refresh(); await process_frame
	await click(ui.inventory.ui.buttons[12].get_global_rect().get_center()); check(panel.selection.visible and panel.prompt.text.contains("50"),"Player item selects native Sell confirmation using server-scoped pricing")
	await click(panel.cancel_button.get_global_rect().get_center()); check(not panel.selection.visible,"Original Cancel dismisses the transaction prompt without closing the merchant")
	panel.select_item(12); var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true; surface.push_input(escape,true); await process_frame
	check(not panel.selection.visible and panel.visible,"Escape dismisses the native confirmation without ending merchant interaction")
	var start: Vector2=panel.position; var from: Vector2=panel.heading.get_global_rect().get_center()
	await motion(from); await mouse(from,true); await motion(from+Vector2(20,15),true); await mouse(from+Vector2(20,15),false)
	check(panel.position.distance_to(start+Vector2(20,15))<1,"Original merchant title supports native dragging and saved placement")
	await click(panel.close_button.get_global_rect().get_center()); check(requests.back().operation=="close" and panel.visible,"Original Close requests server closure without predicting its acknowledgement")
	store.open=false; ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	check(not panel.visible and not panel.selection.visible,"Received store closure retires merchant and detached confirmation together")
	var snapshot: Dictionary=skin.snapshot(); ui.close(); check(skin.assets.running.is_empty() and skin.assets.pending.is_empty(),"Merchant retirement drains its bounded native resource workers"); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"merchant":snapshot,"aspect":aspect,"requests":requests,"scope":"Original-resource merchant panels, tab hooks, grid, confirmation artwork and injected native GUI input with authored snapshots. Actual original-server transactions are verified separately; full text/identify/mixed-client parity remains open."},"\t")); file.close(); print("NATIVE_STORE_UI ",checks," checks / ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
