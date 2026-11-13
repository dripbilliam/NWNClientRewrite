extends SceneTree
# Actual Desktop/ServerRadial pointer + drag boundary; typed authored disclosures.
# No live server, predicted values, visual instances or injected game outcomes.
const Base=preload("res://tests/native_world_radial_input_test.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
const Wheel=preload("res://systems/server_radial.gd")
const Access=preload("res://systems/native_gui_panel_access.gd")
const Bar=preload("res://systems/server_quickbar.gd")
var checks:=0
var failures:Array=[]
var samples:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:call_deferred("run")
func click(wheel,slot:int)->void:
	var point:Vector2=wheel.buttons[slot].get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await process_frame
	for down in [true,false]:
		var input:=InputEventMouseButton.new();input.position=point;input.global_position=point;input.button_index=MOUSE_BUTTON_LEFT;input.pressed=down;input.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;root.push_input(input,true);await process_frame
func open(d,id:int=100)->void:
	var began:=Time.get_ticks_usec();d.open_radial({"id":id,"position":Vector3(1,3,-2),"origin":"world"},Vector2(600,400));samples.append(Time.get_ticks_usec()-began)
func roster()->Array:
	return [[7,{"playerId":7,"objectId":102,"isDM":false,"name":"Other player","peerD8":0,"peerC8":"","character":{"id":101,"firstName":{"text":"Other"},"lastName":{"text":"PC"},"portrait":0}}]]
func received(id:int,token:int)->Dictionary:
	return {"id":id,"objectType":5,"areaId":10,"clientKnownLifetime":token,"replicated":{"master":2130706432,"field8D4":1,"field8D6":0,"reaction":0,"stats":{"racialType":8,"field4E8":false}}}
func run()->void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	root.size=Vector2i(1280,900)
	var owner:=Base.Owner.new();root.add_child(owner)
	var d:=Desktop.new();var wheel:=Wheel.new();root.add_child(wheel);var access:=Access.new();root.add_child(access);var bar:=Bar.new();root.add_child(bar);bar.setup();bar.radial_valid=d.can_radial_shortcut;bar.request.connect(d.input_request)
	owner.desktop=d;owner.gui_panel_access=access;access.configure(owner);d.owner_ui=owner;d.radial=wheel;d.art=Base.Art.new();d.rules.text=owner.text;d.shortcut_rules.rules=d.rules;d.ability_rules.rules=d.rules;d.feat_rules.rules=d.rules;d.ability_rules.feats=d.feat_rules;d.spell_rules.rules=d.rules;d.spell_rules.abilities=d.ability_rules
	owner.text.tables.skills={"orderedRows":Array(range(28))};d.target_prompt=Label.new();root.add_child(d.target_prompt);d.actor_id=99;d.generation=1;d.area_id=10
	var view:=Base.View.new()
	for key in ["party","quickbar","sheet","book","journal","area_map","players","buffs","level_up","action_queue"]:d.set(key,view)
	d.quickbar=bar;var rows:Array=[]
	for index in 36:rows.append({"index":index,"label":"Empty","empty":true,"enabled":false,"uses":null})
	bar.receive({"kind":"quickbar-view","quickbarId":7,"rows":rows})
	var actor:=received(99,1);actor.replicated.field8D4=128;actor.playerState={"visibility":{}};actor.clientSkillAdmission={"version":1,"source":"native_received_skill_admission","mask":8193,"knownMask":4294967295,"playerUpdateSeen":true,"inventoryUpdateSeen":false,"override":0,"overrideSource":"received_game_master_permission_31_22"}
	var npc:=received(100,2);var pc:=received(101,3);var controlled_npc:=received(102,4)
	d.objects={99:actor,100:npc,101:pc,102:controlled_npc};d.state={"players":roster(),"playerRosterKnown":true,"gameMasterPermission":{"permission":0,"field114":null,"parameter":null,"source":"native_connection_start_16"}}
	var sent:Array=[];d.request.connect(func(message):sent.append(message));wheel.request.connect(d.input_request)
	open(d);await process_frame
	check(wheel.active and d.radial_entries.size()==8 and [0,1,2,3,4,5,6,7].all(func(slot):return d.radial_entries.has(slot)),"Actual normal NPC root has exact original sectors and received skill admissions")
	check(d.radial_entries[7].interaction=="conversation.start" and d.radial_entries[4].binding=={"type":3,"intParam":0} and d.radial_entries[5].binding=={"type":3,"intParam":13},"NPC Talk and exact skill bindings derive from source policy")
	check(sent.size()==1 and sent[0].panel=="context-attempt" and sent[0].targetId==100,"One canonical GUI context attempt precedes target menu")
	await click(wheel,2)
	check(sent[-1].kind=="interact" and sent[-1].action=="combat.attack" and sent[-1].targetId==100 and d.target.is_empty(),"Other-creature Attack is immediate on clicked target, unlike self targeting")
	open(d);await click(wheel,5)
	check(sent[-1].kind=="native-skill" and sent[-1].packedSkill==13 and sent[-1].targetId==100 and sent[-1].position==[0,0,0] and d.target.is_empty(),"Physical Pick Pocket sends original packed skill/target/zero XYZ directly")
	open(d);await click(wheel,4)
	check(sent[-1].kind=="native-skill" and sent[-1].packedSkill==0 and sent[-1].targetId==100,"Physical Animal Empathy uses exact active server skill ID")
	pc.replicated.field8D4=0;open(d,101)
	check(d.radial_entries.size()==2 and d.radial_entries.has(0) and d.radial_entries.has(1),"Selected PC with zero native flags has original two-sector root")
	pc.replicated.field8D4=1;open(d,101);await click(wheel,7)
	check(sent[-1].kind=="native-barter" and sent[-1].operation=="start" and sent[-1].targetId==101,"Known selected player uses Barter and existing native command")
	open(d,102)
	check(d.radial_entries[7].get("interaction")=="conversation.start","A controlled possession ID does not masquerade as selected player identity")
	d.state.playerRosterKnown=false;open(d)
	check(not wheel.active and d.world_radial_coverage.missing.has("selected-character-player-lookup"),"Initial/incomplete roster cannot invent a normal NPC")
	open(d,101);check(wheel.active and d.radial_entries[7].action=="barter","Explicit selected identity is usable before full-roster knowledge")
	d.state.playerRosterKnown=true;npc.replicated.erase("master");open(d)
	check(not wheel.active and d.world_radial_coverage.missing.has("clicked.replicated.master"),"Missing ownership is unavailable rather than an invented nonassociate")
	npc.replicated.master=2130706432;var permission:Dictionary=d.state.gameMasterPermission;d.state.erase("gameMasterPermission");open(d)
	check(not wheel.active and d.world_radial_coverage.missing.has("connection.permission"),"Uninitialized permission cannot choose a normal root")
	d.state.gameMasterPermission=permission;actor.erase("clientSkillAdmission");open(d)
	check(wheel.active and not d.radial_entries.has(4) and not d.radial_entries.has(5) and d.world_radial_coverage.missing.has("controlled.native-skill-admission.13"),"Unknown skill override/cache does not grant stale skill buttons")
	actor.clientSkillAdmission={"version":1,"source":"native_received_skill_admission","mask":8193,"knownMask":4294967295,"playerUpdateSeen":true,"inventoryUpdateSeen":false};open(d)
	check(d.radial_entries.has(4) and d.radial_entries.has(5),"Known true skill bits remain safe when unknown override cannot change admission")
	npc.replicated.stats={"race":8,"field4E8":false};open(d)
	check(d.radial_entries[4].disabled and d.world_radial_coverage.missing.has("clicked.replicated.stats.racialType"),"Race BYTE cannot stand in for original racialType WORD")
	npc.replicated.stats={"racialType":8,"field4E8":false};open(d)
	var stale:={"requestId":wheel.request_id,"menuId":wheel.menu_id,"slot":5};var before:=sent.size();npc.clientKnownLifetime=20;d.radial_select(stale)
	check(not wheel.active and sent.size()==before and d.world_context.is_empty(),"Reused target ID rejects old selection token and retires only that wheel")
	open(d);stale={"requestId":wheel.request_id,"menuId":wheel.menu_id,"slot":5};var old_request:=wheel.request_id;var scope:Dictionary=d.world_context.duplicate();actor.clientKnownLifetime=10
	check(not d.retire_current_radial(old_request-1) and d.world_context==scope,"Stale modal callback cannot clear a current private target scope")
	before=sent.size();d.input_request({"kind":"radial-shortcut","requestId":stale.requestId,"menuId":stale.menuId,"slot":5,"index":2})
	check(not wheel.active and sent.size()==before,"Direct stale drop intent is rejected after controlled lifetime replacement")
	open(d);var payload:Dictionary=wheel.buttons[5].payload.duplicate();npc.replicationRemoved=true
	check(not d.can_radial_shortcut(payload) and not wheel.active,"Drag admission rejects current target removal without a whole-world scan")
	npc.replicationRemoved=false;npc.clientKnownLifetime=21;open(d);stale={"requestId":wheel.request_id,"menuId":wheel.menu_id,"slot":7};before=sent.size()
	owner.generation=2;d.set_world(2,10,99,d.objects,d.state);d.radial_select(stale)
	check(not wheel.active and sent.size()==before and d.world_context.is_empty(),"Transition generation retires target scope before stale action can dispatch")
	# The real Quickbar reset clears its owned input Array; publish a fresh view,
	# as Gameplay would, rather than reusing that retired fixture Array header.
	rows=[]
	for index in 36:rows.append({"index":index,"label":"Empty","empty":true,"enabled":false,"uses":null})
	bar.receive({"kind":"quickbar-view","quickbarId":8,"rows":rows})
	# Physical valid drag follows the exact production validator and drop handler.
	open(d);var source:Vector2=wheel.buttons[5].get_global_rect().get_center();var destination:Vector2=bar.buttons[5].get_global_rect().get_center();var motion:=InputEventMouseMotion.new();motion.position=source;motion.global_position=source;root.push_input(motion,true);await process_frame
	var down:=InputEventMouseButton.new();down.position=source;down.global_position=source;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(down,true);await process_frame
	for point in [source+Vector2(20,0),destination]:
		motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;motion.relative=point-source;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true);await process_frame
	check(root.gui_is_dragging(),"Physical target skill motion starts a native radial drag")
	before=sent.size();var up:=InputEventMouseButton.new();up.position=destination;up.global_position=destination;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;root.push_input(up,true);await process_frame
	check(sent.size()==before+1 and sent[-1].kind=="native-quickbar-assign" and sent[-1].button=={"type":3,"intParam":13},"Physical target skill drop assigns exact binding and does not activate the skill")
	check(wheel.active and d.target.is_empty(),"Assignment retains target menu and never creates a spell/skill target cursor")
	npc.clientKnownLifetime=22;d.set_world(2,10,99,d.objects,d.state)
	check(not wheel.active and d.world_context.is_empty(),"Same-area D+A disclosure lifetime change retires the target wheel at publication")
	samples.sort();var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"openUsecMedian":samples[samples.size()/2],"openUsecP95":samples[int(samples.size()*0.95)],"openUsecMax":samples[-1],"scope":"Actual source Desktop/ServerRadial/Quickbar/canonical GUI context pointer and drag controls with typed authored current fields. No network, original-server outcome, original pixels or GPU acceptance."}
	owner.gui_panel_access=null;access.close();access.free();var prompt=d.target_prompt;d.closed=true;d.free();prompt.free();bar.free();wheel.free();owner.free();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();quit(0 if failures.is_empty() else 1)
