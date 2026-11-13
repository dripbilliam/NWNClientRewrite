extends "res://tests/native_creation_feat_adapter_test.gd"
const Automatic=preload("res://systems/native_data/creation_feat_automatic.gd")
const Package=preload("res://systems/native_data/creation_package_rules.gd")
func model():
	var rules=fixture();rules.tables.racialtypes.orderedRows[0].NumberNormalFeatsEveryNthLevel="1"
	rules.tables.packages={"orderedRows":[{"FeatPref2DA":"preferences"}]};rules.tables.preferences={"orderedRows":[{"FeatIndex":"8"},{"FeatIndex":"9"},{"FeatIndex":"0"}]}
	rules.tables.classfeats.orderedRows.append_array([{"FeatIndex":"8","List":"1","GrantedOnLevel":"3"},{"FeatIndex":"8","List":"1","GrantedOnLevel":"1"},{"FeatIndex":"9","List":"1","GrantedOnLevel":"5"}])
	rules.draft.merge({"packageSource":true,"goodEvil":50,"lawChaos":50},true)
	return rules
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var rules=model();var raw: Dictionary=rules.tables.duplicate(true);var outcome: Dictionary=Package.recommend_feats(rules,rules.tables.packages.orderedRows[0]);var ids: Array=rules.draft.feats.map(func(row):return int(row.id))
	check(outcome.get("ready",false) and ids==[0],"Source automatic recommendation skips future grants and preserves the first duplicate class record",outcome)
	var receipt:=Automatic.capture(rules,{},[894,2]);var validity:=Automatic.verify(rules,receipt.get("receipt",{}))
	check(receipt.ready and validity.get("valid",false),"Source producer output and mandatory original worker replay agree",validity)
	check(rules.tables==raw,"Native recommendation does not mutate raw active class/feat definitions")
	rules.draft.feats=[{"id":8,"kind":"normal"}];outcome=Package.recommend_feats(rules,rules.tables.packages.orderedRows[0])
	check(outcome.get("ready",false) and rules.draft.feats.map(func(row):return int(row.id))==[0],"Repeated source Recommended replaces old choices instead of retaining an ineligible initial selection")
	rules.tables.preferences={"orderedRows":[]};outcome=Package.recommend_feats(rules,rules.tables.packages.orderedRows[0])
	check(outcome.get("ready",false) and rules.draft.feats.is_empty(),"Exhausted source preferences leave no stale prior feat or arbitrary filler")
	rules=model();rules.draft.packageSource=false;outcome=Package.recommend_feats(rules,rules.tables.packages.orderedRows[0])
	check(rules.draft.feats.map(func(row):return int(row.id))==[8],"Unrelated generic direct recommendation preserves its existing behavior")
	rules=model();rules.tables.preferences={"orderedRows":[{"FeatIndex":"0xZZ"}]};var before: Dictionary=rules.draft.duplicate(true);outcome=Package.recommend_feats(rules,rules.tables.packages.orderedRows[0])
	check(not outcome.get("ready",false) and rules.draft==before,"Unavailable native preference conversion leaves the private draft untouched",outcome)
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Source automatic Package recommendation uses exact original grant-level/first-record/candidate behavior, replaces prior choices and agrees with mandatory replay; generic direct branch remains historical. Controlled active data, no complete controls or original server acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
