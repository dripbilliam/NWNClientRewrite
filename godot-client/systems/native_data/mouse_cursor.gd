extends RefCounted
# nwmain 14083a2c0/14083b3e0; exact names and press flags are independently
# executed in scripts/inspect-native-mouse-cursor.py. No JS image/layout path.
const NetworkDoor=preload("res://systems/native_data/native_network_door.gd")
const NetworkTargeting=preload("res://systems/native_data/native_network_targeting.gd")
const BASE=["default","walk","nowalk","attack","noatck","talk","notalk","follow","examine","noexam","trans","door","use","nouse","magic","nomagic","disarm","nodisarm","action","noaction","lock","nolock","pushpin","create","nocreat","kill","nokill","heal","noheal"]
static func resource(id: int) -> String:
	if id<1 or id>292: return ""
	if id<=58: return "gui_mp_"+BASE[(id-1)/2]+("u" if id%2 else "d")
	if id<=90: return "gui_mp_"+("arrun" if id<75 else "arwalk")+("%02d"%((id-59)%16))
	if id<=92: return "gui_mp_pickup"+("u" if id==91 else "d")
	return "gui_mp_custom%02d%s"%[(id-93)/2,"u" if id%2 else "d"]
static func variant(id: int,allow_pressed: bool,pressed: bool) -> int:
	return id+1 if allow_pressed and pressed and id%2==1 and (id<=58 or id>=91) else id
static func selection(id: int=1,centered: bool=false,allow_pressed: bool=true) -> Dictionary:
	return {"id":id,"centered":centered,"allow_pressed":allow_pressed}
static func geometry(scale: float,centered: bool) -> Dictionary:
	# Godot hardware cursor limit is256px. Until software cursor publication is
	# ported, keep its hotspot inside that image at exceptionally large UI scales.
	scale=clampf(scale,1.0/32.0,8.0)
	var physical:=clampi(int(scale*32.0),1,256)
	return {"size":physical,"hotspot":Vector2i(int(scale*16.0),int(scale*16.0)) if centered else Vector2i.ZERO}
static func trigger_id(table: Dictionary,display_type: int,fallback: int=21) -> int:
	# 14086f6a0: physical cursors.2da row (BYTE), CursorID column. ResRef is
	# not a replacement filename map for the global cursor enum.
	var rows: Array=table.get("orderedRows",[]); var index:=display_type&255
	if index>=rows.size(): return fallback
	var value:=str(rows[index].get("CursorID","****"))
	return int(value)&65535 if value.is_valid_int() else fallback
static func override_id(object: Dictionary) -> int:
	var state: Dictionary=object.get("replicated",{})
	var light: Variant=state.get("light")
	var light_state: Variant=object.get("lightState")
	var misc: Variant=object.get("nativeMiscVisualFields")
	var value: Variant=null
	if light is Dictionary: value=light.get("field260")
	if value==null and light_state is Dictionary:value=light_state.get("field260")
	if value==null and misc is Dictionary:value=misc.get(0x260,misc.get("608"))
	if value==null:value=state.get("mouseCursor")
	return int(value) if (value is int or value is float) and is_finite(float(value)) and float(value)==float(int(value)) and value>=0 else -1
static func target(binding: Dictionary,kind: int,is_self: bool,mask: int=0,property_type: int=-1) -> Dictionary:
	# Original CActionTarget: 704720/703ea0 spell mask, 703310 feats,
	# 702c30 skills, 7039f0 tool properties, 98d5f0 server-script cursors.
	var type:=int(binding.get("type",0)); var valid:=false; var good:=29; var bad:=31
	if type==45:
		valid=NetworkTargeting.allowed(binding,kind)
		good=int(binding.get("cursor",29)); bad=int(binding.get("badCursor",31))
	elif type==3:
		good=37; bad=39; valid=kind in ([9,10] if int(binding.get("intParam",-1))==9 else [5])
	elif type==1 and property_type in [55,70,80]:
		good={55:41,70:33,80:55}[property_type]; bad=good+2
		valid=kind in ([9,10] if property_type==55 else [2,5,9,10])
	elif type==4 and int(binding.get("spellId",-1))<0:
		good=37; bad=39; valid=kind==5
	else:
		if type==4: bad=39
		var bit:= (1 if is_self else 2) if kind==5 else int({2:4,6:8,10:16,9:32,7:64}.get(kind,0))
		valid=(mask&bit)!=0
	var result:=selection(good if valid else bad); result.valid=valid; return result
static func world(hit: Dictionary,objects: Dictionary,actor_id: int,_cursors: Dictionary,_players: Array=[]) -> Dictionary:
	if hit.is_empty(): return selection()
	var id:=int(hit.get("id",-1)); var object: Dictionary=objects.get(id,{})
	if object.is_empty(): return selection(3)
	var state: Dictionary=object.get("replicated",{}); var custom:=override_id(object)
	if custom>=0:return selection(custom)
	match int(object.get("objectType",0)):
		5:
			return selection(1 if id==actor_id else (7 if int(state.get("reaction",0))>1 else 11))
		6: return selection(91)
		7: return selection(21 if bool(state.get("hasTransition",false)) and not bool(state.get("isTrap",false)) else 1)
		9:
			var usable: Variant=state.get("field264")
			if usable==null:usable=object.get("nativeUseable264")
			if usable==null:usable=object.get("usable")
			if usable==null and object.get("authored") is Dictionary:usable=object.authored.get("Useable")
			match typeof(usable):
				TYPE_NIL: return selection()
				TYPE_BOOL: return selection(25 if usable else 1)
				TYPE_INT, TYPE_FLOAT: return selection(25 if usable!=0 and not is_nan(float(usable)) else 1)
				TYPE_STRING: return selection(25 if not usable.is_empty() else 1)
			return selection(25)
		10:
			var click:Variant=NetworkDoor.click_state(object)
			return selection(21 if bool(state.get("hasTransition",false)) and click!=null and click>0 else 23)
	return selection()
