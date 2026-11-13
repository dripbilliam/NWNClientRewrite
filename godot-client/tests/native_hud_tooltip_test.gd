extends SceneTree
# Production gameplay UI, original resource workers and real viewport input.
# Snapshot data here is authored explicitly; localhost acceptance is separate.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Preferences=preload("res://systems/native_data/tooltip_preferences.gd")
var checks:=0
var failures: Array=[]
var surface: SubViewport
var shortcuts: Array=[]
var assignments: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func frames(count: int=2) -> void:
	for index in count: await process_frame
func wait_for(predicate: Callable,seconds: float=20) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if predicate.call(): return true
		await frames()
	return false
func motion(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new(); event.position=Vector2(Vector2i(point)); event.global_position=event.position; surface.push_input(event,true); await frames()
func click(control: Control,button: int=MOUSE_BUTTON_LEFT) -> void:
	var point:=control.get_global_rect().get_center(); await motion(point)
	for down in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=button; event.pressed=down; event.button_mask=(1<<(button-1)) if down else 0; surface.push_input(event,true); await frames()
func key(code: int,down: bool) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down; surface.push_input(event,true); await frames()
func hint(owner,control: Control) -> bool:
	await motion(Vector2(600,300)); await motion(control.get_global_rect().get_center())
	return await wait_for(func():return owner.target!=null and owner.target.get_ref()==control and owner.plate.visible and owner.plate.caption.get_parsed_text()==control.tooltip_text,3)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.trim_prefix("--report=")
		if argument.begins_with("--install="): install=argument.trim_prefix("--install=")
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	surface=SubViewport.new(); surface.size=Vector2i(1280,900); surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed original HUD source mounts read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,output+".cache",output+".layout")
	var ready: bool=await wait_for(func():return ui.tables_ready and ui.inventory.frame_skin.layout_ready)
	check(ready,"The actual production gameplay controller prepares native active tables and source inventory frame headlessly")
	if ready:
		var desktop=ui.desktop; var spell:=-1
		for id in ui.text.tables.spells.orderedRows.size():
			if desktop.rules.spell_level(id,10)==0: spell=id; break
		check(spell>=0,"A real installed wizard cantrip supplies the authored quickbar snapshot")
		var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"HUD input"},"position":[0,0,0],"hitPoints":{"current":10,"maximum":15},"stats":{"racialType":6,"classes":[{"id":10,"level":3}]}},"playerState":{"abilities":{"base":[10,12,10,16,11,8],"current":[10,12,10,16,11,8]},"combat":{"armorClass":12,"canLevelUp":false},"feats":[0],"effectIcons":{"25":0},"effectIconSerials":{"25":1},"actionQueue":[{"widgetSerial":7,"type":0,"group":12,"special":false}],"spellbooks":{"0":{"known":[spell],"memorized":{"0":[{"spell":spell,"ready":true,"metamagic":0}]}}}}}
		var bindings: Array=[]
		for index in 36: bindings.append({"type":2,"intParam":spell,"classIndex":0} if index==0 else {"type":0})
		var header:={"area":{"id":55},"ui":{"quickbar":bindings,"party":[{"id":42}]}}
		ui.set_world(1,55,42,[actor],{},header); ui.set_gameplay_visible(true)
		ready=await wait_for(func():return desktop.quickbar_frame.layout_ready and desktop.action_queue.layout_ready and desktop.buff_frame.layout_ready and desktop.party_frame.layout_ready and desktop.quickbar.buttons.has(0) and desktop.action_queue.buttons.has(7) and desktop.buffs.buttons.has(25))
		check(ready,"Actual quickbar/action/effect/party source controls prepare through their production owners")
		if ready:
			Preferences.apply(100000); var owner=ui.inventory.item_tooltips; var queue=desktop.action_queue; var bar=desktop.quickbar
			var quick: Button=bar.buttons[0]; var effect: Button=desktop.buffs.buttons[25]; var action: Button=queue.buttons[7]
			check(queue.painter.tooltips==owner and desktop.buff_frame.tooltips==owner and not queue.painter.owns_tooltips,"HUD consumers borrow the existing source tooltip scope without creating competing ownership")
			for pair in [[quick,"Quickbar"],[effect,"Effect"],[action,"Action queue"]]:
				check(pair[0].get_meta("native_tooltip_managed",false) and pair[0].get_tooltip(Vector2.ZERO).is_empty(),str(pair[1])+" suppresses its duplicate engine tooltip through the shared native registration")
			check(await hint(owner,quick),"Actual scripted quickbar-slot hover displays its source native tooltip")
			Preferences.apply(1000000); await motion(Vector2(600,300)); await motion(quick.get_global_rect().get_center()); await key(KEY_TAB,true)
			check(ui.key_bindings.highlighted and owner.plate.visible and owner.plate.caption.get_parsed_text()==quick.tooltip_text and owner.elapsed<1.0,"The actual production highlight key opens a scripted quickbar hint before its one-second normal delay")
			await create_timer(0.22).timeout; await key(KEY_TAB,false)
			check(not ui.key_bindings.highlighted and owner.router.policy.delay==1000000,"The actual HUD key owner restores the configured normal delay on hold release")
			Preferences.apply(100000); await frames()
			bar.request.connect(func(message):shortcuts.append(message.duplicate(true)))
			bar.assignment_requested.connect(func(index,point):assignments.append({"index":index,"point":point}))
			check(bool(bar.rows[0].enabled),"The authored active cantrip slot is enabled by real native rules")
			await click(quick)
			check(shortcuts.any(func(message):return message.kind=="quickbar-activate" and int(message.index)==0 and int(message.quickbarId)==bar.quickbar_id),"Actual left click retains the scripted slot's original quickbar activation request")
			desktop.cancel_target(); await click(quick,MOUSE_BUTTON_RIGHT)
			check(assignments.size()==1 and int(assignments[0].index)==0,"Actual right click retains the scripted slot's assignment/context request")
			var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.physical_keycode=KEY_ESCAPE; escape.pressed=true; surface.push_input(escape,true); await frames(); escape.pressed=false; surface.push_input(escape,true); await frames()
			check(await hint(owner,action),"Actual action-queue hover uses the same original source bubble")
			queue.close()
			check(not owner.closed and not owner.plate.visible and not action.has_meta("native_tooltip_managed"),"Closing the borrowed queue immediately retires its tooltip without closing the shared inventory/HUD scope")
			check(await hint(owner,effect),"Effect hover still works after another HUD consumer closes")
			Preferences.apply(1000000); await motion(Vector2(600,300)); await motion(effect.get_global_rect().get_center()); await key(KEY_TAB,true)
			check(owner.plate.visible and owner.plate.caption.get_parsed_text()==effect.tooltip_text and owner.elapsed<1.0,"The production highlight key also opens the borrowed native effect hint immediately")
			await create_timer(0.22).timeout; await key(KEY_TAB,false); Preferences.apply(100000); await frames()
			var effect_id:=effect.get_instance_id(); actor.playerState.effectIcons={}; actor.playerState.effectIconSerials={}; actor.playerState.actionQueue=[]
			ui.update_world(1,55,42,[actor],[],{},header)
			check(await wait_for(func():return not owner.plate.visible and not owner.controls.has(effect_id) and not desktop.buffs.buttons.has(25),3),"Queued received effect retirement removes the displayed hint and its weak registration")
			await frames(); check(await hint(owner,quick),"Quickbar source hints survive unrelated effect and queue retirement")
			var card=desktop.party.cards.values()[0]; var portrait: Button=card.get_node("Box/Portrait")
			check(portrait.get_meta("native_tooltip_managed",false) and portrait.get_tooltip(Vector2.ZERO).is_empty(),"Actual party portrait also participates in shared native tooltip handling")
			check(await hint(owner,portrait),"Actual party portrait hover displays its existing disclosed caption in the source bubble")
			await click(portrait); check(desktop.sheet.wanted,"Actual portrait click still opens its character controller")
			desktop.sheet.close_sheet(); ui.close(); await frames()
			check(owner.closed,"Closing the actual gameplay owner finally retires the shared tooltip scope")
	ui.close(); ui.queue_free(); surface.queue_free(); await frames(4)
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual production native HUD controllers/resources and viewport input over explicitly authored snapshot data; no original-server disclosure or rendered-pixel acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
