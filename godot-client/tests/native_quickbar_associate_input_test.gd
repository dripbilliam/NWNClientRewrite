extends "res://tests/native_quickbar_context_test.gd"
const Associates=preload("res://systems/native_quickbar_associate_commands.gd")
const Identity=preload("res://systems/native_data/player_identity.gd")
var desktop
var bar
var pool: Array=[]
var timings: Array=[]
func populate(count: int) -> void:
	desktop.objects={99:{"id":99,"objectType":5,"areaId":7,"clientKnownLifetime":1,"replicated":{"position":[1,2,3],"field908":0,"stats":{"classes":[{"id":8,"level":1}]}},"playerState":{"feats":[],"spellbooks":{}}}}
	pool=[]
	# Raw cards include a non-associate player before the henchmen. The
	# displayed portrait order is intentionally irrelevant to these indices.
	desktop.objects[100]={"id":100,"objectType":5,"areaId":7,"clientKnownLifetime":2,"replicated":{"field908":0}}
	var party: Array=[100,99]
	for index in count:
		var id:=200+index;pool.append(id);party.append(id)
		desktop.objects[id]={"id":id,"objectType":5,"areaId":7,"clientKnownLifetime":10+index,"replicated":{"field908":1,"master":99,"name":{"firstName":{"text":"Hench"},"lastName":{"text":str(index)}}}}
	desktop.state={"party":party,"partyListRevision":1,"gameMasterPermission":{"source":Identity.INITIAL_PERMISSION,"permission":0,"field114":null,"parameter":null}}
func commands() -> void:
	# Each authored scenario starts without an earlier wheel's pointer capture;
	# this is fixture isolation, not a claim about cancelling an open menu.
	desktop.retire_shortcut_context()
	var began:=Time.get_ticks_usec()
	await click(bar.buttons[0].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	await choose(desktop,5)
	timings.append({"operation":"commands-pointer-and-frames","elapsed_usec":Time.get_ticks_usec()-began,"associates":pool.size()})
func payload(slot: int) -> Dictionary:return desktop.radial.buttons[slot].payload.duplicate(true)
func drag(slot: int,index: int,retire: Callable=Callable()) -> void:
	var source: Vector2=desktop.radial.buttons[slot].get_global_rect().get_center();var destination: Vector2=bar.buttons[index].get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=source;motion.global_position=source;root.push_input(motion,true);await process_frame
	await mouse(source,MOUSE_BUTTON_LEFT,true)
	for point in [source+Vector2(20,0),destination]:
		var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;move.relative=point-source;move.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(move,true);await process_frame
	check(root.gui_is_dragging(),"Physical pointer motion starts the associate shortcut drag")
	if retire.is_valid():retire.call()
	await mouse(destination,MOUSE_BUTTON_LEFT,false)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	root.size=Vector2i(1440,1000);create_timer(30).timeout.connect(func():quit(3))
	desktop=Desktop.new();root.add_child(desktop);desktop.owner_ui=Ui.new();desktop.actor_id=99;desktop.area_id=7;desktop.generation=1
	desktop.rules.text=desktop.owner_ui.text;desktop.shortcut_rules.rules=desktop.rules;desktop.feat_rules.rules=desktop.rules;desktop.ability_rules.rules=desktop.rules;desktop.ability_rules.feats=desktop.feat_rules;desktop.spell_rules.rules=desktop.rules;desktop.spell_rules.abilities=desktop.ability_rules
	desktop.art=Art.new();desktop.add_child(desktop.art);desktop.radial=Radial.new();desktop.add_child(desktop.radial);desktop.radial.request.connect(desktop.input_request)
	desktop.shortcut_dialogs=Dialogs.new();desktop.add_child(desktop.shortcut_dialogs);desktop.target_prompt=Label.new();desktop.add_child(desktop.target_prompt)
	for index in 36:desktop.quick_bindings.append({"type":0})
	desktop.request.connect(func(message):sent.append(message))
	bar=Bar.new();root.add_child(bar);bar.setup();bar.assignment_requested.connect(desktop.shortcut_menu);bar.request.connect(desktop.input_request);bar.radial_valid=desktop.can_radial_shortcut;desktop.quickbar=bar
	var rows: Array=[]
	for binding in desktop.quick_bindings:rows.append(desktop.shortcut_row(binding))
	bar.receive({"kind":"quickbar-view","quickbarId":11,"rows":rows});await process_frame;await process_frame
	populate(1);await commands()
	check(desktop.radial_entries.size()==8 and desktop.radial_entries.has_all([0,1,2,3,4,5,6,7]),"One received henchman adds three source actions to the five original hotbar Commands sectors")
	for pair in [[1,-19],[0,-20],[7,-18]]:
		var binding: Dictionary=desktop.radial_entries[int(pair[0])].binding
		check(binding=={"type":39,"intParam":int(pair[1]),"associateType":1,"associateId":200},"Hotbar hench action retains exact original command/target: "+str(pair[1]))
	var before:=sent.size();await choose(desktop,1)
	check(sent.size()==before+1 and sent[-1].kind=="native-quickbar-assign" and sent[-1].index==0 and sent[-1].button=={"type":39,"intParam":-19,"associateType":1,"associateId":200},"Physical Inventory click assigns the exact type39 binding through the existing private command boundary")
	check(desktop.quick_bindings[0]=={"type":0},"Assignment never mutates the received shortcut layout locally")
	populate(3);await commands()
	check(desktop.radial_entries[0].menu.objectId==200 and desktop.radial_entries[1].menu.objectId==201 and desktop.radial_entries[7].menu.objectId==202,"Three associates preserve native named root positions0/1/7")
	await choose(desktop,1)
	check(desktop.radial_stack.size()==3 and desktop.radial_entries.size()==3 and desktop.radial_entries[7].binding.associateId==201,"Real named-branch click opens the selected henchman's three actions")
	before=sent.size();await choose(desktop,7)
	check(sent.size()==before+1 and sent[-1].button=={"type":39,"intParam":-18,"associateType":1,"associateId":201},"Nested Unlock assigns the selected raw-card member rather than displayed portrait index")
	populate(2);await commands();await choose(desktop,7)
	check(desktop.radial.active and desktop.radial_entries.is_empty(),"Exactly two associates preserve the original visible empty More branch")
	populate(11);await commands();await choose(desktop,7)
	check(desktop.radial_entries.size()==8 and desktop.radial_entries[0].menu.objectId==202 and desktop.radial_entries[6].menu.objectId==208 and desktop.radial_entries[7].menu.offset==9,"First More page preserves seven physical members and the original cursor+7")
	await choose(desktop,7);await choose(desktop,1);before=sent.size();await choose(desktop,0)
	check(sent.size()==before+1 and sent[-1].button=={"type":39,"intParam":-20,"associateType":1,"associateId":210},"Physical deep pagination resolves the final henchman's Trap command")
	populate(1);await commands();before=sent.size();await drag(7,5)
	check(sent.size()==before+1 and sent[-1].index==5 and sent[-1].button=={"type":39,"intParam":-18,"associateType":1,"associateId":200} and desktop.radial.active,"Actual viewport drag/drop assigns without activating or closing the originating wheel")
	# Retire at the exact drop boundary, after the GUI accepted drag data.
	populate(1);await commands();before=sent.size();await drag(7,5,func():desktop.objects[200].clientKnownLifetime+=100)
	check(sent.size()==before and not desktop.radial.active,"An ID reused during a physical drag cannot target a new entity at drop")
	for change in ["member-lifetime","actor-lifetime","removed","master","type","party-index","actor-id","generation","area","binding","permission"]:
		populate(3);desktop.actor_id=99;desktop.area_id=7;desktop.generation=1;desktop.quick_bindings[0]={"type":0};await commands();await choose(desktop,1)
		before=sent.size()
		match change:
			"member-lifetime":desktop.objects[201].clientKnownLifetime+=100
			"actor-lifetime":desktop.objects[99].clientKnownLifetime+=100
			"removed":desktop.objects[201].replicationRemoved=true
			"master":desktop.objects[201].replicated.master=100
			"type":desktop.objects[201].replicated.field908=2
			"party-index":desktop.state.party.reverse()
			"actor-id":desktop.actor_id=100
			"generation":desktop.generation+=1
			"area":desktop.area_id+=1
			"binding":desktop.quick_bindings[0]={"type":40}
			"permission":desktop.state.gameMasterPermission={}
		await choose(desktop,1)
		check(sent.size()==before and not desktop.radial.active,"Current leaf rejects stale "+change+" on actual pointer input")
	desktop.actor_id=99;desktop.area_id=7;desktop.generation=1;desktop.quick_bindings[0]={"type":0}
	for missing in ["permission","party","type","master","lifetime"]:
		populate(1)
		match missing:
			"permission":desktop.state.erase("gameMasterPermission")
			"party":desktop.state.erase("partyListRevision")
			"type":desktop.objects[200].replicated.erase("field908")
			"master":desktop.objects[200].replicated.erase("master")
			"lifetime":desktop.objects[200].erase("clientKnownLifetime")
		await commands()
		check(desktop.radial_entries.size()==5 if missing!="lifetime" else desktop.radial_entries[1].disabled,"Unknown "+missing+" is unavailable, never invented as a live henchman")
	populate(1);desktop.objects[200].areaId=8;desktop.objects[200].visualLoaded=false;await commands()
	check(desktop.radial_entries.size()==8 and not desktop.radial_entries[1].disabled,"Client-known party object does not need a loaded visual or matching area to expose native party commands")
	var detached: Dictionary=Associates.query(desktop);detached.associates[0].name.firstName.text="Changed"
	check(desktop.objects[200].replicated.name.firstName.text=="Hench","Projection does not expose mutable received identity dictionaries")
	check(desktop.ability_entries({"kind":"world-commands"}).size()==5,"World mode0 stays distinct from hotbar mode1 even with a known henchman")
	var began:=Time.get_ticks_usec()
	for index in 1000:Associates.entries(desktop,{"kind":"quickbar-commands"})
	var elapsed:=Time.get_ticks_usec()-began
	check(elapsed<1000000,"One thousand synchronous associate projections avoid a one-second pathological menu stall")
	bar.free();desktop.quickbar=null;desktop.close();desktop.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"timings":timings,"projection_iterations":1000,"projection_elapsed_usec":elapsed,"scope":"Actual Desktop/Radial/Quickbar mouse and drag/drop input, raw received party authored state, private exact binding outputs and stale lifetime boundaries. No server, original artwork pixels or GPU/FPS acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
