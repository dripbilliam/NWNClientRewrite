extends Node
signal probe_frame
# Loopback acceptance driver: only installed native controls change the draft.
# The host separately verifies received world admission and original-server BIC.
var owner_world
var creator
var front
var checks:=0
var failures: Array=[]
var expected: Dictionary={}
var events: Array=[]
var voice_proof: Dictionary={}
var reconnect_selection: Dictionary={}
var completed:=false
func check(value: bool,label: String,detail: Variant=null) -> bool:
	checks+=1
	if is_instance_valid(owner_world) and owner_world.args.get("creation-phase-trace","")=="true":owner_world.send({"kind":"creation-source-phase","phase":label.left(160),"checks":checks})
	if not value:failures.append({"label":label,"detail":detail})
	return value
func _process(_delta: float) -> void:
	probe_frame.emit()
func wait_for(predicate: Callable,seconds: float=30.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline:await probe_frame
	return predicate.call()
func frames(count: int=2) -> void:
	for index in count:await probe_frame
func new_button() -> Button:
	var pane=owner_world.character_lobby.native_chooser
	return pane.buttons.get("newcharbutton") if is_instance_valid(pane) and pane.layout_ready else null
func proof() -> void:
	if completed:return
	completed=true
	var context: Dictionary={}
	if is_instance_valid(creator) and not creator.rules.draft.is_empty():context={"phase":creator.phase,"child":front.child,"classId":creator.rules.draft.classId,"classRow":creator.rules.cls(),"postSource":preload("res://systems/native_data/creation_post_feats.gd").creation_source(creator.rules),"postStage":creator.source_post.stage}
	owner_world.send({"kind":"creation-proof","success":failures.is_empty(),"checks":checks,"failures":failures,"expected":expected,"events":events,"context":context,"reconnectSelection":reconnect_selection,"driver":"installed-source-controls-v1"})
func click(button: Button,label: String) -> bool:
	if not check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled,label+" is a visible enabled native control"):return false
	var viewport:=button.get_viewport()
	var point:=button.get_global_transform_with_canvas()*(button.size*.5)
	return await pointer(point,viewport,label)
func feat_input_state() -> Dictionary:
	if not is_instance_valid(creator):return {}
	var state=creator.source_feats
	return {"builds":state.builds,"modelBuilds":state.model_builds,"textRevision":state._text_revision,"liveTextRevision":creator.ui.text.revision,"tableSame":is_same(state._table,creator.rules.tables.get("feat",{}))}
func pointer(point: Vector2,viewport: Viewport,label: String) -> bool:
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;viewport.push_input(motion,true);await frames(1)
	var feat_before: Dictionary=feat_input_state() if label=="package-feats Recommended" else {}
	var began:=Time.get_ticks_usec();var callbacks: Array=[]
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		var callback_began:=Time.get_ticks_usec();viewport.push_input(event,true);callbacks.append(Time.get_ticks_usec()-callback_began)
		await frames(1)
	events.append({"event":label,"inputAndFrameUsec":Time.get_ticks_usec()-began,"dispatchUsec":callbacks,"featBefore":feat_before,"featAfter":feat_input_state() if not feat_before.is_empty() else {}})
	return true
func type_text(control: LineEdit,value: String) -> void:
	control.grab_focus();control.select_all()
	var viewport:=control.get_viewport()
	for index in value.length():
		var key:=InputEventKey.new();key.pressed=true;key.unicode=value.unicode_at(index);viewport.push_input(key,true)
	await frames()
func open_main(tag: String) -> bool:
	if not check(await wait_for(func():return front.wanted and front.child.is_empty() and front.main.visible and front.main.buttons.has(tag) and not front.main.buttons[tag].disabled),"Main enables "+tag,creator.status):return false
	return await click(front.main.buttons[tag],"Main "+tag)
func accept(pane,label: String) -> bool:
	if not check(await wait_for(func():return pane.layout_ready and pane.buttons.has("okbutton") and not pane.buttons.okbutton.disabled),label+" can accept",creator.status):return false
	return await click(pane.buttons.okbutton,label+" OK")
func choose_without_recommend(pane,tag: String) -> bool:
	if tag=="package-domains":
		while pane.state.chosen.size()<2:
			if not check(not pane.state.available_ids.is_empty(),"Actual Domains has another active physical choice"):return false
			var id:=int(pane.state.available_ids[0]);pane.list.ensure_control_visible(pane.row_nodes[id]);await frames()
			if not await click(pane.buttons["domain:"+str(id)+":add"],"Domains actual row add "+str(id)):return false
	elif tag=="package-school":
		if not await click(pane.buttons[pane.State.TAGS[0]],"School actual General choice"):return false
	elif tag=="package-spells":
		var levels: Array=[int(pane.model.get("level",-1))]
		for level in 10:
			if not levels.has(level):levels.append(level)
		for level in levels:
			if not pane.buttons.okbutton.disabled:break
			if level<0 or pane.buttons["spelllevel"+str(level)].disabled:continue
			if not await click(pane.buttons["spelllevel"+str(level)],"Spells actual level "+str(level)):return false
			for turn in 256:
				if not pane.buttons.okbutton.disabled:break
				var index:=-1
				for at in pane.model.get("available",[]).size():
					if pane.model.available[at].get("enabled",true):index=at;break
				if index<0:break
				pane.lists.available.scroll_vertical=int(absf(pane.plan.row.hooks.next.y)*index);await frames()
				var slot:=-1
				for at in pane.rows.available.size():
					if int(pane.rows.available[at].index)==index:slot=at;break
				if not check(slot>=0,"Actual virtual spell pool binds the selected active row"):return false
				if not await click(pane.buttons["available:"+str(slot)+":arrow"],"Spells actual add "+str(pane.model.available[index].id)):return false
	return true
func prefer_manual_child(_tag: String) -> bool:return false
func configure_package() -> bool:
	if not await open_main("packagesbutton"):return false
	if not check(await wait_for(func():return front.packages.layout_ready and front.child=="packagesbutton"),"Package source pane opens"):return false
	if owner_world.args.get("creation-package","manual")=="recommended":
		if not await click(front.packages.buttons.recommendbutton,"Package Recommended") or not await accept(front.packages,"Recommended Package"):return false
		return check(await wait_for(func():return creator.phase=="editing" and front.child.is_empty() and front.flow.completed.packages,30),"Actual Recommended package transaction completes",creator.status)
	if not await click(front.packages.buttons.configurepckg,"Package Configure"):return false
	for turn in 12:
		if not check(await wait_for(func():return creator.phase=="editing" and (front.child.is_empty() or front.child.begins_with("package-"))),"Class-dependent continuation is current",creator.status):return false
		if front.child=="package-post-skills":
			if not check(await wait_for(func():return front.child!="package-post-skills",30),"Internal class continuation resolves to an actual source pane",{"source":preload("res://systems/native_data/creation_post_feats.gd").creation_source(creator.rules),"stage":creator.source_post.stage,"classId":creator.rules.draft.classId,"classRow":creator.rules.cls(),"fallback":creator.source_fallback,"status":creator.status}):return false
		if front.child.is_empty():return check(front.flow.completed.packages,"Manual Package chain completes")
		var tag: String=front.child
		var pane
		match tag:
			"package-configuration":pane=front.skills
			"package-feats":pane=front.feats
			"package-school":pane=front.school
			"package-domains":pane=front.domains
			"package-spells":pane=front.spells
			"package-associate":pane=front.associate
			_:return check(false,"Known class-dependent native pane",tag)
		if not check(await wait_for(func():return pane.layout_ready and pane.buttons.has("okbutton")),tag+" source resources prepare"):return false
		if not prefer_manual_child(tag) and pane.buttons.has("recommendbutton") and not pane.buttons.recommendbutton.disabled:
			if not await click(pane.buttons.recommendbutton,tag+" Recommended"):return false
		else:
			if not await choose_without_recommend(pane,tag):return false
		if tag=="package-associate" and pane.buttons.has("gennamebutton") and not pane.buttons.gennamebutton.disabled:
			if not await click(pane.buttons.gennamebutton,tag+" Generate name"):return false
		if not await accept(pane,tag):return false
		if not check(await wait_for(func():return front.child!=tag or front.ticket!=pane.scope),tag+" advances its exact child ticket",creator.status):return false
	return check(false,"Package chain terminates within its finite stages")
func capture_expected() -> void:
	var rules=creator.rules;var d: Dictionary=rules.draft;var cls: Dictionary=rules.cls()
	expected={"classId":int(d.classId),"domains":d.domains.duplicate() if rules.num(cls,"PickDomains")!=0 else null,"school":int(d.school) if rules.num(cls,"PickSchool")!=0 else null,"known":[],"feats":rules.granted_feats().duplicate(),"skills":[],"gender":int(d.gender),"abilities":[],"goodEvil":int(d.goodEvil),"lawChaos":int(d.lawChaos),"race":int(d.raceId),"subrace":str(d.subrace),"age":int(d.age),"appearance":rules.num(rules.race(),"Appearance"),"biography":str(d.biography),"firstName":str(d.firstName),"lastName":str(d.lastName),"sourceTailAppearance":d.get("sourceTailAppearance",{}).duplicate(true),"sourceTailInformation":d.get("sourceTailInformation",{}).duplicate(true)}
	var abilities: Dictionary=rules.abilities()
	for ability in rules.ABILITIES:expected.abilities.append(int(abilities[ability]))
	for index in rules.rows("skills").size():expected.skills.append(int(d.skills.get(index,0)))
	for values in d.known.values():expected.known.append_array(values)
	for choice in d.feats:
		var id: int=int(choice.id) if choice is Dictionary else int(choice)
		if not expected.feats.has(id):expected.feats.append(id)
	var hp:=preload("res://systems/native_data/creation_bic.gd").source_hp_fields(rules)
	expected.hitpoints={}
	if hp.ready:
		for field in hp.fields:expected.hitpoints[field]=hp.fields[field].value
	expected.voiceProof=voice_proof.duplicate(true);expected.packageRoute=str(owner_world.args.get("creation-package","manual"))
	for field in ["familiar","familiarName","companion","companionName"]:expected[field]=d[field]
func sample_voice(tail) -> bool:
	var pane=tail.information
	if not check(not pane.rows.is_empty() and pane.rows[0].id!=null,"Information has an actual active voice row"):return false
	var id: int=int(pane.rows[0].id)
	for turn in 49:
		var code: int=int(pane.state.sample) if pane.state.selected==id else 0
		if not await click(pane.rows[0].button,"Information voice sample "+str(code)):return false
		if not check(await wait_for(func():return creator.voice.request_id<0,5),"Native SSF/audio worker settles without blocking input"):return false
		if not check(tail.current() and creator.voice.last.get("voice")==id and creator.voice.last.get("code")==code and pane.state.sample==(code+1)%49,"Information owns exactly one scoped sample counter advance"):return false
		if creator.voice.last.get("played",false):
			var audio=creator.view.voice_audio
			voice_proof=creator.voice.last.duplicate(true)
			voice_proof.muted=audio.player.volume_db<=-80.0
			return check(audio.player.stream!=null and audio.player.stream.get_length()>0 and voice_proof.muted,"Actual source row decodes and plays a muted installed audio sample")
	return check(false,"An installed source voice supplies a playable original sample",creator.view.voice_audio.status)
func reconnect(world) -> void:
	var file: String=str(world.args.get("creation-reconnect-report",""))
	if not check(FileAccess.file_exists(file) and FileAccess.get_sha256(file)==str(world.args.get("creation-reconnect-sha","")),"Reconnect uses the exact accepted creation report"):proof();return
	var previous: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
	if not check(previous is Dictionary and previous.get("success")==true and previous.get("creationProof",{}).get("success")==true,"Reconnect reference contains accepted source creation"):proof();return
	expected=previous.creationProof.expected.duplicate(true)
	var label: String=(str(expected.firstName)+" "+str(expected.lastName)).strip_edges()
	var lobby=world.character_lobby
	if not check(await wait_for(func():return lobby.state.get("localAllowed")==false and is_instance_valid(lobby.native_chooser) and lobby.native_chooser.layout_ready and lobby.state.get("choices",[]).any(func(row):return row.get("source")=="server" and row.get("label")==label),45),"Fresh native chooser receives the created original server-vault row",lobby.state.get("error")):proof();return
	var selected: Dictionary={}
	for row in lobby.state.get("choices",[]):
		if row.get("source")=="server" and row.get("label")==label:selected=row;break
	var key: String=str(selected.get("key",""));var connection: int=int(lobby.connection);var pane=lobby.native_chooser
	if not check(not key.is_empty() and await wait_for(func():return pane.row_keys.has(key)),"Received server row is represented by an actual source control"):proof();return
	var row_button: Button=pane.rows[pane.row_keys.find(key)];pane.list.ensure_control_visible(row_button);await frames()
	# Metadata/preview publication may rebuild the physical rows during scroll.
	# Resolve the same canonical received key again instead of retaining a Control.
	if not check(await wait_for(func():return lobby.connection==connection and is_instance_valid(lobby.native_chooser) and lobby.native_selection.is_empty() and lobby.native_chooser.row_keys.has(key)),"Same canonical vault row remains current after scrolling"):proof();return
	pane=lobby.native_chooser
	row_button=pane.rows[pane.row_keys.find(key)]
	if not check(lobby.connection==connection and is_instance_valid(row_button) and row_button.is_visible_in_tree(),"Current received vault row has a live physical control"):proof();return
	if not await click(row_button,"Server-vault created character row"):proof();return
	if not check(await wait_for(func():return lobby.connection==connection and lobby.state.get("selected")==key and lobby.native_selection.is_empty() and not pane.buttons.playbutton.disabled,45),"Actual server preview/selection settles for the same current row",lobby.state.get("error")):proof();return
	if not await click(pane.buttons.playbutton,"Server-vault Play received character"):proof();return
	reconnect_selection={"success":lobby.connection==connection,"connection":connection,"key":key,"source":"server","serverSource":selected.get("serverSource"),"generation":selected.get("generation"),"name":label,"uploadPerformed":false}
	proof()
func run(world) -> void:
	owner_world=world
	if world.args.has("creation-reconnect-report"):await reconnect(world);return
	if not check(await wait_for(func():return is_instance_valid(new_button()) and not new_button().disabled and new_button().is_visible_in_tree()),"Production source chooser New is ready"):proof();return
	if not await click(new_button(),"Source chooser New"):proof();return
	creator=world.gameplay_ui.creator
	creator.view.voice_audio.player.volume_db=-80.0
	if not check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.wanted and creator.source_frontend.main.layout_ready,60),"Default New automatically enters source Main",creator.resource_errors):proof();return
	front=creator.source_frontend
	if not check(front.main.buttons.playbutton.disabled,"Incomplete new source draft cannot be submitted"):proof();return
	var old_scope: Array=creator.summary_identity().duplicate()
	if not await click(front.main.buttons.cancelbutton,"Main Cancel before changes"):proof();return
	if not check(await wait_for(func():return creator.phase=="closed" and not front.wanted and is_instance_valid(new_button()) and not new_button().disabled and new_button().is_visible_in_tree()),"Cancel retires draft and restores actual source chooser"):proof();return
	if not await click(new_button(),"Source chooser New after Cancel"):proof();return
	if not check(await wait_for(func():return creator.phase=="editing" and front.wanted and creator.summary_identity()!=old_scope,60),"New has a distinct draft scope"):proof();return
	var current_scope: Array=creator.summary_identity().duplicate();var prior_status: String=creator.status
	creator.result({"kind":"native-creation-result","connection":old_scope[0],"draft":old_scope[1],"operation":"native-creation-begin","accepted":false,"error":"stale test reply"})
	if not check(creator.summary_identity()==current_scope and creator.phase=="editing" and creator.status==prior_status,"Stale cancelled-draft reply cannot alter the new source draft"):proof();return
	if not await open_main("genderbutton"):proof();return
	if not check(await wait_for(func():return front.gender.layout_ready),"Gender prepares"):proof();return
	if not await click(front.gender.buttons.malebutton,"Gender Male") or not await accept(front.gender,"Gender"):proof();return
	if not await open_main("racebutton"):proof();return
	if not check(await wait_for(func():return front.race.layout_ready),"Race prepares"):proof();return
	if not await click(front.race.buttons.recommendbutton,"Race Recommended") or not await accept(front.race,"Race"):proof();return
	if not await open_main("portraitbutton"):proof();return
	if not check(await wait_for(func():return front.portrait.layout_ready and not front.portrait.cells.is_empty() and not front.portrait.cells[0].button.disabled),"Portrait has actual admitted choices"):proof();return
	if not await click(front.portrait.cells[0].button,"Portrait first available") or not await accept(front.portrait,"Portrait"):proof();return
	if not await open_main("classbutton"):proof();return
	if not check(await wait_for(func():return front.class_chooser.layout_ready and not front.class_chooser.row_buttons.is_empty()),"Active Class rows prepare"):proof();return
	var selected:=-1;var class_label:=str(world.args.get("creation-class","fighter")).to_lower()
	for index in front.class_chooser.state.entries.size():
		var id: int=front.class_chooser.state.entries[index].id
		if str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()==class_label:selected=index;break
	if not check(selected>=0,"Requested original active class exists",class_label):proof();return
	front.class_chooser.list.ensure_control_visible(front.class_chooser.row_buttons[selected]);await frames()
	if not await click(front.class_chooser.row_buttons[selected],"Class "+class_label) or not await accept(front.class_chooser,"Class"):proof();return
	if not await open_main("alignbutton"):proof();return
	if not check(await wait_for(func():return front.alignment.layout_ready),"Alignment prepares"):proof();return
	var align_index: int=front.alignment.state.enabled.find(true)
	if not check(align_index>=0,"Active class offers a legal alignment"):proof();return
	if not await click(front.alignment.buttons[front.alignment.State.TAGS[align_index]],"Alignment legal source choice") or not await accept(front.alignment,"Alignment"):proof();return
	if not await open_main("abilitiesbutton"):proof();return
	if not check(await wait_for(func():return front.attributes.layout_ready),"Attributes prepares"):proof();return
	if not await click(front.attributes.buttons.recommendbutton,"Attributes Recommended") or not await accept(front.attributes,"Attributes"):proof();return
	if not await configure_package():proof();return
	if not await open_main("customizebutton"):proof();return
	var tail=creator.tail
	if not check(await wait_for(func():return tail.stage=="appearance" and tail.appearance.layout_ready,45),"Active native Appearance worker publishes typed outfits",tail.failure):proof();return
	var appearance=tail.appearance
	if not await click(appearance.buttons.head_right,"Appearance next installed head") or not await click(appearance.buttons.clothes_right,"Appearance next admitted outfit"):proof();return
	if not await click(appearance.buttons.skin,"Appearance active skin palette"):proof();return
	if not check(is_instance_valid(appearance.palette),"Original source color board opens"):proof();return
	var color_local:=Vector2(24,appearance.palette.size.y-168.0)
	if not check(Rect2(Vector2.ZERO,appearance.palette.size).has_point(color_local),"Source board contains the original sixteen-unit swatch cell"):proof();return
	var color_point: Vector2=appearance.palette.get_global_transform_with_canvas()*color_local
	await pointer(color_point,appearance.get_viewport(),"Appearance physical skin swatch1")
	if not check(appearance.state.value.skin==1 and not is_instance_valid(appearance.palette),"Source board release commits palette row1 and retires capture"):proof();return
	if not check(await wait_for(func():return creator.preview.diagnostics.get("ready",false) and creator.preview.diagnostics.get("native",false),20),"Actual native preview admits the selected installed head/outfit/skin",creator.preview.diagnostics):proof();return
	if not await accept(tail.appearance,"Appearance"):proof();return
	if not check(await wait_for(func():return tail.stage=="information" and tail.information.layout_ready),"Appearance8002 reaches Information with the same parent ticket",tail.failure):proof();return
	if not await sample_voice(tail):proof();return
	await type_text(tail.information.edits.firstnameedit,"NativeFull")
	var desired_last: String="Source"+str(Time.get_unix_time_from_system()).get_slice(".",0).right(5)
	await type_text(tail.information.edits.lastnameedit,desired_last)
	if not check(tail.information.state.fields.firstName=="NativeFull" and tail.information.state.fields.lastName==desired_last,"Actual Information keyboard input updates both private name fields"):proof();return
	if not await accept(tail.information,"Information"):proof();return
	if not check(front.child.is_empty() and creator.rules.draft.get("sourceTailChoices")==true,"Info8007 returns to source Main with committed typed tail"):proof();return
	var problems: Array=preload("res://systems/native_data/creation_bic.gd").validation_errors(creator.rules)
	if not check(problems.is_empty(),"Source controls produce a saveable first-level draft",problems):proof();return
	capture_expected()
	if not await open_main("playbutton"):proof();return
	if not check(await wait_for(func():return creator.phase in ["waiting","closed"] or creator.phase=="editing" and not creator.status.is_empty(),40) and creator.phase in ["waiting","closed"],"Typed native worker submits once and waits for real server admission",creator.status):proof();return
	expected.tailCallbacks=tail.callback_timings.duplicate(true);expected.buildTimings=creator.build_timings.duplicate(true)
	proof()
