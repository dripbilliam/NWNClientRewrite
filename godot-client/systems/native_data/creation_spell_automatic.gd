extends RefCounted
# Original Package8e4620, not the CG_SPELLS9c9df0 chooser. Only the mandatory
# BIC worker replays the operation; input capture contains bounded ID arrays.
const Context=preload("res://systems/native_data/creation_feat_automatic.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Snapshot=preload("res://systems/native_data/creation_spells_snapshot.gd")
const Plan=preload("res://systems/native_data/creation_spell_recommendation_plan.gd")
const Preferences=preload("res://systems/native_data/creation_spell_preferences.gd")
class NumericText extends RefCounted:
	func raw(_reference: Dictionary) -> String:return ""
static func unavailable(reason: String) -> Dictionary:return {"ready":false,"valid":false,"reason":reason}
static func invalid(reason: String) -> Dictionary:return {"ready":true,"valid":false,"reason":reason}
static func books(value: Variant,prepared: bool=false) -> Dictionary:
	if not value is Dictionary:return unavailable("The automatic package spell book is unavailable.")
	var result: Array=[]
	for level in 10:
		var row: Variant=value.get(level,value.get(str(level),[]))
		if not row is Array or row.size()>255:return unavailable("An automatic spell level exceeds verified native save storage.")
		var ids: Array=[];var seen: Dictionary={}
		for id in row:
			if prepared and id==null:ids.append(null);continue
			if not id is int or id<0 or id>65535:return unavailable("An automatic spell ID exceeds verified native word storage.")
			if not prepared and seen.has(id):return unavailable("An automatic known-spell book repeats an ID.")
			seen[id]=true;ids.append(id)
		result.append(ids)
	return {"ready":true,"value":result}
static func before(rules) -> Dictionary:
	var known:=books(rules.draft.get("known"));var memorized:=books(rules.draft.get("memorized"),true)
	if not known.ready:return known
	if not memorized.ready:return memorized
	#8e5770/8dc6d0 clears these derived choices before opening Package. Do not
	# admit a transplanted book or invent an untraced pre-entry cache.
	if known.value.any(func(row):return not row.is_empty()) or memorized.value.any(func(row):return not row.is_empty()):return unavailable("Reopen the package before applying its spell recommendations.")
	return {"ready":true,"known":known.value,"memorized":memorized.value}
static func operation(rules) -> Dictionary:
	var table: Variant=rules.tables.get("packages")
	if not table is Dictionary or not table.get("orderedRows") is Array:return unavailable("The active automatic spell package is unavailable.")
	var id:=int(rules.draft.get("packageId",-1))
	if id<0 or id>=table.orderedRows.size():return unavailable("The active automatic spell package row is unavailable.")
	var cell:=Tables.cell(table,id,"SpellPref2DA")
	if not cell.found or cell.text in ["","****"]:return {"ready":true,"kind":"none","name":"","loaded":false}
	var name:=str(cell.text).to_lower().left(16);var classes: Variant=rules.tables.get("classes")
	if not classes is Dictionary:return unavailable("The compiled automatic spell class is unavailable.")
	var restricted:=Tables.integer(classes,int(rules.draft.classId),"SpellbookRestricted")
	if not restricted.ready or not restricted.ok:return unavailable("The compiled automatic spell restriction is unavailable.")
	if int(restricted.value)==0:return {"ready":true,"kind":"none","name":name,"loaded":false}
	var memorizes:=Tables.integer(classes,int(rules.draft.classId),"MemorizesSpells")
	if not memorizes.ready or not memorizes.ok:return unavailable("The compiled automatic memorization flag is unavailable.")
	if not rules.tables.has(name):return unavailable("The automatic spell preferences have not arrived.")
	var value: Variant=rules.tables[name]
	if not value is Dictionary or not value.is_empty() and not value.get("orderedRows") is Array:return unavailable("The automatic spell preference table is malformed.")
	return {"ready":true,"kind":"memorizing" if int(memorizes.value)!=0 else "spontaneous","name":name,"loaded":value.get("orderedRows") is Array}
static func capture(rules,initial: Dictionary,scope: Array) -> Dictionary:
	if not initial.get("ready",false) or not initial.get("known") is Array or not initial.get("memorized") is Array:return unavailable("The initial automatic spell operation is unavailable.")
	if scope.size()!=2 or scope.any(func(value):return not value is int or value<0 or value>9007199254740991):return unavailable("The automatic spell draft owner is unavailable.")
	var core:=Context.context(rules);var known:=books(rules.draft.get("known"));var memorized:=books(rules.draft.get("memorized"),true);var op:=operation(rules)
	for value in [core,known,memorized,op]:
		if not value.ready:return value
	return {"ready":true,"receipt":{"version":1,"completed":true,"scope":scope.duplicate(),"context":core.value,"initialKnown":initial.known.duplicate(true),"initialMemorized":initial.memorized.duplicate(true),"known":known.value,"memorized":memorized.value,"operation":{"kind":op.kind,"name":op.name,"loaded":op.loaded}}}
static func arrays(value: Variant,prepared: bool=false) -> Dictionary:
	if not value is Array or value.size()!=10:return unavailable("The automatic spell receipt levels are malformed.")
	var dictionary: Dictionary={}
	for level in 10:dictionary[level]=value[level]
	return books(dictionary,prepared)
static func verify(rules,receipt: Variant) -> Dictionary:
	if not receipt is Dictionary or not receipt.get("version") is int or receipt.version!=1 or not receipt.get("completed") is bool or not receipt.completed:return invalid("The completed automatic spell receipt is unavailable.")
	if not rules.draft.get("packageSource") is bool or not rules.draft.packageSource or rules.draft.get("sourceSpellChoices",false):return invalid("The automatic spell receipt belongs to another selection mode.")
	var scope: Variant=receipt.get("scope")
	if not scope is Array or scope.size()!=2 or scope.any(func(value):return not value is int or value<0 or value>9007199254740991):return invalid("The automatic spell draft owner is malformed.")
	var core:=Context.context(rules);var known:=books(rules.draft.get("known"));var memorized:=books(rules.draft.get("memorized"),true);var op:=operation(rules)
	var initial:=arrays(receipt.get("initialKnown"));var initial_mem:=arrays(receipt.get("initialMemorized"),true);var saved:=arrays(receipt.get("known"));var saved_mem:=arrays(receipt.get("memorized"),true)
	for value in [core,known,memorized,op,initial,initial_mem,saved,saved_mem]:
		if not value.ready:return value
	if not receipt.get("context") is Dictionary or core.value!=receipt.context:return invalid("The automatic spell character context changed.")
	if known.value!=saved.value or memorized.value!=saved_mem.value:return invalid("The accepted automatic spell books changed.")
	if not receipt.get("operation") is Dictionary or receipt.operation!={"kind":op.kind,"name":op.name,"loaded":op.loaded}:return invalid("The active automatic spell preference source changed.")
	if initial.value.any(func(row):return not row.is_empty()) or initial_mem.value.any(func(row):return not row.is_empty()):return invalid("The automatic spell baseline was not reset by package entry.")
	var expected: Array=initial.value.duplicate(true);var prepared: Array=initial_mem.value.duplicate(true)
	if op.kind!="none":
		var view:=Context.RuleView.new();view.tables=rules.tables;view.draft=core.value.duplicate(true);view.draft.known={}
		for level in 10:view.draft.known[level]=initial.value[level].duplicate()
		# This is a data/getter projection, never GUI initialization9ce190.
		# Its optional counter guard stays enabled for every manual caller.
		var snapshot:=Snapshot.compose(view,NumericText.new(),false)
		if not snapshot.ready:return snapshot
		var source: Dictionary=snapshot.source
		if op.kind=="memorizing" and expected[0].is_empty():
			for spell in source.spells:
				if int(spell.level)==0:expected[0].append(int(spell.id))
		if expected.any(func(row):return row.size()>255):return unavailable("An automatic known book exceeds the terminating native save counter.")
		source.known=expected
		var plan:=Plan.compose(view,source)
		if not plan.ready:return plan
		if not plan.get("helperInvoked",false):return invalid("The automatic spell helper source changed.")
		source.restricted=plan.restricted;source.loaded=plan.loaded;source.preferences=plan.preferences;source.opposition=plan.opposition
		var answer:=Preferences.apply(source)
		if not answer.ready:return answer
		expected=answer.known
		if op.kind=="memorizing":
			prepared=[]
			for level in 10:
				var count: Variant=source.gain[level]
				if not count is int or count<0 or count>255:return unavailable("An automatic memorization slot count is unavailable.")
				prepared.append(expected[level].slice(0,mini(int(count),expected[level].size())))
		# Exact replay above validates active physical IDs/levels/minimum/gain/
		# opposition/duplicates; no arbitrary spell or counter filler is added.
	if expected!=known.value or prepared!=memorized.value:return invalid("The active automatic spell recommendation result changed.")
	return {"ready":true,"valid":true}
