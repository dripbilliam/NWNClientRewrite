extends RefCounted
# Original7ee690 OR traversal over a complete decoded native class snapshot.
# The caller retains its native spell-gain owner and supplies that getter for
# memorizing classes; unknown capacity is never converted into zero/denied.
const Nonmemorizing=preload("res://systems/native_data/creation_feat_spell_rules.gd")

static func pending(reason: String,index: int=-1) -> Dictionary:
	return {"ready":false,"allowed":false,"reason":reason,"classIndex":index}
static func scalar(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value)
static func evaluate(source: Dictionary,required_level: int,memorizing_gain: Callable=Callable()) -> Dictionary:
	var required:=required_level&255
	if required==0:return {"ready":true,"allowed":true}
	if not source.get("classes") is Array or source.classes.size()>8:return pending("Native class snapshot is unavailable or outside its physical capacity.")
	var unresolved: Dictionary={}
	for index in source.classes.size():
		var cls: Variant=source.classes[index]
		var spell: Variant=cls.get("spell") if cls is Dictionary else null
		if not spell is Dictionary or not scalar(spell.get("SpellCaster")):
			if unresolved.is_empty():unresolved=pending("Native class spell metadata is unavailable.",index)
			continue
		if int(spell.SpellCaster)==0:continue
		if not scalar(spell.get("MemorizesSpells")):
			if unresolved.is_empty():unresolved=pending("Native class memorization metadata is unavailable.",index)
			continue
		if int(spell.MemorizesSpells)!=0:
			if not memorizing_gain.is_valid():
				if unresolved.is_empty():unresolved=pending("Native memorizing spell-gain owner is unavailable.",index)
				continue
			var capacity: Variant=memorizing_gain.call(index,required)
			if not capacity is Dictionary or not capacity.get("ready") is bool or not capacity.ready or not scalar(capacity.get("gain")) or capacity.gain<0 or capacity.gain>255:
				if unresolved.is_empty():unresolved=pending("Native memorizing spell-gain result is unavailable.",index)
				continue
			if int(capacity.gain)!=0:return {"ready":true,"allowed":true}
		else:
			var metadata_ready:=spell.get("knownPresent") is bool
			for key in ["SpellbookRestricted","LearnScroll","ability","NumSpellLevels"]:
				if not scalar(spell.get(key)):metadata_ready=false
			var valid_arrays:=true
			for values in [source.get("baseAbilities"),source.get("raceAdjust"),spell.get("abilityGain")]:
				if not values is Array or values.size()!=6 or values.any(func(value):return not scalar(value)):valid_arrays=false
			for values in [spell.get("gain"),spell.get("known")]:
				if not values is Array or values.any(func(value):return not scalar(value)):valid_arrays=false
			if not metadata_ready or not valid_arrays:
				if unresolved.is_empty():unresolved=pending("Native non-memorizing ability storage is unavailable.",index)
				continue
			# Preserve the original per-class non-memorizing branch and current
			# ordering. This shallow context owns only its one-element class list;
			# the existing core reads, but never mutates, the borrowed stat arrays.
			var context:=source.duplicate();context.classes=[cls]
			var answer:=Nonmemorizing.nonmemorizing(context,required)
			if not answer.ready:
				if unresolved.is_empty():unresolved=pending(str(answer.get("reason","Native non-memorizing spell storage is unavailable.")),index)
			elif answer.allowed:return {"ready":true,"allowed":true}
	return unresolved if not unresolved.is_empty() else {"ready":true,"allowed":false}
