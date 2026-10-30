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
func mouse(point: Vector2,down: bool,button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.pressed=down; event.button_index=button; event.button_mask=MOUSE_BUTTON_MASK_LEFT if down and button==MOUSE_BUTTON_LEFT else 0; surface.push_input(event,true); await process_frame
func motion(point: Vector2,held: bool=false) -> void:
	var event:=InputEventMouseMotion.new(); event.position=point; event.global_position=point; event.relative=point-pointer; pointer=point; event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0; surface.push_input(event,true); await process_frame
func click(point: Vector2) -> void:
	await motion(point); await mouse(point,true); await mouse(point,false)
func drawn_checked(view,tag: String) -> bool:
	var drawn: Dictionary=view.frame.button_geometry[view.buttons[tag].get_instance_id()].get("drawn",{})
	return str(drawn.get("state","")).ends_with("_checked")
func shot(path: String,view) -> void:
	await wait_for(func():return view.frame.art.waiting.is_empty() and view.frame.art.models.pending.is_empty() and not view.frame.art.models.active)
	await process_frame; await RenderingServer.frame_post_draw; surface.get_texture().get_image().save_png(path)
func drag(from: Vector2,to: Vector2) -> void:
	await motion(from); await mouse(from,true); await motion(from+Vector2(12,12),true); await motion(to,true); await mouse(to,false)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	root.size=Vector2i(1424,921); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.notify_mouse_entered()
	var image:=TextureRect.new(); root.add_child(image); image.texture=surface.get_texture(); image.mouse_filter=Control.MOUSE_FILTER_IGNORE; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.size=root.size
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original barter catalog mounts read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg"); ui.request.connect(func(message):requests.append(message.duplicate(true)))
	check(await wait_for(func():return ui.tables_ready and ui.skin_owner.announced and ui.inventory.frame_skin.layout_ready and ui.barter.layout_ready or not ui.barter.failure.is_empty()),"Native original barter GUI, models, rules and fonts finish preparation")
	check(ui.barter.failure.is_empty() and ui.barter.layout_ready,"Original barter layout validates: "+ui.barter.failure)
	if not ui.barter.layout_ready: ui.close(); ui.free(); quit(1); return
	var portrait:=-1
	for index in ui.text.tables.portraits.orderedRows.size():
		var ref:=str(ui.desktop.rules.cell(ui.desktop.rules.row("portraits",index),"BaseResRef",""))
		if not ref.is_empty() and ref!="****" and not catalog.raster_location("po_"+ref+"m").is_empty(): portrait=index; break
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-item-icon-oracle-v1.json")); var item: Dictionary=oracle.cases.filter(func(row):return not row.error and row.plan.get("kind","")=="flat")[0].item.duplicate(true); item.name={"text":"Bargaining item"}; item.stackSize=1
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"firstName":{"text":"Native"},"lastName":{"text":"Trader"}},"portrait":portrait},"playerState":{"combat":{"field898":27}}}
	var partner: Dictionary=actor.duplicate(true); partner.id=84; partner.replicated.name={"firstName":{"text":"Other"},"lastName":{"text":"Trader"}}
	var carried:={"id":11,"objectType":6,"item":item.duplicate(true),"inventoryLocation":{"channel":"R","ownerId":42,"x":0,"y":0}}
	var offered:={"id":12,"objectType":6,"item":item.duplicate(true),"inventoryLocation":{"channel":"B","ownerId":42,"x":0,"y":0}}
	var remote:={"id":13,"objectType":6,"item":item.duplicate(true),"inventoryLocation":{"channel":"A","ownerId":84,"x":0,"y":0}}
	var objects: Array=[actor,partner,carried,offered,remote]
	var trade:={"open":true,"serial":1,"revision":1,"actorId":42,"areaId":55,"firstId":42,"secondId":84,"partnerId":84,"initiator":true,"ownLocked":false,"otherLocked":false,"ownAccepted":false,"otherAccepted":false}
	var header:={"ui":{"barter":trade,"players":[[1,{"objectId":42}],[2,{"objectId":84}]]}}
	var raw:={"inventories":[["R",{"entries":[{"id":11,"x":0,"y":0}]}],["B",{"entries":[{"id":12,"x":0,"y":0}]}],["A",{"entries":[{"id":13,"x":0,"y":0}]}]],"containers":[]}
	ui.set_world(1,55,42,objects,raw,header); ui.inventory.ui.open(); ui.inventory.refresh()
	var owner=ui.barter; var view=owner.view
	check(await wait_for(func():return view.visible and view.item_buttons.has(12) and view.item_buttons.has(13) and view.item_buttons[12].image.texture!=null and view.item_buttons[13].image.texture!=null and ui.inventory.ui.buttons.has(11)),"Native trade window displays original offer icons and player backpack")
	check(view.grids.B.size==Vector2(99,330) and view.grids.A.size==Vector2(99,330),"Original barter offers use3×10 native33px repositories")
	check(owner.own_rows.has(12) and not owner.own_rows.has(13) and view.heading.text.contains("Other"),"Original B-own/A-remote binding and partner title are preserved")
	var fonts=ui.inventory.frame_skin.fonts
	check(await wait_for(func():return fonts.fonts.has("fnt_galahad14")),"Original barter bitmap font finishes native preparation")
	check(view.heading.get_meta("native_font_applied","")=="fnt_galahad14" and view.heading.get_theme_font("font")==fonts.fonts.get("fnt_galahad14") and view.heading.get_theme_font_size("font_size")==17,"Barter title uses the shared original glyph atlas and17-pixel line metrics")
	check(requests.filter(func(row):return row.kind=="native-barter" and row.operation=="window" and row.value).size()==1,"Opening the actual native trade view requests its original server window once")
	check(await wait_for(func():
		var styles: Dictionary=view.frame.button_geometry[view.buttons.leftdeclinebut.get_instance_id()].styles
		return styles.normal[0].texture!=null and styles.normal_checked[0].texture!=null),"Original Offer unchecked and checked artwork both finish rendering")
	var offer_styles: Dictionary=view.frame.button_geometry[view.buttons.leftdeclinebut.get_instance_id()].styles
	var unchecked_pixels: PackedByteArray=offer_styles.normal[0].texture.get_image().get_data()
	var checked_pixels: PackedByteArray=offer_styles.normal_checked[0].texture.get_image().get_data()
	check(unchecked_pixels!=checked_pixels,"Original checked Offer artwork visibly differs from the unchecked atlas row")
	check(view.buttons.leftacceptbut.disabled and view.buttons.rightacceptbut.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Accept waits for both server locks; remote controls cannot submit input")
	await click(view.buttons.leftdeclinebut.get_global_rect().get_center())
	check(requests.back().operation=="lock" and requests.back().value and owner.pending.has("lock") and not owner.state.ownLocked and not view.buttons.leftdeclinebut.button_pressed,"Actual Lock click sends the request but never predicts a server lock")
	ui.receive({"kind":"barter-lock","initiator":true,"value":true,"nativeBarterSerial":1,"nativeBarterRevision":2},1)
	check(owner.pending.has("lock"),"A reply cannot release pending input before its corresponding snapshot revision")
	trade.revision=2; trade.ownLocked=true; ui.update_world(1,55,42,objects,[],raw,header)
	check(not owner.pending.has("lock") and view.buttons.leftdeclinebut.button_pressed and view.buttons.leftacceptbut.disabled,"Authoritative own lock updates the original checked control")
	check(await wait_for(func():return drawn_checked(view,"leftdeclinebut") and not drawn_checked(view,"rightdeclinebut")),"Rendered Offer highlight distinguishes the acknowledged local side from the unlocked peer")
	await shot(str(args.report).trim_suffix(".json")+"-own-offered.png",view)
	trade.revision=3; trade.otherLocked=true; ui.update_world(1,55,42,objects,[],raw,header)
	check(not view.buttons.leftacceptbut.disabled and view.buttons.rightdeclinebut.button_pressed,"Both original server locks enable Accept and display the remote lock")
	check(await wait_for(func():return drawn_checked(view,"rightdeclinebut")),"Rendered remote Offer highlight follows only the remote server flag")
	trade.revision=4; trade.otherAccepted=true; ui.update_world(1,55,42,objects,[],raw,header)
	check(await wait_for(func():return drawn_checked(view,"rightacceptbut") and not drawn_checked(view,"leftacceptbut")),"The peer's accepted artwork is visible while local acceptance remains unchecked")
	await shot(str(args.report).trim_suffix(".json")+"-peer-accepted.png",view)
	trade.revision=5; trade.otherAccepted=false; ui.update_world(1,55,42,objects,[],raw,header)
	check(await wait_for(func():return not drawn_checked(view,"rightacceptbut")),"Received peer retraction restores its original unchecked artwork")
	await click(view.buttons.leftacceptbut.get_global_rect().get_center())
	check(requests.back().operation=="accept" and requests.back().value and owner.pending.has("accept") and not owner.state.ownAccepted,"Actual Accept click waits for server acceptance")
	trade.revision=6; trade.ownAccepted=true; ui.update_world(1,55,42,objects,[],raw,header); ui.receive({"kind":"barter-accept","initiator":true,"value":true,"nativeBarterSerial":1,"nativeBarterRevision":6},1)
	check(not owner.pending.has("accept") and view.buttons.leftacceptbut.button_pressed,"Server acceptance changes only the acknowledged own control")
	check(await wait_for(func():return drawn_checked(view,"leftacceptbut") and not drawn_checked(view,"rightacceptbut")),"Rendered local acceptance remains distinct from the peer's retracted state")
	var old: Dictionary=trade.duplicate(true); old.revision=2; old.ownAccepted=false; ui.update_world(1,55,42,objects,[],raw,{"ui":{"barter":old}})
	check(owner.state.ownAccepted and owner.state.revision==6,"An older in-flight snapshot cannot roll back acknowledged barter state")
	await wait_for(func():return owner.owner_ui.inventory.equipment_skin.art.waiting.is_empty()); await RenderingServer.frame_post_draw
	var artwork_geometry: Array=[]; var distorted: Array=[]
	for control in ui.find_children("*","TextureRect",true,false):
		if not control.is_visible_in_tree() or control.texture==null or control.stretch_mode!=TextureRect.STRETCH_SCALE or control.size.x<=0 or control.size.y<=0: continue
		var raster: Vector2=control.texture.get_size(); var scale: Vector2=control.size/raster
		var unequal:=absf(scale.x-scale.y)/maxf(scale.x,scale.y)
		artwork_geometry.append({"name":str(control.get_path()),"size":[control.size.x,control.size.y],"raster":[raster.x,raster.y],"axis_scale_error":unequal})
		if unequal>0.02: distorted.append(str(control.get_path()))
	check(not artwork_geometry.is_empty() and distorted.is_empty(),"Visible original GUI model rasters keep uniform axis scale within two-percent pixel rounding: "+str(distorted))
	surface.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+"-locked.png")
	partner.replicated.erase("name"); partner.replicated.erase("portrait")
	header.ui.players[1][1].character={"id":84,"firstName":{"text":"Disclosed"},"lastName":{"text":"Trader"},"portrait":portrait}
	ui.update_world(1,55,42,objects,[],raw,header)
	check(view.heading.text.contains("Disclosed") and not partner.replicated.has("name") and not partner.replicated.has("portrait"),"Native barter resolves disclosed player-list title and portrait without mutating object replication")
	header.ui.players[1][1].character.firstName.text="Renamed"; ui.update_world(1,55,42,objects,[],raw,header)
	check(view.heading.text.contains("Renamed"),"Disclosed name changes invalidate native barter identity artwork and title")
	trade.revision=7; trade.ownLocked=false; trade.ownAccepted=false; ui.update_world(1,55,42,objects,[],raw,header)
	var source: Vector2=view.item_buttons[12].get_global_rect().get_center(); var target: Vector2=ui.inventory.ui.repository.get_global_transform()*Vector2(214,49)
	await drag(source,target)
	check(requests.back().kind=="native-barter" and requests.back().operation=="remove" and requests.back().itemId==12 and requests.back().x==6 and requests.back().y==4 and owner.own_rows.has(12),"Actual offer-to-backpack drag sends Remove with native coordinates and retains membership until the reply")
	offered.inventoryLocation={"channel":"R","ownerId":42,"x":6,"y":4}; raw.inventories[0][1].entries.append({"id":12,"x":6,"y":4}); raw.inventories[1][1].entries=[]; ui.update_world(1,55,42,objects,[],raw,header)
	await process_frame
	check(not owner.own_rows.has(12) and not owner.pending.has("item:12") and ui.inventory.ui.buttons.has(12),"Actual replicated membership retires the offer and restores its canonical backpack item")
	await click(view.buttons.examinebutton.get_global_rect().get_center()); await click(view.item_buttons[13].get_global_rect().get_center())
	check(requests.back().kind=="examine" and requests.back().targetId==13,"Original eye mode examines the received remote offer through the real request path")
	await click(view.buttons.goldbutton.get_global_rect().get_center()); var gold=ui.inventory.gold
	check(gold.number.get_meta("native_font_applied","")=="fnt_galahad14" and gold.number.get_theme_font("font")==fonts.fonts.get("fnt_galahad14") and gold.number.get_theme_font_size("font_size")==17,"Gold amount edit uses the original caption font while retaining real native editing")
	gold.number.text="5"; await click(gold.buttons.okbutton.get_global_rect().get_center())
	var gold_target: Vector2=view.grids.B.get_global_transform()*Vector2(49,214); await motion(gold_target); await click(gold_target)
	check(requests.back().kind=="inventory-gold" and requests.back().placement and requests.back().barterSerial==1 and requests.back().targetId==84 and requests.back().x==1 and requests.back().y==3 and actor.playerState.combat.field898==27,"Actual gold offer drag uses the original barter placement variant without editing the balance")
	var caption_point: Vector2=view.heading.get_global_rect().get_center(); var start: Vector2=view.position; await drag(caption_point,caption_point+Vector2(20,15)); check(view.position.distance_to(start+Vector2(20,15))<1,"Original barter title supports persistent native window dragging")
	var saved: Vector2=view.position; trade.open=false; trade.revision=8; trade.completed=true; ui.update_world(1,55,42,objects,[],raw,header)
	check(not view.visible and requests.back().operation=="window" and not requests.back().value,"Only the actual server close retires the trade window and sends window-close interest")
	trade.open=true; trade.serial=2; trade.revision=1; trade.firstId=84; trade.secondId=42; trade.initiator=false; trade.ownLocked=false; trade.otherLocked=false; trade.ownAccepted=false; trade.otherAccepted=false; ui.update_world(1,55,42,objects,[],raw,header)
	check(view.visible and view.position.distance_to(saved)<1 and owner.all_rows.has(13),"A new recipient-role trade restores the saved window position and its received offers")
	await click(view.buttons.leftdeclinebut.get_global_rect().get_center()); check(requests.back().serial==2 and requests.back().value,"Recipient role sends its own original Lock request with the current trade identity")
	ui.receive({"kind":"barter-lock","initiator":false,"value":true,"nativeBarterSerial":2,"nativeBarterRevision":2},1); trade.revision=2; trade.ownLocked=true; ui.update_world(1,55,42,objects,[],raw,header)
	check(view.buttons.leftdeclinebut.button_pressed and not view.buttons.rightdeclinebut.button_pressed,"Recipient-role acknowledgement updates own, not remote, lock")
	owner.item_menu(13,Vector2(600,350))
	var item_menu=ui.inventory.item_context; var wheel=item_menu.wheel
	check(wheel.active and item_menu.entries.size()==1 and item_menu.entries[0].action=="examine","Requested remote-offer wheel uses native artwork and only an authoritative Examine action")
	var before_menu:=requests.size(); wheel.choose(0)
	check(requests.size()==before_menu+1 and requests[-1].kind=="examine" and requests[-1].targetId==13,"Remote-offer wheel routes its current item to the original examination request")
	# Restore an own offer in a fresh authored snapshot; original barter cells
	# suppress their default item menu, so Remove is an explicit client extension.
	offered.inventoryLocation={"channel":"B","ownerId":42,"x":0,"y":0}; raw.inventories[0][1].entries=[]; raw.inventories[1][1].entries=[{"id":12,"x":0,"y":0}]; trade.revision=3; ui.update_world(1,55,42,objects,[],raw,header)
	owner.item_menu(12,Vector2(600,350))
	check(wheel.active and item_menu.entries[2].action=="barter-remove" and item_menu.entries[2].disabled,"Own-offer wheel visibly disables Remove while the authoritative trade is locked")
	trade.ownLocked=false; trade.revision=4; ui.update_world(1,55,42,objects,[],raw,header); await process_frame
	check(wheel.active and not item_menu.entries[2].disabled,"A received unlock refreshes the open offer wheel's action state")
	before_menu=requests.size(); wheel.choose(2)
	check(requests.size()==before_menu+1 and requests[-1].kind=="native-barter" and requests[-1].operation=="remove" and requests[-1].serial==2 and requests[-1].itemId==12 and owner.own_rows.has(12),"Offer wheel sends Remove for its current serial without predicting a transfer")
	var snapshot: Dictionary=owner.snapshot(); var requests_copy: Array=requests.duplicate(true); ui.close()
	check(owner.assets.running.is_empty() and owner.assets.pending.is_empty(),"Native barter retirement drains its original-resource workers")
	ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"barter":snapshot,"requests":requests_copy,"artwork_geometry":artwork_geometry,"scope":"Original-resource native barter UI with actual injected GUI input and authored server snapshots. Full original-server two-player trade acceptance remains separate. Aspect audit checks model-raster display rectangles, not all original texture/UV fidelity."},"\t")); file.close(); print("NATIVE_BARTER_UI ",checks," checks / ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
