extends "res://tests/native_quickbar_context_test.gd"

func key(code: int,echo: bool=false) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;event.echo=echo
		root.push_input(event,true);await process_frame
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	create_timer(30).timeout.connect(func():quit(3));root.size=Vector2i(1440,1000)
	var desktop:=Desktop.new();root.add_child(desktop);desktop.owner_ui=Ui.new();desktop.actor_id=99;desktop.area_id=7;desktop.generation=1
	desktop.rules.text=desktop.owner_ui.text;desktop.shortcut_rules.rules=desktop.rules;desktop.feat_rules.rules=desktop.rules;desktop.ability_rules.rules=desktop.rules;desktop.ability_rules.feats=desktop.feat_rules;desktop.spell_rules.rules=desktop.rules;desktop.spell_rules.abilities=desktop.ability_rules
	desktop.art=Art.new();desktop.add_child(desktop.art);desktop.radial=Radial.new();desktop.add_child(desktop.radial);desktop.radial.request.connect(desktop.input_request);desktop.shortcut_dialogs=Dialogs.new();desktop.add_child(desktop.shortcut_dialogs);desktop.target_prompt=Label.new();desktop.add_child(desktop.target_prompt)
	desktop.objects={99:{"id":99,"objectType":5,"appearance":{"appearance":864},"replicated":{"position":[1,2,3]},"playerState":{"effects":[{"type":62,"id":"500"}]}}}
	for index in 36:desktop.quick_bindings.append({"type":0})
	desktop.quick_bindings[0]={"type":43,"intParam":123};desktop.quick_bindings[1]=desktop.quick_bindings[0].duplicate(true)
	var before: Dictionary=desktop.objects.duplicate(true);var bindings: Array=desktop.quick_bindings.duplicate(true)
	desktop.request.connect(func(message):sent.append(message.duplicate(true)))
	var bar:=Bar.new();root.add_child(bar);bar.setup();desktop.quickbar=bar;bar.assignment_requested.connect(desktop.shortcut_menu);bar.request.connect(desktop.input_request)
	var rows: Array=[]
	for binding in desktop.quick_bindings:rows.append(desktop.shortcut_row(binding))
	bar.receive({"kind":"quickbar-view","quickbarId":11,"rows":rows});await process_frame;await process_frame
	check(rows[0].label=="TLK 8272" and rows[0].icon=="IR_SKILLSELF" and rows[0].enabled,"Received43 uses the original fixed Cancel Polymorph label/icon without a fabricated effect gate")
	await click(bar.buttons[0].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(desktop.radial.active and desktop.radial_entries.size()==2 and desktop.radial_entries[3].label=="TLK 8272" and desktop.radial_entries[3].icon=="IR_SKILLSELF" and desktop.radial_entries[4].action=="quickbar-clear","Physical43 right-click opens source Use3/Clear4 instead of assignment or Rest")
	desktop.target={"type":6};await choose(desktop,3)
	check(sent.size()==1 and sent[-1].kind=="native-quickbar-activate" and sent[-1].index==0 and desktop.target.is_empty() and not desktop.radial.active,"Physical Cancel Polymorph Use immediately dispatches exact originating index and retires targeting")
	await click(bar.buttons[1].get_global_rect().get_center())
	check(sent.size()==2 and sent[-1].index==1,"Physical duplicate shortcut click keeps the actual second slot identity")
	await key(KEY_F1)
	check(sent.size()==3 and sent[-1].index==0,"Actual F1 input activates the original bound43 slot")
	await key(KEY_F1,true);check(sent.size()==3,"Repeated key echo cannot spam cancellation")
	rows[0].enabled=false;bar.receive({"kind":"quickbar-view","quickbarId":12,"rows":rows});await process_frame;await key(KEY_F1)
	check(sent.size()==3,"Native disabled shortcut state prevents physical key activation")
	desktop.input_request({"kind":"quickbar-activate","quickbarId":11,"index":1});check(sent.size()==3,"Retired quickbar view input cannot activate against a new view")
	desktop.activate({"type":43,"intParam":999},1);check(sent.size()==3,"Changed binding cannot reuse an old physical slot admission")
	desktop.shortcut_menu(1,Vector2(650,300));var held:={"requestId":desktop.radial.request_id,"menuId":desktop.radial.menu_id,"slot":3};desktop.generation=2;desktop.radial_select(held)
	check(sent.size()==3 and not desktop.radial.active,"Old-session wheel input is retired before dispatch")
	desktop.generation=1;desktop.objects[99].erase("playerState");desktop.shortcut_menu(1,Vector2(650,300));await choose(desktop,3)
	check(sent.size()==4 and sent[-1].index==1,"Missing undisclosed server effect metadata does not invent an unavailable-state gate")
	desktop.objects=before.duplicate(true)
	var started:=Time.get_ticks_usec()
	for count in 1000:desktop.activate(desktop.quick_bindings[1],1)
	var elapsed:=Time.get_ticks_usec()-started
	check(elapsed<1000000,"One thousand current-scope native43 dispatches avoid a one-second pathological CPU stall")
	check(desktop.objects==before and desktop.quick_bindings==bindings,"Native controls never predict shape restoration, effect removal or layout changes")
	var timings: Array=desktop.shortcut_timings.duplicate(true);bar.free();desktop.close();desktop.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"requests":sent.slice(0,4),"dispatches":1000,"dispatch_elapsed_usec":elapsed,"root_timings":timings,"scope":"Actual Godot quickbar pointer/F1/wheel/current-binding input; controlled actor state and TLK text fixture. Original256 instruction cases and original-server shape/reversion are separate proofs; no original pixels/GPU acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
