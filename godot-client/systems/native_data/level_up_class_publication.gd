extends RefCounted
# Class names/order rebuild only when the active table/TLK/context publishes.
const State=preload("res://systems/native_data/level_up_class_state.gd")
var class_table: Variant=null
var rules_table: Variant=null
var text_owner
var text_revision:=-1
var context: Dictionary={}
var value: Dictionary={}
var publications:=0
func read(tables: Dictionary,text,current: Dictionary) -> Dictionary:
	var revision: int=int(text.revision) if text!=null else -1
	if not value.is_empty() and is_same(class_table,tables.get("classes")) and is_same(rules_table,tables.get("ruleset")) and text_owner==text and text_revision==revision and context==current:return value
	class_table=tables.get("classes");rules_table=tables.get("ruleset");text_owner=text;text_revision=revision;context=current.duplicate(true);value=State.compose(tables,text,current,true);publications+=1;return value
func reset() -> void:
	class_table=null;rules_table=null;text_owner=null;text_revision=-1;context={};value={}
