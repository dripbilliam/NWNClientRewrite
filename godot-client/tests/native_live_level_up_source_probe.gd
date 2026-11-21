extends "res://tests/native_creation_source_live_probe.gd"
# Source-mode1 input only. The inherited helper supplies owner-bound frame waits
# and physical viewport input; none of the creation run/draft methods are used.
const PANES:={"class":"native_level_up_class.gd","attributes":"native_level_up_attributes.gd","skills":"native_level_up_skills.gd","feats":"native_level_up_feats.gd","spells":"native_spells_chooser.gd","domains":"native_level_up_domains.gd","school":"native_level_up_school.gd","associate":"native_associate_chooser.gd","summary":"native_level_up_summary.gd"}
var desktop
var controller
var identity: Array=[]
var presentations: Array=[]
var steps: Array=[]
var current_ability:=3
var desired_group:=-1
var group_selected:=false
var outcomes: Array=[]
var attempted_submit_token:=-1
func check(value: bool,label: String,detail: Variant=null) -> bool:
	var accepted: bool=super.check(value,label,detail)
	if outcomes.size()<512:outcomes.append({"passed":value,"label":label,"detail":detail if detail==null or detail is String or detail is int or detail is float or detail is bool else "Structured diagnostic omitted"})
	if is_instance_valid(owner_world):owner_world.send({"kind":"level-source-progress","generation":identity[0],"areaId":identity[1],"actorId":identity[2],"checks":checks,"phase":label.left(160),"success":value})
	return accepted
func bind_desktop(value) -> void:
	desktop=value;controller=desktop.level_owner;identity=controller.source_identity().duplicate()
func source_current() -> bool:
	return controller!=null and controller.source_identity()==identity and is_instance_valid(controller.source_runtime) and controller.source_runtime.owns() and desktop.level_up.source_active and not desktop.level_up.visible
func record_presentation(stage: String) -> bool:
	if not check(source_current(),"Actual source mode1 owns every input; generic fallback is rejected",controller.status):return false
	front=controller.source_runtime.frontend
	if not check(PANES.has(stage) and front.stage==stage and front.panes.has(stage),"Current source frontend owns stage "+stage):return false
	var pane=front.panes[stage];var owner=controller.source_runtime.source_owner
	if is_instance_valid(owner_world) and owner_world.args.get("level-source-check","")=="true":
		if not check(controller.source_runtime.enable_source_probe_diagnostics(identity+[controller.token]),"Opt-in diagnostic scope is the actual current source token"):return false
	if not check(pane.wanted and pane.is_visible_in_tree() and pane.layout_ready and pane.scope==front.ticket and front.scope==owner.navigation.ticket and owner.current(front.ticket) and str(pane.get_script().resource_path)=="res://systems/"+str(PANES[stage]),"Installed mode1 pane/ticket is physically current: "+stage):return false
	if presentations.size()>=64:return check(false,"Finite source presentation evidence bound")
	presentations.append({"sourceActive":true,"genericVisible":false,"runtimeOwns":true,"paneVisible":true,"wanted":true,"ready":true,"frontend":str(front.get_script().resource_path),"identity":identity.duplicate(),"navigationTicket":owner.navigation.ticket.duplicate(),"ticket":front.ticket.duplicate(),"token":controller.token,"stage":stage,"pane":str(pane.get_script().resource_path)})
	return true
func accept(pane,label: String) -> bool:
	if not check(await wait_for(func():return source_current() and pane.layout_ready and pane.buttons.has("okbutton") and not pane.buttons.okbutton.disabled),label+" can accept",controller.status):return false
	return await click(pane.buttons.okbutton,label+" OK")
func pane_data_ready(stage: String,pane) -> bool:
	if stage=="class":return pane.state.resources_ready
	if stage=="summary":return pane.content_ready
	if stage in ["attributes","skills","feats","spells"]:return pane.model.get("ready",false)
	return true
func ready_stage() -> bool:
	var until:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<until:
		if controller.source_identity()!=identity:return check(false,"Actor/area/generation retirement rejects the source input")
		if desktop.level_up.wanted and not desktop.level_up.source_active and controller.token>=0:return check(false,"Source level-up may not fall back to the generic editor",controller.status)
		if source_current():
			front=controller.source_runtime.frontend
			if front.panes.has(front.stage) and front.panes[front.stage].layout_ready and front.panes[front.stage].wanted and pane_data_ready(front.stage,front.panes[front.stage]):return record_presentation(front.stage)
		await frames(1)
	return check(false,"Current original pane prepares before its finite deadline",controller.status)
func select_class(pane,class_id: int) -> bool:
	var at:=-1
	for index in pane.state.entries.size():
		if int(pane.state.entries[index].id)==class_id:at=index;break
	if not check(at>=0 and pane.state.entries[at].enabled,"Original server bitmap admits the requested physical class",class_id):return false
	pane.list.ensure_control_visible(pane.row_buttons[at]);await frames()
	# Table publication may recreate rows; resolve the same physical class again.
	at=-1
	for index in pane.state.entries.size():
		if int(pane.state.entries[index].id)==class_id:at=index;break
	return check(at>=0 and source_current(),"Canonical class row remains current after scroll") and await click(pane.row_buttons[at],"Level-up physical class "+str(class_id))
func add_skill(pane) -> bool:
	for index in pane.model.get("entries",[]).size():
		var id: int=int(pane.model.entries[index].id);var tag:="up:"+str(id)
		if pane.buttons.has(tag) and not pane.buttons[tag].disabled:
			pane.list.ensure_control_visible(pane.row_buttons[index]);await frames()
			if not check(source_current() and pane.buttons.has(tag),"Actual skill arrow survives its scroll publication"):return false
			return await click(pane.buttons[tag],"Level-up physical skill increment "+str(id))
	return check(false,"An active original class has an allocatable skill point")
func add_feat(pane) -> bool:
	var index:=-1
	for at in pane.model.get("available",[]).size():
		var entry: Dictionary=pane.model.available[at]
		if not entry.get("enabled",true):continue
		if desired_group>=0 and not group_selected:
			if entry.get("children",[]).any(func(child):return int(child.id)==desired_group and child.get("enabled",true)):index=at;break
		elif not entry.has("children"):index=at;break
	if not check(index>=0,"Actual mode1 Feats contains the requested enabled choice/group"):return false
	var entry: Dictionary=pane.model.available[index];var expected_id: int=int(entry.id)
	pane.lists.available.ensure_control_visible(pane.rows.available[index]);await frames()
	index=-1
	for at in pane.model.available.size():
		if int(pane.model.available[at].id)==expected_id:index=at;break
	if not check(index>=0 and source_current(),"Current physical feat row is reacquired before click"):return false
	if not await click(pane.buttons["available:"+str(index)+":arrow"],"Level-up physical feat/group arrow"):return false
	if entry.has("children"):
		var popup=pane.group_popup
		if not check(await wait_for(func():return source_current() and pane.modal_active and popup.wanted and popup.layout_ready),"Original grouped Feat popup owns the modal input"):return false
		var selected:=-1
		for at in popup.model.entries.size():
			if int(popup.model.entries[at].id)==desired_group:selected=at;break
		if not check(selected>=0,"Original popup contains the explicit physical grouped Feat"):return false
		popup.scroll.ensure_control_visible(popup.row_buttons[selected]);await frames()
		if not await click(popup.row_buttons[selected],"Level-up grouped Feat physical row") or not await click(popup.buttons.okbutton,"Level-up grouped Feat OK"):return false
		group_selected=true
	return true
func drive_to_summary(class_id: int,ability: int,group: int=-1) -> bool:
	current_ability=ability;desired_group=group;group_selected=false
	for turn in 20:
		if not await ready_stage():return false
		var stage: String=front.stage;var pane=front.panes[stage];var ticket: Array=front.ticket.duplicate()
		match stage:
			"class":
				if not await select_class(pane,class_id):return false
			"attributes":
				if not check(pane.buttons.okbutton.disabled,"Unallocated level4+ ability cannot complete the actual source pane"):return false
				var key: String=["str","dex","con","int","wis","cha"][ability]+"upbutton"
				if not await click(pane.buttons[key],"Level-up physical ability increase"):return false
			"skills":
				if not await add_skill(pane):return false
			"feats":
				for selection in 8:
					if not pane.buttons.okbutton.disabled:break
					if not await add_feat(pane):return false
				if not check(group<0 or group_selected,"Requested grouped Feat is selected through the actual popup"):return false
			"spells":
				if not await choose_without_recommend(pane,"package-spells"):return false
			"domains":
				if not await choose_without_recommend(pane,"package-domains"):return false
			"school":
				if not await choose_without_recommend(pane,"package-school"):return false
			"associate":
				if pane.buttons.has("gennamebutton") and not pane.buttons.gennamebutton.disabled:
					if not await click(pane.buttons.gennamebutton,"Level-up actual associate name worker"):return false
			"summary":return check(pane.content_ready and not pane.buttons.okbutton.disabled,"Original Summary owns a fully prepared current private proposal")
			_:return check(false,"Only actual known original level-up panes may continue",stage)
		if not await accept(pane,"Level-up "+stage):return false
		if not check(await wait_for(func():return not source_current() or front.ticket!=ticket),"Actual source pane retires its exact ticket: "+stage):return false
	return check(false,"Native level-up navigation has a finite original stage count")
func facts() -> Dictionary:
	var actor: Dictionary=desktop.actor();var state: Dictionary=actor.get("playerState",{});var stats: Dictionary=actor.get("replicated",{}).get("stats",{})
	var abilities: Variant=actor.get("clientAbilityCache",{}).get("base",state.get("abilities",{}).get("base"));var skills: Variant=state.get("levelUp",{}).get("skills")
	if not stats.get("classes") is Array or not abilities is Array or abilities.size()!=6 or not skills is Array or not state.get("feats") is Array or not state.get("spellbooks") is Dictionary or not actor.get("replicated",{}).get("hitPoints") is Dictionary:return {"ready":false}
	return {"ready":true,"actorId":desktop.actor_id,"classes":stats.classes.duplicate(true),"abilities":abilities.duplicate(),"skills":skills.duplicate(),"skillsOwner":"Last actual begin/raw-skill disclosure; post-submit freshness is not inferred","feats":state.feats.duplicate(),"spellbooks":state.spellbooks.duplicate(true),"hp":actor.replicated.hitPoints.duplicate(true)}
func total_level(value: Dictionary) -> int:
	var total:=0
	for cls in value.get("classes",[]):total+=int(cls.level)
	return total
func owned_level(value: Dictionary,id: int) -> int:
	for cls in value.get("classes",[]):
		if int(cls.id)==id:return int(cls.level)
	return 0
func local_submit_refusal(expected_token: int) -> bool:
	return attempted_submit_token==expected_token and source_current() and desktop.level_up.wanted and controller.token==expected_token and not controller.submitting
func submit_summary(expected_token: int) -> bool:
	var clicked: bool=await click(front.panes.summary.buttons.okbutton,"Source Summary submit")
	if clicked:attempted_submit_token=expected_token
	return clicked
func open_from_record() -> bool:
	var bindings=desktop.owner_ui.key_bindings
	if not check(await wait_for(func():return is_instance_valid(bindings) and bindings.bindings_ready),"Actual native keymap is ready"):return false
	if not desktop.sheet.wanted:
		var binding: int=int(bindings.active.normal.values.get(66,0));var chord: Dictionary=bindings.native_chord(binding)
		if not check(binding>0 and int(chord.key)!=0,"Received native Character Record action has a physical chord"):return false
		for pressed in [true,false]:
			var event:=InputEventKey.new();event.keycode=int(chord.key);event.physical_keycode=int(chord.key);event.pressed=pressed;event.shift_pressed=(int(chord.modifiers)&1)!=0;event.ctrl_pressed=(int(chord.modifiers)&2)!=0;desktop.get_viewport().push_input(event,true);await frames()
	if not check(await wait_for(func():return desktop.sheet.wanted and is_instance_valid(desktop.sheet.native_skin) and desktop.sheet.native_skin.layout_ready and desktop.sheet.level_button.is_visible_in_tree()),"Original Character Record presents the authoritative Level Up button"):return false
	return await click(desktop.sheet.level_button,"Original record Level Up")
func proof() -> void:
	if completed:return
	completed=true
	owner_world.send({"kind":"level-source-finished","generation":identity[0],"areaId":identity[1],"actorId":identity[2],"success":failures.is_empty(),"checks":checks,"outcomes":outcomes,"failures":failures,"presentations":presentations,"steps":steps,"events":events,"driver":"native-source-mode1-controls-v1"})
func run(world) -> void:
	owner_world=world;bind_desktop(world.gameplay_ui.desktop)
	var name: String=str(world.args.get("level-source-case",""));var recipe: Dictionary={"wizard-multiclass":{"classes":[10,4],"ability":3,"group":72},"sorcerer-caster":{"classes":[9,9],"ability":5,"group":-1},"cleric-new-class":{"classes":[2,2],"ability":4,"group":-1}}.get(name,{})
	if not check(not recipe.is_empty() and world.args.get("level-source-check","")=="true","Explicit isolated source authority workload is required"):proof();return
	if not check(await wait_for(func():return controller.source_configured),"Production Session late-ready hook configures source mode1"):proof();return
	if not await open_from_record() or not await ready_stage():proof();return
	var original: Dictionary=facts()
	if not check(original.get("ready",false),"Actual begin has received complete comparison fields; no missing data becomes empty"):proof();return
	if not await click(front.panes["class"].buttons.cancelbutton,"Source Class Cancel"):proof();return
	if not check(await wait_for(func():return not desktop.level_up.wanted) and facts()==original,"Actual source Cancel preserves all received actor fields"):proof();return
	for index in recipe.classes.size():
		var old_token: int=controller.token
		if not await open_from_record() or not await ready_stage():proof();return
		var before: Dictionary=facts()
		if not check(before.get("ready",false),"Each actual begin refresh owns its raw-skill comparison baseline"):proof();return
		if not await drive_to_summary(int(recipe.classes[index]),int(recipe.ability),int(recipe.group) if int(recipe.classes[index])==4 else -1):proof();return
		var runtime=controller.source_runtime;var private=runtime.source_owner;var prepared: Dictionary=private.proposal()
		if not check(prepared.get("ready",false) and controller.token>old_token and facts()==before,"Source Summary preparation cannot optimistically mutate received state"):proof();return
		if index==0:
			var cancelled_token: int=controller.token;var cancelled_draws: int=runtime.hit_die_owner.stream.draws
			if not await click(front.panes.summary.buttons.cancelbutton,"Source Summary Cancel after real roll"):proof();return
			if not check(await wait_for(func():return not desktop.level_up.wanted) and facts()==before,"Original server-bound Summary Cancel preserves received class/HP/skills/books"):proof();return
			if not await open_from_record() or not await drive_to_summary(int(recipe.classes[index]),int(recipe.ability),int(recipe.group) if int(recipe.classes[index])==4 else -1):proof();return
			runtime=controller.source_runtime;private=runtime.source_owner;prepared=private.proposal()
			if not check(controller.token>cancelled_token and runtime.hit_die_owner.stream.draws==cancelled_draws+1 and facts()==before,"Fresh Summary after Cancel has a new token/one next draw without actor changes"):proof();return
		var rolled: Dictionary=runtime.hit_die_owner.receipt
		if not check(rolled.get("ready",false) and int(rolled.randomCalls)==1 and int(rolled.totalLevel)>3 and int(rolled.hitDie)==int(prepared.proposal.hitDie) and not rolled.serverAcknowledged,"Level4+ actual source Summary owns one private process-stream roll"):proof();return
		var proposal: Dictionary=prepared.proposal.duplicate(true);var token: int=controller.token
		var diagnostic: Dictionary=runtime.finalization_diagnostic(private.navigation.ticket)
		if not check(diagnostic.get("ready",false) and diagnostic.get("scope")==identity+[token] and diagnostic.get("ticket")==private.navigation.ticket,"Numeric finalization witness belongs to this exact source Summary",diagnostic.get("reason","")):proof();return
		steps.append({"token":token,"identity":identity.duplicate(),"before":before,"proposal":proposal,"displayHitPointGain":int(private.finalization.displayHitPointGain),"finalizationDiagnostics":diagnostic,"roll":{"hitDie":int(rolled.hitDie),"randomCalls":int(rolled.randomCalls),"totalLevel":int(rolled.totalLevel),"drawCount":int(rolled.drawCount)},"submitted":false})
		if not await submit_summary(token):proof();return
		steps[-1].submitted=true
		if not check(await wait_for(func():return controller.source_identity()!=identity or not desktop.level_up.wanted or local_submit_refusal(token),30),"Scoped source submission settles before its finite deadline",controller.status):proof();return
		if not check(not local_submit_refusal(token),"Current source submission is not locally refused",controller.status):proof();return
		if not check(controller.source_identity()==identity and not desktop.level_up.wanted,"Same actor/area/generation owns accepted source advancement"):proof();return
		if not check(await wait_for(func():return received_advanced(before,proposal),30),"Independent received class advancement follows the actual server result"):proof();return
		steps[-1].after=facts()
	proof()
func received_advanced(before: Dictionary,proposal: Dictionary) -> bool:
	var value:=facts()
	return controller.source_identity()==identity and value.get("ready",false) and total_level(value)==total_level(before)+1 and owned_level(value,int(proposal.classId))==owned_level(before,int(proposal.classId))+1
