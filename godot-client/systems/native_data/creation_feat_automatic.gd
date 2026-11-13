extends RefCounted
# Package8e4620 ignores RecommendFeats7eb040's remaining CHAR. This receipt
# records that operation, not manual CG_FEATS completion. Replay stays in the
# existing mandatory BIC worker; no definitions or table graphs enter draft.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Snapshot=preload("res://systems/native_data/creation_feat_snapshot.gd")
const Choice=preload("res://systems/native_data/creation_feat_choice_rules.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Index=preload("res://systems/native_data/creation_feat_context.gd")
class RuleView extends RefCounted:
	var tables: Dictionary={}
	var draft: Dictionary={}
	func rows(name: String) -> Array:return tables.get(name.to_lower(),{}).get("orderedRows",[])
	func row(name: String,id: int) -> Dictionary:
		var values:=rows(name);return values[id] if id>=0 and id<values.size() else {}
	func cls() -> Dictionary:return row("classes",int(draft.classId))
	func num(data: Dictionary,key: String,fallback: int=0) -> int:return Game.number(Game.cell(data,key),fallback)
static func unavailable(reason: String) -> Dictionary:return {"ready":false,"valid":false,"reason":reason}
static func invalid(reason: String) -> Dictionary:return {"ready":true,"valid":false,"reason":reason}
static func rank_map(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size()>256:return unavailable("The automatic package skill context is unavailable.")
	var result: Dictionary={}
	for key in value:
		if not key is int or key<0 or key>255 or not value[key] is int or value[key]<0 or value[key]>255:return unavailable("The automatic package skill context is malformed.")
		result[key]=value[key]
	return {"ready":true,"value":result}
static func context(rules) -> Dictionary:
	var d: Dictionary=rules.draft;var result: Dictionary={}
	for field in ["classId","raceId","packageId","school","goodEvil","lawChaos"]:
		if not d.get(field) is int:return unavailable("The automatic package character context is unavailable.")
		result[field]=d[field]
	if not d.get("abilities") is Dictionary or not d.get("domains") is Array or d.domains.size()>2:return unavailable("The automatic package ability/domain context is unavailable.")
	result.abilities={};result.domains=[]
	for key in Snapshot.Skills.KEYS:
		if not d.abilities.get(key) is int:return unavailable("The automatic package raw abilities are unavailable.")
		result.abilities[key]=d.abilities[key]
	for id in d.domains:
		if not id is int:return unavailable("The automatic package domain identity is malformed.")
		result.domains.append(id)
	return {"ready":true,"value":result}
static func selected(d: Dictionary) -> Dictionary:
	if not d.get("feats") is Array or d.feats.size()>255:return unavailable("The automatic package feat list is unavailable.")
	var result: Array=[]
	for value in d.feats:
		if not value is Dictionary or not value.get("id") is int or value.id<0 or value.id>65535:return unavailable("The automatic package feat identity is malformed.")
		result.append(value.id)
	return {"ready":true,"value":result}
static func preference(rules) -> Dictionary:
	var table: Variant=rules.tables.get("packages")
	if not table is Dictionary or not table.get("orderedRows") is Array:return unavailable("The active automatic package table is unavailable.")
	var id:=int(rules.draft.get("packageId",-1))
	if id<0 or id>=table.orderedRows.size():return unavailable("The active automatic package row is unavailable.")
	var field:=Tables.cell(table,id,"FeatPref2DA")
	if not field.found or field.text in ["","****"]:return {"ready":true,"invoked":false,"name":"","loaded":false}
	var name:=str(field.text).to_lower().left(16)
	if not rules.tables.has(name):return unavailable("The active automatic feat preferences have not arrived.")
	var value: Variant=rules.tables[name]
	if not value is Dictionary or not value.is_empty() and not value.get("orderedRows") is Array:return unavailable("The active automatic feat preference table is malformed.")
	# An explicitly published empty failure differs from an unloaded table.
	# Original Load2DArray failure returns the untouched remaining budget.
	return {"ready":true,"invoked":true,"name":name,"loaded":value.get("orderedRows") is Array}
static func capture(rules,before_skills: Dictionary,scope: Array) -> Dictionary:
	if scope.size()!=2 or scope.any(func(value):return not value is int or value<0 or value>9007199254740991):return unavailable("The automatic package draft owner is unavailable.")
	var current:=context(rules);var before:=rank_map(before_skills);var after:=rank_map(rules.draft.get("skills"));var ids:=selected(rules.draft);var prefs:=preference(rules)
	for value in [current,before,after,ids,prefs]:
		if not value.ready:return value
	var slots: Dictionary=rules.feat_slots();var normal:=int(slots.normal)&255;var bonus:=int(slots.bonus)&255
	return {"ready":true,"receipt":{"version":1,"completed":true,"scope":scope.duplicate(),"context":current.value,"preSkills":before.value,"postSkills":after.value,"selected":ids.value,"normal":normal,"bonus":bonus,"remaining":(normal+bonus-ids.value.size())&255,"preferences":{"invoked":prefs.invoked,"name":prefs.name,"loaded":prefs.loaded}}}
static func recommendation(rules,prepared: Dictionary={}) -> Dictionary:
	# The Package producer and worker replay share7eb040's candidate semantics.
	# In particular the first class record's future grant must reject a feat.
	var prefs:=preference(rules)
	if not prefs.ready:return prefs
	var decoded: Dictionary=prepared if prepared.get("ready",false) else Tables.decode(rules.tables.get("feat",{}))
	if not decoded.ready:return decoded
	var initial:=Snapshot.resolve_spells(Snapshot.compose(rules,[],decoded),rules)
	if not initial.ready:return initial
	var source:=Index.prepare(initial.source);var remaining: int=(int(source.normal)+int(source.bonus))&255;var chosen: Array=[]
	if prefs.invoked and prefs.loaded:
		var table: Dictionary=rules.tables[prefs.name];var columns:=Tables.columns(table)
		for row in table.orderedRows.size():
			if remaining==0:break
			var read:=Tables.integer(table,row,"FeatIndex",columns)
			if not read.ready:return read
			if not read.ok:continue
			var id:=int(read.value)&65535;var check:=source.duplicate();check.selected=chosen.duplicate();check.featId=id;check.feat=source.definitions[id] if id<source.definitions.size() else {}
			var answer:=Choice.evaluate(check)
			if not answer.ready:return answer
			if answer.allowed:chosen.append(id);remaining=(remaining-1)&255
	return {"ready":true,"selected":chosen,"remaining":remaining,"normal":source.normal,"bonus":source.bonus}
static func verify(rules,receipt: Variant) -> Dictionary:
	if not receipt is Dictionary or not receipt.get("version") is int or receipt.version!=1 or not receipt.get("completed") is bool or not receipt.completed:return invalid("The completed automatic package feat receipt is unavailable.")
	if not rules.draft.get("packageSource") is bool or not rules.draft.packageSource or rules.draft.get("sourceFeatChoices",false):return invalid("The automatic package feat receipt belongs to another selection mode.")
	var scope: Variant=receipt.get("scope")
	if not scope is Array or scope.size()!=2 or scope.any(func(value):return not value is int or value<0 or value>9007199254740991):return invalid("The automatic package feat owner is malformed.")
	# Creator owns actual connection/draft publication and build/result fences.
	# This detached scope is provenance, not a replacement for those fences.
	if not receipt.get("context") is Dictionary or not receipt.get("postSkills") is Dictionary or not receipt.get("selected") is Array or not receipt.get("preferences") is Dictionary:return invalid("The automatic package feat receipt context is malformed.")
	if receipt.selected.size()>255 or receipt.selected.any(func(value):return not value is int or value<0 or value>65535):return invalid("The automatic package feat receipt identities are malformed.")
	var current:=context(rules);var before:=rank_map(receipt.get("preSkills"));var after:=rank_map(rules.draft.get("skills"));var ids:=selected(rules.draft);var prefs:=preference(rules)
	for value in [current,before,after,ids,prefs]:
		if not value.ready:return value
	if current.value!=receipt.get("context") or after.value!=receipt.get("postSkills") or ids.value!=receipt.get("selected"):return invalid("The accepted automatic package character choices changed.")
	if receipt.get("preferences")!={"invoked":prefs.invoked,"name":prefs.name,"loaded":prefs.loaded}:return invalid("The active automatic package preference source changed.")
	for field in ["normal","bonus","remaining"]:
		if not receipt.get(field) is int or receipt[field]<0 or receipt[field]>255:return invalid("The automatic package feat budget is malformed.")
	var view:=RuleView.new();view.tables=rules.tables;view.draft=current.value.duplicate(true);view.draft.skills=before.value
	var decoded:=Tables.decode(rules.tables.get("feat",{}))
	if not decoded.ready:return decoded
	var replay:=recommendation(view,decoded)
	if not replay.ready:return replay
	if replay.normal!=receipt.normal or replay.bonus!=receipt.bonus:return invalid("The active automatic package feat budgets changed.")
	var chosen: Array=replay.selected;var remaining: int=replay.remaining
	if chosen!=ids.value or remaining!=receipt.remaining:return invalid("The active automatic feat preference result changed.")
	var final:=Snapshot.resolve_spells(Snapshot.compose(rules,chosen,decoded),rules)
	if not final.ready:return final
	var seen: Dictionary={}
	for id in chosen:
		if seen.has(id):return invalid("The automatic package repeats a feat.")
		seen[id]=true
		var check: Dictionary=final.source.duplicate();check.selected=chosen.duplicate();check.selected.erase(id);check.featId=id;check.feat=final.source.definitions[id]
		var answer:=Choice.evaluate(check)
		if not answer.ready:return answer
		if not answer.allowed:return invalid("An automatic feat prerequisite or reservation changed.")
	# Deliberately no manual all-candidate completeness scan:8e4620 ignores
	# the original preference-only helper's remaining CHAR, including nonzero.
	return {"ready":true,"valid":true,"selected":chosen,"remaining":remaining}
