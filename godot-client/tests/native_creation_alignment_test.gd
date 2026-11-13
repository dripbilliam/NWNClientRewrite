extends "res://tests/native_creation_gender_test.gd"
const Alignment=preload("res://systems/native_data/creation_alignment_state.gd")
const AlignmentRules=preload("res://systems/native_data/alignment_rules.gd")
func alignment_oracle(path: String) -> void:
	check(FileAccess.get_sha256(path)=="12f5b05687adb787ef7c6e591b4b18d99699300edc546159b5e1675a7be04355","Immutable original Alignment instruction corpus")
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));check(corpus.binarySha256==ORIGINAL and corpus.restrictions.size()==2304 and corpus.rows.size()==180,"Original class restrictions and full Alignment callback sequences")
	for row in corpus.restrictions:
		var input: Dictionary=row.input
		check(AlignmentRules.allowed({"AlignRestrict":input.mask,"AlignRstrctType":input.axes,"InvertRestrict":input.invert},int(input.good),int(input.law))==(int(row.result)!=0),"Original complete class restriction bitmask/inversion comparison",input)
	for row in corpus.rows:
		var input: Dictionary=row.input;var state:=Alignment.new();var data:={"AlignRestrict":input.mask,"AlignRstrctType":input.axes,"InvertRestrict":input.invert}
		state.reset(data,int(input.classId),int(input.goodEvil),int(input.lawChaos))
		check(state.selected==int(row.initial.selected) and state.help_title==int(row.initial.help["0x628"]) and state.help_description==int(row.initial.help["0x220"]),"Original initialization coarsens signed WORD axes and describes its current selection",input)
		check(state.enabled==row.initial.enabled and bool(row.initial.recommendEnabled)==(int(input.recommended)!=0),"Original nine active class restrictions and recommended flag",input)
		if input.title:state.general_help()
		check(state.help_title==int(row.titled.help["0x628"]) and state.help_description==int(row.titled.help["0x220"]),"Original title restores general help without changing selected alignment",input)
		if input.recommend:state.recommend()
		else:state.select_index(int(input.selected))
		check(state.selected==int(row.selection.selected) and state.help_title==int(row.selection.help["0x628"]) and state.help_description==int(row.selection.help["0x220"]),"Original programmatic selection/recommendation preserves disabled-choice semantics",input)
		var result:=state.result(int(input.goodEvil),int(input.lawChaos),bool(input.present),bool(input.cancel))
		check(int(result.goodEvil)==int(row.output.goodEvil) and int(result.lawChaos)==int(row.output.lawChaos) and int(result.code)==int(row.output.code),"Original full OK/Cancel/absent-object writes and parent callback result",input)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	alignment_oracle(args.oracle)
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Original frame and active rule catalogs mount independently")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(base.get_resource("cg_alignment",2047))=="8d6863d2b4e22c790695fe9b3ded7555e6b8522a7b6e25ce1d1aa6237242a4ad","Pinned original Alignment GUI")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original pregame captions load independently")
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,text,base,"");creator.open(151)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.alignment.layout_ready,100),"Actual draft and original Alignment frame prepare",creator.source_frontend.alignment.failure):
		var front=creator.source_frontend;var pane=front.alignment;var scope: Array=creator.summary_identity();var previous: Array=[int(creator.rules.draft.goodEvil),int(creator.rules.draft.lawChaos)]
		check(not front.wanted and pane.assets.catalog==base and front.alignment_text==ui.text,"Original Alignment artwork is pregame-owned; restrictions and descriptions are active-draft-owned")
		front.begin(scope,{"classBase":int(creator.rules.draft.classId)},creator.rules.rows("classes"));front.flow.enabled.align=true;front.refresh();await frames();await click(front.main.buttons.alignbutton)
		check(pane.wanted and pane.title.text==text.raw({"strRef":111}) and pane.buttons.size()==12,"Physical source parent action opens all original Alignment controls/caption")
		var selected: int=pane.state.selected;var alternative:=-1;var disabled:=-1
		for index in 9:
			if pane.state.enabled[index] and index!=selected:alternative=index
			if not pane.state.enabled[index]:disabled=index
		if check(alternative>=0,"Active class has another permitted alignment"):
			await click(pane.buttons[Alignment.TAGS[alternative]])
			check(pane.state.selected==alternative and [int(creator.rules.draft.goodEvil),int(creator.rules.draft.lawChaos)]==previous,"Physical radio selection previews without a draft write")
			check(pane.help.title.text==ui.text.raw({"strRef":Alignment.HELP[alternative][0]}) and pane.help.body.get_parsed_text().length()>0,"Shared source help shows selected original descriptions through active text")
			await click(pane.title);check(pane.help.current.slice(1)==[260,458] and pane.state.selected==alternative,"Physical title restores source general help without changing selected radio")
			if disabled>=0:
				await click(pane.buttons[Alignment.TAGS[disabled]]);check(pane.state.selected==alternative and pane.buttons[Alignment.TAGS[disabled]].get_child(0).modulate==Color(.5,.5,.5,1),"Disabled class-specific alignment rejects a click and has original gray caption")
			await click(pane.buttons.cancelbutton);check(front.child.is_empty() and not front.flow.completed.align and [int(creator.rules.draft.goodEvil),int(creator.rules.draft.lawChaos)]==previous,"Cancel returns2 without writing axes or advancing parent completion")
			await click(front.main.buttons.alignbutton);await click(pane.buttons[Alignment.TAGS[alternative]]);await click(pane.buttons.okbutton)
			check(front.flow.completed.align and front.flow.enabled.abilities and front.child.is_empty() and int(creator.rules.draft.goodEvil)==[85,50,15][alternative%3] and int(creator.rules.draft.lawChaos)==[85,50,15][alternative/3],"Actual source OK commits canonical axes and reports8001 to enable Abilities")
		await click(front.main.buttons.alignbutton);await key(KEY_ESCAPE);check(front.child.is_empty() and front.wanted,"Physical Escape dismisses only Alignment")
		# Server restrictions replace stock class behavior without replacing GUI.
		var custom: Dictionary=creator.rules.tables.classes.duplicate(true);var class_id:=int(creator.rules.draft.classId);custom.orderedRows[class_id].AlignRestrict="21";custom.orderedRows[class_id].AlignRstrctType="3";custom.orderedRows[class_id].InvertRestrict="0";creator.rules.tables.classes=custom;creator.refresh_source()
		await click(front.main.buttons.alignbutton);check(pane.state.enabled==[true,false,false,false,false,false,false,false,false],"Changed active classes2DA permits only Lawful Good in actual source controls")
		await click(pane.buttons.recommendbutton)
		var recommended_index: int=[7,6,1,4,6,1,0,6,4,7,1][class_id] if class_id<11 else 0
		check(pane.state.selected==recommended_index and pane.buttons[Alignment.TAGS[recommended_index]].button_pressed and pane.buttons[Alignment.TAGS[recommended_index]].disabled and not pane.buttons.okbutton.disabled,"Original programmatic recommendation can check a disabled button without substituting another alignment")
		await click(pane.buttons.okbutton);check(front.flow.completed.align and creator.rules.errors().has("Choose an allowed alignment."),"Source OK mirrors original selection while final active-table legality validation still rejects it")
		await click(front.main.buttons.alignbutton);await click(pane.buttons.lgbutton);front.flow.enabled.packages=true;creator.rules.draft.domains=[1,2];creator.rules.draft.skills={0:1};creator.rules.draft.feats=[{"id":1,"kind":"normal"}];creator.rules.skill_summary_mask=7;await click(pane.buttons.okbutton)
		check(creator.rules.draft.domains.is_empty() and creator.rules.draft.skills.is_empty() and creator.rules.draft.feats.is_empty() and creator.rules.skill_summary_mask==0 and not front.flow.enabled.packages and not front.flow.completed.abilities,"Alignment acceptance applies the original conditional derived reset and invalidates later parent steps")
		await click(front.main.buttons.alignbutton);var old_ticket: Array=front.ticket.duplicate();pane.capture("okbutton");ui.text.revision+=1;creator.refresh_source();pane.invoke("okbutton")
		check(front.ticket!=old_ticket and pane.wanted and front.child=="alignbutton","Active text replacement retires held Alignment input and refreshes shared help")
		var disabled_context: Dictionary=front.alignment_context.duplicate(true);front.bind_alignment(scope,disabled_context,false,ui.text,creator.commit_source_alignment);var before_recommend: int=pane.state.selected;await click(pane.buttons.recommendbutton)
		check(pane.buttons.recommendbutton.disabled and pane.state.selected==before_recommend,"Active rules can disable Recommended without triggering a result")
		pane.buttons.lnbutton.set_pressed_no_signal(true);pane.invoke("lnbutton");check(not pane.buttons.lnbutton.button_pressed,"Rejected held/radio input restores the visible checked state")
		surface.size=Vector2i(512,400);await frames();front.place();await click(pane.buttons.lgbutton);check(pane.scale.x<1 and pane.state.selected==0,"Scaled original Alignment radios retain physical pointer alignment")
		var retiring:=func(_selected,_identity):front.dismiss();return {"accepted":true,"code":0x8001}
		front.bind_alignment(scope,front.alignment_context,true,ui.text,retiring);await click(pane.buttons.okbutton);check(not front.wanted,"Reentrant draft retirement rejects a late accepted Alignment result")
		creator.cancel();creator.open(152);await wait_for(func():return creator.phase=="editing",100);front.alignment_result(true,0,old_ticket)
		check(creator.summary_identity()!=scope and creator.commit_source_alignment(0,scope).is_empty() and not front.wanted,"Old Alignment tickets/commit callbacks cannot mutate a replacement draft")
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"Input inspection never fabricates upload or server admission")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"sourceArtworkDouble":true,"scope":"2304 original class restrictions and180 original bind/title/selection/recommendation/OK/Cancel sequences; source Alignment physical input, active class/TLK replacement, conditional draft reset, scaling and retirement. Artwork/font doubles; original pixels, full source creator, level-up and final save remain separate."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
