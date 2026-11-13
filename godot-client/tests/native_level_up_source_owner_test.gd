extends "res://tests/native_level_up_source_controls_test.gd"
const Frontend=preload("res://systems/native_level_up_frontend.gd")
const Owner=preload("res://systems/native_data/level_up_source_owner.gd")
const HitDie=preload("res://systems/native_data/level_up_hit_die.gd")
const DefinitionTables=preload("res://systems/native_data/creation_feat_tables.gd")
var front
var owner:=Owner.new()
var submissions: Array=[]
var cancellations: Array=[]
var summaries: Array=[]
func gate(value: bool,label: String) -> bool:check(value,label);return value
func wait_for(predicate: Callable) -> bool:
	var until:=Time.get_ticks_msec()+22000
	while Time.get_ticks_msec()<until:
		if predicate.call():return true
		await process_frame
	return false
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var post_mode: bool=args.get("post","false")=="true"
	var spell_mode: bool=args.get("spells","false")=="true" or post_mode
	catalog=Catalog.new();check(catalog.mount_install(args.install),"Actual original mode1 controls mount read-only")
	base_text=preload("res://systems/native_data/talk_text.gd").new();active_text=preload("res://systems/native_data/talk_text.gd").new()
	check(base_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")) and active_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Artwork captions and active server names have separate TLK owners")
	active_text.overrides[100]="Server current class";active_text.overrides[101]="Server current skill";active_text.overrides[102]="Server current feat"
	surface=SubViewport.new();surface.size=Vector2i(1200,850);surface.disable_3d=true;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	painter=Painter.new();painter.art=Art.new();painter.fonts=Doubles.HeadlessFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);painter.art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	front=Frontend.new();surface.add_child(front);front.configure(painter,base_text,catalog,"");owner.configure(front)
	owner.submission_requested.connect(func(proposal,token,identity):submissions.append([proposal.duplicate(true),token,identity.duplicate()]))
	owner.cancellation_requested.connect(func(token,identity,pending):cancellations.append([token,identity.duplicate(),pending]))
	owner.summary_requested.connect(func(private_draft,ticket):
		var numeric:=HitDie.compose(owner.finalization_snapshot(ticket),owner.tables,{})
		summaries.append([private_draft.duplicate(true),ticket.duplicate(),numeric.duplicate(true)])
		if numeric.ready:owner.set_summary({"ready":true,"summary":"Prepared original summary","hitDie":int(numeric.hitDie)},ticket))
	var tables:={"classes":{"orderedRows":[{"Name":"100","Description":"200","PlayerClass":"1","SkillsTable":"server_skills","FeatsTable":"server_feats","AttackBonusTable":"server_bab","SkillPointBase":"2","PickDomains":"0","PickSchool":"0","SpellbookRestricted":"0","SkipSpellSelection":"0","MinAssociateLevel":"255","Arcane":"0"}]},"racialtypes":{"orderedRows":[{"NormalFeatEveryNthLevel":"3","NumberNormalFeatsEveryNthLevel":"1"}]},"ruleset":{"orderedRows":[]},"skills":{"orderedRows":[{"Name":"101","Description":"201","KeyAbility":"STR","Untrained":"1","AllClassesCanUse":"1"}]},"server_skills":{"orderedRows":[{"SkillIndex":"0","ClassSkill":"1"}]},"server_feats":{"orderedRows":[]},"server_bab":{"orderedRows":[{"BAB":"1"},{"BAB":"2"},{"BAB":"30"}]},"feat":{"orderedRows":[{"Feat":"99","AllClassesCanUse":"1"},{"Feat":"102","Description":"202","AllClassesCanUse":"1","MinAttackBonus":"22","Icon":"if_powerattack"}]}}
	var received:={"actorId":42,"race":0,"classes":[{"id":0,"level":2}],"baseAbilities":[12,12,14,14,12,12],"skills":[1],"fieldDC6":0,"feats":[0],"fieldC0":0,"fieldD4":0,"fieldE34":-1,"fieldE48":"Copied familiar","fieldE30":-1,"fieldE38":"Copied companion"}
	tables.classes.orderedRows[0].HitDie="8"
	if spell_mode:
		tables.classes.orderedRows[0].merge({"SpellCaster":"1","MemorizesSpells":"1","LearnScroll":"1","SpellbookRestricted":"1","SpellcastingAbil":"INT","SpellGainTable":"server_gain","SpellTableColumn":"ServerCaster","Arcane":"1"},true)
		tables.server_gain={"orderedRows":range(3).map(func(_at):return {"NumSpellLevels":"2","SpellLevel0":"3","SpellLevel1":"2"})}
		tables.spells={"orderedRows":range(4).map(func(at):return {"Name":str(300+at),"SpellDesc":str(400+at),"ServerCaster":"0" if at==0 else "1","School":"A","IconResRef":"server_spell"+str(at)})}
		received.classes[0].school=0;received.spellbooks={"0":{"known":[0,1]}}
		for id in 6:active_text.overrides[300+id]="Server spell "+str(id)
	if post_mode:
		var new_class: Dictionary=tables.classes.orderedRows[0].duplicate();new_class.merge({"PickDomains":"1","PickSchool":"1","Package":"1"},true);tables.classes.orderedRows.append(new_class)
		tables.classes.orderedRows[0].merge({"SpellCaster":"0","Arcane":"0","ArcSpellLvlMod":"0","DivSpellLvlMod":"0"},true)
		received.classes[0].level=3;received.spellbooks["0"].known=[]
		tables.ruleset.orderedRows.append({"Label":"MIN_LEVEL_FOR_MAX_HP","Value":"4"})
		tables.server_bab.orderedRows[0].BAB="30";tables.classes.orderedRows[1].BonusFeatsTable="server_bonus";tables.server_bonus={"orderedRows":[{"Bonus":"1"}]}
		tables.server_feats.orderedRows.append({"FeatIndex":"1","GrantedOnLevel":"0","List":"2"})
		tables.server_feats.orderedRows.append({"FeatIndex":"2","GrantedOnLevel":"99","List":"3"});tables.feat.orderedRows.append({"Feat":"103","AllClassesCanUse":"1"})
		tables.packages={"orderedRows":[{"Domain1":"2","Domain2":"0","School":"0"},{"Domain1":"0","Domain2":"2","School":"5"}]}
		tables.domains={"orderedRows":[{"Name":"501","Description":"601","GrantedFeat":"0"},{"Name":"0"},{"Name":"502","Description":"602","GrantedFeat":"2"}]}
		tables.spellschools={"orderedRows":range(9).map(func(id):return {"StringRef":str(700+id),"Description":str(800+id),"Opposition":"0"})}
		tables.spells.orderedRows=range(6).map(func(id):return {"Name":str(300+id),"SpellDesc":str(400+id),"ServerCaster":"0" if id==0 else "1","School":"A","IconResRef":"server_spell"+str(id)})
	if not tables.classes.orderedRows[0].has("SpellCaster"):tables.classes.orderedRows[0].SpellCaster="0"
	var prepared_definitions:=DefinitionTables.decode(tables.feat);owner.configure_definitions(func():return prepared_definitions)
	var before:=received.duplicate(true);var begin:={"token":11,"snapshot":received,"available":[false,true] if post_mode else [true],"protocolFeatures":{"multiclassRuleset":true},"draftContext":{"baseFortitude":0}}
	check(owner.begin(begin,[91,42,3],tables,active_text,painter.art).ready,"Staged source owner consumes typed begin result and separate private context")
	if gate(await wait_for(func():return front.panes.has("class") and front.panes["class"].layout_ready),"Actual Class controls prepare through the staged owner"):
		var stale: Array=front.ticket.duplicate();await click(front.panes["class"].buttons.okbutton)
		if post_mode and gate(await wait_for(func():return front.panes.has("attributes") and front.panes.attributes.layout_ready),"Original total4 enters actual level-up Attributes before Skills"):
			await click(front.panes.attributes.buttons.intupbutton)
			check(owner.attributes.selected==3 and front.panes.attributes.points.text=="0","Actual original attribute arrow spends the private one-point choice")
			await click(front.panes.attributes.buttons.okbutton)
		if gate(await wait_for(func():return front.panes.has("skills") and front.panes.skills.layout_ready),"Physical Class OK transfers into the real mode1 Skills view"):
			check(owner.navigation.stage=="skills" and front.panes.skills.ranks[0].text=="1" and front.panes.skills.points.text=="4","Original current level and received rank baseline drive the owned source controls")
			owner.action("skills","up",0,stale);check(owner.skills.ranks==[1],"Retired Class ticket cannot alter owned Skills")
			await click(front.panes.skills.buttons["up:0"]);check(owner.skills.ranks==[2] and owner.skills.changes()==[1],"Physical Skills edits reach the actual separate private state owner")
			await click(front.panes.skills.buttons.okbutton)
			if gate(await wait_for(func():return front.panes.has("feats") and front.panes.feats.layout_ready and front.panes.feats.info_popup.layout_ready and front.panes.feats.group_popup.layout_ready),"Owned Skills OK transfers to actual Feats/source children"):
				await click(front.panes.feats.buttons["available:0:arrow"]);check(owner.feats.selected==[1],"Physical custom Feat add edits the owned mode1 private chooser")
				await click(front.panes.feats.buttons.okbutton)
				if post_mode and gate(await wait_for(func():return front.panes.has("domains") and front.panes.domains.layout_ready),"New mode1 class enters original Domain controls"):
					var domain_pane=front.panes.domains;var domain_ticket: Array=front.ticket.duplicate()
					owner.accepted_child("school",5,domain_ticket);check(owner.navigation.stage=="domains" and owner.selected_school==-1,"Wrong-stage child callback cannot borrow the current Domain ticket")
					await click(domain_pane.buttons.recommendbutton)
					check(domain_pane.state.chosen==[0,2] and not domain_pane.buttons.okbutton.disabled,"Actual mode1 Domain recommendation uses the new class Package1, not copied slot0 Package0")
					await click(domain_pane.buttons.okbutton)
					if gate(await wait_for(func():return front.panes.has("school") and front.panes.school.layout_ready),"Domain OK transfers to original School controls"):
						check(owner.selected_domains==[0,2] and owner.domain_grants==[0,2],"Original Domain fields/granted WORDs remain separate from manual feat allocation")
						await click(front.panes.school.buttons.recommendbutton)
						check(front.panes.school.state.selected==5,"Actual later-class School recommendation uses its active class Package")
						await click(front.panes.school.buttons.okbutton)
				if spell_mode and gate(await wait_for(func():return front.panes.has("spells") and front.panes.spells.layout_ready),"Mode1 restricted caster transfers to actual original Spells controls"):
					var pane=front.panes.spells
					check(pane.model.ready and pane.model.level==1 and pane.remaining.text==("5" if post_mode else "2") and owner.spells.state.baseline[1]==([] if post_mode else [1]),"Original mode1 new/current class receives its exact scroll budget and copied/constructor book")
					for action in 5 if post_mode else 2:await click(pane.buttons["available:0:arrow"])
					check(owner.spells.state.known[1]==([1,2,3,4,5] if post_mode else [1,2,3]) and pane.remaining.text=="0" and not pane.buttons.okbutton.disabled,"Actual original spell arrows edit only the copied private book and exact mode1 budget")
					await click(pane.buttons.okbutton)
				if gate(await wait_for(func():return front.panes.has("summary") and front.panes.summary.layout_ready),"Owned Feats OK reaches original Summary and explicit finalization provider"):
					check(summaries.size()==1 and summaries[0][0].skills==[1] and summaries[0][0].selectedFeats==[1] and summaries[0][2].ready and summaries[0][2].hitDie==8 and summaries[0][2].randomCalls==0,"Summary receives private draft and source-backed active-rule numeric maximum branch without actor mutation or invented RNG/application state")
					await click(front.panes.summary.buttons.okbutton);await click(front.panes.summary.buttons.okbutton)
					var expected:={"classId":0,"ability":6,"skills":[1],"skillPoints":3,"fieldE34":-1,"fieldE48":"Copied familiar","fieldE30":-1,"fieldE38":"Copied companion","hitDie":8,"feats":[1],"known":{},"removed":{},"domains":[],"school":0}
					if spell_mode:
						for level in 10:expected.known[level]=([1,2,3,4,5] if post_mode else [2,3]) if level==1 else [0] if post_mode and level==0 else [];expected.removed[level]=[]
					if post_mode:expected.classId=1;expected.ability=3;expected.feats=[1,2];expected.domains=[0,2];expected.school=5
					check(submissions==[[expected,11,[91,42,3]]] and owner.navigation.submitted and front.panes.summary.wanted,"Original Summary produces one exact proposal intent/token and remains pending, without a fabricated ACK")
					await click(front.panes.summary.buttons.cancelbutton)
					check(cancellations==[[11,[91,42,3],true]] and not owner.wanted,"Physical Summary Cancel retires source UI and preserves pending-submit ownership distinction")
					owner.accepted("class",0,stale);check(not owner.wanted and submissions.size()==1,"Late original control callback cannot reopen or resubmit a retired source transaction")
	begin.token=12;begin.draftContext={};owner.begin(begin,[92,42,3],tables,active_text,painter.art);await frames();await click(front.panes["class"].buttons.okbutton);await frames()
	if post_mode:await click(front.panes.attributes.buttons.intupbutton);await click(front.panes.attributes.buttons.okbutton);await frames()
	await click(front.panes.skills.buttons.okbutton);await frames()
	check(owner.navigation.stage=="skills" and not front.panes.skills.model.ready and not front.panes.skills.buttons.cancelbutton.disabled and submissions.size()==1,"Missing separate received base-save context blocks progression safely, without assuming a zero constructor/live value")
	await click(front.panes.skills.buttons.cancelbutton);check(cancellations[-1]==[12,[92,42,3],false],"Pending original-data preparation can cancel through its current owner/token")
	check(not owner.begin({"token":13,"snapshot":received,"available":[true],"protocolFeatures":null},[93],tables,active_text,painter.art).ready,"Malformed capability context fails without entering source controls")
	check(received==before,"Complete staged owner/control flow preserves every received snapshot field")
	owner.close();front.close();front.free();painter.art.close();painter.close();painter.queue_free();base_text.close();active_text.close();await frames(5);surface.queue_free();await frames()
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"spells":spell_mode,"postChildren":post_mode,"gpu":false,"serverConnections":0,"runtimeIntegrated":false,"scope":"Actual installed Class→optionalAttributes→mode1 Skills→Feats→optionalDomains/School/Spells→Summary bound to staged private source owner and source-backed numeric maximum branch; authored summary text, no high-level app/random producer, runtime entry, Associate jobs/commit, other-class school slot-cache presentation, server or pixels."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
