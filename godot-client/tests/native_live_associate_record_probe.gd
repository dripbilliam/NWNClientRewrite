extends "res://tests/native_live_world_radial_probe.gd"
# Composed owned original-server proof. No received object/stat/token mutation.
var target_id:=-1
var gui_count:=0
var source_actor:=-1
var source_generation:=-1
var source_actor_lifetime: Variant
var source_target_lifetime: Variant
func same_scope() -> bool:
	return desktop.actor_id==source_actor and desktop.generation==source_generation and desktop.world_member_lifetime(source_actor)==source_actor_lifetime and desktop.world_member_lifetime(target_id)==source_target_lifetime
func row_id(id:int) -> int:
	for key in desktop.sheet.entry_data:
		if int(desktop.sheet.entry_data[key].id)==id:return int(key)
	return -1
func received_page_zero_ready() -> bool:
	var raw:Variant=desktop.objects.get(target_id,{}).get("inventoryStats",{}).get("fields70")
	var rows:Variant=desktop.sheet.state.get("model",{}).get("abilities")
	if not raw is Array or raw.size()!=6 or not rows is Array or rows.size()!=6:return false
	for index in 6:
		if not (raw[index] is int or raw[index] is float) or raw[index]<0 or raw[index]>255 or int(raw[index])!=raw[index] or not rows[index] is Dictionary or rows[index].get("score")!=raw[index]:return false
	return true
func source_click(control:Control) -> bool:
	if not probe.check(is_instance_valid(control) and control.is_visible_in_tree(),"Actual installed target Record control is visible"):return false
	await click(control.get_global_rect().get_center());return true
func page(index:int) -> bool:
	if not await source_click(desktop.sheet.tabs[index]):return false
	return await probe.wait_for(func():return desktop.sheet.wanted and desktop.sheet.page==index and desktop.current_sheet_target()==target_id and (index==0 or not desktop.sheet.entry_nodes.is_empty()),"Installed target Record page "+str(index)+" uses current received target data")
func inspect_row(kind:String,id:int,customized:bool) -> bool:
	var sheet=desktop.sheet;var entry:=row_id(id)
	if not probe.check(entry>=0 and sheet.entry_nodes.has(entry),"Original server supplies the requested "+kind+" row "+str(id)):return false
	var node:Control=sheet.entry_nodes[entry]
	sheet.active_scrolls.entries.ensure_control_visible(node);await probe.get_tree().process_frame
	var before:int=probe.ui.chat.sequence;gui_count+=1
	var started:=Time.get_ticks_usec()
	if not await source_click(node):return false
	var returned:bool=await probe.wait_for(func():
		var values:Array=probe.ui.chat.rows.filter(func(row):return int(row.get("chat_sequence",0))>before).map(func(row):return str(row.get("text","")))
		return values.has("NATIVE_RECORD_COUNT:"+str(gui_count)) and values.has("NATIVE_RECORD_CUSTOMIZED:"+("1" if customized else "0")) and values.has("NATIVE_RECORD_TARGET_NPC:1") and values.has("NATIVE_RECORD_TARGET_PC:0"),"Physical NPC "+kind+" row reaches original target GUI callback "+str(gui_count))
	if not returned:return false
	if customized:
		var event:=3 if kind=="skill" else 4;var token:=9011 if kind=="skill" else 9012
		if not await probe.wait_for(func():return probe.ui.text.custom_tokens.get(token)=="Owned Record GUI"+str(event)+" token "+str(gui_count),"Original server returns selective "+kind+" custom token "+str(gui_count)):return false
	probe.check(same_scope() and desktop.current_sheet_target()==target_id and sheet.entry_data[entry].canDrag==false,"Target detail retains received ownership and suppresses nonself drag",{"kind":kind,"rowId":id,"callback":gui_count,"elapsedUs":Time.get_ticks_usec()-started,"selection":sheet.selection_timings.duplicate(true),"displayed":sheet.description.get_parsed_text()})
	return true
func run(owner)->void:
	probe=owner;desktop=probe.desktop
	if not probe.check(DisplayServer.get_name()=="headless","Associate Record acceptance uses the owned headless original-server fixture"):return
	for id in desktop.objects:
		if desktop.objects[id].get("objectType")==5 and probe.ui.text.name(null,int(id))=="Native Speaker":target_id=int(id);break
	if not probe.check(target_id>=0 and target_id!=desktop.actor_id,"Original server discloses a separate current NPC"):return
	source_actor=desktop.actor_id;source_generation=desktop.generation;source_actor_lifetime=desktop.world_member_lifetime(source_actor);source_target_lifetime=desktop.world_member_lifetime(target_id)
	probe.ui.chat.submit("-native-party-add")
	if not await probe.wait_for(func():return desktop.objects.get(target_id,{}).get("replicated",{}).get("master")==source_actor and desktop.objects[target_id].replicated.get("field908")==1,"Original AddHenchman establishes exact NPC master and associate type"):return
	if not probe.check(same_scope() and source_actor_lifetime!=null and source_target_lifetime!=null,"Authoritative owned associate retains its source Record target",{"targetId":target_id,"actorId":source_actor,"actorLifetime":source_actor_lifetime,"targetLifetime":source_target_lifetime}):return
	if not await open_creature(target_id):return
	if not probe.check(desktop.radial_entries.size()==8 and desktop.radial_entries.get(7,{}).get("menu",{}).get("kind")=="associate-actions","Owned current NPC root exposes the source eight-sector hierarchy"):return
	if not await choose(7) or not probe.check(desktop.radial_entries.get(0,{}).get("action")=="associate-record","Owned Examine dispatches to target Record rather than ordinary Examine or own sheet"):return
	if not await choose(0):return
	var sheet=desktop.sheet
	var prepared:bool=await probe.wait_for(func():return sheet.wanted and desktop.current_sheet_target()==target_id and sheet.native_skin.layout_ready and received_page_zero_ready(),"Installed target Record frame and actual received NPC abilities prepare",30)
	if not prepared:
		probe.check(false,"Target page0 readiness retains raw and projected owner diagnostics",{"rawFields70":desktop.objects.get(target_id,{}).get("inventoryStats",{}).get("fields70"),"modelAbilities":sheet.state.get("model",{}).get("abilities"),"wanted":sheet.wanted,"displayedTarget":desktop.current_sheet_target(),"skinReady":sheet.native_skin.layout_ready});return
	if not probe.check(sheet.native_skin.stage.visible and not sheet.window_column.visible and sheet.state.model.abilities.map(func(row):return row.score)==[12,12,12,10,10,10] and not sheet.state.canLevelUp,"Original sheet geometry presents actual NPC abilities and suppresses nonself Level Up",{"rawFields70":desktop.objects[target_id].inventoryStats.fields70,"modelAbilities":sheet.state.model.abilities,"stageVisible":sheet.native_skin.stage.visible,"fallbackColumnVisible":sheet.window_column.visible,"canLevelUp":sheet.state.canLevelUp}):return
	if not probe.check(sheet.state.model.armorClass==null and sheet.state.model.experience==null and sheet.state.model.nextExperience==null,"Unavailable NPC final AC and player-only progress remain explicit; no actor borrowing"):return
	if not await page(1):return
	if not await probe.wait_for(func():return row_id(1)>=0 and row_id(3)>=0,"Original NPC skill disclosure supplies both selective description rows"):return
	var unchanged_skill:String=probe.ui.text.raw({"strRef":347})
	if not await inspect_row("skill",1,true) or not await inspect_row("skill",1,true):return
	if not probe.check(sheet.description.get_parsed_text().contains("Owned Record GUI3 help ") and not sheet.description.get_parsed_text().contains("<CUSTOM"),"Repeat physical NPC skill click resolves actual selective TLK and custom token"):return
	if not await inspect_row("skill",3,false):return
	if not probe.check(probe.ui.text.raw({"strRef":347})==unchanged_skill and not sheet.description.get_parsed_text().contains("Owned Record GUI3 help"),"Unchanged NPC skill still sends GUI3 and retains its own source help"):return
	if not await page(2):return
	if not await probe.wait_for(func():return row_id(3)>=0 and row_id(4)>=0 and row_id(45)>=0,"Original NPC feat disclosure supplies authored rows and retained proficiency"):return
	var unchanged_feat:String=probe.ui.text.raw({"strRef":224})
	if not await inspect_row("feat",3,true) or not await inspect_row("feat",3,true):return
	if not probe.check(sheet.description.get_parsed_text().contains("Owned Record GUI4 help ") and not sheet.description.get_parsed_text().contains("<CUSTOM"),"Repeat physical NPC feat click resolves actual selective TLK and custom token"):return
	if not await inspect_row("feat",4,false):return
	if not probe.check(probe.ui.text.raw({"strRef":224})==unchanged_feat and not sheet.description.get_parsed_text().contains("Owned Record GUI4 help"),"Unchanged NPC feat still sends GUI4 and retains its own source help"):return
	if not await source_click(sheet.close_button):return
	if not probe.check(not sheet.wanted and desktop.current_sheet_target()==null and desktop.sheet_context.is_empty(),"Installed target X closes the exact foreign subscription and retires its lease"):return
	var portrait:Control
	if not await probe.wait_for(func():return desktop.party.rows.any(func(row):return row.id==target_id and row.available),"Original party replication supplies the current owned NPC portrait"):return
	for row in desktop.party.rows:
		if row.id==target_id:portrait=desktop.party.cards[int(row.entryId)].get_node("Box/Portrait");break
	if not probe.check(is_instance_valid(portrait),"Actual current owned party portrait control exists"):return
	await click(portrait.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	if not probe.check(desktop.radial.active and desktop.radial_entries.get(7,{}).get("menu",{}).get("kind")=="associate-actions","Physical owned portrait opens its distinct source hierarchy"):return
	if not await choose(7) or not await choose(0):return
	if not probe.check(sheet.wanted and desktop.current_sheet_target()==target_id and sheet.page==0,"Physical portrait Record reopens the same current target without control transfer"):return
	probe.ui.chat.submit("-native-party-remove")
	if not await probe.wait_for(func():return desktop.objects[target_id].replicated.get("master")!=source_actor and not sheet.wanted and desktop.current_sheet_target()==null,"Original ownership removal retires the foreign sheet and prevents actor fallback"):return
	probe.check(same_scope() and desktop.actor_id==source_actor and gui_count==6,"Composed target Record completes six exact inspections with actor and disclosure lifetimes intact",{"targetId":target_id,"callbacks":gui_count,"selectionTimings":sheet.selection_timings.duplicate(true),"scope":"CPU/input and original-server outcomes; pixels, remote portraits, DM and unknown final AC remain separate."})
