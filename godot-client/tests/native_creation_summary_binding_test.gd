extends "res://tests/native_creation_derived_reset_test.gd"
const Summary=preload("res://systems/native_data/creation_summary_values.gd")
const Doubles=preload("res://tests/native_portrait_chooser_test.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const SOURCE_SHA="d00dcf18d5c3844d335d55c8707388e1a515ca02c0433e4dfa36a749d8bcf9a8"
func oracle(path: String) -> void:
	check(FileAccess.get_sha256(path)==SOURCE_SHA,"Original bounded summary/title observations are unchanged")
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(data is Dictionary and data.binarySha256==ORIGINAL and data.region==["0x1409b6380","0x1409b72a5"] and data.title=="0x14088b180","Provider-confirmed original region and complete title routine identify the corpus"): return
	var fields:={"0x188":"classes","0x988":"title","0x940":"hitpoints","0x9d8":"armorclass"}
	for index in 6:
		fields["0x%x"%(0x220+index*0x130)]=Summary.KEYS[index].to_lower()+"stat"
		fields["0x%x"%(0x2b8+index*0x130)]=Summary.KEYS[index].to_lower()+"mod"
	for row in data.cases:
		var result:=Summary.compose(row.input,int(row.input.mask),{}); var matches:=true
		for offset in row.labels: matches=matches and result.labels[fields[offset]].text==row.labels[offset]
		check(matches,"All original masked header/title and fourteen numeric outputs match, mask="+str(int(row.input.mask)),result)
	check(Summary.full_name(""," Last ")==" Last " and Summary.full_name(" First ","")==" First " and Summary.full_name("First","Last")=="First Last","Original full-name joining preserves authored field contents")
func type_text(control: Control,value: String) -> void:
	await click(control)
	for point in value.length():
		var code:=value.unicode_at(point)
		for pressed in [true,false]:
			var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.unicode=code; event.pressed=pressed; surface.push_input(event,true); await frames()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	oracle(args.oracle)
	surface=SubViewport.new(); surface.size=Vector2i(1600,1000); surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface)
	var base:=Catalog.new(); var active:=Catalog.new(); check(base.mount_install(args.install) and active.mount_install(args.install),"Separate pregame and active catalogs mount the original install read-only")
	var override_dir: String=str(args.report)+".active"; DirAccess.make_dir_recursive_absolute(override_dir)
	var file:=FileAccess.open(override_dir.path_join("cg_main.gui"),FileAccess.WRITE); file.store_string("Different active-server GUI data must not replace the pregame frame"); file.close(); check(active.mount_directory(override_dir,99999999),"Active server catalog can contain a different CG_MAIN resource")
	var painter:=Painter.new(); var art:=Doubles.HeadlessArt.new(); var fonts:=Doubles.HeadlessFonts.new(); painter.art=art; painter.fonts=fonts; painter.add_child(art); painter.add_child(fonts); art.loaded.connect(painter.art_loaded); surface.add_child(painter)
	var text:=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Pregame captions have their independently owned original TLK")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg"); ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator; creator.configure_source(painter,text,base,""); creator.open(73)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.portrait.layout_ready,90),"Actual native creator and source summary/portrait owners prepare",creator.resource_errors):
		var front=creator.source_frontend; var scope: Array=creator.summary_identity(); await frames()
		check(front.main.assets.catalog==base and creator.rules.catalog==active and front.main.buttons.size()==11,"Source frame remains pregame-owned while actual draft rules/resources are active-server-owned")
		check(not front.wanted and not front.surface.visible and creator.view.panel.visible and front.summary_scope==scope and front.summary_model.get("scope")==scope,"Production owner stages and binds its real draft without prematurely replacing the unfinished creator")
		check(front.summary_model.mask==0 and front.main.summary_view.labels.strstat.text.is_empty(),"Default draft values do not imply completed creation choices")
		var fighter:=-1
		for id in creator.rules.rows("classes").size():
			if str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()=="fighter": fighter=id
		await page(creator,3); await choose(creator,"class",fighter); await recommend(creator)
		front.flow.summary_mask=31; front.refresh()
		await page(creator,13)
		var first: Control=await control_for(creator,"field","firstName"); var last: Control=await control_for(creator,"field","lastName")
		await type_text(first,"Owner"); await type_text(last,"Draft"); await page(creator,6)
		var view=front.main.summary_view
		check(view.labels.title.text==text.raw({"strRef":61826})+", Owner Draft" and front.summary_model.draft_revision==creator.serial,"Actual text-entry commit updates the bound real-draft title and revision")
		var before:=int(creator.rules.abilities().Str); await choose(creator,"ability",["Str",-1])
		check(int(view.labels.strstat.text)==int(creator.rules.abilities().Str) and int(view.labels.strstat.text)==before-1,"Actual ability input updates source summary values from the same native draft")
		check(not view.labels.hitpoints.text.is_empty() and not view.labels.armorclass.text.is_empty() and not front.summary_model.pending.has("hitpoints") and not front.summary_model.pending.has("armorclass"),"Committed native creation-vitals values reach the actual source summary without a BIC import")
		var hp_before:=int(view.labels.hitpoints.text.split("/")[1]); var armor_before:=int(view.labels.armorclass.text)
		if check(int(creator.rules.draft.abilities.Con)>=10 and int(creator.rules.draft.abilities.Dex)>=10,"Recommended fighter has two actual ability decrements available for vitals input"):
			for stat in ["Con","Dex"]:
				for count in 2: await choose(creator,"ability",[stat,-1])
			check(int(view.labels.hitpoints.text.split("/")[1])==hp_before-1 and int(view.labels.armorclass.text)==armor_before-1,"Actual CON/DEX mouse inputs update source HP/AC from their committed class cache")
		var ref: int=creator.rules.num(creator.rules.cls(),"Name",-1); var base_name:=text.raw({"strRef":ref})
		ui.receive({"kind":"tlk-overrides","entries":[{"strRef":ref,"text":"Active draft class"}]},-1)
		check(await wait_for(func():return view.labels.classes.text.contains("Active draft class (1)")),"Late active-server text revision refreshes bound summary content without another draft edit")
		check(text.raw({"strRef":ref})==base_name and front.main.text_owner==text,"Active text publication does not replace or mutate the independently owned pregame TLK")
		var values: Array=creator.rules.portraits(); check(not values.is_empty(),"The actual creation owner supplies admitted portrait choices")
		front.begin(scope,{"classBase":fighter},creator.rules.rows("classes")); front.flow.summary_mask=31; front.refresh(); front.open_child("portraitbutton"); await frames(5)
		await click(front.portrait.cells[0].button); await click(front.portrait.buttons.okbutton)
		check(creator.rules.draft.portrait==values[0] and front.flow.completed.portrait and front.child.is_empty(),"Actual original portrait-pane OK commits through the production creation owner and accepts its original child result")
		check(front.summary_model.get("portrait")==str(values[0])+"l" and front.summary_model.scope==scope,"The current draft portrait is published through the same scoped summary binding")
		creator.cancel(); check(front.summary_model.is_empty() and front.summary_scope.is_empty() and not front.wanted and view.labels.title.text==text.raw({"strRef":61826})+", ","Cancel retires the draft provider, portrait binding and displayed source values")
		creator.open(74); await wait_for(func():return creator.phase=="editing",90); await frames()
		var next_scope: Array=creator.summary_identity()
		check(next_scope!=scope and front.summary_scope==next_scope and front.summary_model.get("scope")==next_scope,"Reopened connection owns a fresh source-summary draft scope")
		check(creator.summary_source(scope,31,"Old").is_empty() and not creator.commit_source_portrait(str(values[0]),scope),"Retired source callbacks cannot read or mutate the replacement draft")
		check(not front.bind_summary(scope,creator.summary_source,ui.desktop.art) and front.summary_scope==next_scope,"Late old-scope summary binding cannot poison a staged but hidden replacement draft")
		check(not front.bind_portraits(scope,values,"",ui.desktop.art,active,creator.commit_source_portrait) and front.portrait_scope==next_scope,"Late old-scope portrait data cannot poison a hidden draft whose summary already owns the new scope")
		var reentrant:=func(_identity,_mask,_prefix): front.dismiss(); return {"scope":next_scope,"labels":{"title":{"text":"STALE"}}}
		front.bind_summary(next_scope,reentrant,ui.desktop.art)
		check(front.summary_model.is_empty() and front.summary_scope.is_empty() and view.labels.title.text!= "STALE","Reentrant draft retirement prevents an otherwise matching summary reply from publishing")
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"Summary/portrait inspection never invents a character upload or server outcome")
	ui.close(); ui.free(); await frames()
	var late_ui:=Gameplay.new(); surface.add_child(late_ui); late_ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".late-layout.cfg")
	late_ui.creator.open(91)
	if check(await wait_for(func():return late_ui.creator.phase=="editing",90),"A real native draft can become ready before pregame source binding"):
		check(not is_instance_valid(late_ui.creator.source_frontend),"Delayed source binding starts without a duplicate frontend")
		late_ui.creator.configure_source(painter,text,base,"")
		check(await wait_for(func():return late_ui.creator.source_frontend.main.layout_ready and late_ui.creator.source_frontend.summary_model.get("scope",[])==late_ui.creator.summary_identity()),"Late pregame readiness immediately binds the current live draft summary")
		check(late_ui.creator.source_frontend.portrait_scope==late_ui.creator.summary_identity() and not late_ui.creator.source_frontend.wanted,"Late binding also supplies actual current portraits without activating unfinished presentation")
	late_ui.close(); late_ui.free(); painter.free(); surface.queue_free(); await frames(5)
	file=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"sourceArtworkDouble":true,"scope":"Pinned bounded original mask/ability/vitals region and complete title observations; actual shipping creator draft edits, active text publication, source portrait commit, independent pregame resources and lifecycle. Source frame staging remains hidden pending full original child workflow; unported vitals/details/lists and graphical/server acceptance remain separate."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
