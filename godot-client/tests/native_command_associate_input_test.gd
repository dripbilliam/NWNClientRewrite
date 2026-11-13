extends "res://tests/native_quickbar_context_test.gd"
const StagedDesktop=preload("res://tests/staged_command_associate_desktop.gd")
func enter_commands(desktop,index: int=0) -> void:
	await click(desktop.quickbar.buttons[index].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	await choose(desktop,5)
func publish(desktop,bar,id: int) -> void:
	var rows: Array=[]
	for binding in desktop.quick_bindings:rows.append(desktop.shortcut_row(binding))
	bar.receive({"kind":"quickbar-view","quickbarId":id,"rows":rows})
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	create_timer(30).timeout.connect(func():quit(3));root.size=Vector2i(1440,1000)
	var desktop:=StagedDesktop.new();root.add_child(desktop);desktop.owner_ui=Ui.new();desktop.actor_id=99;desktop.area_id=7;desktop.generation=1
	desktop.rules.text=desktop.owner_ui.text;desktop.shortcut_rules.rules=desktop.rules;desktop.feat_rules.rules=desktop.rules;desktop.ability_rules.rules=desktop.rules;desktop.ability_rules.feats=desktop.feat_rules;desktop.spell_rules.rules=desktop.rules;desktop.spell_rules.abilities=desktop.ability_rules
	desktop.art=Art.new();desktop.add_child(desktop.art);desktop.radial=Radial.new();desktop.add_child(desktop.radial);desktop.radial.request.connect(desktop.input_request);desktop.shortcut_dialogs=Dialogs.new();desktop.add_child(desktop.shortcut_dialogs);desktop.target_prompt=Label.new();desktop.add_child(desktop.target_prompt)
	desktop.objects={99:{"id":99,"objectType":5,"clientKnownLifetime":1,"replicated":{"position":[1,2,3]}}}
	desktop.command_party=[{"id":777}];desktop.command_revision=1
	desktop.objects[777]={"id":777,"objectType":5,"clientKnownLifetime":2,"replicated":{"field908":2,"master":99}}
	for id in [100,101]:desktop.command_party.append({"id":id});desktop.objects[id]={"id":id,"objectType":5,"clientKnownLifetime":id,"replicated":{"field908":1,"master":99,"name":{"text":"Associate "+str(id)}}}
	for index in 36:desktop.quick_bindings.append({"type":0})
	desktop.request.connect(func(message):sent.append(message.duplicate(true)))
	var bar:=Bar.new();root.add_child(bar);bar.setup();desktop.quickbar=bar;bar.assignment_requested.connect(desktop.shortcut_menu);bar.request.connect(desktop.input_request)
	publish(desktop,bar,1);await process_frame;await process_frame
	await enter_commands(desktop)
	check(desktop.radial_entries.size()==8 and desktop.radial_entries[0].has("children") and desktop.radial_entries[1].has("children") and desktop.radial_entries[7].children.is_empty(),"Physical empty-slot Commands shows original two names and empty More")
	await choose(desktop,0);check(desktop.radial_entries.size()==3 and desktop.radial_entries[1].binding.associateId==100,"Physical named branch resolves raw party index1, not filtered ordinal0")
	await choose(desktop,1)
	check(sent.size()==1 and sent[-1].kind=="native-quickbar-assign" and int(sent[-1].index)==0 and sent[-1].button=={"type":39,"intParam":-19,"associateType":1,"associateId":100},"Actual Inventory click assigns exact bound39 without issuing the command")
	check(not desktop.radial.active and desktop.target.is_empty(),"Assignment closes only originating wheel without target prediction")
	desktop.quick_bindings[0]=sent[-1].button.duplicate(true);publish(desktop,bar,2);await process_frame
	await click(bar.buttons[0].get_global_rect().get_center())
	check(sent.size()==2 and sent[-1].kind=="native-quickbar-activate" and int(sent[-1].index)==0,"Actual bound shortcut activation carries original physical index")
	await enter_commands(desktop,1);var before:=sent.size();desktop.command_revision=2;await choose(desktop,0)
	check(sent.size()==before and not desktop.radial.active,"Changed party receipt revision retires stale branch before assignment")
	await enter_commands(desktop,1);await choose(desktop,0);desktop.objects[100].clientKnownLifetime=999;await choose(desktop,1)
	check(sent.size()==before and not desktop.radial.active,"Canonical target ID reuse retires old native leaf")
	desktop.objects[100].clientKnownLifetime=100
	await enter_commands(desktop,1);await choose(desktop,0);desktop.objects[100].replicated.master=777;await choose(desktop,1)
	check(sent.size()==before and not desktop.radial.active,"Current master loss blocks captured assignment")
	desktop.objects[100].replicated.master=99
	await enter_commands(desktop,1);desktop.objects[99].clientKnownLifetime=2;await choose(desktop,0)
	check(sent.size()==before and not desktop.radial.active,"Controlled actor disclosure replacement retires the context")
	desktop.objects[99].clientKnownLifetime=1
	await enter_commands(desktop,1);var stale:={"requestId":desktop.radial.request_id,"menuId":desktop.radial.menu_id,"slot":0};desktop.retire_shortcut_context();await enter_commands(desktop,1);desktop.radial_select(stale)
	check(desktop.radial.active and sent.size()==before,"Old request/menu callback cannot consume replacement wheel")
	desktop.retire_shortcut_context();desktop.command_party=[{"id":777}]
	for id in range(100,111):desktop.command_party.append({"id":id});desktop.objects[id]={"id":id,"objectType":5,"clientKnownLifetime":id,"replicated":{"field908":1,"master":99,"name":{"text":"Associate "+str(id)}}}
	desktop.command_revision=3;await enter_commands(desktop,1);await choose(desktop,7)
	check(desktop.radial_entries.size()==8 and desktop.radial_entries[7].has("children") and desktop.radial_entries[6].low32==9,"More page keeps seven physical raw-index branches before continuation")
	await choose(desktop,7);await choose(desktop,1);await choose(desktop,7)
	check(sent.size()==before+1 and int(sent[-1].index)==1 and sent[-1].button=={"type":39,"intParam":-18,"associateType":1,"associateId":110},"Actual nested More→name→Unlock retains signed command and final canonical target")
	desktop.quick_bindings[1]=sent[-1].button.duplicate(true);publish(desktop,bar,3);await process_frame;await click(bar.buttons[1].get_global_rect().get_center())
	check(sent[-1].kind=="native-quickbar-activate" and int(sent[-1].index)==1,"Actual assigned Unlock shortcut dispatches originating slot1")
	check(desktop.ability_entries({"kind":"world-commands"}).size()==5,"Normal world Commands stays five rows despite eleven owned associates")
	desktop.command_party=[{"id":777},{"id":100}];desktop.command_revision=4;await enter_commands(desktop,2);await choose(desktop,0)
	check(sent[-1].kind=="native-quickbar-assign" and sent[-1].button=={"type":39,"intParam":-20,"associateType":1,"associateId":100},"Single-associate Disarm sector0 assigns signed command without named submenu")
	desktop.quick_bindings[2]=sent[-1].button.duplicate(true);publish(desktop,bar,4);await process_frame;await click(bar.buttons[2].get_global_rect().get_center())
	check(sent[-1].kind=="native-quickbar-activate" and int(sent[-1].index)==2,"Actual assigned Disarm shortcut dispatches originating slot2")
	desktop.objects[100].replicated.erase("field908");await enter_commands(desktop,3)
	check(desktop.radial_entries.size()==5,"Undisclosed canonical associate type leaves extras unavailable")
	desktop.retire_shortcut_context();var requests:=sent.duplicate(true);bar.free();desktop.close();desktop.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"requests":requests,"scope":"STAGED test-only Desktop subclass with actual installed ServerRadial/Quickbar pointer input and current production assignment/use dispatch. Canonical authored received scalar metadata; no imported production mutation, network/server outcome or graphical pixels."},"  "));file.close();quit(0 if failures.is_empty() else 1)
