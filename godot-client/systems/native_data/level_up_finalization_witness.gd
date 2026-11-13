extends RefCounted
# Opt-in test witness only. Select existing scalar finalization data; never copy
# rule definitions, tables, text owners, live actors, Objects or private strings.
static func number(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high
static func pending(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func vector(value: Variant,count: int,low: int,high: int) -> bool:
	return value is Array and value.size()==count and value.all(func(item):return number(item,low,high))
static func feats(value: Variant) -> bool:
	return value is Array and value.size()<=4096 and value.all(func(item):return number(item,0,65535))
static func capture(scope: Array,ticket: Array,private: Dictionary,primary: Array,application: Dictionary,review: Dictionary,toughness: Variant) -> Dictionary:
	if not vector(scope,4,0,9007199254740991) or ticket.size()!=6 or ticket.slice(0,4)!=scope or not number(ticket[4],0,9007199254740991) or ticket[5]!="summary":return pending("Retired diagnostic finalization scope.")
	if not private.get("ready",false) or not private.get("vitals") is Dictionary or not private.get("source") is Dictionary or not review.get("ready",false):return pending("Diagnostic finalization data is unavailable.")
	var vitals: Dictionary=private.vitals;var source: Dictionary=private.source
	for key in ["raw","racial","gains","scores","modifiers"]:
		if not vector(vitals.get(key),6,-128,255):return pending("Diagnostic ability vector is malformed.")
	if not source.get("classes") is Array or source.classes.is_empty() or source.classes.size()>8 or not number(source.get("current"),0,source.classes.size()-1):return pending("Diagnostic class storage is malformed.")
	var classes: Array=[]
	for row in source.classes:
		if not row is Dictionary or not number(row.get("id"),0,254) or not number(row.get("level"),1,255):return pending("Diagnostic class row is malformed.")
		classes.append({"id":row.id,"level":row.level})
	if not feats(source.get("owned")) or not feats(primary):return pending("Diagnostic feat storage exceeds its bound.")
	if not application.get("forceMaximum") is bool or not application.get("hideHitPointGain") is bool or not number(toughness,-2147483648,2147483647):return pending("Diagnostic received/configured HP rules are unavailable.")
	if not number(review.get("hitDie"),1,255) or not number(review.get("displayHitPointGain"),-128,127) or not review.get("hiddenHitPointGain") is bool:return pending("Diagnostic numeric Summary is malformed.")
	var copied_vitals: Dictionary={}
	for key in ["raw","racial","gains","scores","modifiers"]:copied_vitals[key]=vitals[key].duplicate()
	var result:={"ready":true,"scope":scope.duplicate(),"ticket":ticket.duplicate(),"classes":classes,"currentClassIndex":source.current,"vitals":copied_vitals,"ownedFeats":source.owned.duplicate(),"primaryFeats":primary.duplicate(),"ownedTypes":source.owned.map(func(value):return typeof(value)),"primaryTypes":primary.map(func(value):return typeof(value)),"literalInt40Membership":{"owned":source.owned.has(40),"primary":primary.has(40)},"moduleFlags":{"forceMaximum":application.forceMaximum,"hideHitPointGain":application.hideHitPointGain},"toughnessHPBonus":toughness,"summary":{"hitDie":review.hitDie,"displayHitPointGain":review.displayHitPointGain,"hiddenHitPointGain":review.hiddenHitPointGain},"serverAcknowledged":false}
	# Only the two known module bits are emitted, even if the caller has more.
	result.moduleFlags={"forceMaximum":application.forceMaximum,"hideHitPointGain":application.hideHitPointGain}
	if JSON.stringify(result).to_utf8_buffer().size()>128*1024:return pending("Diagnostic finalization exceeds128KiB.")
	return result
