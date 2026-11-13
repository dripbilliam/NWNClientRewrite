extends "res://tests/native_creation_summary_binding_test.gd"
const GenderState=preload("res://systems/native_data/creation_gender_state.gd")
const GENDER_SHA="b4492bcc017e5cf435c289bd448737a4d5dcfdd7edd88ebea6a3798b44d88601"
func gender_oracle(path: String) -> void:
	check(FileAccess.get_sha256(path)==GENDER_SHA,"Original Gender callback corpus is pinned")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data.target==ORIGINAL and data.rows.size()==64 and data.procedures.has("0x1401eff30") and data.procedures.has("0x1401e5ae0"),"Original Gender corpus includes actual programmatic tab selection and radio-state setters")
	for row in data.rows:
		var state:=GenderState.new();state.reset(int(row.input.gender),bool(row.input.present))
		check(state.selected==int(row.initial.selected) and state.help_title==int(row.initial.help["0x628"]) and state.help_description==int(row.initial.help["0x220"]),"Initial selection and source help references match original preparation")
		state.selected=int(row.input.selected)
		if state.selected in [0,1]:state.select(state.selected)
		check(state.help_title==int(row.selection.help["0x628"]) and state.help_description==int(row.selection.help["0x220"]),"Selection changes source help without changing the draft")
		var result:=state.result(int(row.input.gender),bool(row.input.present),bool(row.input.cancel))
		check(int(result.gender)==int(row.output.gender) and int(result.code)==int(row.output.code),"Original changed/unchanged/cancel result and gender write match")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	gender_oracle(args.oracle)
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Independent pregame and active catalogs mount read-only")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Gender/help source text comes from independently owned pregame TLK")
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,text,base,"");creator.open(120)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.gender.layout_ready,120),"Real creator and original Gender frame prepare",creator.source_frontend.gender.failure):
		var front=creator.source_frontend;var scope: Array=creator.summary_identity();var pane=front.gender;var original_gender:=int(creator.rules.draft.gender)
		check(not front.wanted and not pane.visible and front.gender_scope==scope and pane.assets.catalog==base,"Gender is pregame-owned and bound without prematurely replacing the unfinished source creator")
		check(pane.plan.entries.malebutton.callback=="0x1408e14a0" and pane.plan.entries.okbutton.callback=="0x1408e56e0" and pane.plan.help_body.size==Vector2(323,317),"Real original controls, callback identities and help model hooks are used")
		front.begin(scope,{"classBase":int(creator.rules.draft.classId)},creator.rules.rows("classes"));await frames();await click(front.main.buttons.genderbutton);await frames()
		check(front.child=="genderbutton" and pane.wanted and pane.visible and pane.state.selected==original_gender,"Physical original parent action opens the bound current draft Gender child")
		check(pane.help_refs==[203,447] and pane.help_title.text==text.raw({"strRef":203}),"Original initial radio state retains general help until a real choice click")
		await click(pane.buttons.femalebutton)
		check(pane.state.selected==1 and int(creator.rules.draft.gender)==original_gender and pane.help_title.text==text.raw({"strRef":446}),"Actual radio click previews female source help without committing gender")
		await click(pane.buttons.cancelbutton)
		check(front.child.is_empty() and not front.flow.completed.gender and int(creator.rules.draft.gender)==original_gender,"Actual Cancel leaves draft and completion unchanged")
		await click(front.main.buttons.genderbutton);await click(pane.buttons.femalebutton);var ticket: Array=front.ticket.duplicate();await click(pane.buttons.okbutton);await frames()
		check(int(creator.rules.draft.gender)==1 and front.flow.completed.gender and front.flow.enabled.race and front.child.is_empty() and front.ticket!=ticket,"Actual OK commits through the owner and advances the original parent after its own refresh")
		front.flow.completed.portrait=true;var retained:=str(creator.rules.portraits()[0]);creator.rules.draft.portrait=retained;creator.refresh_source();front.refresh()
		await click(front.main.buttons.genderbutton);await click(pane.buttons.malebutton);await click(pane.buttons.okbutton);await frames()
		check(int(creator.rules.draft.gender)==0 and creator.rules.draft.portrait==retained and front.child=="portraitbutton" and front.portrait.wanted,"Changed Gender reopens an already-completed portrait child without clearing its authored draft ResRef")
		await click(front.portrait.buttons.cancelbutton);await click(front.main.buttons.genderbutton)
		var old_scope: Array=scope.duplicate();var old_ticket: Array=front.ticket.duplicate();pane.capture("femalebutton");creator.cancel();creator.open(121);await wait_for(func():return creator.phase=="editing",120);await frames()
		pane.invoke("femalebutton");front.gender_result(true,1,old_ticket)
		check(int(creator.rules.draft.gender)==0 and front.child.is_empty() and not front.wanted and creator.summary_identity()!=old_scope and creator.commit_source_gender(1,old_scope).is_empty(),"Cancelled/reopened drafts reject held clicks, late Gender results and old owner commits")
		scope=creator.summary_identity();front.begin(scope,{"classBase":int(creator.rules.draft.classId)},creator.rules.rows("classes"))
		var retiring:=func(_selected,_scope):front.dismiss();return {"accepted":true,"gender":1,"code":0x8017}
		front.bind_gender(scope,0,retiring);await frames();await click(front.main.buttons.genderbutton);await click(pane.buttons.femalebutton);await click(pane.buttons.okbutton)
		check(not front.wanted and not front.flow.completed.gender and int(creator.rules.draft.gender)==0,"A reentrant retirement prevents a formerly valid Gender acknowledgment from advancing a replacement")
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"Gender inspection does not invent a character upload or original-server result")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"sourceArtworkDouble":true,"scope":"Original Gender instruction corpus plus real source control/input/owner commit and cancellation. Existing-portrait progress is a parent-state fixture; full source creation sequence, exact hover/keyboard policy, pixels and authoritative upload remain separate."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
