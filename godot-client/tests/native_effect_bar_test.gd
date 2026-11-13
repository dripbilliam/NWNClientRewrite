extends "res://tests/native_party_indicators_test.gd"
const EffectPlan=preload("res://systems/native_data/effect_bar_layout.gd")
const Bar=preload("res://systems/server_buffs.gd")
const EffectFrame=preload("res://systems/native_effect_bar.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
var sent: Array=[]
var ground_clicks:=0
class RevisionUi extends RefCounted:
	var hud_ready:=true
	var tables_ready:=true
class RevisionDesktop extends Desktop:
	var syncs:=0
	func ensure_ability_tables() -> bool: return true
	func pump_map_art() -> void: pass
	func sync() -> void: syncs+=1
func receive(bar,serial: int,actor: int,rows: Array) -> void:
	bar.receive({"kind":"buff-begin","viewId":serial,"actorId":actor,"count":rows.size()}); bar.receive({"kind":"buff-rows","viewId":serial,"rows":rows}); bar.receive({"kind":"buff-commit","viewId":serial})
func mouse(surface: SubViewport,point: Vector2,pressed: bool) -> void:
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; surface.push_input(motion,true); await frames()
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; surface.push_input(event,true); await frames()
func source_rules() -> Dictionary:
	var text:=Talk.new(); var rules:=Rules.new(); rules.text=text; var rows: Array=[]; rows.resize(601); rows.fill({})
	rows[1]={"Icon":"server_bless","StrRef":"1001"}; rows[20]={"Icon":"****","StrRef":"1002"}; rows[21]={"Icon":"","StrRef":"1002"}; rows[600]={"Icon":"server_flash","StrRef":"1002"}
	text.tables={"effecticons":{"orderedRows":rows}}; text.overrides={1001:"Server blessing",1002:"Server flashing effect"}
	var state:={"effectIcons":{"1":0,"20":1,"21":0,"90":1,"600":1},"effectIconSerials":{"1":2,"20":1,"600":0}}
	var projected:=rules.effect_icons(state)
	check(projected.size()==2 and projected[0].id==1 and projected[1].id==600 and not projected[0].state and projected[1].state,"Both state bits remain present; missing/empty/placeholder icon resources do not create original widgets")
	check(projected[0].label=="Server blessing" and projected[1].label=="Server flashing effect","Effect labels use StrRef from the active effecticons table")
	state.effectIconSerials["600"]=3; projected=rules.effect_icons(state)
	check(projected[0].id==600 and projected[1].id==1,"Received addition serials retain linked-list head order across coalesced snapshots")
	text.overrides[1001]="Updated server token"; rows[1].Icon="changed_bless"; text.mark_changed()
	check(rules.effect_icons(state)[1].label=="Updated server token" and rules.effect_icons(state)[1].resource=="changed_bless","Native projection rereads server-specific icon and TLK changes")
	state.erase("effectIconSerials"); check(rules.effect_icons(state)[0].id==600,"Old sealed snapshots have an explicit descending-ID fallback")
	var objects:={42:{"objectType":5,"replicated":{"hitPoints":{"current":5,"maximum":10}},"playerState":{"effectIcons":{"20":false,"21":false}}},43:{"objectType":5,"replicated":{"hitPoints":{"current":6,"maximum":10},"party":{"field8B0":0,"field8B4":1}},"playerState":{"effectIcons":{"20":true}}}}
	var party_rows: Array=rules.party(objects,42,[43])
	check(party_rows[0].health.clip=="diseasepoison" and party_rows[1].health.clip=="disease","Actual controlled portrait uses original effect IDs; other members retain received party flags")
	objects[42].playerState.effectIcons.clear(); party_rows=rules.party(objects,42,[43]); check(party_rows[0].health.clip=="percentage","Received removal clears controlled health tint independently of visible icon metadata")
	rows[1].Icon="server_bless"; text.overrides[1001]="Server blessing"; state.effectIconSerials={"1":2,"600":0}
	return {"text":text,"rules":rules,"state":state}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var fixture:=source_rules(); var rules=fixture.rules
	var revision_ui:=RevisionUi.new(); var revision_owner:=RevisionDesktop.new(); revision_owner.owner_ui=revision_ui; revision_owner.objects={42:{}}; revision_owner.actor_id=42; revision_owner.rules.text=fixture.text; revision_owner.theme_ready=true; revision_owner.startup_notice=Label.new()
	revision_owner._process(0); check(revision_owner.syncs==1,"Actual desktop metadata revision schedules its initial HUD projection")
	for index in 30: revision_owner._process(0)
	check(revision_owner.syncs==1,"Idle UI frames do not repeat metadata projection")
	fixture.text.mark_changed(); revision_owner._process(0); check(revision_owner.syncs==2,"Server TLK/table revision refreshes HUD labels without waiting for another world snapshot")
	revision_owner.closed=true; revision_owner.startup_notice.free(); revision_owner.free()
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Read-only installed original catalog")
	var models: Dictionary={}
	for name in EffectPlan.RESOURCES:
		var parser:=Actor.new(); models[name]=parser.parse(catalog.get_resource(name,2002)); check(parser.failure.is_empty(),"Original effect bar model "+name)
	var definition:=EffectPlan.parse(models)
	check(str(definition.error).is_empty() and definition.parts.size()==2,"Original two-layer icon and alpha controller parse without a model viewport")
	var static_only: Dictionary=models.duplicate(true); static_only.ctl_ig_plreffect.erase("animations")
	check(not str(EffectPlan.parse(static_only).error).is_empty(),"Missing dynamic source data is rejected explicitly without a script exception")
	check(EffectPlan.slot(definition,0)==Rect2(-43,3,40,40) and EffectPlan.slot(definition,1)==Rect2(-86,3,40,40),"Original effect icons link leftward from Queue at43px spacing")
	var border: Dictionary=definition.parts[0]; var glyph: Dictionary=definition.parts[1]
	check(border.resource=="ctl_btn_dm" and glyph.resource=="gui_replace01" and glyph.faces.size()==2 and glyph.faces[0].vertices[0].distance_to(Vector2(4,4))<0.001,"Original source rim and32px replacement glyph retain their hierarchy/size")
	check(border.faces[0].uv[0]==Vector2(0.203125,0.914062976837158) and glyph.faces[0].uv[0]==Vector2(0,1),"Original atlas crop and bitmap orientation remain raw UVs")
	check(definition.keys.size()==4 and is_equal_approx(float(definition.length),1.46667003631592),"Original1.46667-second opacity animation is sourced from physical controller128")
	for key in definition.keys:
		check(is_equal_approx(EffectPlan.alpha(definition,float(key.time)),float(key.value[0])),"Source opacity key "+str(key.time))
	check(EffectPlan.alpha(definition,0.8)<0.00001 and EffectPlan.alpha(definition,0.4)>0 and EffectPlan.alpha(definition,0.4)<1,"Flashing fades only the icon layer using interpolated source opacity")
	var source_hash:=Cache.digest(var_to_bytes(models))
	var surface:=SubViewport.new(); surface.size=Vector2i(1000,700); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface); surface.notify_mouse_entered()
	var ui_root:=Control.new(); surface.add_child(ui_root); ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var ground:=Button.new(); ui_root.add_child(ground); ground.size=surface.size; ground.focus_mode=Control.FOCUS_NONE; ground.pressed.connect(func():ground_clicks+=1)
	var art:=Art.new(); root.add_child(art); art.models=QueuedModels.new(); art.add_child(art.models); art.catalog=RasterCatalog.new(); art.assets=QueuedRasters.new(); art.add_child(art.assets)
	var bar:=Bar.new(); ui_root.add_child(bar); bar.setup()
	var frame:=EffectFrame.new(); frame.requested=true; root.add_child(frame); frame.configure(bar,art,catalog,str(args.report)+".cache")
	var desktop:=Desktop.new(); root.add_child(desktop); desktop.set_process(false); desktop.art=art; desktop.actor_id=42; desktop.area_id=55; desktop.generation=3; desktop.objects={42:{"objectType":5}}; desktop.request.connect(func(value):sent.append(value))
	bar.effect_selected.connect(func(id):desktop.command({"kind":"native-panel","panel":"effect","open":true,"effectId":id}))
	var projected: Array=rules.effect_icons(fixture.state)
	receive(bar,1,42,projected); check(not bar.visible and bar.rows.size()==2,"Raw native effect view is retained while original geometry prepares")
	frame.models=models; frame.activate(); frame.set_process(false); await frames(); frame.place()
	var first: Button=bar.buttons[1]; var flashing: Button=bar.buttons[600]; var glyph_view=flashing.get_node("Icon")
	check(first.position==Vector2(-43,3) and first.size==Vector2(40,40) and bar.position==Vector2(920,0),"Connected source bar reserves80px for the portrait and keeps40px authored buttons")
	check(not bar.scroll.visible and not bar.tip.visible and first.tooltip_text=="Server blessing" and first.focus_mode==Control.FOCUS_NONE,"Prototype wrapping and pinned tooltip are absent from the original native bar")
	check(glyph_view.flashing and not first.get_node("Icon").flashing,"Received state bit selects native flashing without hiding either effect")
	var asset_count: int=art.assets.serial
	for index in 120: frame._process(1.0/60.0)
	check(art.assets.serial==asset_count and art.models.requests.is_empty() and glyph_view.time>=0 and glyph_view.time<=definition.length,"Flashing samples native Canvas opacity without model baking or further asset requests")
	check(frame.definition.parts[0].alpha==1.0,"Flashing does not dim the original rim")
	var point:=first.get_global_transform_with_canvas()*(first.size*0.5)
	await mouse(surface,point,true); receive(bar,2,42,projected); frame.set_process(false); await mouse(surface,point,false)
	check(sent==[{"kind":"native-panel","panel":"effect","open":true,"effectId":1,"actorId":42,"areaId":55,"generation":3}],"Actual click release survives an unchanged server view and reaches scoped original GUI-event transport")
	check(not bar.pinned and not bar.tip.visible and ground_clicks==0 and bar.rows.has(1),"Effect click sends server GUI event without local pinning, removal or world click")
	var held: Button=bar.buttons[1]
	for index in 30: receive(bar,3+index,42,projected)
	frame.set_process(false)
	check(bar.buttons[1]==held and art.assets.serial==asset_count,"Unchanged metadata and state preserve native widgets and raster bindings")
	fixture.state.effectIcons["3"]=0; fixture.text.tables.effecticons.orderedRows[3]={"Icon":"new_effect","StrRef":"1001"}; fixture.state.effectIconSerials["3"]=5
	projected=rules.effect_icons(fixture.state); receive(bar,40,42,projected); frame.set_process(false)
	check(bar.buttons[3].position==Vector2(-43,3) and bar.buttons[1]==held and held.position==Vector2(-86,3),"Newest received addition takes the source head slot; old widgets retain identity")
	var texture:=ImageTexture.create_from_image(Image.create(64,128,false,Image.FORMAT_RGBA8)); art.deliver("server_bless",texture); art.deliver("ctl_btn_dm",texture)
	check(held.get_node("Icon").icon_texture==texture and held.get_node("Icon").border_texture==texture,"Native raster owner delivers both original raw-UV layers")
	projected[1].label="New blessing text"; receive(bar,41,42,projected); frame.set_process(false)
	check(held.tooltip_text=="New blessing text" and bar.buttons[1]==held,"Resolved tooltip refresh does not replace the control")
	fixture.state.effectIcons.erase("1"); fixture.state.effectIconSerials.erase("1"); receive(bar,42,42,rules.effect_icons(fixture.state)); frame.set_process(false); held.pressed.emit()
	check(not bar.buttons.has(1) and sent.size()==1,"Server expiry retires the right widget and rejects its old click")
	flashing=bar.buttons[600]; var stale_icon=flashing.get_node("Icon")
	fixture.state.effectIconSerials["600"]=6; receive(bar,43,42,rules.effect_icons(fixture.state)); frame.set_process(false); flashing.pressed.emit()
	check(bar.buttons[600]!=flashing and sent.size()==1 and stale_icon.closed,"Same-ID removal/readdition retires the old occurrence and stale callback")
	var survivor: Button=bar.buttons[600]; receive(bar,44,43,rules.effect_icons(fixture.state)); frame.set_process(false); survivor.pressed.emit()
	check(bar.buttons[600]!=survivor and sent.size()==1,"Controlled-actor transfer invalidates previous effect-widget callbacks")
	var count:=bar.rows.size(); receive(bar,43,42,[]); check(bar.rows.size()==count and bar.view_id==44,"An older completed view cannot replace current effect ownership")
	surface.size=Vector2i(800,600); await frames(); frame.place(); check(bar.position==Vector2(720,0),"Viewport resize reanchors the original native bar")
	point=bar.buttons[600].get_global_rect().get_center(); check(bar.blocks_pointer(point) and not bar.blocks_pointer(Vector2(676,20)),"Pointer blocking covers visible effect quads and leaves linked-list gaps open")
	await mouse(surface,Vector2(676,20),true); await mouse(surface,Vector2(676,20),false); check(ground_clicks==1,"Actual gap click reaches world controls")
	var last: Button=bar.buttons[3]; var late=last.get_node("Icon"); frame.close(); last.pressed.emit(); art.deliver("new_effect",texture); frame.prepared(1,{"value":models.ctl_ig_plreffect,"error":""})
	check(frame.closed and bar.rows.is_empty() and bar.buttons.is_empty() and not bar.visible and sent.size()==1 and late.icon_texture==null,"Close rejects stale clicks/metadata/raster delivery and clears the HUD")
	check(Cache.digest(var_to_bytes(models))==source_hash,"Live icon animation and retirement do not mutate the shared original model")
	var loading_bar:=Bar.new(); ui_root.add_child(loading_bar); loading_bar.setup(); var loading:=EffectFrame.new(); root.add_child(loading); loading.configure(loading_bar,art,catalog,str(args.report)+".cache"); receive(loading_bar,1,42,rules.effect_icons(fixture.state))
	var deadline:=Time.get_ticks_msec()+5000
	while not loading.layout_ready and loading.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(loading.layout_ready and loading.failure.is_empty() and loading.jobs.is_empty() and loading_bar.buttons.size()==2,"Real native worker requests prepare the effect bar headlessly from original models")
	loading.close(); loading.queue_free(); loading_bar.queue_free()
	desktop.closed=true; desktop.free(); frame.queue_free(); bar.queue_free(); art.close(); art.queue_free(); ui_root.queue_free(); surface.queue_free(); fixture.text.close(); fixture.clear(); catalog=null; await frames(3)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"scope":"Original effect-bar geometry/UV/alpha keys; active metadata, real native input/scoped requests and lifetime. Pixel comparison, GUI sound/tooltip timing and actual local server-script results remain open."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
