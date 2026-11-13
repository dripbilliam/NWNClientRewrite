extends RefCounted
# A small, detached projection of the exact received token owner. Decoder field
# names remain unchanged: Stats+58=subrace, +bc8=deity, +c6/+c8=alignment.
static func scalar(value: Variant) -> bool:
	return value==null or value is String or value is int or value is float or value is bool
static func name_value(value: Variant) -> Variant:
	if value is String:return value
	if not value is Dictionary:return null
	if value.get("bytes") is Array:return {"bytes":value.bytes.duplicate()}
	var copy: Dictionary={}
	for key in ["text","strRef","gender","firstName","lastName"]:
		if value.has(key):copy[key]=name_value(value[key]) if key in ["firstName","lastName"] else (value[key] if scalar(value[key]) else null)
	return copy
static func project(value: Dictionary) -> Dictionary:
	var copy: Dictionary={}
	for key in ["id","objectType","areaId","nativeLifetime","clientKnownLifetime"]:
		if value.has(key) and scalar(value[key]):copy[key]=value[key]
	for section in ["replicated","appearance"]:
		if not value.get(section) is Dictionary:continue
		var source: Dictionary=value[section];var selected: Dictionary={}
		if source.has("name"):selected.name=name_value(source.name)
		if section=="replicated" and source.get("stats") is Dictionary:
			var stats: Dictionary={}
			for key in ["race","racialType","fieldD20","fieldD28","fieldE58","fieldDE4","fieldDE6"]:
				if source.stats.has(key):
					if key in ["fieldD28","fieldE58"]:stats[key]=name_value(source.stats[key])
					elif scalar(source.stats[key]):stats[key]=source.stats[key]
			if source.stats.get("classes") is Array:
				stats.classes=[]
				if not source.stats.classes.is_empty():
					var first: Variant=source.stats.classes[0];var entry: Dictionary={}
					if first is Dictionary:
						for key in ["id","level"]:
							if first.has(key) and scalar(first[key]):entry[key]=first[key]
					stats.classes.append(entry)
			selected.stats=stats
		copy[section]=selected
	if value.get("nativeStoredName") is Dictionary:
		copy.nativeStoredName={}
		for key in ["override","first","last"]:
			var part: Variant=value.nativeStoredName.get(key)
			if part is Dictionary:
				copy.nativeStoredName[key]={}
				for field in ["known","text"]:
					if part.has(field) and scalar(part[field]):copy.nativeStoredName[key][field]=part[field]
	return copy
static func frame(value: Dictionary) -> Dictionary:
	var copy: Dictionary={}
	for key in ["gender","nativeB8","nativeBC","nativeC0","nativePlayersComplete"]:
		if value.has(key) and scalar(value[key]):copy[key]=value[key]
	if value.get("context") is Dictionary:copy.context=project(value.context)
	if value.get("nativeWorld") is Dictionary:
		copy.nativeWorld={}
		for key in ["native160","native164","native16c","native17c","native17d"]:
			if value.nativeWorld.has(key) and scalar(value.nativeWorld[key]):copy.nativeWorld[key]=value.nativeWorld[key]
	if value.get("nativePlayers") is Dictionary:
		copy.nativePlayers={}
		for key in value.nativePlayers:
			if not value.nativePlayers[key] is Dictionary:copy.nativePlayers[key]=null;continue
			copy.nativePlayers[key]={}
			for field in ["known","present","name"]:
					if value.nativePlayers[key].has(field):
						if field=="name":copy.nativePlayers[key][field]=name_value(value.nativePlayers[key][field])
						elif scalar(value.nativePlayers[key][field]):copy.nativePlayers[key][field]=value.nativePlayers[key][field]
	return copy
static func tokens(value: Dictionary,wire: bool) -> Dictionary:
	var copy: Dictionary={}
	for key in value:
		if wire and value[key] is String:
			var encoded:=preload("res://systems/native_data/native_talk_parser.gd").encode(value[key],0)
			copy[key]={"bytes":Array(encoded.bytes)} if encoded.get("ready",false) else null
		else:copy[key]=value[key].duplicate(true) if value[key] is Dictionary or value[key] is Array else value[key]
	return copy
static func event_frame(value: Dictionary) -> Dictionary:
	# Envelope.context is an identity witness, not retained ParseStr context.
	# Only the newly captured module/roster providers belong to this frame.
	var selected: Dictionary={}
	for key in ["nativeWorld","nativePlayers","nativePlayersComplete"]:
		if value.has(key):selected[key]=value[key]
	return frame(selected)
