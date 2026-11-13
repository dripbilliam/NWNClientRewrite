extends SceneTree
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Metadata=preload("res://systems/native_data/creation_class_metadata.gd")
const Associate=preload("res://systems/native_data/creation_associate_state.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual original data mounts read-only")
	var rules:=Rules.new();rules.catalog=catalog
	for name in ["classes","racialtypes","ruleset"]:rules.tables[name]=Parser.new().parse(catalog.get_resource(name,2017).get_string_from_utf8())
	rules.tables.classes=Metadata.compile(rules.tables.classes).table;rules.initialize()
	check(int(rules.draft.classId)>=0 and int(rules.draft.raceId)>=0 and rules.draft.abilities.size()==6,"Real new-character initialization executes installed class/race/vitals rules")
	check(rules.draft.familiar== -1 and rules.draft.companion== -1,"Original7ea7a0 initializes both signed associate types to -1 viaQWORD+bec")
	check(rules.draft.familiarName.is_empty() and rules.draft.companionName.is_empty(),"Original7ea7a0 initializes+bf8/+c08 CExoStrings empty, without generic names")
	var pane:=Associate.new();var choices:={"ready":true,"entries":[{"id":2,"title":1,"base":"server_pet_","name":"Server pet"}],"arcane":1,"level":1}
	var view:=pane.configure(choices,rules.draft.familiar,rules.draft.familiarName)
	check(view.ready and view.selected==0 and view.physicalId==2 and view.needsGeneratedName,"The current manual source chooser maps original unset type to its first physical row and requests real generation")
	check(not pane.commit().ready and pane.commit().get("needsGeneratedName",false),"An unset native name cannot silently commit a generic label")
	rules.draft.familiar=2;rules.draft.familiarName="Chosen name";rules.reset_choices()
	check(rules.draft.familiar==2 and rules.draft.familiarName=="Chosen name" and rules.draft.companion== -1,"Original derived-choice reset preserves explicitly accepted associate choices")
	rules.initialize();check(rules.draft.familiar== -1 and rules.draft.companion== -1 and rules.draft.familiarName.is_empty() and rules.draft.companionName.is_empty(),"A new draft resets both namespaces to the proven original constructor state")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Actual first-level Rules.initialize with installed class/race/ruleset and original private class metadata, native constructor associate sentinels/empty strings, manual chooser generation admission and derived reset. No BIC type/admission or complete control flow claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
