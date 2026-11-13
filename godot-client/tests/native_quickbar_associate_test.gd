extends "res://tests/native_quickbar_polymorph_test.gd"

func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	create_timer(30).timeout.connect(func():quit(3));root.size=Vector2i(1440,1000)
	var desktop:=Desktop.new();root.add_child(desktop);desktop.owner_ui=Ui.new();desktop.actor_id=99;desktop.area_id=7;desktop.generation=1
	desktop.rules.text=desktop.owner_ui.text;desktop.shortcut_rules.rules=desktop.rules;desktop.feat_rules.rules=desktop.rules;desktop.ability_rules.rules=desktop.rules;desktop.ability_rules.feats=desktop.feat_rules;desktop.spell_rules.rules=desktop.rules;desktop.spell_rules.abilities=desktop.ability_rules
	desktop.art=Art.new();desktop.add_child(desktop.art);desktop.radial=Radial.new();desktop.add_child(desktop.radial);desktop.radial.request.connect(desktop.input_request);desktop.shortcut_dialogs=Dialogs.new();desktop.add_child(desktop.shortcut_dialogs);desktop.target_prompt=Label.new();desktop.add_child(desktop.target_prompt)
	desktop.objects={99:{"id":99,"objectType":5,"companionId":100,"familiarId":101,"replicated":{"position":[1,2,3]}},100:{"id":100,"objectType":5,"replicated":{"name":{"text":"Actual associate"}}}}
	for index in 36:desktop.quick_bindings.append({"type":0})
	desktop.quick_bindings[0]={"type":39,"intParam":-19,"associateType":1,"associateId":100};desktop.quick_bindings[1]=desktop.quick_bindings[0].duplicate(true)
	var before: Dictionary=desktop.objects.duplicate(true);var bindings: Array=desktop.quick_bindings.duplicate(true)
	desktop.request.connect(func(message):sent.append(message.duplicate(true)))
	var bar:=Bar.new();root.add_child(bar);bar.setup();desktop.quickbar=bar;bar.assignment_requested.connect(desktop.shortcut_menu);bar.request.connect(desktop.input_request)
	var rows: Array=[]
	for binding in desktop.quick_bindings:rows.append(desktop.shortcut_row(binding))
	bar.receive({"kind":"quickbar-view","quickbarId":11,"rows":rows});await process_frame;await process_frame
	check(rows[0].label=="TLK 3731 : Actor" and rows[0].icon=="IR_INVENTORY" and rows[0].enabled,"Bound39 tooltip uses original command TLK/icon plus disclosed stored associate name")
	await click(bar.buttons[0].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(desktop.radial.active and desktop.radial_entries.size()==2 and desktop.radial_entries[3].label=="TLK 3731" and desktop.radial_entries[3].icon=="IR_INVENTORY" and desktop.radial_entries[4].action=="quickbar-clear","Physical39 wheel exposes plain original Use3/clear4, without a tooltip-name suffix in the radial caption")
	desktop.target={"type":6};await choose(desktop,3)
	check(sent.size()==1 and sent[-1].kind=="native-quickbar-activate" and sent[-1].index==0 and desktop.target.is_empty(),"Physical Use39 dispatches actual source slot to canonical protocol activation and retires targeting")
	await click(bar.buttons[1].get_global_rect().get_center());await key(KEY_F1)
	check(sent.size()==3 and sent[-2].index==1 and sent[-1].index==0,"Duplicate pointer input and actual F1 retain the originating slot identities")
	await key(KEY_F1,true);check(sent.size()==3,"Key echo cannot spam associate requests")
	for pair in [[-20,"IR_HAND_TRAP",1482],[-19,"IR_INVENTORY",3731],[-18,"IR_UNLOCK",1467],[-9,"IFE_NOFAMILIAR",1569],[-8,"IFE_NOFAMILIAR",1569]]:
		var binding:={"type":39,"intParam":int(pair[0])+65536,"associateType":2,"associateId":777};var value: Dictionary=desktop.shortcut_row(binding);var entries: Array=desktop.shortcut_rules.bound(binding,true,str(value.icon),str(value.label))
		check(value.label=="TLK "+str(pair[2]) and value.icon==pair[1] and entries[1].label==value.label,"Original command low SHORT selects source metadata without substituting current dynamic target into stored tooltip")
	var unknown:={"type":39,"intParam":123,"associateType":1,"associateId":100};var unknown_row:=desktop.shortcut_row(unknown)
	check(unknown_row.label.is_empty() and unknown_row.icon.is_empty() and unknown_row.enabled and desktop.shortcut_rules.bound(unknown,true,"","").size()==1,"Unknown command keeps unresolved metadata without an invented label or unavailable-state gate")
	for associate_type in [0,4,65535]:desktop.activate({"type":39,"intParam":-8,"associateType":associate_type,"associateId":100})
	check(sent.size()==3,"Invalid original associate types cannot silently route to the current familiar")
	desktop.activate({"type":39,"intParam":-9,"associateType":2,"associateId":999});desktop.activate({"type":39,"intParam":65528,"associateType":3,"associateId":999})
	check(sent.size()==5 and sent[-2].kind=="native-associate" and sent[-2].targetId==100 and sent[-2].command==-9 and sent[-1].targetId==101 and sent[-1].command==-8,"Unbound world actions preserve current companion/familiar resolution and signed command")
	desktop.activate({"type":39,"intParam":-19,"associateType":1,"associateId":999},1);check(sent.size()==5,"A changed binding cannot reuse a previous physical shortcut index")
	desktop.shortcut_menu(1,Vector2(650,300));var held:={"requestId":desktop.radial.request_id,"menuId":desktop.radial.menu_id,"slot":3};desktop.generation=2;desktop.radial_select(held)
	check(sent.size()==5 and not desktop.radial.active,"Old area/session context cannot dispatch held associate wheel input")
	desktop.generation=1;rows[0].enabled=false;bar.receive({"kind":"quickbar-view","quickbarId":12,"rows":rows});await process_frame;await key(KEY_F1)
	check(sent.size()==5,"Received disabled quickslot blocks physical associate hotkey activation")
	desktop.input_request({"kind":"quickbar-activate","quickbarId":11,"index":1});check(sent.size()==5,"Retired quickbar view cannot activate a current associate binding")
	var started:=Time.get_ticks_usec()
	for count in 1000:desktop.activate(desktop.quick_bindings[1],1)
	var elapsed:=Time.get_ticks_usec()-started
	check(elapsed<1000000,"One thousand current source39 dispatches avoid a pathological one-second CPU stall")
	check(desktop.objects==before and desktop.quick_bindings==bindings,"Associate controls never predict command outcomes, master/party changes or shortcut state")
	var timings: Array=desktop.shortcut_timings.duplicate(true);bar.free();desktop.close();desktop.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"dispatches":1000,"dispatch_elapsed_usec":elapsed,"root_timings":timings,"scope":"Actual native pointer/F1/wheel input and scope retirement; controlled text state. Original432 packing/1728 instruction cases and original-server associate result are separate gates; no pixel/GPU acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
