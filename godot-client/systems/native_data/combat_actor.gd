extends RefCounted
# Original server fields and native active-table projections for the retained
# original-derived attack selector. Missing information stays missing.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Queue=preload("res://systems/animation_queue.gd")
static func row(tables: Dictionary,name: String,index: int) -> Dictionary:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
static func integer(table: Dictionary,index: int,column: String) -> int:
	var rows: Array=table.get("orderedRows",[])
	var value: Variant=Rules.cell(rows[index] if index>=0 and index<rows.size() else {},column)
	var is_default:=value==null
	var text:=str(table.get("defaultValue","")) if is_default else str(value)
	var hex:=not is_default and text.to_lower().begins_with("0x")
	var pattern:=RegEx.new(); pattern.compile("^0[xX][0-9a-fA-F]+" if hex else "^\\s*[+-]?\\d+")
	var found:=pattern.search(text)
	if found==null: return 0
	var parsed:=found.get_string(); var number:=parsed.hex_to_int() if parsed.to_lower().begins_with("0x") else parsed.to_int()
	number&=0xffffffff
	return number-0x100000000 if number>=0x80000000 else number
static func real(data: Dictionary,column: String) -> Variant:
	var value: Variant=Rules.cell(data,column)
	if value==null or str(value) in ["","****"]: return null
	var pattern:=RegEx.new(); pattern.compile("^\\s*[+-]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][+-]?\\d+)?")
	var found:=pattern.search(str(value)); var number:=Queue.f(found.get_string().to_float() if found!=null else 0.0)
	return number if is_finite(number) else null
static func project(object: Dictionary,tables: Dictionary) -> Dictionary:
	var appearance: Dictionary=row(tables,"appearance",int(object.get("appearance",{}).get("appearance",-1)))
	var equipment: Dictionary={}
	for source in object.get("appearance",{}).get("equipment",[]):
		var item: Dictionary=source.get("item",{})
		if item.is_empty(): continue
		var base:=int(item.baseItem); var data:=row(tables,"baseitems",base)
		equipment[str(int(source.slot))]={"baseItem":base,"weaponType":integer(tables.get("baseitems",{}),base,"WeaponType"),"weaponWield":integer(tables.get("baseitems",{}),base,"WeaponWield"),"weaponSize":integer(tables.get("baseitems",{}),base,"WeaponSize"),"slashLeft":integer(tables.get("baseitems",{}),base,"%AnimSlashL"),"slashRight":integer(tables.get("baseitems",{}),base,"%AnimSlashR"),"preferredDistance":real(data,"PrefAttackDist")}
	var result:={"id":int(object.id),"lifetime":int(object.get("nativeLifetime",0)),"objectType":int(object.objectType),"equipment":equipment,"hitDistance":real(appearance,"HITDIST"),"preferredDistance":real(appearance,"PREFATCKDIST"),"weaponScale":real(appearance,"WEAPONSCALE"),"targetHeight":str(Rules.cell(appearance,"TARGETHEIGHT","")),"abortOnParry":integer(tables.get("appearance",{}),int(object.get("appearance",{}).get("appearance",-1)),"ABORTONPARRY") if not appearance.is_empty() else null}
	refresh(result,object); return result
static func refresh(result: Dictionary,object: Dictionary) -> void:
	var state: Dictionary=object.get("replicated",{}); var classes: Variant=state.get("stats",{}).get("classes")
	result.lifetime=int(object.get("nativeLifetime",0))
	result.monk=classes.any(func(cls):return int(cls.id)==5) if classes is Array else null
	result.facingTarget=state.get("facingTarget",0x7f000000)
	result.hitPoints=state.get("hitPoints",{}).get("current")
	result.animationSpeed=state.get("animationSpeed",1.0); result.base=state.get("animation",0)
