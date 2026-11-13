extends "res://tests/native_creation_summary_binding_test.gd"
var trace:Array=[]
var observations:Dictionary={}
var blocker:=""
func configure_fixture_catalog(_catalog)->void:pass
func before_fixture_close(_creator)->void:pass
func verify_fixture_transport()->void:
	check(not sent.any(func(message):return message.get("kind")=="native-creation-submit"),"Offline actual source regression never uploads a character or opens a network session")
func fixture_scope()->String:return "Actual shipping first-level Creator/source controls using exact cached Arelith raw2DA/customTLK and original installed fallbacks. No authored rule rows/defaults, injected post states, network, preview/associate template, upload or original-pixel acceptance."
func finish_associate(creator,_ui)->bool:
	# This bounded table/control slice does not substitute installed UTCs for
	# a declared override. The complete fixture owns template/name acceptance.
	return await input(creator.source_frontend.associate.buttons.cancelbutton,"Associate Cancel")
func pane_diagnostics(front)->Dictionary:
	var result:Dictionary={}
	for tag in ["main","gender","race","portrait","class_chooser","alignment","attributes","packages","skills","feats","school","domains","spells","associate"]:
		var pane=front.get(tag)
		result[tag]={"started":pane.started,"layoutReady":pane.layout_ready,"visible":pane.visible,"wanted":null if tag=="main" else pane.wanted,"failure":pane.failure,"pendingJobs":pane.jobs.size()}
	var popup=front.feats.group_popup
	result.featGroup={"started":popup.started,"layoutReady":popup.layout_ready,"wanted":popup.wanted,"failure":popup.failure,"pendingJobs":popup.jobs.size()}
	return result
func mark(creator,label:String)->void:
	trace.append({"label":label,"phase":creator.phase,"child":creator.source_frontend.child,"status":creator.status,"classId":creator.rules.draft.get("classId"),"packageId":creator.rules.draft.get("packageId"),"points":creator.rules.point_balance()})
func input(button:Control,label:String)->bool:
	if not check(is_instance_valid(button) and button.is_visible_in_tree() and button is BaseButton and not button.disabled,"Actual source input is admitted: "+label):blocker=label;return false
	await click(button);return true
func select_entry(pane,id:int,label:String)->bool:
	for index in pane.state.entries.size():
		if int(pane.state.entries[index].id)!=id:continue
		pane.list.ensure_control_visible(pane.row_buttons[index]);await frames(4)
		return await input(pane.row_buttons[index],label)
	check(false,"Actual active choice is present: "+label,id);blocker=label;return false
func wait_source(creator,allowed:Array,seconds:float=8.0)->bool:
	var front=creator.source_frontend;var end:=Time.get_ticks_msec()+int(seconds*1000);var last:=""
	while Time.get_ticks_msec()<end:
		var state:String=creator.phase+":"+front.child+":"+creator.status
		if state!=last:mark(creator,"transition");last=state
		if creator.phase=="editing" and front.child in allowed:return true
		await process_frame
	blocker="Source transition did not reach "+str(allowed);return false
func path(creator,ui)->bool:
	var front=creator.source_frontend;var warlock:=-1
	for id in creator.rules.rows("classes").size():
		if str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()=="warlock":warlock=id
	if not check(warlock==92 and ui.text.raw({"strRef":creator.rules.num(creator.rules.row("classes",warlock),"Name")})=="Warlock","Actual active Label/TLK identify cached Warlock at fixture physical92"):return false
	mark(creator,"ready")
	if not await input(front.main.buttons.genderbutton,"Gender"):return false
	if not await input(front.gender.buttons.malebutton,"Male") or not await input(front.gender.buttons.okbutton,"Gender OK"):return false
	if not await input(front.main.buttons.racebutton,"Race"):return false
	if not await select_entry(front.race,6,"Active Human6") or not await input(front.race.buttons.okbutton,"Race OK"):return false
	if not await input(front.main.buttons.portraitbutton,"Portrait"):return false
	if not check(await wait_for(func():return front.portrait.layout_ready and not front.portrait.cells.is_empty(),5),"Original portrait rows prepare"):return false
	if not await input(front.portrait.cells[0].button,"First admitted portrait") or not await input(front.portrait.buttons.okbutton,"Portrait OK"):return false
	if not await input(front.main.buttons.classbutton,"Class"):return false
	if not await select_entry(front.class_chooser,warlock,"Actual Warlock row") or not await input(front.class_chooser.buttons.okbutton,"Warlock OK"):return false
	if not check(int(creator.rules.draft.classId)==warlock,"Source Class callback commits exact cached class without injected row overrides"):return false
	mark(creator,"class")
	if not await input(front.main.buttons.alignbutton,"Alignment"):return false
	var alignment_button:Button=null
	for tag in front.alignment.buttons:
		if str(tag) not in front.alignment.Layout.BUTTONS and not front.alignment.buttons[tag].disabled:alignment_button=front.alignment.buttons[tag];break
	if not check(alignment_button!=null,"Actual cached Warlock alignment has an admitted source choice"):return false
	if not await input(alignment_button,"Admitted alignment") or not await input(front.alignment.buttons.okbutton,"Alignment OK"):return false
	if not await input(front.main.buttons.abilitiesbutton,"Abilities"):return false
	if not front.attributes.buttons.recommendbutton.disabled:await input(front.attributes.buttons.recommendbutton,"Active class recommended abilities")
	# Spend only through actual source arrows. Every proposed step must be
	# affordable under the displayed live model; no raw-score fixture writes.
	for attempt in 160:
		if int(front.attributes.model.get("points",-1))==0:break
		var prior:int=int(front.attributes.model.get("points",-1));var moved:=false
		for index in 6:
			var raw:int=int(front.attributes.model.raw[index]);var cost:int=creator.rules.AbilityRules.cost(creator.rules.tables,raw)
			if raw>=creator.rules.cfg("BASE_ABILITY_MAX",18) or cost>prior:continue
			await input(front.attributes.buttons[front.attributes.Layout.KEYS[index]+"upbutton"],"Spend current ability point")
			if int(front.attributes.model.points)<prior:moved=true;break
		if not moved:break
	if not check(int(front.attributes.model.get("points",-1))==0,"Actual active ability allocation reaches its source completion gate",front.attributes.model):return false
	if not await input(front.attributes.buttons.okbutton,"Abilities OK"):return false
	if not await input(front.main.buttons.packagesbutton,"Package"):return false
	observations.packages={"default":front.packages.state.default_package,"entries":front.packages.state.entries,"selected":front.packages.state.selected_package(),"recommendedDisabled":front.packages.buttons.recommendbutton.disabled}
	if not check(front.packages.state.default_package==149 and front.packages.state.entries.map(func(row):return int(row.id))==[310,311,312,313,314],"Header default149 and actual visible packages310..314 remain distinct"):return false
	if not front.packages.buttons.recommendbutton.disabled:await input(front.packages.buttons.recommendbutton,"Native package Recommended")
	if not check(front.packages.state.selected_package()==310,"Actual source Recommended/initial row remains visible310, without forcing hidden149"):return false
	return await package_flow(creator,ui)
func package_flow(creator,ui)->bool:
	var front=creator.source_frontend
	if not await input(front.packages.buttons.configurepckg,"Configure visible package"):return false
	if not check(await wait_source(creator,["package-configuration"]),"Real selected package transfers to Skills",trace):return false
	mark(creator,"skills")
	if not front.skills.buttons.recommendbutton.disabled:await input(front.skills.buttons.recommendbutton,"Captured skill preferences")
	if not check(await wait_for(func():return creator.phase=="editing" and not front.skills.busy,8),"Captured skill preference work completes"):return false
	if not await input(front.skills.buttons.okbutton,"Skills OK"):return false
	if not check(await wait_source(creator,["package-feats"]),"Source Skills commit transfers to actual Feats",trace):return false
	var feats=front.feats
	observations.feats={"remaining":feats.model.get("remaining"),"availableCount":feats.model.get("available",[]).size(),"knownCount":feats.model.get("known",[]).size(),"families":feats.model.get("available",[]).filter(func(row):return row.has("children")).map(func(row):return {"name":row.name,"enabled":row.get("enabled",false),"children":row.children.map(func(child):return child.id)})}
	var family_used:=false
	for attempt in 12:
		if feats.model.get("canAccept",false):break
		var picked:=-1
		for index in feats.model.get("available",[]).size():
			var entry:Dictionary=feats.model.available[index]
			if not entry.get("enabled",false):continue
			if picked<0:picked=index
			if not family_used and entry.has("children") and entry.name=="Warlock Pact":picked=index;break
		if not check(picked>=0,"Actual cached feat reservations have an admitted source row",observations.feats):return false
		var entry:Dictionary=feats.model.available[picked];feats.lists.available.ensure_control_visible(feats.rows.available[picked]);await frames()
		if not await input(feats.buttons["available:"+str(picked)+":arrow"],"Actual feat add/family arrow"):return false
		if entry.has("children"):
			if not check(feats.group_popup.wanted and not feats.group_popup.row_buttons.is_empty(),"Actual captured feat family opens original popup"):return false
			var selected_id:int=int(feats.group_popup.model.entries[0].id)
			if not family_used and not check(entry.name=="Warlock Pact" and selected_id in [2300,2303,2306,2309,2312,2315,2318],"Actual custom Warlock Pact family exposes captured pact feats",feats.group_popup.model):return false
			await input(feats.group_popup.row_buttons[0],"Actual family child");await input(feats.group_popup.buttons.okbutton,"Family OK")
			if not family_used:
				var committed:bool=await wait_for(func():return feats.model.get("known",[]).any(func(row):return int(row.id)==selected_id),8)
				observations.customFamily={"name":entry.name,"selectedId":selected_id,"knownAfter":feats.model.get("known",[]).map(func(row):return row.id)}
				if not check(committed,"Physical custom pact-family callback reaches actual reserved feats",observations.customFamily):return false
			family_used=true
		await frames()
	if not check(feats.model.get("canAccept",false),"Actual cached feat reservations can complete without replacement definitions",feats.model.get("remaining")):return false
	observations.familyUsed=family_used
	check(family_used,"Cached custom-class regression exercises an actual Warlock Pact family selection")
	if not await input(feats.buttons.okbutton,"Feats OK"):return false
	if not check(await wait_source(creator,["package-spells","package-associate",""]),"Internal post continuation resolves to a real required pane",trace):return false
	if front.child=="package-spells":
		if not check(await wait_for(func():return front.spells.started and front.spells.layout_ready and front.spells.model.get("ready",false),8),"Lazy original Spells prepares only after its actual source entry",pane_diagnostics(front)):return false
		var spells=front.spells;observations.spells=spells.model.duplicate(true)
		if not check(spells.model.get("ready",false) and spells.model.get("remaining")==0 and spells.model.get("canAccept",false) and spells.model.get("tabs")==[false,false,false,false,false,false,false,false,false,false],"Actual Warlock source Spells accepts its zero-capacity first level with all ten tabs disabled",spells.model):return false
		if not await input(spells.buttons.okbutton,"Zero-capacity Spells OK"):return false
		if not check(await wait_source(creator,["package-associate",""]),"Zero-capacity source OK advances actual post flow",trace):return false
	else:observations.spells={"route":front.child,"notOpened":true}
	if front.child=="package-associate":
		if not check(await wait_for(func():return front.associate.started and front.associate.layout_ready,8),"Lazy original Associate prepares only after its actual source entry",pane_diagnostics(front)):return false
		observations.associate={"ready":front.associate.state.ready,"reason":front.associate.state.reason,"selected":front.associate.state.selected,"storedType":front.associate_context.get("storedType"),"entries":front.associate.state.entries,"name":front.associate.state.current_name,"okDisabled":front.associate.buttons.okbutton.disabled}
		check(front.associate.wanted and front.associate.state.ready,"Actual Arcane1/MinAssociate1 branch reaches real original associate chooser",observations.associate)
		if not await finish_associate(creator,ui):return false
	else:check(front.child.is_empty() and front.flow.enabled.customize,"Completed captured class-dependent route enables Customize")
	mark(creator,"bounded-end")
	return failures.is_empty()
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","fixture","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.fixture).path_join("fixture.json")))
	check(fixture.success and fixture.captureGaps.is_empty(),"SHA-verified cached Arelith table closure is complete")
	var base:=Catalog.new();var active:=Catalog.new();var mounted:bool=base.mount_install(args.install) and active.mount_install(args.install)
	if fixture.has("privateNwsyncCatalog"):mounted=mounted and active.mount_nwsync(str(fixture.manifest),str(args.fixture).path_join("nwsync"),"","",100000001)
	else:mounted=mounted and active.mount_directory(str(args.fixture).path_join("resources"),100000001)
	check(mounted,"Exact full active namespace mounts helperlessly above read-only original install")
	configure_fixture_catalog(active)
	for resource in fixture.resources:check(FileAccess.get_sha256(str(args.fixture).path_join(str(resource.file)))==str(resource.sha256),"Captured fixture remains exact: "+str(resource.name))
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,str(args.report)+".prepared",str(args.report)+".layout.cfg",{"name":"arelith"});ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(9201)
	var front=creator.source_frontend
	# configure() eagerly starts these owners, while Domains/Spells/Associate
	# intentionally prepare only when their original class-dependent route opens.
	var startup_ready:bool=await wait_for(func():return creator.phase=="editing" and ui.tlk_jobs.is_empty() and [front.main,front.gender,front.race,front.portrait,front.class_chooser,front.alignment,front.attributes,front.packages,front.skills,front.feats,front.school].all(func(pane):return pane.layout_ready) and front.feats.group_popup.layout_ready,25)
	observations.startup={"phase":creator.phase,"status":creator.status,"pendingCustomTlk":ui.tlk_jobs.size(),"panes":pane_diagnostics(front),"resourceErrors":creator.resource_errors.duplicate(true)}
	if check(startup_ready,"Actual eagerly-started cached Creator/source controls and custom TLK become ready",observations.startup):await path(creator,ui)
	observations.panes=pane_diagnostics(front)
	observations.final={"phase":creator.phase,"child":creator.source_frontend.child,"status":creator.status,"resourceErrors":creator.resource_errors,"draft":creator.rules.draft.duplicate(true)}
	before_fixture_close(creator);verify_fixture_transport()
	ui.close();ui.free();painter.free();surface.queue_free();captions.close();await frames(6)
	var output:Dictionary={"success":failures.is_empty(),"checks":checks,"failures":failures,"manifest":fixture.manifest,"trace":trace,"observations":observations,"blocker":blocker,"gpu":false,"sourceArtworkDouble":true,"serverConnections":0,"scope":fixture_scope()}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
