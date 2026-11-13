extends "res://tests/native_creation_gender_test.gd"
const SpellSnapshot=preload("res://systems/native_data/creation_spells_snapshot.gd")
const Post=preload("res://systems/native_data/creation_post_feats.gd")
func class_id(creator,label: String) -> int:
	for id in creator.rules.rows("classes").size()&255:
		if str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()==label:return id
	return -1
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Independent original/active catalogs mount read-only")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(746)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready,20),"Actual source creator initializes with private compiled class metadata",creator.resource_errors):
		var identity: Array=creator.summary_identity();var raw: Dictionary=ui.text.tables.classes;var before:=JSON.stringify(raw)
		check(not is_same(creator.rules.tables,ui.text.tables) and is_same(creator.source_classes_raw,raw) and not is_same(creator.rules.tables.classes,raw),"Creator separates private tables/compiled class view from canonical raw active text/catalog data")
		var fighter:=class_id(creator,"fighter");check(fighter>=0 and creator.commit_source_class(fighter,identity).get("accepted",false),"Real class commit admits physical Fighter discovered from active metadata")
		var next: Dictionary=creator.continue_source_creation(identity,0x800e)
		check(next.ready and next.next.is_empty() and creator.source_post.stage==0,"Actual stock Fighter post-Skills/Feats now finishes instead of stalling on failed optional cells",next)
		var wizard:=class_id(creator,"wizard");check(wizard>=0 and creator.commit_source_class(wizard,identity).get("accepted",false),"Real class commit admits physical Wizard from metadata")
		check(creator.rules.primary()=="Int" and int(creator.rules.abilities().Int)==creator.rules.cfg("BASE_ABILITY_MIN_PRIMARY",11) and creator.rules.num(creator.rules.cls(),"PickSchool")==1 and creator.rules.num(creator.rules.cls(),"MinAssociateLevel")==1,"Actual class/vitals getters consume original initialized Wizard primary/school/familiar state")
		var spells:=SpellSnapshot.compose(creator.rules,ui.text)
		check(spells.ready and spells.source.learnScroll and spells.source.memorizes and spells.source.pickSchool and not spells.source.spells.is_empty(),"Actual installed Wizard active-table Spell Snapshot composes through private legacy fields",spells.get("reason",""))
		creator.source_post.reset();next=creator.continue_source_creation(identity,0x800e);check(next.ready and next.next=="package-school","Actual Wizard continuation reaches native School using original initialized metadata",next)
		for label in ["cleric","druid","sorcerer","bard","ranger"]:
			var id:=class_id(creator,label);check(id>=0 and creator.commit_source_class(id,identity).get("accepted",false),"Real class callback admits installed "+label)
			creator.source_post.reset();next=creator.continue_source_creation(identity,0x800e)
			var expected: String="package-domains" if label=="cleric" else "package-associate" if label=="druid" else "package-spells" if label in ["sorcerer","bard"] else ""
			check(next.get("ready",false) and next.get("next")==expected,"Actual initialized "+label+" follows its original first-level child branch",next)
			if label in ["sorcerer","bard"]:
				spells=SpellSnapshot.compose(creator.rules,ui.text);check(spells.ready and not spells.source.memorizes and not spells.source.learnScroll and spells.source.capacity.any(func(value):return int(value)!=0),"Installed "+label+" spontaneous Snapshot uses real known capacity and independent flags",spells.get("reason",""))
		check(JSON.stringify(raw)==before and is_same(ui.text.tables.classes,raw),"All real class commits/getters leave canonical raw class cells/headers unchanged")
		var count: int=creator.source_class_compiles;ui.text.mark_changed();creator.synchronize_source_tables();creator.synchronize_source_tables()
		check(creator.source_class_compiles==count,"TLK-only and repeated publication observations do not rebuild class metadata")
		var raw_arcane: String=str(creator.rules.cell(raw.orderedRows[wizard],"Arcane"))
		var changed: Dictionary=preload("res://tests/native_creation_fixture_tables.gd").row_update(raw,wizard,{"PickSchool":"0","Arcane":"2","MinAssociateLevel":"7","SpellcastingAbil":"CHA","SpellTableColumn":"SERVER_CUSTOM"})
		ui.text.publish_table("classes",changed);creator.synchronize_source_tables()
		check(creator.source_class_compiles==count+1 and is_same(creator.source_classes_raw,changed) and is_same(ui.text.tables.classes,changed),"An accepted new raw class publication recompiles only the private first-level view")
		creator.rules.draft.classId=wizard;var cls: Dictionary=creator.rules.cls()
		check(creator.rules.num(cls,"PickSchool")==0 and creator.rules.num(cls,"Arcane")==1 and creator.rules.num(cls,"MinAssociateLevel")==7 and creator.rules.primary()=="Cha" and str(creator.rules.cell(cls,"SpellTableColumn"))=="SERVER_CUSTOM","Explicit active custom class fields override legacy defaults without changing physical identity")
		check(str(creator.rules.cell(changed.orderedRows[wizard],"Arcane"))=="2" and str(creator.rules.cell(raw.orderedRows[wizard],"Arcane"))==raw_arcane and JSON.stringify(raw)==before,"Custom BOOL2 and all actual original cells remain raw in their respective canonical source graphs")
		creator.rules.tables.private_fixture={"orderedRows":[{"value":"preserved"}]};ui.text.mark_changed();creator.synchronize_source_tables();check(creator.rules.tables.has("private_fixture"),"Unrelated TLK publication retains draft-owned dependency tables")
	check(not sent.any(func(message):return message.get("kind")=="native-creation-submit"),"Metadata/control initialization does not fabricate a character upload")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Actual Gameplay/Creator initialization and accepted raw table publication, real class commit callbacks and Vitals/Spell Snapshot/post-child routing for installed Fighter/Wizard/Cleric/Druid/Sorcerer/Bard/Ranger, raw isolation and custom metadata override. Headless artwork/font doubles; no complete physical class flow, BIC/server or pixel acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
