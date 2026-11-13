extends "res://tests/native_party_indicators_test.gd"
const Queue=preload("res://systems/server_action_queue.gd")
const ActionPlan=preload("res://systems/native_data/action_queue_layout.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
var sent: Array=[]
var world_clicks:=0
func row(serial: int,type: int=0,group: int=7,special: bool=false) -> Dictionary:
	return {"widgetSerial":serial,"type":type,"group":group,"special":special,"label":"Queued action","icon":"queue_test"}
func mouse(surface: SubViewport,point: Vector2,pressed: bool) -> void:
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; surface.push_input(motion,true); await frames()
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; surface.push_input(event,true); await frames()
func projection() -> void:
	var text:=Talk.new(); var rules:=Rules.new(); rules.text=text
	text.tables={"actions":{"orderedRows":[{"ICONRESREF":"authored"},{"ICONRESREF":""},{},{"ICONRESREF":"****"},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}]},"spells":{"orderedRows":[{"IconResRef":"server_spell","FeatID":"1"}]},"feat":{"orderedRows":[{},{"ICON":"server_feat"}]}}
	var values:=rules.queued_actions([row(0,0),row(1,1),row(2,2),row(3,3),row(4,4),row(5,19)])
	check(values[0].icon=="authored" and values[1].icon=="ir_use" and values[2].icon=="ir_use" and values[3].icon=="ir_use","Original ordinary fallback covers absent, empty and2DA placeholder icon cells")
	check(values.size()==5 and values[4].icon=="","Missing type19 spell is hidden; missing type4 spell has an empty explicit icon")
	var spell:=row(4,4); spell.spell=0; var special:=spell.duplicate(true); special.special=true
	values=rules.queued_actions([spell,special])
	check(values[0].icon=="server_feat" and values[1].icon=="","Ordinary spell-associated feat uses active server data; special queue rows remain action-table icons")
	text.tables.feat.orderedRows[1].ICON="changed_feat"
	check(rules.queued_actions([spell])[0].icon=="changed_feat","Queue projection does not hardcode installed spell/feat metadata")
	text.close()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	projection()
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original installed source opens read-only")
	var models: Dictionary={}
	for name in ActionPlan.RESOURCES:
		var parser:=Actor.new(); models[name]=parser.parse(catalog.get_resource(name,2002)); check(parser.failure.is_empty(),"Read actual original queue resource "+name)
	var definition:=ActionPlan.parse(models); check(str(definition.error).is_empty(),"Original queue hooks and geometry admitted")
	check(ActionPlan.slot(definition,0).rect==Rect2(3,3,40,40) and ActionPlan.slot(definition,1).rect==Rect2(46,3,40,40) and ActionPlan.slot(definition,11).rect==Rect2(476,3,40,40),"Original Current/Queue/NextLink positions, including beyond the old ten-widget cap")
	check(ActionPlan.slot(definition,0).icon==Rect2(7,7,32,32),"Original1x1 large icon is32px centered on its Icon hook")
	var surface:=SubViewport.new(); surface.size=Vector2i(1000,700); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface); surface.notify_mouse_entered()
	var ui_root:=Control.new(); surface.add_child(ui_root); ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var ground:=Button.new(); ui_root.add_child(ground); ground.size=surface.size; ground.focus_mode=Control.FOCUS_NONE; ground.pressed.connect(func():world_clicks+=1)
	var art:=Art.new(); root.add_child(art); art.models=QueuedModels.new(); art.add_child(art.models); art.catalog=catalog; art.assets=QueuedRasters.new(); art.add_child(art.assets)
	var desktop:=Desktop.new(); root.add_child(desktop); desktop.set_process(false); desktop.art=art; desktop.actor_id=42; desktop.area_id=55; desktop.generation=3; desktop.objects={42:{"objectType":5}}; desktop.request.connect(func(value):sent.append(value))
	var queue:=Queue.new(); queue.requested=true; ui_root.add_child(queue); queue.setup(desktop); desktop.action_queue=queue
	art.catalog=RasterCatalog.new() # Controlled raster completion; no viewport/model rendering.
	queue.cancel_requested.connect(func(type,group):desktop.command({"kind":"native-cancel-action","actionId":type,"groupId":group}))
	var entries: Array=[row(100),row(101,4,8)]
	queue.present(entries); check(not queue.visible and queue.rows.size()==2,"Received actions are retained until source geometry is ready")
	queue.models=models; queue.activate(); await frames()
	var first: Button=queue.buttons[100]; var second: Button=queue.buttons[101]
	check(first.position==Vector2(3,3) and first.size==Vector2(40,40) and first.get_node("Icon").position==Vector2(4,4) and first.get_node("Icon").size==Vector2(32,32),"Actual native widget uses source slot/icon geometry")
	check(first.tooltip_text=="Queued action" and first.focus_mode==Control.FOCUS_NONE,"Original action label is a tooltip; HUD buttons do not take keyboard focus")
	check(not queue.blocks_pointer(Vector2(44,20)) and queue.blocks_pointer(Vector2(20,20)),"Only actual action rectangles block world clicks; gaps remain open")
	var jobs_before: int=art.assets.serial; var models_before: int=art.models.requests.size()
	for index in 100: queue.present(entries)
	check(queue.buttons[100]==first and queue.buttons[101]==second and art.assets.serial==jobs_before and art.models.requests.size()==models_before,"Repeated server projections retain controls and do not enqueue artwork/model work")
	var point:=first.get_global_transform_with_canvas()*(first.size*0.5)
	await mouse(surface,point,true)
	entries.append(row(102,2,9)); queue.present(entries)
	await mouse(surface,point,false)
	check(sent.size()==1 and sent[0]=={"kind":"native-cancel-action","actionId":0,"groupId":7,"actorId":42,"areaId":55,"generation":3},"Real click survives a queue update and routes original type/group through scoped Desktop command")
	check(queue.pending.has(100) and first.modulate.a==0.5 and queue.buttons.has(100),"Cancel dims immediately but does not locally remove an authoritative server action")
	first.pressed.emit(); check(sent.size()==1,"Repeated pending click does not send another cancellation")
	entries.push_front(row(103,36,10,true)); queue.present(entries)
	check(queue.buttons[100]==first and first.position==Vector2(46,3) and queue.pending.has(100),"Received special-prefix insertion repositions persistent ordinary widgets and preserves pending state")
	entries.erase(entries[1]); queue.present(entries)
	check(not queue.buttons.has(100) and not queue.pending.has(100) and queue.buttons[101]==second and second.position==Vector2(46,3),"Received deletion retires only that widget and promotes the surviving queue")
	first.pressed.emit(); check(sent.size()==1,"A removed action cannot route a stale pressed signal")
	queue.rejected(); second.pressed.emit(); check(sent.size()==2 and queue.pending.has(101),"Another action can be cancelled independently")
	queue.rejected(); check(queue.pending.is_empty() and second.modulate.a==1.0 and queue.buttons[101]==second,"Transport rejection restores the surviving widget without rebuilding it")
	entries=[row(101,0x10004,0x10008)]
	queue.present(entries); check(queue.buttons[101]==second,"Original WORD identity is stable across JSON integer representations")
	second.pressed.emit(); check(sent.size()==3 and sent[2].actionId==4 and sent[2].groupId==8,"Cancellation explicitly preserves original WORD wire widths")
	queue.reset(); queue.present([row(101,4,8)]); var replacement: Button=queue.buttons[101]
	second.pressed.emit(); check(sent.size()==3 and replacement!=second,"Reset prevents a stale control from cancelling a reused serial in a new session")
	var previous:=replacement; queue.present([row(101,4,99)]); replacement=queue.buttons[101]; previous.pressed.emit()
	check(replacement!=previous and sent.size()==3,"A changed wire identity retires an otherwise reused local widget serial")
	var many: Array=[]
	for index in 12: many.append(row(index))
	queue.present(many); check(queue.buttons.size()==12 and queue.buttons[11].position==Vector2(476,3),"All received queue widgets remain represented rather than silently truncating at ten")
	var image: TextureRect=queue.buttons[0].get_node("Icon"); var texture:=ImageTexture.create_from_image(Image.create(32,32,false,Image.FORMAT_RGBA8))
	art.deliver("queue_test",texture); check(image.texture==texture and image.flip_v,"Actual native raster delivery retains original bottom-left bitmap orientation")
	many[0].icon=""; queue.present(many); check(image.texture==null and not art.bindings.has(str(image.get_instance_id())+":texture"),"An explicitly blank updated icon clears the previous raster and binding")
	await mouse(surface,Vector2(44,20),true); await mouse(surface,Vector2(44,20),false)
	check(world_clicks==1,"Real world click in an action-queue gap reaches the underlying surface")
	many[1].icon="late_queue_icon"; queue.present(many)
	var retired: Button=queue.buttons[1]; var retired_icon: TextureRect=retired.get_node("Icon"); queue.close(); retired.pressed.emit(); queue.prepared(0,{"value":models.ctl_actionqueue,"error":""}); queue.present([row(5)])
	art.deliver("late_queue_icon",texture)
	check(queue.closed and queue.rows.is_empty() and queue.buttons.is_empty() and not queue.visible and sent.size()==3,"Close rejects stale buttons, metadata replies and future snapshots")
	check(retired_icon.texture==null and not art.bindings.has(str(retired_icon.get_instance_id())+":texture") and queue.painter.button_geometry.is_empty(),"Close removes borrowed raster/style listeners and painter controls; late raster completion cannot revive a retired icon")
	art.catalog=catalog
	var loading:=Queue.new(); ui_root.add_child(loading); loading.setup(desktop); loading.present([row(200)]); art.catalog=RasterCatalog.new()
	var deadline:=Time.get_ticks_msec()+5000
	while not loading.layout_ready and loading.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(loading.layout_ready and loading.failure.is_empty() and loading.jobs.is_empty() and loading.buttons.has(200),"Production native asset-service requests prepare the original queue asynchronously without a graphical viewport")
	loading.close(); loading.queue_free()
	desktop.closed=true; desktop.free(); queue.queue_free(); ui_root.queue_free(); surface.queue_free(); art.close(); art.queue_free(); catalog=null; await frames(3)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"scope":"Original action queue geometry, active metadata, native mouse/cancellation/lifecycle; graphical comparison and authoritative local server remain separate."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
