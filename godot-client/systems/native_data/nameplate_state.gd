extends RefCounted
# Presentation of received fields only. Exact HP is never requested to fill a
# plate: most remote creatures disclose only the server's damage category.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const F=preload("res://systems/native_render/particle_math.gd")
const CaptionState=preload("res://systems/native_data/popup_caption_state.gd")
# Original creature hover caption80b240. These are byte colors, independent
# of the mesh highlight palette and without a special controlled-player tint.
static func name_color(reaction: int) -> Color:
	return Color("#80ff80") if reaction==1 else Color("#ff5040") if reaction==2 else Color("#8080ff")
static func injury_color(level: int) -> Color:
	return Color(["#80ff80","#c8ff01","#ffc801","#ff6401","#ff5040"][level]) if level>=0 and level<=4 else Color("#808080")
static func integer(value: Variant) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or floor(float(value))!=float(value): return -1
	return int(value)
static func damage_level(state: Dictionary) -> int:
	var level:=integer(state.get("damageLevel"))
	if level>=0 and level<=5: return level
	var hp: Dictionary=state.get("hitPoints",{})
	if not hp.has("current") or not hp.has("maximum"): return -1
	var current: Variant=hp.current; var maximum: Variant=hp.maximum; var temporary: Variant=hp.get("fieldE8",0)
	for value in [current,maximum,temporary]:
		if not (value is int or value is float) or not is_finite(float(value)) or floor(float(value))!=float(value): return -1
	if float(maximum)<=0: return -1
	# Original495130 includes temporary HP for GetCurrentHitPoints(0).
	# Original495290 compares the binary32 ratio against these six categories.
	var total: int=(int(current)+int(temporary))&65535
	if total>=32768: total-=65536
	var ratio:=F.f(F.f(float(total))/F.f(float(maximum)))
	return 0 if ratio>=F.f(0.95) else 1 if ratio>=0.75 else 2 if ratio>=0.5 else 3 if ratio>=0.25 else 4 if ratio>0 else 5
static func signature(object: Dictionary,controlled: int,text_revision: int) -> int:
	var state: Dictionary=object.get("replicated",{})
	var misc: Dictionary=state.get("light",{})
	var item: Dictionary=object.get("item",state.get("item",{}))
	return hash([object.get("id"),object.get("objectType"),object.get("replicationRemoved",false),object.get("destroyed",false),item.get("name"),item.get("field2b8"),item.get("field2c0"),state.get("name",object.get("appearance",{}).get("name",object.get("staticState",{}).get("name"))),state.get("portrait"),state.get("portraitRef"),state.get("reaction"),state.get("damageLevel"),state.get("hitPoints"),state.get("interactionFlags"),misc.get("field270"),misc.get("field278"),controlled,text_revision])
static func color_open(color: Color) -> String:
	return "<c"+String.chr(color.r8)+String.chr(color.g8)+String.chr(color.b8)+">"
static func override_caption(raw: String,mode: int,custom: String) -> Dictionary:
	if mode==1: raw=custom
	elif mode==2: raw=custom+raw
	elif mode==3: raw+=custom
	var result:=Rich.parse(raw);var stream:=CaptionState.encoded(raw)
	if stream.get("ready",false):result.nativeRawBytes=stream.bytes
	return result
static func compose(name: String,condition: String,color: Color,condition_color: Color,mode: int,custom: String) -> Dictionary:
	# Original80b240 concatenates one raw caption before parsing inline colors.
	return override_caption(color_open(color)+name+"</c>\n"+color_open(condition_color)+condition+"</c>",mode,custom)
static func object_color(type: int,state: Dictionary) -> Color:
	if type==6: return Color("#ffc81e") # Original item83f230.
	# Original placeable871b60 uses client+1a0, the SECOND BOOL of update7a8460.
	# Creation's legacy reaction field maps to+1a8, not this caption flag.
	var flags: Array=state.get("interactionFlags",[])
	return Color("#ff0101") if type==9 and flags.size()>1 and flags[1] else Color("#8080ff")
static func project(object: Dictionary,controlled: int,text) -> Dictionary:
	var id:=int(object.get("id",-1)); var type:=int(object.get("objectType",0)); var creature:=type==5
	var state: Dictionary=object.get("replicated",{})
	var item: Dictionary=object.get("item",state.get("item",{}))
	var value: Variant=item.get("name",state.get("name",object.get("appearance",{}).get("name",object.get("staticState",{}).get("name"))))
	var name_raw: String=text.resolve({"text":text.name(value,id)},id); var name:=Rich.parse(name_raw)
	var reaction:=integer(state.get("reaction")); var level:=damage_level(state) if creature else -1
	var condition:={"text":"","spans":[]}; var portrait:=""; var condition_raw:=""
	if creature:
		var rules:=Rules.new(); rules.text=text; portrait=rules.portrait(object,1)
		var row:=rules.row("damagelevels",level); var ref:=Rules.number(Rules.cell(row,"STRING_REF"),-1)
		if ref>=0: condition_raw=text.resolve({"strRef":ref},id); condition=Rich.parse(condition_raw)
	var color:=name_color(reaction) if creature else object_color(type,state)
	# Reader781e80's generic0x400000 block already carries these raw misc fields;
	# its second INT and CExoString are client+124/+128, not light properties.
	var misc: Dictionary=state.get("light",{}); var mode:=integer(item.get("field2b8",misc.get("field270",0)) if type==6 else misc.get("field270",0)); var custom: String=str(item.get("field2c0",misc.get("field278","")) if type==6 else misc.get("field278",""))
	var caption:=compose(name_raw,condition_raw,color,injury_color(level),mode,custom) if creature else override_caption(color_open(color)+name_raw+"</c>",mode,custom)
	# Door/trigger vtable+220 is the original no-op766a60. Selection/highlight
	# remains available; those classes do not publish this world-name caption.
	return {"id":id,"available":type in [5,6,9] and not object.is_empty() and not object.get("replicationRemoved",false) and not object.get("destroyed",false) and not str(caption.text).is_empty(),"creature":creature,"name":name,"condition":condition,"caption":caption,"caption_color":Color.WHITE,"override_mode":mode,"portrait":portrait,"color":color,"condition_color":injury_color(level),"damage_level":level}
static func visible_ids(ids: Array,rows: Dictionary,hovered: int=-1) -> Array:
	var output: Array=[]
	for raw_id in ids:
		var id:=int(raw_id); var row: Dictionary=rows.get(id,{})
		var type:=int(row.get("type",0))
		if row.get("eligible",false) and (type==5 or id==hovered and type in [6,9]) and not output.has(id): output.append(id)
	return output
