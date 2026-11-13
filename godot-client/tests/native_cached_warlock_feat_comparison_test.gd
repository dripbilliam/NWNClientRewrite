extends "res://tests/native_cached_warlock_creation_test.gd"
# Diagnostic private rule views only. The real shipping controls establish
# class/race/abilities; neither comparator mutates that actor or applies Skills.
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Package=preload("res://systems/native_data/creation_package_rules.gd")
const FeatState=preload("res://systems/native_data/creation_feat_state.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
func fixture_scope()->String:return "Bounded differential of generic PackageRules.recommend_feats and original-backed State.apply(recommend), using actual cached Warlock tables and the same physical-control pre-skill draft. Private clones only; no slot relaxation, actor edits, post-state injection, upload or server claim."
func rule_view(original,package_id:int):
	var value:=Rules.new();value.tables=original.tables;value.catalog=original.catalog;value.draft=original.draft.duplicate(true);value.draft.packageId=package_id;value.draft.feats=[]
	return value
func package_flow(creator,ui)->bool:
	var original=creator.rules;var before:=JSON.stringify(original.draft);var state:=FeatState.new();var cases:Array=[]
	if not check(original.draft.skills.is_empty() and original.draft.feats.is_empty(),"Actual source Package entry has the original pre-skill empty selection state",original.draft):return false
	var preference_names:Array=[]
	for package_id in [149,310,311,312,313,314]:
		var name:String=Package.resource(original,original.row("packages",package_id),"FeatPref2DA")
		if not preference_names.has(name):preference_names.append(name);creator.table(name)
	if not check(await wait_for(func():return preference_names.all(func(name):return original.tables.has(name)),8),"Existing active resource owner publishes every compared package preference",preference_names):return false
	for package_id in [149,310,311,312,313,314]:
		var generic=rule_view(original,package_id);var native=rule_view(original,package_id);var package_row:Dictionary=original.row("packages",package_id)
		var preference:String=Package.resource(original,package_row,"FeatPref2DA")
		Package.recommend_feats(generic,package_row)
		state.reset_selection();var model:Dictionary=state.apply("recommend",-1,native,ui.text,preference)
		if not check(model.get("ready",false),"Original-backed native recommendation is available for actual package"+str(package_id),model):return false
		var context:Dictionary=state.snapshot(native,ui.text);var source:Dictionary=context.source
		var owned:Array=generic.granted_feats()+generic.draft.feats.map(func(row):return int(row.id))
		var pref_ids:Array=[]
		for at in original.rows(preference).size():
			var entry:Dictionary=Tables.integer(original.tables[preference],at,"FeatIndex")
			if entry.get("ready",false) and entry.get("ok",false):pref_ids.append(int(entry.value)&65535)
		var candidates:Array=[]
		for id in [2300,2301,2302,2303,2304,2305,408,945]:
			candidates.append({"id":id,"inPreference":pref_ids.has(id),"genericNormal":generic.feat_allowed(id,"normal"),"genericBonus":generic.feat_allowed(id,"bonus"),"genericReason":generic.feat_requirement(id,owned),"native":state.candidate(source,id),"raw":original.row("feat",id).duplicate(true)})
		cases.append({"packageId":package_id,"preference":preference,"preSkillRanks":native.draft.skills.duplicate(true),"slots":generic.feat_slots(),"granted":generic.granted_feats(),"generic":generic.draft.feats.duplicate(true),"nativeSelected":state.selected.duplicate(),"nativeRemaining":model.get("remaining"),"nativeCanAccept":model.get("canAccept"),"nativeNormal":model.get("normal"),"nativeBonus":model.get("bonus"),"preferenceIds":pref_ids,"candidates":candidates})
	observations.featComparison=cases
	check(JSON.stringify(original.draft)==before,"Both private recommendation diagnostics leave the actual source draft unchanged")
	return failures.is_empty()
