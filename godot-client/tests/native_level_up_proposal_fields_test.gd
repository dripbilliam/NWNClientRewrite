extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Metadata=preload("res://systems/native_data/level_up_class_metadata.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Names=preload("res://systems/native_data/pregame_skills.gd")
const Owner=preload("res://systems/native_data/level_up_source_owner.gd")
const Snapshot=preload("res://systems/native_data/level_up_feat_snapshot.gd")
var checks:=0
var failures: Array=[]
var proposals: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> bool:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
	return value
func read(catalog,name: String,tables: Dictionary) -> void:
	if name.is_empty() or name=="****" or tables.has(name):return
	var parser:=Parser.new();tables[name]=parser.parse(catalog.get_resource(name,2017).get_string_from_ascii());check(parser.failure.is_empty(),"Actual source2DA parses: "+name)
func id_for(table: Dictionary,label: String) -> int:
	for at in table.orderedRows.size():
		var cell:=Tables.cell(table,at,"Label")
		if cell.found and str(cell.text).to_lower()==label:return at
	return -1
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original installed active tables mount read-only")
	var tables: Dictionary={}
	for name in ["classes","racialtypes","ruleset","skills","feat","domains"]:read(catalog,name,tables)
	var raw_classes: Dictionary=tables.classes.duplicate(true);var compiled:=Metadata.compile(tables.classes)
	if not check(compiled.ready,"Actual native mode1 class projection is ready"):quit(1);return
	tables=tables.duplicate();tables.classes=compiled.table
	var wizard:=id_for(tables.classes,"wizard");var cleric:=id_for(tables.classes,"cleric");var fighter:=id_for(tables.classes,"fighter");var human:=id_for(tables.racialtypes,"human")
	if not check(wizard>=0 and cleric>=0 and fighter>=0 and human>=0,"Original labels resolve physical IDs without stock UI substitution"):quit(1);return
	for id in [wizard,cleric,fighter]:
		for field in ["FeatsTable","SkillsTable","StatGainTable","AttackBonusTable","BonusFeatsTable"]:read(catalog,Names.table_name(tables.classes.orderedRows[id],field),tables)
	var domain_ids: Array=[]
	for id in tables.domains.orderedRows.size():
		var value:=Tables.integer(tables.domains,id,"Name")
		if value.ready and value.ok and int(value.value)>0:domain_ids.append(id)
	var pair: Array=domain_ids.slice(0,2);check(pair.size()==2,"Two actual source domain IDs are available")
	var ranks: Array=[];ranks.resize(tables.skills.orderedRows.size()&255);ranks.fill(0)
	var prepared_definitions:=Tables.decode(tables.feat)
	for label in ["wizard_owned_zero","wizard_owned_other","cleric_owned","wizard_fresh_selected","cleric_fresh_selected"]:
		var fresh: bool=str(label).contains("fresh");var domain: bool=str(label).begins_with("cleric");var class_id: int=cleric if domain else wizard
		var cls: Dictionary={"id":fighter if fresh else class_id,"level":3}
		if not fresh:
			if domain:cls.domains=pair.duplicate()
			else:cls.school=2 if label=="wizard_owned_other" else 0
		var received:={"actorId":42,"race":human,"classes":[cls],"baseAbilities":[14,14,14,14,14,14],"skills":ranks.duplicate(),"fieldDC6":0,"feats":[],"fieldD4":0,"fieldE34":-1,"fieldE48":"","fieldE30":-1,"fieldE38":""};var before:=received.duplicate(true)
		var owner:=Owner.new();owner.wanted=true;owner.received=received.duplicate(true);owner.class_id=class_id;owner.context={"baseFortitude":0};owner.attributes.selected=1;owner.tables=tables;owner.initial_tables=tables.duplicate();owner.navigation.begin([1,7,42,90]);owner.navigation.enter("summary");owner.finalization={"ready":true,"hitDie":4}
		owner.configure_definitions(func():return prepared_definitions)
		if fresh:
			if domain:owner.selected_domains=pair.duplicate()
			else:owner.selected_school=2
		if not check(owner.skills.configure(received,class_id,1,tables),"Actual mode1 skill/private inputs prepare "+str(label),owner.skills.failure):owner.close();continue
		var private_before:=owner.private_draft();var prepared:=Snapshot.compose(received,class_id,1,owner.skills.ranks,tables,owner.context);var value:=owner.proposal()
		if check(value.ready,"Actual SourceOwner.proposal is ready "+str(label),value):
			var expected_school: int=0 if domain else 2 if fresh or label=="wizard_owned_other" else 0;var expected_domains: Array=pair if domain else []
			check(value.proposal.school==expected_school and value.proposal.domains==expected_domains,"Normalized copied or selected school/domains replace private sentinels "+str(label),value.proposal)
			check(value.proposal.hitDie==4 and value.proposal.feats==prepared.source.owned.slice(received.feats.size()) and not value.proposal.has("selectedFeats") and not value.proposal.has("receivedFields"),"Other normalized die/granted-feat fields retain their exact proposal ownership "+str(label))
			check(owner.private_draft()==private_before and received==before and owner.received==before,"Proposal normalization never changes received state or private chooser selections "+str(label))
			proposals.append({"label":label,"level":3,"skillCount":ranks.size(),"pickSchool":not domain,"pickDomains":domain,"expectedSchool":expected_school,"expectedDomains":expected_domains,"proposal":value.proposal})
		owner.close()
	check(raw_classes==compiled.raw,"Raw active class graph is preserved")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"proposals":proposals,"serverConnections":0,"gpu":false,"scope":"Actual SourceOwner.proposal with original installed/private-compiled mode1 tables, owned school0/nonzero/domain pair and fresh selected children; final normalized field precedence and immutable received/private state. Authored prepared source inputs; no full UI/server acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
