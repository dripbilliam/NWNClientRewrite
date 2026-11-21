extends RefCounted
# Read-only query of a separately published ordered native-received mask.
# Missing bits/override/count remain unavailable. This owns no entity store.
const SOURCE:="native_received_skill_admission"
const OVERRIDE_SOURCE:="received_game_master_permission_31_22"
static func active_count(table: Variant) -> Dictionary:
	# Native2ac6f0 stores lowBYTE of C2DA's physical row count, not row labels.
	# Read the current publication each time: no borrowed table or cached length.
	if not table is Dictionary or not table.get("orderedRows") is Array or table.has("error"):
		return {"available":false,"count":null,"physicalRows":null,"source":"active_skills_physical_rows"}
	var size:int=table.orderedRows.size()
	return {"available":true,"count":size&255,"physicalRows":size,"source":"active_skills_physical_rows"}
static func integer(value: Variant,maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=0 and value<=maximum
static func boolean(value: Variant) -> bool:return value is bool or integer(value,1)
static func native_override(value: Variant) -> bool:
	return value is bool or ((value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=-2147483648 and value<=2147483647)
static func valid(view: Variant) -> bool:
	if not view is Dictionary or view.get("version")!=1 or view.get("source")!=SOURCE or not integer(view.get("knownMask"),4294967295) or not view.get("playerUpdateSeen") is bool or not view.get("inventoryUpdateSeen") is bool:return false
	if view.has("override")!=view.has("overrideSource"):return false
	if view.has("override") and (not integer(view.override,0) or view.overrideSource!=OVERRIDE_SOURCE):return false
	var known:=int(view.knownMask)
	return view.get("mask")==null if known==0 else integer(view.get("mask"),4294967295) and (int(view.mask)&(~known&0xffffffff))==0
static func merge(current: Variant,changes: Variant,source: Variant) -> Dictionary:
	if current!=null and not valid(current):return {"ok":false,"error":"Invalid native skill-admission view"}
	if not changes is Dictionary or (source!="player" and source!="inventory" and source!="permission"):
		return {"ok":false,"error":"Invalid native skill-admission input"}
	var value:Dictionary=current.duplicate(false) if current is Dictionary else {"version":1,"source":SOURCE,"mask":null,"knownMask":0,"playerUpdateSeen":false,"inventoryUpdateSeen":false}
	var bits:int=0 if value.mask==null else int(value.mask)
	var known:int=int(value.knownMask)
	if source=="player" and changes.has("skillFlags"):
		if not integer(changes.skillFlags,4294967295):return {"ok":false,"error":"Native player skill flags must be a DWORD"}
		bits=int(changes.skillFlags)
		known=0xffffffff
		value.playerUpdateSeen=true
	elif source=="inventory" and changes.has("skills"):
		if not changes.skills is Array:return {"ok":false,"error":"Native inventory skill changes are unavailable"}
		for row in changes.skills:
			if not row is Dictionary or not integer(row.get("index"),254) or not boolean(row.get("flag")):
				return {"ok":false,"error":"Invalid native inventory skill flag"}
			if row.flag==true or (not row.flag is bool and int(row.flag)==1):
				var bit:int=1<<(int(row.index)&31)
				bits=(bits|bit)&0xffffffff
				known=(known|bit)&0xffffffff
		value.inventoryUpdateSeen=true
	elif source=="permission" and changes.has("permission"):
		if not integer(changes.permission,1):return {"ok":false,"error":"Native permission BOOL is unavailable"}
		if int(changes.permission)==0:
			value.override=0
			value.overrideSource=OVERRIDE_SOURCE
	value.knownMask=known
	value.mask=null if known==0 else bits
	return {"ok":true,"value":value}
static func override_value(view:Variant)->Variant:
	return 0 if valid(view) and view.has("override") else null
static func unknown(reason: String) -> Dictionary:return {"available":false,"value":null,"nativeResult":null,"reason":reason}
static func query(view: Variant,skill: Variant,count: Variant,override: Variant=null) -> Dictionary:
	if not integer(skill,65535):return unknown("invalid_skill")
	if not integer(count,255):return unknown("skill_count_unavailable")
	if int(skill)>=int(count):return {"available":true,"value":false,"nativeResult":0,"reason":"outside_active_rules"}
	if override!=null and not native_override(override):return unknown("override_unavailable")
	if override!=null and bool(override):return {"available":true,"value":true,"nativeResult":1,"reason":"native_override"}
	if not valid(view):return unknown("native_mask_unavailable")
	var bit:=1<<(int(skill)&31)
	if (int(view.knownMask)&bit)==0:return unknown("native_bit_unavailable")
	if (int(view.mask)&bit)!=0:return {"available":true,"value":true,"nativeResult":null if override==null else bit,"reason":"received_set_bit"}
	if override==null:return unknown("native_override_unavailable")
	return {"available":true,"value":false,"nativeResult":0,"reason":"received_clear_bit"}
