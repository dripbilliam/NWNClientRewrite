extends RefCounted
# Original838950 roll before Summary; active class die getter7f4df0 is shared
# with the source-backed creation helper, but this is its separate mode1 roll.
const Class=preload("res://systems/native_data/level_up_class_state.gd")
const Vitals=preload("res://systems/native_data/creation_vitals.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
static func pending(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func roll_byte(die: int,total: int,threshold: int,force_maximum: Variant,seed: Variant) -> Dictionary:
	if die<0 or die>255 or total<0 or total>255:return pending("Original die/total BYTE is malformed.")
	var value:=die;var calls:=0;var seed_after: Variant=seed
	if threshold<total:
		if not force_maximum is bool or not Class.integer(seed,0,4294967295):return pending("Original application flag/private random owner is unavailable.")
		#c7ed00 executes before the application flag overrides the result.
		seed_after=(int(seed)*0x343fd+0x269ec3)&0xffffffff;var random_value: int=(int(seed_after)>>16)&32767;calls=1
		var signed_die:=Values.signed8(die);var half:=int(float(signed_die)/2.0);var divisor:=half+1
		if divisor==0:return {"ready":false,"originalUndefined":true,"randomCalls":calls,"seedAfter":seed_after,"reason":"Original hit-die signed division is undefined."}
		value=((random_value%divisor)+half)&255
		if force_maximum:value=die
	return {"ready":true,"value":value,"randomCalls":calls,"seedAfter":seed_after,"serverAcknowledged":false}
static func compose(snapshot: Dictionary,tables: Dictionary,application: Dictionary) -> Dictionary:
	if not snapshot.get("ready",false) or not tables.has_all(["classes","ruleset"]):return pending("Private finalization class/rule context is unavailable.")
	var source: Dictionary=snapshot.source;var index:=int(source.current)
	if index<0 or index>=source.classes.size():return pending("Private finalization current class is unavailable.")
	var cls: Dictionary=source.classes[index];var owned: Array=source.owned+source.selected
	var die: Variant=Vitals.starting_hitdie(int(cls.id),owned,tables)
	if die==null:return pending("Active original hit-die metadata is unavailable.")
	var total:=0
	for entry in source.classes:total=(total+int(entry.level))&255
	var roll:=roll_byte(int(die),total,Values.cfg(tables,"MIN_LEVEL_FOR_MAX_HP",3),application.get("forceMaximum"),application.get("randomSeed"))
	if roll.ready:roll.hitDie=int(roll.value);roll.classId=int(cls.id);roll.totalLevel=total
	return roll
