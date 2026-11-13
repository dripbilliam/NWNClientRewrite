extends SceneTree
# Actual Desktop/radial/sheet controls with separately captured original NPC
# statistics. Scope IDs/tokens/text are authored; no server/pixel claim here.
const Base=preload("res://tests/native_world_radial_input_test.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
const Wheel=preload("res://systems/server_radial.gd")
const Access=preload("res://systems/native_gui_panel_access.gd")
const Sheet=preload("res://systems/server_character_sheet.gd")
class Text extends Base.Text:
	var prefix:=""
	func raw(value:Variant)->String:return prefix+super.raw(value)
	func rich(value:Variant,_id:int)->Dictionary:return preload("res://systems/native_data/rich_text.gd").parse(raw(value))
class Owner extends Base.Owner:
	var resources_ready:=true
	func panel_ready(_name:String)->bool:return resources_ready
class Art extends Base.Art:
	var portraits:Array=[]
	func bind_portrait(_node,resource:String)->void:portraits.append(resource)
class Party extends Base.View:
	var rows:Array=[{"portraitKey":"playerportrait_"}]
class View extends Base.View:
	var opens:=0
	func open()->void:opens+=1
var checks:=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:call_deferred("run")
func click_point(point:Vector2)->void:
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;root.push_input(event,true);await process_frame
func choose(wheel,slot:int)->void:
	await click_point(wheel.buttons[slot].get_global_rect().get_center())
func control(node:Control)->void:
	await click_point(node.get_global_transform_with_canvas()*(node.size*0.5))
func open(d,origin:String="world")->void:
	d.open_radial({"id":100,"position":Vector3(1,3,-2),"origin":origin},Vector2(1000,300))
func header()->Dictionary:
	return {"players":[],"playerRosterKnown":false,"gameMasterPermission":{"source":"native_connection_start_16","permission":0,"field114":null,"parameter":null}}
func run()->void:
	var output:="";var data_path:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
		if argument.begins_with("--data="):data_path=argument.trim_prefix("--data=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(data_path))
	check(data.get("success")==true and data.get("checks")==14 and data.pages.size()==3,"captured actual original-server NPC data prerequisite14")
	root.size=Vector2i(1280,900)
	var owner:=Owner.new();owner.text=Text.new();root.add_child(owner)
	var d:=Desktop.new();var wheel:=Wheel.new();root.add_child(wheel);var access:=Access.new();root.add_child(access);var sheet:=Sheet.new();root.add_child(sheet);sheet.setup(output+".layout.cfg");sheet.request.connect(d.input_request)
	owner.desktop=d;owner.gui_panel_access=access;access.configure(owner);d.owner_ui=owner;d.radial=wheel;d.sheet=sheet;d.art=Art.new();d.rules.text=owner.text;d.shortcut_rules.rules=d.rules;d.ability_rules.rules=d.rules;d.feat_rules.rules=d.rules;d.ability_rules.feats=d.feat_rules;d.spell_rules.rules=d.rules;d.spell_rules.abilities=d.ability_rules
	d.target_prompt=Label.new();root.add_child(d.target_prompt);d.actor_id=99;d.generation=1;d.area_id=10;wheel.request.connect(d.input_request);sheet.rendered.connect(d.bind_sheet_art)
	var view:=View.new()
	for key in ["quickbar","book","journal","area_map","players","buffs","level_up","action_queue"]:d.set(key,view)
	d.party=Party.new()
	var skills:Array=[]
	for index in 28:skills.append({"Name":str(3000+index),"Description":str(4000+index),"Icon":"isk_test","KeyAbility":"CHA","Untrained":"1","AllClassesCanUse":"1"})
	var feats:Array=[]
	for index in 46:feats.append({})
	feats[45]={"FEAT":"45045","DESCRIPTION":"55045","ICON":"ife_test","SUCCESSOR":"0"}
	owner.text.tables={"skills":{"orderedRows":skills},"feat":{"orderedRows":feats}}
	var actor:={"id":99,"objectType":5,"areaId":10,"clientKnownLifetime":1,"replicated":{"field8D4":128,"field8D6":0,"field908":0},"playerState":{"playerFlags":0,"combat":{"canLevelUp":true,"armorClass":99}},"inventoryStats":{"fields70":[30,30,30,30,30,30],"field94":12345}}
	var npc:={"id":100,"objectType":5,"areaId":10,"clientKnownLifetime":2,"replicated":{"master":99,"field908":1,"field8D6":0,"field8D4":1,"stats":{}},"inventoryStats":{}}
	d.objects={99:actor,100:npc};d.state=header()
	var sent:Array=[];d.request.connect(func(message):sent.append(message))
	open(d);await process_frame
	check(wheel.active and d.radial_entries.size()==8 and d.radial_entries[0].command==-4 and d.radial_entries[5].command==-7,"Actual owned root has native8 sectors/direct associate commands")
	check(sent.size()==1 and sent[0].panel=="context-attempt","World owner still emits one canonical GUI26 context intent")
	await choose(wheel,0)
	check(sent[-1].kind=="native-associate" and sent[-1].command==-4 and sent[-1].targetId==100 and not sent.any(func(value):return value.kind=="native-quickchat"),"Physical HealMe sends selected associate command, not party broadcast")
	var before:=sent.size();open(d,"portrait");await process_frame
	check(wheel.active and sent.size()==before,"Owned portrait opens its native hierarchy without world callback")
	await choose(wheel,7)
	check(d.radial_entries.size()==8 and d.radial_entries[0].action=="associate-record" and d.radial_entries[2].command==-19 and not d.radial_entries[3].canDrag,"Associate Actions physical branch has target Record/Inventory/Kick sectors")
	await choose(wheel,0)
	check(sheet.wanted and d.current_sheet_target()==100 and sent[-1].panel=="character" and sent[-1].targetId==100 and sent[-1].recordActorLifetime==1 and sent[-1].recordTargetLifetime==2,"Physical associate Examine opens exact displayed target with scalar disclosure tokens")
	check(sheet.state.model.identity.contains(":100:") and sheet.state.model.abilities.all(func(value):return value.score==null) and sheet.state.model.armorClass==null and sheet.state.model.experience==null and not sheet.level_button.visible,"Unknown NPC values do not borrow actor scores/AC/progression/LevelUp")
	check(d.art.portraits.is_empty(),"Unknown target portrait never falls back to player's party portrait")
	npc.inventoryStats=data.pages[0].receivedView.duplicate(true);d.refresh_sheet();await process_frame
	check(sheet.state.model.abilities.map(func(value):return value.score)==[12,12,12,10,10,10],"Record renders the six actual received NPC ability values")
	check(sheet.state.model.armorClass==null and npc.inventoryStats.field8c==11,"Received baseAC retained separately; unproved NPC mode adjustment stays explicit unknown")
	owner.resources_ready=false;var count:=sent.size();var old_page:=sheet.page
	check(d.open_character_record(100) and sheet.page==old_page and sent.size()==count,"Already-open same target stays idempotent/page-preserving during transient resource readiness")
	access.policy.disabled={8:{100:"received"}};count=sent.size()
	check(not d.open_character_record(100) and sent.size()==count+1 and sent[-1].panel=="blocked-attempt" and sent[-1].targetId==100 and sent[-1].recordTargetLifetime==2,"Canonical target8 gate still emits GUI14 even alreadywanted/readinessfalse")
	access.policy.disabled.clear();owner.resources_ready=true
	npc.inventoryStats=data.pages[1].receivedView.duplicate(true)
	await control(sheet.tabs[1]);await process_frame
	check(sheet.page==1 and sent[-1].targetId==100 and sent[-1].page==1 and not sheet.entry_data.is_empty(),"Physical Skills tab subscribes to NPC page1 and uses actual disclosed rows")
	var first_id:int=sheet.entry_data.keys()[0];var first:Dictionary=sheet.entry_data[first_id]
	check(not first.canDrag and not sheet.can_drag({"viewId":sheet.view_id,"entryId":first_id}),"Nonself row dragging is suppressed at real sheet boundary")
	await control(sheet.entry_nodes[first_id]);await process_frame
	check(sent[-1].panel=="skill" and sent[-1].targetId==100 and sent[-1].recordActorLifetime==1 and sent[-1].skillId==int(first.id),"Physical skill detail uses displayed NPC and exact current row/tokens")
	var old_description:=JSON.stringify(sheet.entry_data[first_id].description);owner.text.prefix="Updated ";owner.text.revision+=1
	await control(sheet.entry_nodes[first_id]);await process_frame
	check(JSON.stringify(sheet.entry_data[first_id].description)!=old_description and sent[-1].panel=="skill" and sent[-1].targetId==100,"Repeat NPC skill click resolves fresh description and repeats correct GUI3 target")
	npc.inventoryStats=data.pages[2].receivedView.duplicate(true)
	await control(sheet.tabs[2]);await process_frame
	check(sheet.page==2 and sheet.entry_data.size()==1 and sheet.entry_data.values()[0].id==45,"Physical Feats tab uses actual NPC primary/bonus lists")
	await control(sheet.entry_nodes[sheet.entry_data.keys()[0]]);await process_frame
	check(sent[-1].panel=="feat" and sent[-1].featId==45 and sent[-1].targetId==100 and sent[-1].recordTargetLifetime==2,"Physical NPC feat detail targets exact current displayed record")
	await control(sheet.close_button);await process_frame
	check(not sheet.wanted and sent[-1].panel=="character" and sent[-1].open==false and sent[-1].targetId==100 and sent[-1].recordTargetLifetime==2 and d.sheet_context.is_empty(),"Physical X captures foreign close afterwantedfalse before retiring its lease")
	check(d.current_sheet_target()==null,"Closed sheet exposes no active displayed target")
	check(d.open_character_record(100),"Target Record can reopen after its exact close")
	owner.resources_ready=false;check(not d.force_self_character_record() and d.current_sheet_target()==100,"Forced self retarget waits resources instead of consuming foreign owner")
	owner.resources_ready=true;check(d.force_self_character_record() and d.current_sheet_target()==99 and sheet.page==0 and not sent[-1].has("recordTargetLifetime") and sent[-1].targetId==99,"Forced8 retargets foreign wanted sheet to controlled using self defaults")
	owner.resources_ready=false;count=sent.size();check(d.force_self_character_record() and sent.size()==count,"Alreadywanted self forced8 idempotent even readinessfalse")
	owner.resources_ready=true;sheet.close_sheet();check(d.open_character_record(100),"Foreign lease restored for publication retirement cases")
	await control(sheet.tabs[1]);await process_frame
	var stale:={"kind":"sheet-select","viewId":sheet.view_id,"page":1,"entryId":first_id};npc.clientKnownLifetime=3;count=sent.size();d.inspect_sheet_entry(stale)
	check(not sheet.wanted and d.current_sheet_target()==null and sent.size()==count,"Target ID reuse rejects stale row inspection with no actor fallback")
	for mutation in ["master","type","permission","control","area","removed"]:
		npc.replicationRemoved=false;npc.replicated.master=99;npc.replicated.field908=1;d.state=header();d.actor_id=99;d.area_id=10;owner.controlled_id=99;owner.area_id=10
		check(d.open_character_record(100),"Open target before "+mutation+" retirement")
		match mutation:
			"master":npc.replicated.master=101
			"type":npc.replicated.field908=5
			"permission":d.state.erase("gameMasterPermission")
			"control":d.actor_id=101
			"area":d.area_id=11
			"removed":npc.replicationRemoved=true
		count=sent.size();check(not d.sheet_scope_valid() and d.current_sheet_target()==null,"Current source "+mutation+" loss cannot resolve prior displayed lease")
		d.input_request({"kind":"sheet-page","page":1,"viewId":sheet.view_id})
		check(not sheet.wanted and sent.size()==count and d.sheet_context.is_empty(),"Stale "+mutation+" page cannot subscribe to actor or reused target")
	npc.replicationRemoved=false;npc.replicated.master=99;npc.replicated.field908=1;d.state=header();d.actor_id=99;d.area_id=10;owner.controlled_id=99;owner.area_id=10
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"requests":sent,"scope":"Actual Desktop/ServerRadial/ServerCharacterSheet viewport pointer, fresh detail resolver, canonical access adapter and disclosure lifetimes; original-server NPC14 scalar rows reused with authored IDs/text/tokens. No installed frame pixels or composed server/UI acceptance."}
	owner.gui_panel_access=null;access.close();access.free();var prompt=d.target_prompt;d.closed=true;d.free();prompt.free();sheet.free();wheel.free();owner.free();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
