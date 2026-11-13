extends RefCounted
# Original7eb630 with explicit active native getter/table results. The caller
# owns the known book and decides whether to publish this detached result.
const Values=preload("res://systems/native_data/character_record_values.gd")
static func scalar(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value)
static func unavailable(message: String) -> Dictionary:return {"ready":false,"reason":message}
static func apply(source: Dictionary) -> Dictionary:
	for key in ["memorizes","restricted","loaded"]:
		if not source.get(key) is bool:return unavailable("Native preference flag is unavailable: "+key)
	for key in ["classLevel","intModifier","school"]:
		if not scalar(source.get(key)):return unavailable("Native preference scalar is unavailable: "+key)
	if not source.has("opposition") or source.opposition!=null and not scalar(source.opposition):return unavailable("Native preference opposition result is unavailable.")
	for key in ["known","capacity","gain","minimum"]:
		if not source.get(key) is Array or source[key].size()!=10:return unavailable("Native preference level storage is unavailable: "+key)
	for level in 10:
		if not source.known[level] is Array or source.known[level].size()>255 or source.known[level].any(func(id):return not scalar(id)):return unavailable("The known-spell traversal is unavailable.")
		if not scalar(source.capacity[level]) or not scalar(source.gain[level]) or not source.minimum[level] is bool:return unavailable("A native preference getter result is unavailable.")
	if not source.get("spells") is Array or not source.get("preferences") is Array:return unavailable("Physical spell/preferences rows are unavailable.")
	for at in source.spells.size():
		var spell: Variant=source.spells[at]
		if not spell is Dictionary or not scalar(spell.get("id")) or int(spell.id)!=at or not scalar(spell.get("level")) or not spell.has("school") or spell.school!=null and not scalar(spell.school):return unavailable("Physical preference spell identity/metadata is unavailable.")
	for id in source.preferences:
		if id!=null and not scalar(id):return unavailable("A native preference conversion is unavailable.")
	var known: Array=source.known.map(func(row):return row.map(func(id):return int(id)));var remaining:=0;var highest:=0;var learned: Array=[]
	if source.loaded and source.restricted:
		if source.memorizes:
			remaining=(3+maxi(0,Values.signed8(int(source.intModifier))))&255 if (int(source.classLevel)&255)==1 else 2
		for value in source.preferences:
			if source.memorizes and remaining==0:break
			if value==null:continue
			var id:=int(value)
			if id<0 or id>=source.spells.size():continue
			var spell: Dictionary=source.spells[id];var level:=int(spell.level)&255
			if level>=10 or not source.minimum[level]:continue
			if source.memorizes:
				if level!=0 and (int(source.gain[level])&255)==0:continue
				if (int(source.school)&255)!=0 and source.opposition!=null:
					if spell.school==null:return unavailable("A preference requires an unavailable original school byte.")
					if (int(spell.school)&255)==(int(source.opposition)&255):continue
			else:
				# This original branch uses known capacity/minimum, without the
				# memorizing branch's spell-gain or opposition test.
				if known[level].size()>=(int(source.capacity[level])&255):continue
			if known[level].has(id):continue
			known[level].append(id);learned.append(["learn",id]);highest=maxi(highest,level)
			if source.memorizes and level!=0:remaining=(remaining-1)&255
	return {"ready":true,"known":known,"remaining":remaining,"highest":highest,"calls":learned}
