extends "res://tests/native_live_quickbar_probe.gd"
# Physical native target controls -> original localhost server -> raw outcomes.
# Never edits received identity, permission, owner, skills, action or combat flags.
func open_creature(id:int)->bool:
	var p:Array=desktop.objects.get(id,{}).get("replicated",{}).get("position",[])
	if not probe.check(p.size()==3,"Actual received creature position supplies world context"):return false
	desktop.open_radial({"id":id,"position":Vector3(p[0],p[2],-p[1]),"origin":"world"},Vector2(700,300));await probe.get_tree().process_frame
	return probe.check(desktop.radial.active,"Actual current creature opens its source world wheel",{"targetId":id,"coverage":desktop.world_radial_coverage.duplicate(true)})
func run(owner)->void:
	probe=owner;desktop=probe.desktop
	if not probe.check(DisplayServer.get_name()=="headless","World radial acceptance uses the owned headless original-server fixture"):return
	var speaker:=-1
	for id in desktop.objects:
		if desktop.objects[id].get("objectType")==5 and probe.ui.text.name(null,int(id))=="Native Speaker":speaker=int(id);break
	if not probe.check(speaker>=0,"Actual durable original-server speaker is disclosed"):return
	var source:Dictionary=desktop.objects[speaker]
	if not probe.check(desktop.world_member_lifetime(desktop.actor_id)!=null and desktop.world_member_lifetime(speaker)!=null,"Canonical raw disclosure lifetimes exist before target dispatch",{"actorLifetime":probe.current().get("clientKnownLifetime"),"targetLifetime":source.get("clientKnownLifetime")}):return
	if not probe.check(source.get("replicated",{}).has("master"),"Original server discloses current target master ownership",{"targetId":speaker,"replicatedKeys":source.get("replicated",{}).keys(),"coverage":desktop.world_radial_coverage.duplicate(true)}):return
	probe.check(true,"Received target selector owners retained",{"master":source.replicated.master,"controlledId":desktop.actor_id,"permission":desktop.state.get("gameMasterPermission"),"rosterKnown":desktop.state.get("playerRosterKnown"),"skillAdmission":probe.current().get("clientSkillAdmission")})
	if not await open_creature(speaker):return
	if not probe.check(desktop.world_radial_coverage.get("coverage")=="normal-other-creature-993790" and desktop.radial_entries.get(7,{}).get("interaction")=="conversation.start","Verified normal target policy supplies Talk from actual current owners"):return
	if not await choose(7):return
	var dialog=probe.ui.conversation
	if not await probe.wait_for(func():return dialog.opened and dialog.entry_id>=0 and not dialog.pending and dialog.body.get_parsed_text().contains("FIRST_ENTRY"),"Physical target Talk opens the actual original-server dialogue"):return
	dialog.choose(4294967295,true)
	if not await probe.wait_for(func():return not dialog.opened and probe.dialogue_history("GODOT_ABORT_ACK"),"Original server acknowledges target dialogue abort"):return
	if not await open_creature(speaker):return
	if not probe.check(desktop.radial_entries.get(2,{}).get("action")=="world-attack","Current target wheel exposes the verified direct Attack leaf"):return
	var before:int=probe.ui.chat.sequence
	if not await choose(2):return
	if not probe.check(desktop.target.is_empty(),"Target Attack does not create a second targeting cursor"):return
	if not await probe.wait_for(func():return probe.ui.chat.rows.any(func(row):return int(row.get("chat_sequence",0))>before and row.get("category","")=="attack-feedback"),"Original server returns combat feedback after physical target Attack",25):return
	if not await probe.wait_for(func():return desktop.action_queue.rows.any(func(row):return int(row.get("type",-1))==3),"Original server publishes the attack action in its raw native queue"):return
	var action_serials:Array=[]
	for row in desktop.action_queue.rows:
		if int(row.get("type",-1))==3:action_serials.append(int(row.widgetSerial))
	if not await open_creature(desktop.actor_id):return
	var eligible:bool=desktop.radial_entries.get(2,{}).get("action")=="world-disengage"
	probe.check(true,"Original Disengage predicate coverage is recorded without forcing combat flags",{"eligible":eligible,"mode":probe.current().get("replicated",{}).get("field8D6"),"related":probe.current().get("replicated",{}).get("field8D8"),"clickedId":desktop.actor_id,"limit":"UI Disengage remains unexercised when its exact received predicate is false."})
	if eligible:
		if not await choose(2):return
	else:
		await click(desktop.radial.center.get_global_rect().get_center())
		if not await probe.wait_for(func():return not action_serials.is_empty() and desktop.action_queue.buttons.has(action_serials[0]),"The actual received attack action has a current native cancel widget"):return
		await click(desktop.action_queue.buttons[action_serials[0]].get_global_rect().get_center())
	if not await probe.wait_for(func():return not desktop.action_queue.rows.any(func(row):return int(row.get("type",-1))==3),"Original server retires the attack queue after physical native cancellation"):return
	probe.check(desktop.target.is_empty(),"Cancellation completion retains no predicted target cursor",{"retiredActionSerials":action_serials,"cancelMode":"disengage" if eligible else "queue","coverage":desktop.world_radial_coverage.duplicate(true)})
	probe.check(true,"World skill coverage remains explicitly current-data driven",{"zero":desktop.rules.skill_admission(probe.current(),0),"thirteen":desktop.rules.skill_admission(probe.current(),13),"limit":"This run does not grant ranks or force a skill flag; skill gameplay outcomes remain separate."})
