extends "res://tests/native_creation_summary_binding_test.gd"
const LiveSpells=preload("res://systems/native_data/live_summary_spells.gd")
const Admission=preload("res://systems/native_data/character_record_entries.gd")
const LIST_SHA="a092ab8cb97c99c29aea4d176be647c34e703bb9b35f172336b91f93a1bf776d"
func list_oracle(path: String) -> void:
	check(FileAccess.get_sha256(path)==LIST_SHA,"Original live summary observations are pinned")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data.target==ORIGINAL and data.procedures==["0x1409c0920","0x1409c1810"] and data.feats.size()==15 and data.spells.size()==72,"Corpus executes actual live Feats and Spells callbacks, not only imported-BIC callbacks")
	for row in data.feats:
		var result:=Admission.feat_admission(row.case.main,row.case.bonus,func(id):return row.case.successors.get(str(id)))
		check(result.errors.is_empty() and result.ids==row.selected.map(func(id):return int(id)),"Original live feat successors and primary/bonus duplicate behavior match",row.case)
	for row in data.spells:
		var before:=JSON.stringify(row.case); var result:=LiveSpells.compute(row.case.source.stats,row.liveBooks,row.case.tables)
		check(result.ready and result.errors.is_empty(),"Live spell projection admits complete active rules")
		check(result.minimums==row.minimums and result.slots==row.slots.map(func(values):return values.map(func(value):return int(value))),"Live projection retains original numeric minimum, gain, specialization and prestige results")
		var captured: Array=[]
		for entry in result.entries:
			var spell: Dictionary=row.case.tables.spells.orderedRows[int(entry.id)] if not entry.summary else {}
			captured.append({"id":int(entry.id),"nameRef":int(entry.nameRef) if entry.summary else int(spell.Name),"icon":str(entry.icon) if entry.summary else str(spell.IconResRef).to_lower()})
		check(captured==row.captured.map(func(entry):return {"id":int(entry.id),"nameRef":int(entry.nameRef),"icon":entry.icon}),"Original live summary/known enumeration matches including unrestricted-class exclusion",captured)
		check(JSON.stringify(row.case)==before,"Summary inspection never mutates the draft/table source")
	var row: Dictionary=data.spells[2]; var source: Dictionary=row.case.source.stats.duplicate(true); var books: Array=row.liveBooks.duplicate(true)
	for level in 10: books[0].levels[level]=[]
	books[0].levels[0]=[0,0,65535]; var result:=LiveSpells.compute(source,books,row.case.tables)
	check(result.entries.filter(func(entry):return not entry.summary).map(func(entry):return [entry.id,entry.level])==[[0,0],[0,0]],"Live lists retain their actual stored level and duplicates instead of BIC regrouping by the active class column")
	check(not LiveSpells.compute(source,books,{}).ready,"Missing active rules keep spell content pending")
	source.classes[0].id=999; check(not LiveSpells.compute(source,books,row.case.tables).ready,"Unrepresentable original class storage is unavailable rather than an invented preview")
func press(control: Control,down: bool) -> void:
	var point:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; surface.push_input(motion,true)
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0; surface.push_input(event,true); await frames()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	list_oracle(args.oracle)
	surface=SubViewport.new(); surface.size=Vector2i(1600,1000); surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface)
	var base:=Catalog.new(); var active:=Catalog.new(); check(base.mount_install(args.install) and active.mount_install(args.install),"Original frame and active native data catalogs mount read-only")
	var painter:=Painter.new(); var art:=Doubles.HeadlessArt.new(); var fonts:=Doubles.HeadlessFonts.new(); painter.art=art; painter.fonts=fonts; painter.add_child(art); painter.add_child(fonts); art.loaded.connect(painter.art_loaded); surface.add_child(painter)
	var text:=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Source captions have a separate original TLK")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg"); ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator; creator.configure_source(painter,text,base,""); creator.open(73)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.summary_lists.size()==3,90),"Real creator binds all source summary list views",creator.resource_errors):
		var front=creator.source_frontend; var scope: Array=creator.summary_identity(); var wizard:=-1; var cleric:=-1
		for id in creator.rules.rows("classes").size():
			var label: String=str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()
			if label=="wizard": wizard=id
			if label=="cleric": cleric=id
		await page(creator,3); await choose(creator,"class",wizard); await recommend(creator)
		var feats=front.summary_lists["2"]; var spells=front.summary_lists["3"]
		check(front.summary_model.lists["2"].ready and not feats.entries.is_empty() and front.summary_model.lists["3"].ready and not spells.entries.is_empty(),"Actual active-rules recommendations populate the real draft's Feats and Spells")
		check(not front.summary_model.pending.has("skills") and not front.summary_model.pending.has("feats") and not front.summary_model.pending.has("spells") and not front.summary_lists["1"].entries.is_empty(),"Actual completed recommendations commit the live skill mask and populate all three source lists")
		check(not front.wanted and not front.surface.visible,"List binding does not prematurely activate the unfinished source creation workflow")
		front.begin(scope,{"classBase":wizard},creator.rules.rows("classes")); await frames()
		await click(front.main.summary_view.tabs[2])
		check(feats.is_visible_in_tree() and not spells.is_visible_in_tree(),"Actual source Feats tab selects the live draft list")
		await click(feats.rows[0]); var help: String=feats.description.get_parsed_text(); var identity: int=feats.rows[0].get_instance_id()
		check(feats.selected==0 and not help.is_empty(),"Actual native row click selects its feat and shows active-rule help")
		front.refresh(); check(feats.rows[0].get_instance_id()==identity and feats.selected==0 and feats.description.get_parsed_text()==help,"Unchanged summary refresh preserves selection, help and row controls")
		var ref: int=ui.desktop.rules.number(ui.desktop.rules.cell(ui.desktop.rules.row("feat",int(feats.entries[0].id)),"FEAT"),-1)
		ui.receive({"kind":"tlk-overrides","entries":[{"strRef":ref,"text":"Active feat summary"}]},-1)
		check(await wait_for(func():return feats.entries.any(func(entry):return entry.name=="Active feat summary")),"Late server TLK publication refreshes source list names without a new draft edit")
		check(text.raw({"strRef":ref})!="Active feat summary","Active list names do not overwrite source-frame TLK ownership")
		await click(front.main.summary_view.tabs[3]); await click(spells.rows[0])
		check(spells.selected==0 and not spells.description.get_parsed_text().is_empty(),"Actual source Spells tab and row click display known-spell help without casting")
		await press(spells.rows[0],true); front.open_child("portraitbutton"); await press(spells.rows[0],false)
		check(spells.held.is_empty(),"Opening an original child retires held summary-list input")
		front.retire_child(); front.dismiss(); creator.stage_source(); creator.refresh_source(); await frames()
		feats=front.summary_lists["2"]; spells=front.summary_lists["3"]
		await page(creator,3); await choose(creator,"class",cleric); await recommend(creator)
		check(front.summary_model.lists["3"].ready and front.summary_lists["3"].entries.size()==1 and front.summary_lists["3"].entries[0].summary,"Actual unrestricted Cleric draft shows the original highest-castable-level summary")
		var class_data: Dictionary=creator.rules.cls(); var old_restricted: Variant=creator.rules.cell(class_data,"SpellbookRestricted")
		class_data["SpellbookRestricted"]="1"; ui.text.mark_changed(); creator.render()
		check(front.summary_lists["3"].entries.is_empty(),"Active server class data changes live list policy; stock class-name assumptions do not override it")
		class_data["SpellbookRestricted"]=old_restricted; ui.text.mark_changed(); creator.render()
		front.begin(scope,{"classBase":cleric},creator.rules.rows("classes")); await frames(); await click(front.main.summary_view.tabs[3]); await click(spells.rows[0])
		check(spells.selected==0 and spells.description.get_parsed_text().is_empty(),"Original ID-minus-one summary selects without inventing spell help or a cast")
		creator.cancel(); check(feats.entries.is_empty() and spells.entries.is_empty() and not front.list_available(),"Cancellation clears scoped list content and input availability")
		creator.open(74); await wait_for(func():return creator.phase=="editing",90)
		check(front.summary_model.scope==creator.summary_identity() and front.summary_scope!=scope,"A replacement draft owns fresh list data after cancellation")
		check(creator.summary_source(scope,31,"Old").is_empty(),"Retired draft callbacks cannot publish old lists")
	check(not sent.any(func(message):return message.kind=="native-creation-submit" or message.kind in ["cast","feat","action"]),"Summary input never uploads a character, casts or fabricates a server action")
	ui.close(); ui.free(); painter.free(); surface.queue_free(); await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"sourceArtworkDouble":true,"fullUiParity":false,"scope":"Original live Feats/Spells enumeration and numeric instruction observations; real creation draft, source tabs/row input, active table/TLK changes, selection preservation and retirement. Skill-cache initialization, vitals, remaining children, graphical and server acceptance are separate."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
