extends SceneTree
const Context=preload("res://systems/native_data/level_up_recommendation_context.gd")
const Publication=preload("res://systems/native_data/level_up_rule_publication.gd")
const Attributes=preload("res://systems/native_data/level_up_attributes_state.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var received:={"classes":[{"id":0,"level":3}],"fieldD4":0};var tables:={"classes":{"orderedRows":[{"Package":"1"},{"Package":"2"}]},"packages":{"defaultValue":"CHA","orderedRows":[{"Attribute":"DEX","SkillPref2DA":"pref0"},{"Attribute":"CON","SkillPref2DA":"pref1"},{"Attribute":"wis","SkillPref2DA":"****"}]},"pref0":{"orderedRows":[{"SkillIndex":"0"}]},"pref1":{"orderedRows":[{"SkillIndex":"0X1"},{"SkillIndex":"65537"},{"SkillIndex":"****"}]}}
	var before:=received.duplicate(true);var raw:=tables.duplicate(true);var result:=Context.attributes(received,0,tables)
	check(result.ready and result.loaded and result.attribute=="DEX" and result.context.source=="received" and result.context.packageId==0,"Owned slot0 uses copied Package rather than the class's different configured Package",result)
	result=Context.skills(received,0,tables);check(result.ready and result.invoked and result.loaded and result.ids==[0],"Slot0 SkillPref uses the same original received Package")
	result=Context.attributes(received,1,tables);var state:=Attributes.new();state.recommend(result.attribute,result.loaded)
	check(result.ready and result.attribute=="wis" and result.context.source=="native_class" and result.context.packageId==2 and state.selected==0,"Appended class uses active class Package; original lowercase Attribute falls through to STR")
	var changed:=tables.duplicate(true);changed.classes.orderedRows[1].Package="1";result=Context.skills(received,1,changed)
	check(result.ready and result.ids==[1,1],"Native INT conversion and lowWORD preference identity are preserved")
	changed.classes.orderedRows[1].erase("Package");changed.classes.defaultValue="7";result=Context.attributes(received,1,changed);state.recommend(result.attribute,result.loaded)
	check(result.ready and result.context.packageId==-1 and result.attribute=="CHA" and state.selected==5,"Missing conditional class Package keeps proven ctor-1, then Attribute consumes actual table DEFAULT despite failed row lookup")
	changed.classes.orderedRows[1].Package="0xGG";check(not Context.attributes(received,1,changed).ready,"Undefined native class Package conversion does not select row0")
	var missing:=received.duplicate(true);missing.erase("fieldD4");check(not Context.attributes(missing,0,tables).ready,"Missing copied Package cannot borrow a constructor or first-level value")
	missing.fieldD4=4294967295;result=Context.attributes(missing,0,tables);check(result.ready and result.context.packageId==-1 and result.attribute=="CHA","Copied DWORD sentinel preserves signed C2DA row semantics")
	changed=tables.duplicate(true);changed.packages={};result=Context.attributes(received,0,changed);state.selected=1;state.recommend(result.attribute,result.loaded)
	check(result.ready and not result.loaded and state.selected==-1,"Known failed Packages load preserves original Attribute refund with no replacement choice")
	check(Context.skills(received,0,changed).get("invoked")==false,"Failed Packages load does not authorize a Skills baseline reset")
	changed=tables.duplicate(true);changed.packages={"defaultValue":"pref0","orderedRows":[{}]};result=Context.skills(received,0,changed)
	check(result.ready and not result.invoked,"SkillPref false lookup ignores nonempty DEFAULT and preserves begun choices")
	for pref in [{"orderedRows":[]},{}]:
		changed=tables.duplicate(true);changed.pref0=pref;result=Context.skills(received,0,changed)
		check(result.ready and result.invoked and result.ids.is_empty() and result.loaded==pref.has("orderedRows"),"Successful SkillPref lookup distinguishes valid empty from failed load while retaining reset authorization",result)
	changed=tables.duplicate(true);changed.erase("pref0");result=Context.skills(received,0,changed)
	check(not result.ready and result.pending and result.invoked and result.dependencies==["pref0"],"Absent declared preferences are pending after successful string lookup, with reset authorization")
	changed=tables.duplicate(true);changed.erase("packages");result=Context.skills(received,0,changed)
	check(not result.ready and result.pending and result.dependencies==["packages"] and not result.get("invoked",false),"Unloaded Packages is pending before Skills reset")
	changed=tables.duplicate(true);changed.pref0={"orderedRows":[{"SkillIndex":"0xGG"}]};result=Context.skills(received,0,changed)
	check(not result.ready and result.invoked,"Malformed preference conversion stays explicit after the original baseline-reset boundary")
	var duplicate:=Parser.new().parse_reference("2DA V2.0\nattribute Attribute skillpref2da SkillPref2DA\n0 INT CON pref0 pref1\n");changed=tables.duplicate(true);changed.packages=duplicate
	check(Context.attributes(received,0,changed).attribute=="INT" and Context.skills(received,0,changed).ids==[0],"Original first case-insensitive physical column wins over later exact-case aliases")
	check(received==before and tables==raw,"Recommendation context never mutates received snapshot or active table graph")
	var owner:=Publication.new();var catalog:=RefCounted.new();var foreign:=RefCounted.new();var scope: Array=[1,2,42,61];var active:={"classes":{"orderedRows":[{}]},"ruleset":{"orderedRows":[]}}
	var view:=owner.begin(active,scope,catalog);var captured: Dictionary=view.tables
	check(owner.open_private_request(scope,catalog,10),"Current token/catalog can open a scoped private data request")
	var published:=owner.publish_private("packages",tables.packages,scope,catalog,10)
	check(published.ready and published.tables.has("packages") and not active.has("packages") and not captured.has("packages"),"Menu dependency publication changes only a new private map, never canonical/earlier maps")
	for item in [{"name":"classes","scope":scope,"catalog":catalog,"request":10},{"name":"ruleset","scope":scope,"catalog":catalog,"request":10},{"name":"bad","scope":[1,2,42,60],"catalog":catalog,"request":10},{"name":"bad","scope":scope,"catalog":foreign,"request":10},{"name":"bad","scope":scope,"catalog":catalog,"request":9}]:
		check(not owner.publish_private(item.name,{},item.scope,item.catalog,item.request).ready,"Private dependency rejects canonical/class/foreign token/catalog/request publication",item.name)
	owner.finish_private_request(scope,catalog,10);check(not owner.publish_private("late",{},scope,catalog,10).ready and not owner.open_private_request(scope,catalog,10),"Finished request cannot publish or reopen after retirement")
	check(owner.open_private_request(scope,catalog,11),"A later genuine request can reuse the current transaction")
	active.packages={"orderedRows":[]};view=owner.publish(active,scope)
	check(is_same(view.tables.packages,active.packages) and not owner.publish_private("packages",tables.packages,scope,catalog,11).ready,"Canonical data winning a load race retains authority over a private dependency")
	owner.begin(active,[1,2,42,62],foreign);check(not owner.publish_private("late",{},scope,catalog,11).ready,"Reopen/catalog retirement rejects old resource completions")
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"serverConnections":0,"gpu":false,"scope":"Mode1 Attributes/Skills recommendation package/string/native conversion semantics and private dependency token/catalog/request publication. Pure controlled data; no actual button/asset-worker/runtime/server acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
