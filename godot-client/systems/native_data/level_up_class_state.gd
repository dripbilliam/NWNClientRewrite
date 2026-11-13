extends "res://systems/native_data/creation_class_state.gd"
# Shared CG_CLASS artwork; original mode1 availability7f7840 and
# recommendation8e6390 operate on actual received class slots/bitmap.
const Values=preload("res://systems/native_data/character_record_values.gd")
var resources_ready:=false
static func integer(value: Variant,low: int,high: int) -> bool:return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high
static func recommendation(classes: Array,current_index: int,available: Array,count: int) -> int:
	var current:=int(classes[current_index].id) if current_index>=0 and current_index<classes.size() else 255
	if current<available.size() and available[current]:return current
	for cls in classes:
		var id:=int(cls.id)
		if id<available.size() and available[id]:return id
	for id in count:
		if id<available.size() and available[id]:return id
	return -1
static func compose(tables: Dictionary,text,context: Dictionary,sorted: bool=true) -> Dictionary:
	var unavailable:={"ready":false,"entries":[],"recommended":{}}
	if not tables.has("classes") or not context.get("available") is Array or not context.get("classes") is Array or not context.get("multiclassRulesetFeature") is bool or not integer(context.get("currentClassIndex"),0,255):return unavailable
	var rows: Array=tables.classes.get("orderedRows",[]);var count:=rows.size()&255;var available: Array=context.available;var classes: Array=context.classes
	if classes.is_empty() or classes.size()>8:return unavailable
	for value in available:
		if not value is bool:return unavailable
	for cls in classes:
		if not cls is Dictionary or not integer(cls.get("id"),0,254) or not integer(cls.get("level"),1,255):return unavailable
	var limit: int=clampi(Values.cfg(tables,"MULTICLASS_LIMIT",3),1,8) if context.multiclassRulesetFeature else 3
	var recommended_id:=recommendation(classes,int(context.currentClassIndex),available,count);var entries: Array=[];var prepared_count:=0;var recommended: Dictionary={}
	for id in count:
		var entry:=detail(rows[id],id,text)
		if id==recommended_id:recommended=entry.duplicate()
		if Game.number(Game.cell(rows[id],"PlayerClass"),0)==0:continue
		var owned: bool=classes.any(func(cls):return int(cls.id)==id)
		entry.enabled=id<available.size() and available[id] and (classes.size()<limit or owned)
		if sorted:
			var first:=0 if entry.enabled else prepared_count;var end:=prepared_count if entry.enabled else entries.size()
			while first<end:
				var middle: int=(first+end)/2
				if fold(str(entry.name))<=fold(str(entries[middle].name)):end=middle
				else:first=middle+1
			entries.insert(first,entry)
			if entry.enabled:prepared_count=(prepared_count+1)&255
		else:entries.append(entry)
	return {"ready":true,"entries":entries,"recommended":recommended,"classLimit":limit,"recommendedId":recommended_id}
func reset(value: Dictionary) -> void:
	resources_ready=value.get("ready",false);entries=value.get("entries",[]).duplicate(true) if resources_ready else [];recommended=value.get("recommended",{}).duplicate() if resources_ready else {};selected=-1;general_help();recommend()
func recommend() -> void:
	if not resources_ready or recommended.is_empty():return
	for index in entries.size():
		if int(entries[index].id)==int(recommended.id):select_index(index);return
