extends "res://tests/native_level_up_source_controls_test.gd"
const ReplyFixture=preload("res://tests/native_level_up_reply_fixture.gd")
const Front=preload("res://systems/native_level_up_frontend.gd")
const Owner=preload("res://systems/native_data/level_up_source_owner.gd")
const HitDie=preload("res://systems/native_data/level_up_hit_die.gd")
const Fixtures=preload("res://tests/native_creation_fixture_tables.gd")
const NativeOwner=preload("res://systems/native_level_up.gd")
const RuntimePanel=preload("res://systems/server_level_up.gd")
class AssociateArt extends Art:
	func bind_portrait(target: Object,resource: String) -> void:bind(target,resource)
class RuntimeDesktop extends RefCounted:
	var generation:=501
	var area_id:=7
	var actor_id:=42
	var rules
	var owner_ui: Dictionary={}
	var art
	var state:={"module":{"serverFlags":{"field158":false,"field164":false}}}
	var commands: Array=[]
	var actor_value: Dictionary={"objectType":5,"id":42,"areaId":7,"nativeLifetime":1,"clientKnownLifetime":1,"replicationRemoved":false}
	func actor() -> Dictionary:return actor_value
	func command(value: Dictionary) -> void:
		var outgoing:=value.duplicate(true);outgoing.generation=generation;outgoing.areaId=area_id;outgoing.actorId=actor_id
		commands.append(outgoing)
	func class_tables_ready(_id: int) -> bool:return true
var front
var owner:=Owner.new()
var runtime_owner
var runtime_panel
var runtime_desktop
var runtime_mode:=false
var reject_mode:=false
var fixture_class:=0
var flow_identity: Array=[]
var submissions: Array=[]
var cancellations: Array=[]
var diagnostics: Dictionary={}
func wait_for(predicate: Callable) -> bool:
	var until:=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<until:
		if predicate.call():return true
		await process_frame
	return false
func gate(value: bool,label: String) -> bool:check(value,label);return value
func sha256(bytes: PackedByteArray) -> String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes);return digest.finish().hex_encode()
func read_table(name: String) -> Dictionary:
	var parser:=TwoDa.new();var table:=parser.parse(catalog.get_resource(name,2017).get_string_from_ascii())
	check(parser.failure.is_empty(),"Active table parses without substituting stock choices: "+name)
	return table
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	runtime_mode=args.get("runtime","false")=="true"
	reject_mode=args.get("reject","false")=="true";fixture_class=3 if runtime_mode else 0
	flow_identity=[501,7,42] if runtime_mode else [501,42,7]
	catalog=Catalog.new();check(catalog.mount_install(args.install),"Original source resources mount read-only")
	var candidates: Array=catalog.resource_names(2027).filter(func(name):return str(name).begins_with("nw_ac"));candidates.sort()
	if not gate(not candidates.is_empty(),"An installed native animal UTC is available"):quit(1);return
	var utc: PackedByteArray=catalog.get_resource(str(candidates[0]),2027);var parser:=Gff.new();var template:=parser.parse(utc)
	check(parser.failure.is_empty() and template.type=="UTC ","Installed template bytes are native typed UTC")
	var fixture_dir:=str(args.report)+".resources";DirAccess.make_dir_recursive_absolute(fixture_dir)
	var file:=FileAccess.open(fixture_dir.path_join("fix_assoc_03.utc"),FileAccess.WRITE);file.store_buffer(utc);file.close()
	file=FileAccess.open(fixture_dir.path_join("hen_companion.2da"),FileAccess.WRITE);file.store_string("2DA V2.0\nSTRREF BASERESREF DESCRIPTION\n0 61000 missing_lvu_ 61010\n1 **** **** ****\n2 61001 fix_assoc_ 61011\n");file.close()
	check(catalog.mount_directory(fixture_dir,100000001),"Only authored companion rows/current-level UTC mount above original assets")
	base_text=preload("res://systems/native_data/talk_text.gd").new();active_text=preload("res://systems/native_data/talk_text.gd").new()
	check(base_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")) and active_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original captions and active names use separate TLK owners")
	active_text.overrides[61000]="Missing server template";active_text.overrides[61001]="Current server companion";active_text.revision+=1
	var tables: Dictionary={}
	for name in ["classes","racialtypes","skills","ruleset","feat","spells","exptable","portraits","hen_companion"]:tables[name]=read_table(name)
	tables.classes=Fixtures.row_update(tables.classes,fixture_class,{"PlayerClass":"1","SkillPointBase":"2","SkillsTable":"lvu_skills","FeatsTable":"lvu_feats","AttackBonusTable":"lvu_bab","BonusFeatsTable":"****","PickDomains":"0","PickSchool":"0","SpellCaster":"0","SpellbookRestricted":"0","SkipSpellSelection":"0","MinAssociateLevel":"3","Arcane":"2","HitDie":"8"})
	tables.racialtypes=Fixtures.row_update(tables.racialtypes,0,{"NormalFeatEveryNthLevel":"255"})
	tables.lvu_skills={"orderedRows":[{"SkillIndex":"0","ClassSkill":"1"}]};tables.lvu_feats={"orderedRows":[]};tables.lvu_bab={"orderedRows":[{"BAB":"1"},{"BAB":"2"},{"BAB":"3"}]}
	var ranks: Array=[];ranks.resize(tables.skills.orderedRows.size()&255);ranks.fill(0)
	var received:={"actorId":42,"race":0,"classes":[{"id":fixture_class,"level":2}],"baseAbilities":[14,14,14,14,14,14],"skills":ranks,"fieldDC6":0,"feats":[],"fieldC0":0,"fieldD4":0,"fieldE34":-1,"fieldE48":"Copied familiar","fieldE30":-1,"fieldE38":"Copied companion"};var before:=received.duplicate(true)
	var available: Array=[];available.resize(tables.classes.orderedRows.size()&255);available.fill(false);available[fixture_class]=true
	var begin:={"token":31,"snapshot":received,"available":available,"protocolFeatures":{"multiclassRuleset":true},"draftContext":{"baseFortitude":0}}
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	painter=Painter.new();painter.art=AssociateArt.new();painter.fonts=Doubles.HeadlessFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);painter.art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	if runtime_mode:
		active_text.tables=tables;runtime_desktop=RuntimeDesktop.new();runtime_desktop.rules=preload("res://systems/native_data/game_ui_rules.gd").new();runtime_desktop.rules.text=active_text;runtime_desktop.owner_ui={"text":active_text,"catalog":catalog,"modal_order":null,"modal_surfaces":null};runtime_desktop.art=painter.art
		runtime_panel=RuntimePanel.new();surface.add_child(runtime_panel);runtime_panel.setup(str(args.report)+".layout.cfg");runtime_owner=NativeOwner.new();runtime_owner.configure(runtime_desktop,runtime_panel);runtime_panel.request.connect(runtime_owner.input);runtime_owner.configure_source(painter,base_text,catalog,"")
		front=runtime_owner.source_runtime.frontend;owner=runtime_owner.source_runtime.source_owner
	else:
		front=Front.new();surface.add_child(front);front.configure(painter,base_text,catalog,"");owner.configure(front);owner.configure_jobs(catalog)
	owner.submission_requested.connect(func(proposal,token,identity):submissions.append([proposal.duplicate(true),token,identity.duplicate()]))
	owner.cancellation_requested.connect(func(token,identity,pending):cancellations.append([token,identity.duplicate(),pending]))
	if not runtime_mode:
		owner.summary_requested.connect(func(_draft,ticket):
			var numeric:=HitDie.compose(owner.finalization_snapshot(ticket),owner.tables,{})
			if numeric.ready:owner.set_summary({"ready":true,"summary":"Authored review; original numeric maximum branch","hitDie":numeric.hitDie},ticket))
	if runtime_mode:
		runtime_panel.reset();runtime_panel.open();check(runtime_desktop.commands.size()==1 and ReplyFixture.matches(runtime_desktop.commands[0],"begin"),"Actual runtime editor sends only the existing typed begin intent")
		runtime_owner.receive_result(ReplyFixture.echo(runtime_desktop,{"accepted":true,"operation":"begin","result":JSON.parse_string(JSON.stringify(begin))}))
		check(runtime_panel.wanted and runtime_panel.source_active and not runtime_panel.visible and owner.wanted,"Actual begin result enters source controls while retaining the authoritative transaction gate")
	else:check(owner.begin(begin,[501,42,7],tables,active_text,painter.art).ready,"Actual begin result opens private mode1 owner")
	if gate(await wait_for(func():return front.panes.has("class") and front.panes["class"].layout_ready),"Installed Class controls prepare"):
		if runtime_mode:
			var pane=front.panes["class"];var entries: Array=pane.state.entries
			check(entries[0].id==fixture_class and entries[0].enabled and entries.slice(1).all(func(entry):return not entry.enabled),"Actual level-up pane groups available class3 before unavailable classes while preserving physical IDs")
			var publications: int=owner.class_publication.publications;owner.class_model();owner.class_model()
			check(owner.class_publication.publications==publications and pane.state.selected_class()==fixture_class,"Warm Class validation reuses its publication and selection is a physical ID")
			await click(pane.buttons.recommendbutton);check(pane.state.selected_class()==fixture_class,"Actual Recommend resolves the original current physical class3 after display sorting")
		await click(front.panes["class"].buttons.okbutton)
		if runtime_mode:check(owner.class_id==fixture_class,"Physical Class OK commits class3 rather than its first displayed row index0")
		if gate(await wait_for(func():return front.panes.has("skills") and front.panes.skills.layout_ready),"Class3 uses actual mode1 Skills without first-level allocation"):
			await click(front.panes.skills.buttons.okbutton)
			if gate(await wait_for(func():return front.panes.has("associate") and front.panes.associate.layout_ready),"Original class-level3 continuation enters actual Associate controls"):
				var pane=front.panes.associate;var ticket: Array=front.ticket.duplicate()
				check(pane.state.ready and pane.state.class_level==3 and pane.state.arcane==2 and pane.state.entries.map(func(row):return int(row.id))==[0,2] and pane.rows[1].label.text=="Current server companion","Active sparse physical rows/current class level and raw Arcane2 own the actual view")
				check(await wait_for(func():return not owner.associate_jobs.failure.is_empty()),"Missing current template completes as explicit unavailable data")
				check(pane.summary_identity.is_empty() and not pane.buttons.cancelbutton.disabled and received==before,"Missing UTC produces no player-stat proxy and preserves Cancel/received data")
				await click(pane.buttons["row:1"])
				if gate(await wait_for(func():return not pane.summary_identity.is_empty()),"Selecting a valid active row recovers the real private UTC projection"):
					var expected_name: String=active_text.name(preload("res://systems/native_data/character_preview.gd").project(template.root),-1)
					check(not expected_name.is_empty() and pane.summary_view.labels.title.text.contains(expected_name),"Private sheet identity comes from the selected native UTC")
					check(owner.associate_jobs.diagnostics.templateResource=="fix_assoc_03" and owner.associate_jobs.diagnostics.templateSha256==sha256(utc) and int(owner.associate_jobs.diagnostics.templateWorker)!=OS.get_thread_caller_id(),"Exact current-level UTC bytes load on an actual asset worker")
					await click(pane.buttons.gennamebutton)
					if gate(await wait_for(func():return not pane.generating and not pane.state.current_name.is_empty()),"Real familiar LTR/optional NameFilter worker returns a scoped name"):
						var name: String=pane.state.current_name;var revision: int=pane.name_revision
						check(name!="Copied familiar" and int(owner.associate_jobs.names.diagnostics.get("generationWorkerThread",0))!=OS.get_thread_caller_id(),"Generated name is actual worker output rather than a copied player label")
						check(not pane.name_result({"ready":true,"name":"Wrong scope"},ticket+[1],revision) and pane.state.current_name==name,"Foreign name completion cannot change the current private choice")
						var prior_summary: Array=pane.summary_identity.duplicate();owner.associate_preview({"ready":true,"labels":{"title":{"text":"Stale"}}},ticket+[1],pane.preview_serial)
						check(pane.summary_identity==prior_summary and pane.summary_view.labels.title.text.contains(expected_name),"Retired owner preview cannot replace the current template")
						await click(pane.buttons.okbutton)
						if gate(await wait_for(func():return front.panes.has("summary") and front.panes.summary.layout_ready),"Actual Associate OK commits and enters original Summary"):
							check(owner.associate_value.field=="familiar" and owner.associate_value.id==2 and owner.associate_jobs.scope.is_empty(),"Arcane2 uses companion table but commits familiar fields and retires worker scope")
							if runtime_mode:check(front.panes.summary.summary.contains(active_text.raw({"strRef":6388})+" : ") and not front.panes.summary.summary.contains("Authored review") and front.panes.summary.content_ready,"Actual runtime finalization prepares original active-table/TLK Summary rather than an authored fixture review")
							await click(front.panes.summary.buttons.okbutton);await click(front.panes.summary.buttons.okbutton)
							check(submissions.size()==1 and submissions[0][0].fieldE34==2 and submissions[0][0].fieldE48==name and submissions[0][0].fieldE30==-1 and submissions[0][0].fieldE38=="Copied companion" and submissions[0][1]==31 and submissions[0][2]==flow_identity,"Exact physical type/name commits only private familiar fields in one typed intent")
							if reject_mode:
								runtime_owner.receive_result(ReplyFixture.echo(runtime_desktop,{"accepted":true,"operation":"submit","result":{"accepted":false}}))
								check(front.panes.summary.wanted and front.panes.summary.submitted and front.panes.summary.buttons.okbutton.disabled and owner.navigation.result_received and not front.panes.summary.buttons.cancelbutton.disabled,"Authored actual-reply shape resolves pending status, keeps one-shot Summary disabled, and permits Cancel after server rejection")
							await click(front.panes.summary.buttons.cancelbutton)
							check(cancellations==[[31,flow_identity,not reject_mode]],"Summary Cancel distinguishes unresolved send from received rejection")
							if runtime_mode:check(runtime_desktop.commands.size()==3 and runtime_desktop.commands[1].operation=="submit" and runtime_desktop.commands[1].token==31 and ReplyFixture.matches(runtime_desktop.commands[2],"cancel",31) and not runtime_panel.wanted and not runtime_owner.source_runtime.active,"Actual runtime sends one scoped proposal and typed Cancel without fabricating server acceptance")
				diagnostics={"jobs":owner.associate_jobs.diagnostics.duplicate(true),"failure":str(owner.associate_jobs.failure),"template":str(candidates[0]),"templateSha256":sha256(utc)}
	check(received==before,"Original received snapshot remains byte-for-value unchanged")
	if runtime_mode:
		var missing:=begin.duplicate(true);missing.token=32;missing.draftContext={};runtime_panel.reset();runtime_panel.open();runtime_owner.receive_result(ReplyFixture.echo(runtime_desktop,{"accepted":true,"operation":"begin","result":missing}));await frames()
		check(runtime_panel.wanted and not runtime_panel.source_active and runtime_panel.visible and runtime_owner.status.begins_with("Using standard level-up controls."),"Unavailable source context retains a usable explicit generic editor")
		var fallback_items: Array=runtime_panel.state.items;var enabled: Array=fallback_items.filter(func(item):return not item.disabled);var disabled: Array=fallback_items.filter(func(item):return item.disabled)
		check(not enabled.is_empty() and not disabled.is_empty() and fallback_items.slice(0,enabled.size()).all(func(item):return not item.disabled) and runtime_owner.controls[int(enabled[0].controlId)].value==fixture_class,"Generic fallback also groups available classes first and retains physical class IDs")
		var publications: int=runtime_owner.class_publication.publications;runtime_owner.render();runtime_owner.render();check(runtime_owner.class_publication.publications==publications,"Generic Class refresh reuses name sorting until data publication")
		runtime_panel.reset();check(not owner.wanted and runtime_owner.snapshot.is_empty() and not runtime_owner.source_runtime.active,"Actual world/reset boundary retires source workers/private draft without an outgoing ACK")
		runtime_owner.close();runtime_panel.free()
	else:owner.close();front.close();front.free()
	painter.art.close();painter.close();painter.queue_free();base_text.close();active_text.close();await frames(5);surface.queue_free();await frames()
	file=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostics":diagnostics,"gpu":false,"serverConnections":0,"runtimeIntegrated":runtime_mode,"scope":"Actual native runtime owner/panel bridge when runtime=true, otherwise staged owner; Class→Skills→Associate→Summary, active sparse companion rows/current level3, unchanged installed UTC/private projection and real LTR/name workers, missing-template recovery, scoped commits/retirement. Controlled art/fonts and authored server replies; no server/pixel acceptance."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
