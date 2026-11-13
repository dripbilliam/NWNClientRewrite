extends "res://tests/native_modal_owner_input_test.gd"
const Gold=preload("res://systems/native_gold_transfer.gd")
func key(surface: SubViewport,code: int,unicode_value: int=0) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.unicode=unicode_value;event.pressed=pressed;surface.push_input(event,true);await frames()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual installed amount/map-note resources mount read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var ui=make_ui(surface,catalog,args.install,args.report);ui.generation=1;ui.area_id=55;ui.controlled_id=42
	# Gold calls the real InventoryFrame.refresh interface after construction.
	# Borrow only its raster/font publication; keep the actual painter/refresh.
	var painter=ui.inventory.frame_skin;painter.art.close();painter.fonts.close();painter.art=SourceFixture.ControlledArt.new();painter.fonts=ReadyFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts)
	var inventory=ui.inventory;inventory.generation=1;inventory.area_id=55;inventory.controlled_id=42;inventory.view_serial=9;inventory.ui.wanted=true
	var actor:={"id":42,"objectType":5,"areaId":55,"playerState":{"combat":{"field898":27}}}
	var packed:={"id":13,"objectType":6,"item":{"stackSize":27},"inventoryLocation":{"channel":"I","ownerId":42}}
	inventory.objects={42:actor,13:packed};inventory.views={13:{"object":packed.duplicate(true),"row":{"itemId":13,"entryId":13,"channel":"I","stack":27}}}
	var requests: Array=[];ui.request.connect(func(message):requests.append(message.duplicate(true)))
	for amount in [inventory.gold,inventory.stack_dialog]:
		amount.frame=painter;amount.process_mode=Node.PROCESS_MODE_ALWAYS;amount.assets.process_mode=Node.PROCESS_MODE_ALWAYS
	var gold=inventory.gold;var split=inventory.stack_dialog
	var amount_ready:=check(await ready(gold) and await ready(split),"Actual INV_STACKSPLIT models build both separately classified amount owners")
	if amount_ready:
		gold.modal.process_mode=Node.PROCESS_MODE_ALWAYS;split.modal.process_mode=Node.PROCESS_MODE_ALWAYS
		gold.open();await frames();var original: Dictionary=gold.modal_lease.ticket.duplicate(true)
		check(gold.modal.visible and gold.number.has_focus() and gold.modal_lease.admits() and ui.modal_surfaces.snapshot().available,"Gold actual amount show binds focus/admission and explicit render root")
		check(gold.modal_lease.ticket.owner==gold.modal.get_instance_id() and not ui.modal_surfaces.owners.has(gold.get_instance_id()),"Only the actual amount Control is a member; its private drag controller is not promoted")
		await click(surface,gold.buttons.cancelbutton)
		check(not gold.modal.visible and gold.modal_lease.ticket.is_empty() and requests.is_empty(),"Physical source Cancel retires only gold amount without a server request")
		gold.open();gold.number.text="3";await key(surface,KEY_ENTER,13)
		check(not gold.modal.visible and gold.modal_lease.ticket.is_empty() and not gold.payload.is_empty() and surface.gui_is_dragging() and requests.is_empty(),"Physical Enter retires amount before starting the private gold drag; no transfer prediction")
		await key(surface,KEY_ESCAPE);check(gold.payload.is_empty() and not surface.gui_is_dragging(),"Typed drag cancellation remains separate from modal membership")
		gold.open();inventory.generation=2;gold._process(0)
		check(not gold.modal.visible and gold.modal_lease.ticket.is_empty() and not ui.modal_order.retire(original),"Changed authoritative amount context retires exact old lease without a command")
		inventory.generation=1
		split.open_item({"viewId":9,"entryId":13});check(split.modal_lease.ticket.owner==split.modal.get_instance_id(),"Item split uses its separately verified actual amount panel owner");split.number.text="2";await key(surface,KEY_ENTER,13)
		check(not split.modal.visible and split.modal_lease.ticket.is_empty() and requests.size()==1 and requests.back().kind=="item-action" and requests.back().operation=="split" and requests.back().amount==2 and packed.item.stackSize==27,"Actual item-split source Enter retires before its typed command and retains received stack count")
		inventory.pending.clear()
	# Exercise the real lazy-binding branch after source-painted descendants
	# already exist. The ordinary configure path binds before worker completion.
	var late:=Gold.new();late.configure(inventory,ui.controls,catalog,str(args.report)+".late-cache");late.frame=painter;late.process_mode=Node.PROCESS_MODE_ALWAYS;late.assets.process_mode=Node.PROCESS_MODE_ALWAYS
	var late_ready:=check(await ready(late),"Standalone source amount builds before an explicit late modal/surface binding")
	if late_ready:
		late.modal.process_mode=Node.PROCESS_MODE_ALWAYS;ui.controls.scale=Vector2.ONE*1.25;await frames();late.open();await frames()
		var nested_parent:=Control.new();late.modal.add_child(nested_parent);nested_parent.position=Vector2(10,10);nested_parent.size=Vector2(30,30)
		var nested:=Button.new();nested_parent.add_child(nested);var entry: Dictionary=late.entries.upbutton.duplicate(true);entry.rect=Rect2(Vector2.ZERO,Vector2(20,20));entry.offset=Vector2.ZERO;painter.button(nested,entry,nested_parent,late.models)
		var nested_id:=nested.get_instance_id();var source_ids: Array=late.buttons.values().map(func(button):return button.get_instance_id());source_ids.append(nested_id)
		var before_transform: Transform2D=late.modal.get_global_transform_with_canvas();var clicked: Array=[];nested.pressed.connect(func():clicked.append(true))
		late.set_modal_order(ui.modal_order,ui.modal_surfaces,ui.layer);await frames()
		check(late.modal_lease.ticket.get("owner",-1)==late.modal.get_instance_id() and late.modal_lease.admits(),"Late binding adopts only the currently displayed actual amount owner")
		check(late.number.has_focus(),"The explicit subtree relocation restores only its previously focused valid amount edit")
		check(before_transform.is_equal_approx(late.modal.get_global_transform_with_canvas()),"Late dedicated-root move preserves exact125percent source amount transform")
		check(source_ids.all(func(id):return painter.button_geometry.has(id)),"Actual Painter metadata for every painted amount and nested button survives exact root move")
		await click(surface,nested);check(clicked.size()==1,"Actual nested painted-button pointer still works after late root move")
		late.close();await frames();check(source_ids.all(func(id):return not painter.button_geometry.has(id)),"Final amount destruction retires painted subtree metadata after its one move")
	else:late.close()
	ui.controls.scale=Vector2.ONE;await frames()
	var desktop=ui.desktop;desktop.generation=1;desktop.area_id=55;desktop.actor_id=42;desktop.objects=inventory.objects
	check(desktop.objects.has(desktop.actor_id),"Authored received actor exists in the actual Desktop command owner's registry")
	var map=desktop.area_map;map.wanted=true;map.view_id=8;map.board.columns=10;map.board.rows=10;map.board.resize_map()
	var skin=desktop.map_frame;skin.frame=painter;skin.assets.process_mode=Node.PROCESS_MODE_ALWAYS
	var deadline:=Time.get_ticks_msec()+6000
	while (not skin.layout_ready or not is_instance_valid(skin.editor)) and skin.failure.is_empty() and Time.get_ticks_msec()<deadline:
		skin._process(0);await process_frame
	var map_ready:=check(skin.layout_ready and skin.failure.is_empty() and is_instance_valid(skin.editor) and skin.editor.layout_ready,"Actual map frame/pin-text source models construct the real map-note owner at completion")
	if map_ready:
		var editor=skin.editor;editor.process_mode=Node.PROCESS_MODE_ALWAYS;editor.panel.process_mode=Node.PROCESS_MODE_ALWAYS
		var note:={"viewId":8,"scope":[1,55,42],"type":-1,"position":[1.0,2.0,0.0],"text":"Received initial note"}
		editor.open(note);await frames();var old: Dictionary=editor.modal_lease.ticket.duplicate(true)
		check(editor.panel.visible and editor.edit.has_focus() and editor.modal_lease.admits(),"Actual map-note open starts its own input/render lease")
		check(editor.modal_lease.ticket.owner==editor.panel.get_instance_id(),"Map-note registers its actual original panel rather than its controller Node")
		var count:=requests.size();await click(surface,editor.buttons.cancelbutton)
		check(not editor.panel.visible and editor.modal_lease.ticket.is_empty() and requests.size()==count,"Physical installed note Cancel retires without sending or changing received note data")
		editor.open(note);editor.edit.text="Authored new note";await click(surface,editor.buttons.okbutton)
		check(editor.pending and editor.modal_lease.admits() and requests.size()==count+1 and requests.back().kind=="native-map" and requests.back().operation=="add" and note.text=="Received initial note","Physical source OK retains the one pending note lease and awaits received outcome without mutating caller data")
		if requests.size()==count+1:
			var sent: Dictionary=requests.back();skin.receive({"requestId":sent.requestId,"generation":1,"areaId":55,"actorId":42,"accepted":false,"text":"Fixture rejection"})
			check(not editor.pending and editor.panel.visible and editor.modal_lease.admits() and editor.notice.text=="Fixture rejection","Owned rejected send completion restores editing in the same note lifetime")
		else:check(false,"Expected typed map request unavailable; preserve rejection context without empty-array cascade")
		await key(surface,KEY_ESCAPE)
		check(not editor.panel.visible and editor.modal_lease.ticket.is_empty(),"Actual note Escape retires only the admitted editor")
		editor.open(note);check(editor.modal_lease.ticket!=old and not ui.modal_order.retire(old),"Reopening map note rejects old exact tickets")
		skin.close_editor();check(editor.modal_lease.ticket.is_empty() and not editor.panel.visible,"Map owner scope retirement closes its actual note lease")
	var diagnostic:={"goldFailure":str(gold.failure),"splitFailure":str(split.failure),"mapFailure":str(skin.failure),"mapModels":skin.models.keys(),"mapLayouts":skin.layouts.keys()}
	ui.close();ui.free();surface.queue_free();catalog=null;await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"gpu":false,"servers":0,"scope":"Actual Gameplay-owned gold/item amount and map-note Controls over installed original GUI/MDL geometry; physical Cancel/Enter/OK/Escape and exact lease/pending/stale ownership. Authored received gold/stack/map state and send completion; controlled8px art/fallback fonts, no original pixels/game-server outcome/full coverage."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_AMOUNT_MAP_RESULT ",JSON.stringify(result));quit(0 if result.success else 1)
