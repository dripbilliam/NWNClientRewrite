extends RefCounted
# Original9c2d80/9ccb40/9c7e40: fixed nine source tabs, active physical
# spellschools StringRef/Description. Preparation always selects General0.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const TAGS=["general","abjuration","conjuration","divination","enchantment","evocation","illusion","necromancy","transmutation"]
var model: Dictionary={}
var selected:=0
var help_title:=381
var help_description:=381
func reset(value: Dictionary) -> void:
	model=value.duplicate(true);selected=0;help_title=381;help_description=381
	# Original SelectTab0 changes the radio state without dispatching a click.
	# General help381 remains until a physical selection or Recommended.
func select_index(index: int) -> bool:
	if not model.get("ready",false) or index<0 or index>=9:return false
	selected=index;help_title=int(model.entries[index].title)&0xffffffff;help_description=int(model.entries[index].description)&0xffffffff;return true
func recommend() -> bool:
	return select_index(int(model.recommended)) if model.get("recommended") is int else false
static func choices(rules) -> Dictionary:
	if not rules.tables.has("spellschools"):return {"ready":false,"entries":[],"reason":"Active school metadata has not arrived."}
	var entries: Array=[];var table: Dictionary=rules.tables.spellschools
	for id in 9:
		var title:=Tables.integer(table,id,"StringRef");var description:=Tables.integer(table,id,"Description")
		if not title.ready or not description.ready:return {"ready":false,"entries":[],"reason":"Active school help conversion is unresolved."}
		entries.append({"id":id,"title":int(title.value)&0xffffffff,"description":int(description.value)&0xffffffff})
	var recommended: Variant=null
	if rules.tables.has("packages"):
		var read:=Tables.integer(rules.tables.packages,int(rules.draft.get("packageId",-1)),"School")
		if read.ready and int(read.value)>=0 and int(read.value)<9:recommended=int(read.value)
	return {"ready":true,"entries":entries,"recommended":recommended}
