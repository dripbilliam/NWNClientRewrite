extends RefCounted
# nwmain 14083a2c0/14083b3e0; exact names and press flags are independently
# executed in scripts/inspect-native-mouse-cursor.py. No JS image/layout path.
const ObjectAnimation=preload("res://systems/native_data/object_animation.gd")
const BASE=["default","walk","nowalk","attack","noatck","talk","notalk","follow","examine","noexam","trans","door","use","nouse","magic","nomagic","disarm","nodisarm","action","noaction","lock","nolock","pushpin","create","nocreat","kill","nokill","heal","noheal"]
static func resource(id: int) -> String:
	if id<1 or id>292: return ""
	if id<=58: return "gui_mp_"+BASE[(id-1)/2]+("u" if id%2 else "d")
	if id<=90: return "gui_mp_"+("arrun" if id<75 else "arwalk")+("%02d"%((id-59)%16))
	if id<=92: return "gui_mp_pickup"+("u" if id==91 else "d")
	return "gui_mp_custom%02d%s"%[(id-93)/2,"u" if id%2 else "d"]
static func variant(id: int,allow_pressed: bool,pressed: bool) -> int:
	# The original has no directional-ID exception: callers control this flag.
	return id+id%2 if allow_pressed and pressed else id
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
	var value: Variant=state.get("light",{}).get("field260",state.get("mouseCursor",-1))
	return int(value) if value is int or value is float else -1
static func target(binding: Dictionary,kind: int,is_self: bool,mask: int=0,property_type: int=-1) -> Dictionary:
	# Original CActionTarget: 704720/703ea0 spell mask, 703310 feats,
	# 702c30 skills, 7039f0 tool properties, 98d5f0 server-script cursors.
	var type:=int(binding.get("type",0)); var valid:=false; var good:=29; var bad:=31
	if type==45:
		var bit: int=[5,6,7,10,11,12,9,14,13,2].find(kind)
		valid=bit>=0 and (int(binding.get("objectMask",0))&(1<<bit))!=0
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
static func world(hit: Dictionary,objects: Dictionary,actor_id: int,cursors: Dictionary,players: Array=[]) -> Dictionary:
	if hit.is_empty(): return selection(5,true)
	var id:=int(hit.get("id",-1)); var object: Dictionary=objects.get(id,{})
	if object.is_empty(): return selection(3)
	var state: Dictionary=object.get("replicated",{}); var custom:=override_id(object)
	match int(object.get("objectType",0)):
		5:
			var cursor:=1 if id==actor_id or players.has(id) else 7 if int(state.get("reaction",0))>1 else 11
			return selection(custom if custom>=0 else cursor)
		6: return selection(custom if custom>=0 else 91)
		7: return selection(3 if state.get("isTrap",false) else trigger_id(cursors,int(state.get("displayType",0))))
		9: return selection(custom if custom>=0 else 25)
		10:
			if state.get("hasTransition",false) and ObjectAnimation.door_state(state) in [1,2,3]: return selection(21)
			return selection(custom if custom>=0 else 23)
	return selection()
