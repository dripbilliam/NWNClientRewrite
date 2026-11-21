extends RefCounted
# Literal received-object rules from world_highlight.js. These belong to the
# optional world highlight view, independently of native popup caption rules.
const Interaction=preload("res://systems/native_interaction_policy.gd")
static func _truthy(value: Variant) -> bool:
	if value==null:return false
	if value is bool:return value
	if value is String:return not value.is_empty()
	if value is int or value is float:return float(value)!=0.0 and is_finite(float(value))
	return true
static func _greater_one(value: Variant) -> bool:
	if value is int or value is float:return float(value)>1.0
	if value is String and value.is_valid_float():return float(value)>1.0
	return false

static func eligible(object: Dictionary,area_id: int) -> bool:
	return Interaction.eligible(object,area_id)

static func color(object: Dictionary,player_id: int) -> Color:
	if int(object.get("id",-1))==player_id:return Color("#fff2b2")
	if int(object.get("objectType",0))==5:
		var state: Dictionary=object.get("replicated") if object.get("replicated") is Dictionary else {}
		var reaction: Variant=state.get("reaction")
		return Color("#ff5555") if _greater_one(reaction) else Color("#40ff40") if reaction==1 else Color("#a080ff")
	return Color("#00ffff")

static func name_color(object: Dictionary,player_id: int) -> Color:
	if int(object.get("objectType",0))!=5:return Color("#cfffff")
	var state: Dictionary=object.get("replicated") if object.get("replicated") is Dictionary else {}
	var reaction: Variant=state.get("reaction")
	return Color("#80ff80") if int(object.get("id",-1))==player_id or reaction==1 else Color("#ff5555") if _greater_one(reaction) else Color("#9080ff")

static func damage_level(object: Dictionary) -> int:
	var state: Dictionary=object.get("replicated") if object.get("replicated") is Dictionary else {}
	var category: Variant=state.get("damageLevel")
	if (category is int or category is float) and is_finite(float(category)) and floorf(float(category))==float(category) and category>=0 and category<=5:return int(category)
	var hp: Variant=state.get("hitPoints")
	if not hp is Dictionary:return -1
	var current: Variant=hp.get("current")
	var maximum: Variant=hp.get("maximum")
	if not (current is int or current is float) or not (maximum is int or maximum is float):return -1
	if not is_finite(float(current)) or not is_finite(float(maximum)) or float(maximum)<=0.0:return -1
	var temporary: Variant=hp.get("fieldE8",0)
	var bonus:=float(temporary) if temporary is int or temporary is float or temporary is String and temporary.is_valid_float() else NAN
	var ratio: float=(float(current)+bonus)/float(maximum)
	return 0 if ratio>=0.95 else 1 if ratio>=0.75 else 2 if ratio>=0.5 else 3 if ratio>=0.25 else 4 if ratio>0.0 else 5

static func name_value(object: Dictionary) -> Variant:
	var item: Dictionary=object.get("item") if object.get("item") is Dictionary else {}
	var state: Dictionary=object.get("replicated") if object.get("replicated") is Dictionary else {}
	var appearance: Dictionary=object.get("appearance") if object.get("appearance") is Dictionary else {}
	var static_state: Dictionary=object.get("staticState",{}) if object.get("staticState") is Dictionary else {}
	var authored: Dictionary=object.get("authored") if object.get("authored") is Dictionary else {}
	for value in [item.get("name"),state.get("name"),appearance.get("name"),static_state.get("name"),authored.get("LocName"),authored.get("LocalizedName"),object.get("name"),object.get("tag")]:
		if value!=null:return value
	return ""

static func name(value: Variant,resolve: Callable) -> String:
	if value is String:return value
	if value is Dictionary and (_truthy(value.get("firstName")) or _truthy(value.get("lastName"))):
		var fields: Array[String]=[]
		for key in ["firstName","lastName"]:
			var part: Variant=value.get(key)
			if part==null:continue
			var result: String=str(resolve.call(part)) if resolve.is_valid() else ""
			if not result.is_empty():fields.append(result)
		return " ".join(fields)
	return str(resolve.call(value)) if value!=null and resolve.is_valid() else ""
