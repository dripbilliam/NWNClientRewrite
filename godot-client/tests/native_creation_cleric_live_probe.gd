extends "res://tests/native_creation_source_live_probe.gd"
# CreationCheck driver only; the production chooser/controller owns all rules.
func cleric() -> bool:
	return is_instance_valid(creator) and str(creator.rules.cell(creator.rules.cls(),"Label","")).to_lower()=="cleric"
func prefer_manual_child(tag: String) -> bool:
	return tag=="package-domains" and cleric()
func disabled_domains_ok(pane,label: String) -> bool:
	var ticket: Array=pane.scope.duplicate()
	var before: Array=pane.state.chosen.duplicate()
	if not check(pane.buttons.okbutton.disabled,label+" source OK is disabled"):return false
	var button: Button=pane.buttons.okbutton
	var point: Vector2=button.get_global_transform_with_canvas()*(button.size*.5)
	if not await pointer(point,button.get_viewport(),label+" physical disabled OK"):return false
	return check(front.child=="package-domains" and front.ticket==ticket and pane.scope==ticket and pane.state.chosen==before and pane.buttons.okbutton.disabled,label+" cannot commit or retire its current ticket")
func choose_without_recommend(pane,tag: String) -> bool:
	if tag!="package-domains" or not cleric():return await super.choose_without_recommend(pane,tag)
	if not check(await wait_for(func():return pane.state.model.get("ready",false) and front.child==tag and pane.scope==front.ticket),"Active Cleric Domain data and exact source ticket prepare"):return false
	if not check(pane.state.chosen.is_empty(),"Fresh Cleric Domains starts without invented choices"):return false
	if not await disabled_domains_ok(pane,"Zero-domain"):return false
	var ticket: Array=pane.scope.duplicate()
	while pane.state.chosen.size()<2:
		if not check(not pane.state.available_ids.is_empty(),"Cleric has another actual admitted Domain row"):return false
		var id: int=int(pane.state.available_ids[0])
		pane.list.ensure_control_visible(pane.row_nodes[id]);await frames()
		if not check(front.child==tag and front.ticket==ticket and pane.scope==ticket and pane.state.available_ids.has(id) and pane.buttons.has("domain:"+str(id)+":add"),"Domain canonical row/ticket is reacquired after scrolling"):return false
		if not await click(pane.buttons["domain:"+str(id)+":add"],"Cleric actual Domain add "+str(id)):return false
		if pane.state.chosen.size()==1 and not await disabled_domains_ok(pane,"One-domain"):return false
	return check(pane.state.chosen.size()==2 and pane.state.chosen[0]!=pane.state.chosen[1] and not pane.buttons.okbutton.disabled,"Two distinct active Domains enable source acceptance")
func capture_expected() -> void:
	super.capture_expected()
	if not cleric():return
	var rules=creator.rules
	var post: Dictionary=preload("res://systems/native_data/creation_post_feats.gd").creation_source(rules)
	var slots: Array=[]
	for level in 10:slots.append(int(rules.spell_slots(level)))
	expected.divineCreation={"version":1,"classId":int(rules.draft.classId),"label":"cleric","post":post.duplicate(),"memorizes":rules.num(rules.cls(),"MemorizesSpells"),"learnScroll":rules.num(rules.cls(),"LearnScroll"),"spellCaster":rules.num(rules.cls(),"SpellCaster"),"primary":rules.primary(),"slots":slots}
func open_main(tag: String) -> bool:
	if tag=="playbutton" and cleric():
		var model: Dictionary=expected.get("divineCreation",{})
		var post: Dictionary=model.get("post",{})
		if not check(model.get("classId")==2 and model.get("memorizes")==1 and model.get("learnScroll")==0 and model.get("spellCaster")==1 and str(model.get("primary","")).to_lower()=="wis" and post.get("PickDomains")==1 and post.get("PickSchool")==0 and post.get("SpellbookRestricted")==0 and post.get("Arcane")==0 and post.get("MinAssociateLevel")==255,"Original installed Cleric divine metadata owns this source path",model):return false
		if not check(expected.domains is Array and expected.domains.size()==2 and expected.domains[0]!=expected.domains[1] and expected.school==null and expected.known.is_empty(),"Accepted divine draft has distinct Domains, no School and no invented restricted book"):return false
		if not check(events.any(func(row):return row.event=="package-domains OK") and not events.any(func(row):return row.event in ["package-school OK","package-spells OK","package-associate OK"]),"Physical Cleric continuation follows Domains without invented arcane/pet panes"):return false
	return await super.open_main(tag)
