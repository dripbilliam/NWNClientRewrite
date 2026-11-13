extends "res://tests/native_creation_package_name_test.gd"
const Admission=preload("res://systems/native_data/creation_associate_validation.gd")
const SourcePetBuilder=preload("res://systems/native_data/creation_bic.gd")
const PetState=preload("res://systems/native_data/creation_associate_state.gd")
const FieldWriter=preload("res://systems/native_data/gff_writer.gd")
const PetGff=preload("res://systems/native_data/gff_document.gd")
func find_class(table: Dictionary,label: String) -> int:
	for id in table.orderedRows.size():
		if str(preload("res://systems/native_data/game_ui_rules.gd").cell(table.orderedRows[id],"Label","")).to_lower()==label:return id
	return -1
func add_grant(table: Dictionary,id: int) -> Dictionary:
	if not check(table.get("orderedRows") is Array,"Actual class feat dependency is published before the controlled grant"):return table
	var value:=table.duplicate(true);var row:={"FeatIndex":str(id),"List":"3","GrantedOnLevel":"1","OnMenu":"1"};value.orderedRows.append(row)
	if value.has("orderedCells"):
		var cells: Array=[]
		for key in value.columns:cells.append(str(preload("res://systems/native_data/game_ui_rules.gd").cell(row,str(key),"****")))
		value.orderedCells.append(cells)
	return value
func metadata_cases(rules) -> void:
	var saved: Dictionary=rules.tables.classes;var before: Dictionary=rules.draft.duplicate(true);var id:=int(rules.draft.classId)
	for values in [[1,1,"familiar"],[257,-2,"familiar"],[1,0,"companion"]]:
		rules.tables.classes=preload("res://tests/native_creation_fixture_tables.gd").row_update(saved,id,{"MinAssociateLevel":str(values[0]),"Arcane":str(values[1])})
		rules.draft[values[2]]= -1;rules.draft[values[2]+"Name"]=""
		var context:=Admission.verify(rules);var patch:=SourcePetBuilder.source_pet_fields(rules)
		check(context.ready and context.field==values[2] and patch.ready,"Source validation and actual original writer agree on reached BYTE/class-owned namespace "+str(values))
		var writer:=FieldWriter.new();var parser:=PetGff.new();var doc:=parser.parse(writer.write("BIC ",FieldWriter.record(patch.fields)),"BIC ");var prefix: String=str(values[2]).capitalize()
		check(writer.failure.is_empty() and parser.failure.is_empty() and doc.root[prefix+"Type"]== -1 and doc.root[prefix+"Name"]=="" and doc.field_types[0][prefix+"Type"]==5,"Actual typed BIC roundtrip preserves native unset INT5/empty without a template/name invention")
		rules.draft[values[2]]=2147483648;check(not Admission.verify(rules).ready,"A source type outside signed INT storage is unavailable")
		rules.draft[values[2]]= -2147483648;check(Admission.verify(rules).ready,"The complete signed native INT range remains serializable")
		rules.draft[values[2]+"Name"]=null;check(not Admission.verify(rules).ready,"A malformed reached source name is not accepted")
	for values in [["****","0",false],["0xZZ","0",false],["1","****",false],["1","0xZZ",false],["255","****",true]]:
		rules.tables.classes=preload("res://tests/native_creation_fixture_tables.gd").row_update(saved,id,{"MinAssociateLevel":values[0],"Arcane":values[1]});rules.draft=before.duplicate(true)
		check(Admission.verify(rules).ready==values[2],"Unknown reached metadata stays explicit; unreached Arcane is not a dependency "+str(values))
	rules.tables.classes=saved;rules.draft=before
	var child:=PetState.new();child.configure({"ready":true,"entries":[{"id":2,"title":1,"base":"active_pet_","name":"Active pet"}],"arcane":1,"level":1},-1,"")
	check(not child.commit().ready and child.commit().get("needsGeneratedName",false),"Manual child still refuses an empty name even when Recommended may preserve it")
	child.set_name("Actual generated name");check(child.commit().ready and child.commit().id==2,"Manual child still commits the mapped active physical ID with its actual name")
	child.configure({"ready":true,"entries":[],"arcane":1,"level":1},-1,"");check(not child.commit("Name").ready,"Recommended admission never manufactures a missing manual row")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Actual installed resources mount read-only")
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(759)
	var built:=false
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.packages.layout_ready,20),"Actual source Creator/Package controls prepare"):
		var rules=creator.rules;var front=creator.source_frontend;var fighter:=find_class(rules.tables.classes,"fighter")
		check(fighter>=0 and creator.commit_source_class(fighter,creator.summary_identity()).get("accepted",false),"Actual class callback uses the active physical Fighter identity")
		creator.package_tables();check(await wait_for(func():return creator.jobs.is_empty() and creator.resource_queue.is_empty(),10),"Actual package dependencies prepare")
		rules.tables.classes=preload("res://tests/native_creation_fixture_tables.gd").row_update(rules.tables.classes,fighter,{"MinAssociateLevel":"1","Arcane":"1"})
		var feat_table:=str(rules.cell(rules.cls(),"FeatsTable","")).to_lower();rules.tables[feat_table]=add_grant(rules.tables.get(feat_table,{}),303)
		var package_id:=int(rules.draft.packageId);rules.tables.packages=preload("res://tests/native_creation_fixture_tables.gd").row_update(rules.tables.packages,package_id,{"Associate":"****"})
		for turn in 100:
			if rules.point_balance()<=0:break
			var advanced:=false
			for ability in rules.ABILITIES:
				var before:=int(rules.draft.abilities[ability]);rules.change_ability(rules.ABILITIES.find(ability),1)
				if int(rules.draft.abilities[ability])!=before:advanced=true;break
			if not advanced:break
		rules.draft.portrait=rules.portraits()[0];rules.draft.soundset=rules.voices()[0];creator.render()
		check(rules.granted_feats().has(303) and rules.draft.familiar== -1 and rules.draft.familiarName=="","Controlled active class grants familiar feat while retaining original constructor state")
		check(await open_package(creator),"Physical Package entry opens actual native Recommended control")
		await click(front.packages.buttons.recommendbutton);await click(front.packages.buttons.okbutton)
		check(await wait_for(func():return creator.phase=="editing" and front.child.is_empty(),10) and front.flow.completed.packages,"Original failed Associate read still completes actual Recommended8008")
		check(rules.draft.packageSource and rules.draft.familiar== -1 and rules.draft.familiarName=="" and rules.draft.companion== -1 and not is_instance_valid(creator.package_names),"Recommended **** preserves both native sentinels and does not start a fake name worker")
		check(not rules.errors().has("Choose and name your familiar."),"Source Recommended is not rejected by an unrelated generic feat/name requirement")
		rules.draft.erase("packageSource");check(rules.errors().has("Choose and name your familiar."),"Generic drafts retain familiar feat/row/nonempty-name validation");rules.draft.packageSource=true
		metadata_cases(rules)
		await click(front.main.buttons.customizebutton)
		if check(await wait_for(func():return creator.tail.stage=="appearance" or not creator.tail.failure.is_empty(),15) and creator.tail.stage=="appearance","Actual Recommended enables source Appearance",creator.tail.failure):
			await click(creator.tail.appearance.buttons.okbutton)
			if check(creator.tail.stage=="information","Actual Appearance transfers its accepted draft to native Info"):
				var info=creator.tail.information
				check(await wait_for(func():return info.random_ready and info.pending_random<0,10),"Actual Info name worker completes")
				info.edits.firstnameedit.text="SourcePet";info.edits.firstnameedit.text_changed.emit("SourcePet");await click(info.buttons.okbutton)
				check(front.flow.completed.customize and rules.draft.sourceTailChoices,"Actual Info commits the source tail")
				var errors:=SourcePetBuilder.validation_errors(rules);check(errors.is_empty(),"Actual full native Builder admission accepts Recommended unset pet",errors)
				if errors.is_empty():
					var writer:=SourcePetBuilder.new();var bytes:=writer.build(rules);var parser:=PetGff.new();var doc:=parser.parse(bytes,"BIC ");built=not bytes.is_empty() and writer.failure.is_empty() and parser.failure.is_empty()
					check(built and doc.root.FamiliarType== -1 and doc.root.FamiliarName=="" and not doc.root.has("CompanionType"),"Actual full BIC preserves only class-owned signed unset pet fields")
	check(await wait_for(func():return creator.preview.retiring.is_empty(),10),"Normal asynchronous source preview retirement finishes before fixture teardown")
	check(not sent.any(func(message):return message.get("kind")=="native-creation-submit"),"Focused offline Builder acceptance never invents a server upload")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"built":built,"gpu":false,"serverConnections":0,"scope":"Actual Recommended controls with active class pet metadata/failed Associate cell, generic/manual validation separation, original signed-INT/class-owned writer shape, real source Appearance/Info and full native BIC acceptance. Controlled art/fonts; no authoritative server or pixel acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
