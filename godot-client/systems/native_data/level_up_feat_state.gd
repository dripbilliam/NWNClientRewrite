extends "res://systems/native_data/creation_feat_state.gd"
# The list/group/selection core is shared; its first-level source adapter is
# not. Every model/click re-enters the private mode1 snapshot below.
const LevelSnapshot=preload("res://systems/native_data/level_up_feat_snapshot.gd")
const LevelCapacity=preload("res://systems/native_data/level_up_feat_capacity.gd")
const Recommendations=preload("res://systems/native_data/level_up_feat_recommendations.gd")
class ActiveTables extends RefCounted:
	var tables: Dictionary={}
	func rows(name: String) -> Array:return tables.get(name,{}).get("orderedRows",[])
var received: Dictionary={}
var private_context: Dictionary={}
var private_ranks: Array=[]
var selected_class:=-1
var selected_ability:=-1
var revision:=0
var spell_capacity:=Callable()
var view:=ActiveTables.new()
func configure(value: Dictionary,class_id: int,ability: int,ranks: Array,context: Dictionary,resolver: Callable=Callable()) -> void:
	received=value.duplicate(true);selected_class=class_id;selected_ability=ability;private_ranks=ranks.duplicate();private_context=context.duplicate(true);spell_capacity=resolver;selected=[];revision+=1
func model_key(_rules,text) -> Array:return [revision,selected.duplicate(),int(text.revision),text]
func model_tables(rules) -> Dictionary:return rules.tables.duplicate()
func snapshot(rules,text) -> Dictionary:
	var decoded:=prepare(rules,text)
	if not decoded.get("ready",false):return decoded
	var resolver:=spell_capacity
	if not resolver.is_valid():resolver=func(current: Dictionary,level: int):return LevelCapacity.evaluate(current,level,rules.tables)
	var current:=LevelSnapshot.resolve_spells(LevelSnapshot.compose(received,selected_class,selected_ability,private_ranks,rules.tables,private_context,selected,decoded),resolver)
	# Every candidate in this synchronous operation shares the same detached
	# current-class records, including their original first-match semantics.
	if current.get("ready",false):current.source=Context.prepare(current.source)
	return current
func model(tables: Dictionary,text) -> Dictionary:
	view.tables=tables;return compose(view,text)
func act(operation: String,id: int,tables: Dictionary,text,preferences: String="") -> Dictionary:
	view.tables=tables;return apply(operation,id,view,text,preferences)
func recommend(preferences: Dictionary,loaded: bool,tables: Dictionary,text) -> Dictionary:
	view.tables=tables;var current:=snapshot(view,text)
	if not current.get("ready",false):return current
	var value:=Recommendations.apply(current.source,preferences,loaded,candidate)
	if not value.ready:return value
	selected=value.selected.duplicate();return model(tables,text)
func validate(tables: Dictionary,text) -> Dictionary:
	view.tables=tables;var current:=snapshot(view,text)
	if not current.get("ready",false):return current
	var source: Dictionary=current.source;var seen: Dictionary={}
	for id in selected:
		if not id is int or id<0 or id>=source.definitions.size() or seen.has(id):return {"ready":true,"valid":false}
		seen[id]=true;var check_source:=source.duplicate();check_source.selected=selected.duplicate();check_source.selected.erase(id)
		var answer:=candidate(check_source,id)
		if not answer.ready:return answer
		if not answer.allowed:return {"ready":true,"valid":false}
	if ((int(source.normal)+int(source.bonus)-selected.size())&255)!=0:
		for id in source.definitions.size():
			var answer:=candidate(source,id)
			if not answer.ready:return answer
			if answer.allowed:return {"ready":true,"valid":false}
	return {"ready":true,"valid":true}
