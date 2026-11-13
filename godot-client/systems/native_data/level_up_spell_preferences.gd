extends RefCounted
# Mode1 table boundary for original7eb630. Preference conversion is lazy:
# a memorizing helper does not read the next INT after its BYTE budget is0.
# The mode-independent predicate/width behavior is unchanged. No draft I/O.
const Original=preload("res://systems/native_data/creation_spell_preferences.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
static func apply(source: Dictionary,preferences: Dictionary) -> Dictionary:
	var validation:=source.duplicate();validation.preferences=[]
	# Validate getter/book/spell boundaries through the accepted shared owner,
	# without eagerly converting rows that the native loop may never reach.
	var checked:=Original.apply(validation)
	if not checked.ready:return checked
	var known: Array=checked.known;var remaining:=0;var highest:=0;var calls: Array=[];var reads: Array=[]
	if source.loaded and source.restricted:
		if not preferences.get("orderedRows") is Array:return {"ready":false,"reason":"The active mode1 spell preference table is malformed."}
		if source.memorizes:remaining=(3+maxi(0,Values.signed8(int(source.intModifier))))&255 if (int(source.classLevel)&255)==1 else 2
		var columns:=Tables.columns(preferences)
		for at in preferences.orderedRows.size():
			if source.memorizes and remaining==0:break
			reads.append(at);var entry:=Tables.integer(preferences,at,"SpellIndex",columns)
			if not entry.ready:return {"ready":false,"reason":"A reached native spell preference conversion is unavailable."}
			if not entry.ok:continue
			var id:=int(entry.value)
			if id<0 or id>=source.spells.size():continue
			var spell: Dictionary=source.spells[id];var level:=int(spell.level)&255
			if level>=10 or not source.minimum[level]:continue
			if source.memorizes:
				if level!=0 and (int(source.gain[level])&255)==0:continue
				if (int(source.school)&255)!=0 and source.opposition!=null:
					if spell.school==null:return {"ready":false,"reason":"A preference requires an unavailable original school byte."}
					if (int(spell.school)&255)==(int(source.opposition)&255):continue
			else:
				if known[level].size()>=(int(source.capacity[level])&255):continue
			if known[level].has(id):continue
			known[level].append(id);calls.append(["learn",id]);highest=maxi(highest,level)
			if source.memorizes and level!=0:remaining=(remaining-1)&255
	return {"ready":true,"known":known,"remaining":remaining,"highest":highest,"calls":calls,"reads":reads}
