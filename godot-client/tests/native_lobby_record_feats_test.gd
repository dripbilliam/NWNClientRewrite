extends "res://tests/native_character_lobby_frame_test.gd"
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Digest=preload("res://systems/native_data/prepared_cache.gd")
func run() -> void:
	var output:=""; var install:=""; var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--oracle="): oracle=arg.substr(9)
	if output.is_empty() or install.is_empty() or oracle.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Pregame Feats mounts installed resources read-only")
	var game:=Gameplay.new(); surface.add_child(game); game.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); game.set_gameplay_visible(false)
	check(await wait_until(func():return game.tables_ready),"Active native rules prepare for BIC feat presentation")
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle)); var admission=preload("res://systems/native_data/character_record_entries.gd")
	check(original.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.procedure=="0x1409c0db0","Oracle executes the exact original mode-zero pregame callback")
	for case in original.rows:
		var successors: Dictionary=case.case.successors; var result: Dictionary=admission.feat_admission(case.case.main,case.case.bonus,func(id):return successors.get(str(int(id))))
		check(result.ids==case.selected.map(func(id):return int(id)) and result.errors.is_empty(),"Native admission matches unchanged original pregame instructions: "+str(case.case.main)+"/"+str(case.case.bonus))
	var feats: Dictionary=game.text.tables.feat.duplicate(true); var overrides: Array=[]
	for at in range(1,27):
		feats.orderedRows[at].FEAT=str(16777216+at); feats.orderedRows[at].Description=str(16777316+at); feats.orderedRows[at].SUCCESSOR="-1"
		overrides.append({"strRef":16777216+at,"text":"Feat %02d"%[27-at]}); overrides.append({"strRef":16777316+at,"text":"Server feat %d description.\n"%at+"Long native help text.\n".repeat(30)})
	feats.orderedRows[1].SUCCESSOR="2"; feats.orderedRows[3].FEAT="****"; game.text.publish_table("feat",feats); game.receive({"kind":"tlk-overrides","entries":overrides},-1)
	var feat_list: Array=[]
	for at in range(1,27): feat_list.append(Writer.record({"Feat":Writer.field(2,at)}))
	var policy=preload("res://systems/native_data/game_ui_rules.gd").new(); policy.text=game.text; var known_ids: Array=[]
	for level in [0,1]:
		for id in game.text.tables.spells.orderedRows.size():
			if policy.spell_level(id,10)==level and not game.text.raw({"strRef":policy.number(policy.cell(policy.row("spells",id),"Name"),4294967295)}).is_empty() and not game.text.rich({"strRef":policy.number(policy.cell(policy.row("spells",id),"SpellDesc"),4294967295)},-1).get("text","").is_empty() and policy.icon("spells",id) not in ["","****"]: known_ids.append(id); break
	check(known_ids.size()==2,"Original active wizard spell columns supply one cantrip and first-level fixture spell")
	var known: Array=[]
	for id in [known_ids[0],known_ids[1],known_ids[0]]: known.append(Writer.record({"Spell":Writer.field(2,id)}))
	var fields:={"FirstName":Writer.field(12,{"strRef":4294967295,"entries":[{"languageId":0,"text":"Native record preview"}]}),"FeatList":Writer.field(15,feat_list),"Race":Writer.field(0,6),"ClassList":Writer.field(15,[Writer.record({"Class":Writer.field(5,10),"ClassLevel":Writer.field(3,4),"KnownList9":Writer.field(15,known)}),Writer.record({"Class":Writer.field(5,3),"ClassLevel":Writer.field(3,5)})])}
	for ability in ["Str","Dex","Con","Int","Wis","Cha"]: fields[ability]=Writer.field(0,14)
	var skills: Array=[]
	for at in game.text.tables.skills.orderedRows.size()&255: skills.append(Writer.record({"Rank":Writer.field(0,5)}))
	fields.SkillList=Writer.field(15,skills)
	var raw:=Writer.new().write("BIC ",Writer.record(fields))
	var directory:=output.trim_suffix(".json")+"-sources"; DirAccess.make_dir_recursive_absolute(directory); var digest:=Digest.digest(raw); var path:=directory.path_join(digest+".bic"); var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(raw); file.close()
	ui=Lobby.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_preview(directory); ui.configure_native(game.inventory.frame_skin,game.text,catalog,game.assets.cache_directory); native=ui.native_chooser
	state={"phase":"character-selection","connected":true,"canSelect":true,"canCreate":true,"selected":"installed:feats","choices":[{"key":"installed:feats","label":"Native feat preview","source":"installed","pregenerated":false}],"preview":{"format":"native-bic-file-v1","sha256":digest,"bytes":raw.size(),"path":path}}
	await present()
	check(await wait_until(func():return native.layout_ready and not ui.native_preview.value.is_empty()),"Actual native BIC worker prepares the original chooser")
	if native.layout_ready:
		var pane=native.record_feats; var before:=requests.size()
		check(await wait_until(func():return native.skill_projection.get("ready",false) and native.spell_projection.get("ready",false) and native.rule_jobs.is_empty()),"Active class skill/stat/spell dependencies load through native workers before record tabs enable")
		check(not native.record_tabs[2].disabled and not native.record_tabs[1].disabled and not native.record_tabs[3].disabled,"All three native list tabs are available for a typed original BIC preview")
		await click(native.record_tabs[1].get_global_rect().get_center())
		var skill_pane=native.record_skills
		print("NATIVE_SKILL_FRAME ",JSON.stringify({"page":native.record_index,"rows":skill_pane.rows.size(),"source_rows":skills.size(),"projection":native.skill_projection}))
		var restricted: Dictionary=game.text.tables.skills.orderedRows[11]; var class_rule: Dictionary=game.text.tables.classes.orderedRows[10]; var skill_table: String=str(native.rules.cell(class_rule,"SkillsTable")).to_lower()
		check(native.rules.number(native.rules.cell(restricted,"Untrained"))==1 and native.rules.number(native.rules.cell(restricted,"AllClassesCanUse"))==0 and not game.text.tables[skill_table].orderedRows.any(func(row):return native.rules.number(native.rules.cell(row,"SkillIndex"))==11),"Owned original skill11 is untrained but unavailable to the fixture's wizard class")
		check(native.record_index==1 and skills.size()==28 and skill_pane.rows.size()==27 and not skill_pane.entries.any(func(row):return row.id==11) and native.skill_projection.scores==[14,14,14,14,14,14] and skill_pane.entries.all(func(row):return row.value==7),"Typed BIC ranks and original active modifiers populate exactly the source-eligible wizard Skills rows")
		await click(skill_pane.rows[0].get_global_rect().get_center())
		check(skill_pane.selected==0 and not skill_pane.description.get_parsed_text().is_empty() and skill_pane.rows[0].get_child(2).text=="7","Actual original Skill row input selects active help and its separate value attachment")
		if DisplayServer.get_name()!="headless":
			check(await wait_until(func():return game.inventory.frame_skin.art.waiting.is_empty() and game.inventory.frame_skin.art.models.pending.is_empty() and not game.inventory.frame_skin.art.models.active),"Original Skills artwork settles before pixel review")
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+"-skills.png")==OK,"Native Skills viewport saved at source proportions")
			ui.panel.scale=Vector2(1.25,1.25); ui.panel.position=Vector2(80,50); await process_frame
			await click(skill_pane.rows[1].get_global_rect().get_center()); check(skill_pane.selected==1 and skill_pane.rows[1].get_child(2).text=="7","Original Skill row/value input remains aligned at125-percent scale")
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+"-skills-125.png")==OK,"Native Skills viewport saved at125-percent scale")
			ui.panel.scale=Vector2.ONE; ui.panel.position=(Vector2(surface.size)-native.size)/2; await process_frame
		await click(native.record_tabs[3].get_global_rect().get_center())
		var spell_pane=native.record_spells; var summary_index:=-1; var known_index:=-1
		for at in spell_pane.entries.size():
			if spell_pane.entries[at].get("summary",false): summary_index=at
			else: known_index=at
		check(native.record_index==3 and spell_pane.rows.size()==4 and summary_index>=0 and spell_pane.entries[summary_index].nameRef==68533 and spell_pane.entries[summary_index].icon=="ir_level3","Original Spells tab shows three known rows and the third-level Druid summary with its original icon/ref")
		check(spell_pane.entries.filter(func(entry):return entry.id==known_ids[0]).size()==2 and spell_pane.entries.filter(func(entry):return not entry.summary).all(func(entry):return entry.level in [0,1]),"Known spells retain duplicate private rows and regroup from KnownList9 by active class levels")
		await click(spell_pane.rows[known_index].get_global_rect().get_center()); var spell_help: String=spell_pane.description.get_parsed_text()
		check(spell_pane.selected==known_index and not spell_help.is_empty(),"Actual original known-spell row input displays active spell help without casting")
		await click(spell_pane.rows[summary_index].get_global_rect().get_center())
		check(spell_pane.selected==summary_index and spell_pane.description.get_parsed_text()==spell_help,"Original ID-minus-one summary changes selection while retaining the prior spell description")
		check(requests.size()==before,"Pregame Skills/Spells inspection issues no fabricated gameplay or casting request")
		if DisplayServer.get_name()!="headless":
			check(await wait_until(func():return game.inventory.frame_skin.art.waiting.is_empty() and game.inventory.frame_skin.art.models.pending.is_empty() and not game.inventory.frame_skin.art.models.active),"Original Spells icons and artwork settle for visual review")
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+"-spells.png")==OK,"Native Spells viewport saved at source proportions")
			ui.panel.scale=Vector2(1.25,1.25); ui.panel.position=Vector2(80,50); await process_frame
			await click(spell_pane.rows[known_index].get_global_rect().get_center()); check(spell_pane.selected==known_index,"Original spell row input follows125-percent canvas transforms")
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+"-spells-125.png")==OK,"Native Spells viewport saved at125-percent scale")
			ui.panel.scale=Vector2.ONE; ui.panel.position=(Vector2(surface.size)-native.size)/2; await process_frame
		await click(native.record_tabs[2].get_global_rect().get_center())
		var decoded: int=ui.native_preview.stats.decoded
		game.receive({"kind":"tlk-overrides","entries":[{"strRef":68533,"text":"Server Druid summary"},{"strRef":0x145f,"text":"Server spell tooltip"}]},-1)
		await click(native.record_tabs[3].get_global_rect().get_center())
		check(await wait_until(func():return spell_pane.entries.any(func(entry):return entry.get("summary",false) and entry.name=="Server Druid summary") and native.record_tabs[3].tooltip_text=="Server spell tooltip"),"Late server TLK overrides refresh both original spell summary text and the tab tooltip")
		check(ui.native_preview.stats.decoded==decoded,"Updating server spell text does not reread or reparse BIC bytes")
		await click(native.record_tabs[2].get_global_rect().get_center())
		check(native.record_index==2 and pane.is_visible_in_tree() and not native.statistics.visible,"Actual original Feats tab swaps only the embedded record body")
		check(pane.entries.size()==24 and not pane.entries.any(func(row):return row.id in [1,3]),"BIC feat ownership applies active successor admission and inactive-row filtering")
		check(pane.entries[0].id==26 and pane.entries[-1].id==2,"Native pregame feat rows use original bytewise label ordering")
		check(is_equal_approx(pane.list_rect.end.y,pane.size.y) and int(pane.bars[1].plan.size_pixels)==int(pane.size.y-14-pane.bars[1].plan.attachment.y+0.5),"Mode-zero list reaches the original page bottom with a14-pixel scrollbar endpoint inset")
		check(pane.description.get_parsed_text().is_empty() and pane.selected==-1,"Fresh SetData clears selection and description")
		await click(pane.rows[0].get_global_rect().get_center())
		check(pane.selected==0 and pane.rows[0].button_pressed and pane.description.get_parsed_text().begins_with("Server feat 26 description."),"Original row input selects and displays active server feat help")
		check(requests.size()==before,"Pregame inspection issues no fabricated cast or gameplay request")
		check(await wait_until(func():return pane.bars.all(func(bar):return bar.art_ready) and pane.description_scroll.get_v_scroll_bar().max_value>pane.description_scroll.get_v_scroll_bar().page),"Original scrollbar artwork and long native help content become ready before input")
		await click(pane.bars[1].down.get_global_rect().get_center()); await click(pane.bars[0].down.get_global_rect().get_center())
		check(pane.list.scroll_vertical>0 and pane.description_scroll.scroll_vertical>0,"Both original scrollbar arrows move their native list/help content")
		var kept: int=pane.list.scroll_vertical
		await click(native.record_tabs[0].get_global_rect().get_center()); await click(native.record_tabs[2].get_global_rect().get_center())
		check(pane.selected==0 and pane.list.scroll_vertical==kept,"Returning to the unchanged page retains the selected description and list position")
		game.receive({"kind":"tlk-overrides","entries":[{"strRef":16777242,"text":"AAA changed feat"},{"strRef":16777342,"text":"Changed current server help."}]},-1)
		check(await wait_until(func():return pane.entries[0].name=="AAA changed feat" and pane.selected==-1),"Same-key TLK publication updates/reorders rows and retires old selection")
		await click(pane.rows[0].get_global_rect().get_center()); check(pane.description.get_parsed_text()=="Changed current server help.","Selected help uses the current override, not a stale BIC or UI cache")
		await mouse(pane.rows[0].get_global_rect().get_center(),true); state.selected="installed:other"; state.choices[0].key="installed:other"; await present(); await mouse(pane.rows[0].get_global_rect().get_center(),false)
		check(pane.selected==-1 and pane.description.get_parsed_text().is_empty(),"Changing character during a held row cancels its obsolete selection")
		await click(native.record_tabs[0].get_global_rect().get_center()); await mouse(native.record_tabs[2].get_global_rect().get_center(),true); await present(2); await mouse(native.record_tabs[2].get_global_rect().get_center(),false)
		check(native.record_index==0,"A connection change cancels a held tab and resets its private page")
		await click(native.record_tabs[2].get_global_rect().get_center()); ui.panel.scale=Vector2(1.25,1.25); ui.panel.position=Vector2(80,50); await process_frame
		await click(pane.rows[0].get_global_rect().get_center()); check(pane.selected==0,"Original row hit geometry follows125-percent UI transforms")
		check(pane.rows[0].size.y==34 and pane.rows[1].position.y-pane.rows[0].position.y==36 and pane.rows[0].get_child(0).size==Vector2(32,32),"Original row artwork keeps34-pixel height,36-pixel advance and32-square icons")
		if DisplayServer.get_name()!="headless":
			check(await wait_until(func():return game.inventory.frame_skin.art.waiting.is_empty() and game.inventory.frame_skin.art.models.pending.is_empty() and not game.inventory.frame_skin.art.models.active),"Original page/row/icon artwork settles for native pixel review")
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+"-125.png")==OK,"Scaled pregame Feats viewport saved")
			ui.panel.scale=Vector2.ONE; ui.panel.position=(Vector2(surface.size)-native.size)/2; await process_frame; await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Original-scale pregame Feats viewport saved")
		state.phase="playing"; await present(2); check(not native.is_visible_in_tree() and not pane.is_visible_in_tree(),"Admission hides the pregame page")
		ui.close_native(); check(pane.closed and pane.bars.is_empty(),"Closing the chooser retires both original page scrollbar owners")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	ui.free(); game.close(); game.free(); await process_frame; await process_frame
	var out:=FileAccess.open(output,FileAccess.WRITE); out.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"fullCharacterLobbyParity":false,"fullSkillUiParity":false,"scope":"Actual native BIC worker and original pregame Skills/Feats tabs, active server admission/order/values/descriptions, original controls, stale input, scroll and125-percent input. Spells/derived combat and complete original-client comparison remain open."},"  ")+"\n"); out.close(); quit(0 if failures.is_empty() else 1)
