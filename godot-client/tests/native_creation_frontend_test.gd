extends "res://tests/native_portrait_chooser_test.gd"
const Frontend=preload("res://systems/native_creation_frontend.gd")
const SharedSummary=preload("res://systems/native_character_summary_view.gd")
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Table=preload("res://systems/native_data/two_da.gd")
func ready(frontend) -> bool:
	var until:=Time.get_ticks_msec()+20000
	while (not frontend.main.layout_ready or not frontend.portrait.layout_ready) and frontend.main.failure.is_empty() and frontend.portrait.failure.is_empty() and Time.get_ticks_msec()<until: await process_frame
	return frontend.main.layout_ready and frontend.portrait.layout_ready
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Creator base catalog mounts read-only")
	surface=SubViewport.new(); surface.size=Vector2i(1100,800); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface); surface.notify_mouse_entered()
	var painter:=Painter.new(); var art:=HeadlessArt.new(); var fonts:=HeadlessFonts.new(); painter.art=art; painter.fonts=fonts; painter.add_child(art); painter.add_child(fonts); art.loaded.connect(painter.art_loaded); surface.add_child(painter)
	var text:=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original creator captions load read-only")
	var parser:=Table.new(); var rules:=Rules.new(); rules.catalog=catalog; rules.tables.portraits=parser.parse(catalog.get_resource("portraits",2017).get_string_from_utf8()); rules.draft={"gender":0,"raceId":6,"portrait":""}
	var values:=rules.portraits(); check(values.size()>24 and parser.failure.is_empty(),"Actual native creator rules admit installed male/Human portraits")
	var active_classes: Array=[]; active_classes.resize(7)
	for index in active_classes.size(): active_classes[index]={}
	active_classes[6]={"AlignRestrict":"20","AlignRstrctType":"3","InvertRestrict":"0"}
	var frontend:=Frontend.new(); surface.add_child(frontend); frontend.configure(painter,text,catalog,"")
	var children: Array=[]; var commands: Array=[]; var endings: Array=[]
	frontend.child_requested.connect(func(tag,value_ticket):children.append([tag,value_ticket.duplicate()]))
	frontend.command_requested.connect(func(operation,value_scope):commands.append([operation,value_scope.duplicate()]))
	frontend.finished.connect(func(cancelled,value_scope):endings.append([cancelled,value_scope.duplicate()]))
	var commit:=func(base: String,value_scope: Array):
		if value_scope!=["draft",1] or not rules.portraits().has(base): return false
		rules.draft.portrait=base; return true
	frontend.bind_portraits(["draft",1],values,"",art,catalog,commit); frontend.begin(["draft",1],{"classBase":6},active_classes)
	check(await ready(frontend),"Actual native CG_MAIN and portrait child prepare: "+frontend.main.failure+frontend.portrait.failure); await frames(5)
	if frontend.main.layout_ready and frontend.portrait.layout_ready:
		check(frontend.main.buttons.size()==11 and frontend.main.buttons.portraitbutton.disabled and not frontend.main.buttons.genderbutton.disabled,"Original11-button parent gates choices and enables Gender first")
		var summary=frontend.main.summary_view
		check(summary is SharedSummary and summary.tabs.size()==4 and summary.size.distance_to(Vector2(360,468))<0.01,"CG_MAIN embeds the same original fixed summary view used by the shipping character picker")
		check(summary.definition.footer.resource=="ctl_chrsht_nosiz" and summary.tabs[3].tooltip_text==text.raw({"strRef":5215}) and summary.labels.title.text==text.raw({"strRef":61826})+", ","Creation summary uses original fixed footer, Spells tab and incomplete-name title")
		var before: Dictionary=rules.draft.duplicate(true); var summary_commands:=commands.size()
		await click(summary.tabs[3]); check(frontend.main.summary_index==3 and summary.pages[3].is_visible_in_tree() and not summary.statistics.visible and rules.draft==before and commands.size()==summary_commands,"Actual Spells tab input changes only the embedded page without mutating or submitting the draft")
		await mouse(summary.tabs[0],true); frontend.main.retire_input(); await mouse(summary.tabs[0],false)
		check(frontend.main.summary_index==3,"A held summary-tab release cannot survive parent input retirement")
		await click(summary.tabs[0]); check(frontend.main.summary_index==0 and summary.statistics.visible and not summary.pages[3].visible,"Fresh Character tab input returns to the original statistics attachments")
		check(frontend.main.definition.size.distance_to(Vector2(742,526))<0.01 and frontend.main.summary_host.position.distance_to(Vector2(380,42))<0.01,"Original main frame and creation-mode character-sheet attachment are retained")
		check(frontend.main.captions.genderbutton.text==text.raw({"strRef":150}) and painter.button_geometry[frontend.main.buttons.genderbutton.get_instance_id()].styles.normal[1]=="encouraged","Original captions and encouraged state use source resources")
		await click(frontend.main.buttons.genderbutton); var gender_ticket: Array=frontend.ticket.duplicate()
		check(frontend.child=="genderbutton" and children.size()==1 and not frontend.main.visible,"Actual main-button input opens a scoped Gender child")
		check(frontend.accept_child(gender_ticket,0x800d) and frontend.main.visible and not frontend.main.buttons.racebutton.disabled,"Original Gender completion returns to Main and enables Race")
		await click(frontend.main.buttons.racebutton); frontend.accept_child(frontend.ticket.duplicate(),0x800a)
		check(frontend.flow.completed.race and not frontend.main.buttons.portraitbutton.disabled,"Original Race completion enables Portrait")
		await click(frontend.main.buttons.portraitbutton); await frames(5)
		check(frontend.portrait.visible and frontend.child=="portraitbutton" and not frontend.main.visible,"Actual source Portrait button opens the real native portrait pane")
		await click(frontend.portrait.cells[0].button); await click(frontend.portrait.buttons.okbutton)
		check(rules.draft.portrait==values[0] and frontend.flow.completed.portrait and frontend.main.visible and not frontend.main.buttons.classbutton.disabled,"Original OK commits to the real native creation draft and enables Class")
		var original_portrait: String=rules.draft.portrait
		await click(frontend.main.buttons.portraitbutton); await frames(5); await click(frontend.portrait.cells[1].button); await click(frontend.portrait.buttons.cancelbutton)
		check(rules.draft.portrait==original_portrait and frontend.main.visible,"Portrait Cancel returns to Main without committing the tentative selection")
		await click(frontend.main.buttons.classbutton); frontend.accept_child(frontend.ticket.duplicate(),0x8004)
		check(not frontend.main.buttons.alignbutton.disabled and not frontend.flow.completed.align,"Modified active Paladin restrictions require the Alignment choice")
		var identities: Array=frontend.main.buttons.values().map(func(button):return button.get_instance_id())
		await click(frontend.main.buttons.alignbutton); frontend.accept_child(frontend.ticket.duplicate(),0x8001)
		check(not frontend.main.buttons.abilitiesbutton.disabled and frontend.main.buttons.packagesbutton.disabled,"Original Alignment completion enables Abilities before Package")
		await click(frontend.main.buttons.abilitiesbutton); frontend.accept_child(frontend.ticket.duplicate(),0x8003)
		await click(frontend.main.buttons.packagesbutton); frontend.accept_child(frontend.ticket.duplicate(),0x8008)
		await click(frontend.main.buttons.customizebutton); frontend.accept_child(frontend.ticket.duplicate(),0x8007)
		check(not frontend.main.buttons.playbutton.disabled and frontend.flow.completed.customize,"Original package/customization result flow enables Play")
		await click(frontend.main.buttons.playbutton)
		check(commands[-1]==["finish",["draft",1]] and identities==frontend.main.buttons.values().map(func(button):return button.get_instance_id()),"Play routes to the draft owner and all original main controls survive child round trips")
		await click(frontend.main.buttons.resetbutton)
		check(not frontend.flow.completed.portrait and frontend.main.buttons.portraitbutton.disabled and commands.slice(commands.size()-3)==[["retire_draft",["draft",1]],["initialize_draft",["draft",1]],["refresh",["draft",1]]],"Reset emits original draft retirement/reinitialization order and restores the dependency gates")
		await click(frontend.main.buttons.genderbutton); var stale: Array=frontend.ticket.duplicate(); frontend.begin(["draft",2],{},active_classes)
		check(not frontend.accept_child(stale,0x800d) and not frontend.flow.completed.gender,"A previous child result cannot complete a new draft")
		frontend.open_child("portraitbutton"); await frames()
		check(not frontend.portrait.visible and children[-1][0]=="portraitbutton","A new draft cannot silently reuse an old draft's portrait catalog")
		frontend.bind_portraits(["draft",2],values,"",art,catalog,func(_base,_scope):return false); await frames(5)
		check(not frontend.bind_portraits(["draft",1],[values[2]],str(values[2]),art,catalog,commit) and frontend.portrait_values==values and frontend.portrait_scope==["draft",2],"A late old-draft portrait-source reply cannot replace an active pane's choices or commit owner")
		await click(frontend.portrait.cells[0].button); await click(frontend.portrait.buttons.okbutton)
		check(frontend.portrait.visible and not frontend.flow.completed.portrait,"A refused draft commit keeps the portrait pane open and does not complete the step")
		await click(frontend.portrait.buttons.cancelbutton); await click(frontend.main.buttons.cancelbutton)
		check(endings==[[true,["draft",2]]] and not frontend.surface.visible,"Original main Cancel returns its exact draft scope and retires child ownership")
		frontend.bind_portraits(["edit",3],values,str(values[0]),art,catalog,func(_base,_scope):return true); frontend.begin(["edit",3],{"customizeMode":1},active_classes); await frames(5)
		check(frontend.portrait.visible and frontend.child=="portraitbutton","Existing-character customization starts directly at Portrait, as the original picker callback does")
		await click(frontend.portrait.buttons.okbutton)
		check(frontend.child=="appearance" and children[-1][0]=="appearance" and not frontend.flow.completed.portrait,"Customization portrait acceptance routes to Appearance without fabricating new-character completion")
		frontend.accept_child(frontend.ticket.duplicate(),2)
		check(endings[-1]==[true,["edit",3]] and not frontend.wanted,"Customization child cancellation retires the whole customization flow")
		frontend.begin(["held",4],{},active_classes); await frames(); var before_children:=children.size(); await mouse(frontend.main.buttons.genderbutton,true)
		frontend.begin(["held",5],{},active_classes); await frames(); await mouse(frontend.main.buttons.genderbutton,false)
		check(children.size()==before_children and frontend.child.is_empty(),"A main-menu press held across draft replacement cannot open a child in the next draft")
		var reentrant_scope: Array=["reentrant",6]
		frontend.begin(reentrant_scope,{"customizeMode":1},active_classes)
		frontend.bind_portraits(reentrant_scope,values,str(values[0]),art,catalog,func(_base,_scope):frontend.begin(reentrant_scope,{},active_classes); return true)
		await frames(5); await click(frontend.portrait.buttons.okbutton)
		check(frontend.main.visible and frontend.child.is_empty() and not frontend.flow.completed.portrait,"A commit callback that reopens the same draft scope still invalidates the earlier child result")
		frontend.command_requested.connect(func(operation,_scope):
			if operation=="retire_draft": frontend.begin(reentrant_scope,{},active_classes),CONNECT_ONE_SHOT)
		var command_count:=commands.size(); await click(frontend.main.buttons.resetbutton)
		check(commands.slice(command_count)==[["retire_draft",reentrant_scope]],"A reentrant same-scope draft replacement stops the previous reset command batch")
	var diagnostics: Dictionary={"main":frontend.main.snapshot(),"children":children.size(),"commands":commands.size(),"endings":endings}
	var main_ids: Array=frontend.main.buttons.values().map(func(button):return button.get_instance_id())
	frontend.close(); check(frontend.main.assets.running.is_empty() and frontend.portrait.assets.running.is_empty() and main_ids.all(func(id):return not painter.button_geometry.has(id)),"Close drains native source workers and removes retired main-button bindings")
	frontend.queue_free(); painter.close(); painter.queue_free(); await frames(5); surface.queue_free(); await frames(3)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostics":diagnostics,"graphical":false,"publicConnections":0,"scope":"Actual source CG_MAIN and portrait controls, native installed portrait admission and draft commit, source child completion/dependency flow, real headless pointer actions, catalog/draft lifetime isolation. Non-rendering artwork double; non-portrait children are scoped test returns. No complete creator UI/summary, original GUI pixels, saved BIC or server admission acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
