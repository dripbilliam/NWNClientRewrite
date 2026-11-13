extends RefCounted
# Detached mode1 chooser/transcript. Existing original state owns list ordering
# and selection; the adapter above supplies private level-up input, not CG_MAIN.
const Snapshot=preload("res://systems/native_data/level_up_spells_snapshot.gd")
const Original=preload("res://systems/native_data/creation_spells_state.gd")
const Recommendations=preload("res://systems/native_data/level_up_spell_recommendations.gd")
var state:=Original.new()
var context: Dictionary={}
var tables_used: Dictionary={}
func configure(received: Dictionary,private_snapshot: Dictionary,tables: Dictionary,text,school: int=-1) -> Dictionary:
	state=Original.new();context=Snapshot.compose(received,private_snapshot,tables,text,school);tables_used=tables.duplicate()
	if not context.ready:return context
	return state.configure(context.source)
func current(tables: Dictionary) -> bool:
	if not context.get("ready",false) or not state.ready:return false
	for name in tables_used:
		if not tables.has(name) or not is_same(tables_used[name],tables[name]):return false
	return true
func model(tables: Dictionary) -> Dictionary:return state.view() if current(tables) else {"ready":false,"available":[],"known":[],"reason":"Active mode1 spell source changed or is unavailable."}
func act(operation: String,id: int,tables: Dictionary) -> Dictionary:
	if not current(tables):return model(tables)
	match operation:
		"add":state.add(id)
		"remove":state.remove(id)
		"level":state.select_level(id)
		"reset":state.reset_choices()
	return model(tables)
func recommend(plan: Dictionary,tables: Dictionary) -> Dictionary:
	if not current(tables):return model(tables)
	return Recommendations.finish(state,plan)
func changes(tables: Dictionary) -> Dictionary:
	if not current(tables) or not state.can_accept():return {"ready":false}
	var known: Dictionary={};var removed: Dictionary={}
	for level in 10:
		known[level]=state.known[level].filter(func(id):return not state.baseline[level].has(id))
		removed[level]=state.baseline[level].filter(func(id):return not state.known[level].has(id))
	return {"ready":true,"known":known,"removed":removed}
