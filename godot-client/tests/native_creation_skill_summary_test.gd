extends "res://tests/native_creation_summary_binding_test.gd"
const SkillSummary=preload("res://systems/native_data/creation_skill_summary.gd")
const SKILL_SHA="fdc72beff874b721c56affbd8fc3c842041196bfed5df37f9a8a141821254a60"
func expected(rows: Array) -> Array:
	return rows.map(func(entry):return {"id":int(entry.id),"value":int(entry.value),"lostAbilities":bool(entry.lostAbilities)})
func skill_oracle(path: String) -> void:
	check(FileAccess.get_sha256(path)==SKILL_SHA,"Original live skill-cache observations remain pinned")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data.target==ORIGINAL and data.rows.size()==72 and data.procedures==["0x1409bfda0","0x1409c8d10","0x1407fa8b0"],"Oracle executes live Skills display, complete OK and actual rank-write instructions")
	for row in data.rows:
		var before:=JSON.stringify(row.case); var stats: Dictionary=row.case.source; var tables: Dictionary=row.case.tables
		var initial:=SkillSummary.project(stats,tables,0); var calculated:=SkillSummary.calculate(stats,tables)
		check(initial.ready and calculated.ready and initial.entries==expected(row.initial),"Initial/reset mask does not infer eligibility from prefilled scores/ranks")
		check(int(calculated.mask)==int(row.mask),"Native committed eligibility matches original Skills OK")
		var committed:=SkillSummary.project(stats,tables,int(row.mask))
		check(committed.entries==expected(row.entries),"Original live values, signed arithmetic, lost-ability flags and32-bit mask aliasing match")
		if row.update!=null:
			var changed: Dictionary=stats.duplicate(true); changed.ranks[int(row.update.id)]=int(row.update.rank)
			var pending:=SkillSummary.project(changed,tables,int(row.mask))
			check(int(row.update.maskBeforeCommit)==int(row.mask) and pending.entries==expected(row.update.entriesBeforeCommit),"Original rank writes update values while retaining prior eligibility")
			var recalculated:=SkillSummary.calculate(changed,tables)
			check(int(recalculated.mask)==int(row.update.mask),"Reaccepting Skills rebuilds eligibility after zero/positive/signed-byte rank changes")
			check(SkillSummary.project(changed,tables,int(recalculated.mask)).entries==expected(row.update.entries),"Recommitted live rows match original after rank mutation")
		check(JSON.stringify(row.case)==before,"Skill inspection does not mutate source rules or draft")
	var source: Dictionary=data.rows[2].case.source.duplicate(true); var tables: Dictionary=data.rows[2].case.tables
	check(not SkillSummary.project(source,{},0).ready,"Unpublished rules retain pending skill content")
	source.classes[0].id=999; check(not SkillSummary.project(source,tables,0).ready,"Invalid live class storage is not silently normalized as an imported BIC")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	skill_oracle(args.oracle)
	surface=SubViewport.new(); surface.size=Vector2i(1600,1000); surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface)
	var base:=Catalog.new(); var active:=Catalog.new(); check(base.mount_install(args.install) and active.mount_install(args.install),"Actual source and active native catalogs mount read-only")
	var painter:=Painter.new(); var art:=Doubles.HeadlessArt.new(); var fonts:=Doubles.HeadlessFonts.new(); painter.art=art; painter.fonts=fonts; painter.add_child(art); painter.add_child(fonts); art.loaded.connect(painter.art_loaded); surface.add_child(painter)
	var text:=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Source caption ownership is independent of active data")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg"); ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator; creator.configure_source(painter,text,base,""); creator.open(91)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.summary_lists.size()==3,90),"Actual creator and source skill-list owners prepare",creator.resource_errors):
		var front=creator.source_frontend; var scope: Array=creator.summary_identity(); var fighter:=-1
		check(creator.rules.skill_summary_mask==0 and front.summary_model.lists["1"].ready and front.summary_lists["1"].entries.is_empty(),"Real initialized draft retains the original valid-but-empty skill cache")
		for id in creator.rules.rows("classes").size():
			if str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()=="fighter": fighter=id
		await page(creator,3); await choose(creator,"class",fighter); await recommend(creator)
		var skills=front.summary_lists["1"]
		check(creator.rules.skill_summary_mask!=0 and not skills.entries.is_empty() and not front.summary_model.pending.has("skills"),"Actual package recommendations commit eligible skills into the source summary")
		front.begin(scope,{"classBase":fighter},creator.rules.rows("classes")); await frames(); await click(front.main.summary_view.tabs[1]); await click(skills.rows[0])
		check(skills.is_visible_in_tree() and skills.selected==0 and not skills.description.get_parsed_text().is_empty(),"Actual source Skills tab and row input show active-rule help")
		check(skills.rows[0].get_children().any(func(child):return child is Label and child.text==str(int(skills.entries[0].value))),"Source skill row displays its integer value in the original value control")
		var ref: int=creator.rules.num(creator.rules.row("skills",int(skills.entries[0].id)),"Name",-1)
		ui.receive({"kind":"tlk-overrides","entries":[{"strRef":ref,"text":"Active skill summary"}]},-1)
		check(await wait_for(func():return skills.entries.any(func(entry):return entry.name=="Active skill summary")),"Late active-server TLK updates the live skill summary")
		front.dismiss(); creator.stage_source(); creator.refresh_source(); await frames(); skills=front.summary_lists["1"]
		await page(creator,3); await choose(creator,"class",fighter)
		check(creator.rules.skill_summary_mask==0 and skills.entries.is_empty(),"Actual upstream class replacement clears skill eligibility and ranks")
		await page(creator,8)
		var allocations:=0
		while creator.rules.skill_balance()>0 and allocations<80:
			var choice: Variant=null
			for id in creator.controls:
				var item: Dictionary=creator.controls[id]
				if item.operation=="skill" and int(item.value[1])==1 and not item.disabled: choice=item.value; break
			if choice==null: break
			await choose(creator,"skill",choice); allocations+=1
		check(allocations>0 and creator.rules.skill_balance()==0 and creator.rules.skill_summary_mask==0 and skills.entries.is_empty(),"Actual rank-allocation inputs do not prematurely rebuild the cleared skill mask")
		await click(creator.view.next); await frames()
		check(creator.step==9 and creator.rules.skill_summary_mask!=0 and not skills.entries.is_empty(),"Leaving a finished Skills allocation through actual Next commits the shared native cache")
		await page(creator,6)
		var candidate: Variant=null
		for id in creator.controls:
			var item: Dictionary=creator.controls[id]
			if item.operation=="ability" and int(item.value[1])==1 and not item.disabled: candidate=item.value; break
		if check(candidate!=null,"An actual upstream ability control can invalidate chosen skills"):
			await choose(creator,"ability",candidate)
			check(creator.rules.skill_summary_mask==0 and creator.rules.draft.skills.is_empty() and skills.entries.is_empty(),"Actual ability edit clears derived ranks and cached skill rows together")
		creator.cancel(); creator.open(92); await wait_for(func():return creator.phase=="editing",90)
		check(creator.rules.skill_summary_mask==0 and front.summary_scope!=scope and front.summary_lists["1"].entries.is_empty(),"Cancel/reopen owns a fresh empty skill cache without stale rows")
		check(creator.summary_source(scope,31,"Old").is_empty(),"Retired draft reads cannot publish old skill content")
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"Summary input never fabricates a character upload or original-server outcome")
	ui.close(); ui.free(); painter.free(); surface.queue_free(); await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"sourceArtworkDouble":true,"fullUiParity":false,"scope":"Original live Skills callback/accept/rank-write instructions and real native cache lifecycle, recommendations, skill allocation/Next, source tab/help/integer input, active TLK and reset/retirement. Source child workflow, vitals, pixels and authoritative server acceptance remain separate."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
