extends RefCounted
# Original UpdateIcons14083f6f0 / base-item resource naming29dd90/29dc80.
# Data-only native selection; no browser renderer or hardcoded module items.
var failure:=""
static func row(tables: Dictionary,name: String,index: int) -> Dictionary:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
static func number(value: Variant,fallback: int=0) -> int:
	var text:=str(value)
	if text.to_lower().begins_with("0x") and text.is_valid_hex_number(true): return text.hex_to_int()
	return int(float(text)) if text.is_valid_float() else fallback
static func resource_ref(type: int,prefix: String,gender_specific: bool,part: int,id: int,gender: int) -> String:
	var signed:=(id&65535)-65536 if id&32768 else id&65535
	var suffix:="_"+"BMT"[part] if type==2 else ("_"+str(char(gender)) if gender_specific else "")
	var digits:="-"+str(-signed).pad_zeros(2) if signed<0 else str(signed).pad_zeros(3)
	return ("i"+prefix+suffix+"_"+digits).left(16).to_lower()
func plan(item: Dictionary,tables: Dictionary,gender: int=0) -> Dictionary:
	failure=""
	var base:=int(item.get("baseItem",-1)); var original:=row(tables,"baseitems",base)
	var width:=number(original.get("InvSlotWidth")); var height:=number(original.get("InvSlotHeight")); var type:=number(original.get("ModelType"),-1)
	if width<1 or height<1 or width>10 or height>10 or type not in [0,1,2,3]: failure="Original icon dimensions/type are unavailable"; return {}
	var parts: Array=item.get("parts",[])
	if parts.size()<(19 if type==3 else (3 if type==2 else 1)): failure="Original icon parts are incomplete"; return {}
	var colors: Array=item.get("colors",[])
	if type in [1,3] and colors.size()!=6: failure="Original icon palette is incomplete"; return {}
	var palette:=[0,0,colors[4] if colors.size()>4 else 0,colors[5] if colors.size()>5 else 0,colors[2] if colors.size()>2 else 0,colors[3] if colors.size()>3 else 0,colors[0] if colors.size()>0 else 0,colors[1] if colors.size()>1 else 0,0,0]
	var layers: Array=[]
	if type==3:
		var armor_parts:=[6,7,8,14,15,18]; var palette_parts:=[6,7,8,15,14,18]; var palettes: Array=[]; var robe:=int(parts[18])
		for part in palette_parts:
			var selected:=palette.duplicate(); var channels:=[6,7,4,5,2,3]; var overrides: Variant=item.get("partColors",[])
			var overrides_row: Variant=overrides.get(str(part),overrides.get(part,[])) if overrides is Dictionary else (overrides[part] if overrides is Array and part<overrides.size() else [])
			for index in 6:
				if overrides_row is Array and index<overrides_row.size() and int(overrides_row[index])!=255: selected[channels[index]]=int(overrides_row[index])
			palettes.append(selected)
		for index in armor_parts.size():
			var hidden: Variant=row(tables,"parts_robe",robe).get(["HIDEPELVIS","HIDECHEST","HIDEBELT","HIDESHOR","HIDESHOL"][index]) if index<5 else null
			if (index==5 and robe<3) or (index<5 and robe>=3 and (hidden==null or number(hidden)!=0)): layers.append(null); continue
			var name:=str(row(tables,"capart",armor_parts[index]).get("MDLNAME",""))
			if name in ["","****"]: failure="Original armor icon part is unavailable"; return {}
			layers.append({"primary":("ip"+("f" if gender==1 else "m")+"_"+name+str(int(parts[armor_parts[index]])).pad_zeros(3)).left(16).to_lower(),"type":6})
		return {"kind":"armor","width":2,"height":3,"palettes":palettes,"layers":layers,"fallback":"ipm_chest001"}
	var id:=int(parts[0]); var prefix:=str(original.get("ItemClass","")); var fallback:=str(original.get("DefaultIcon","")); var specific:=number(original.get("GenderSpecific",0))!=0
	if prefix=="****": prefix=""
	if fallback=="****": fallback=""
	if type==1 and base==80: id=number(row(tables,"cloakmodel",id).get("ICON"),id)
	var primary:=resource_ref(type,prefix,specific,0,id,70 if gender==1 else 77)
	if type==0 and base==75:
		for property in item.get("properties",[]):
			if int(property.type)==15:
				var icon:=str(row(tables,"iprp_spells",int(property.subtype)).get("Icon",""))
				if icon not in ["","****"]: primary=icon
				break
	for part in (3 if type==2 else 1): layers.append({"primary":resource_ref(type,prefix,specific,part,int(parts[part]),70 if gender==1 else 77) if type==2 else primary,"fallback":fallback,"type":6 if type==1 else 3,"palette":palette if type==1 else null})
	return {"kind":"layered" if type==1 else ("composite" if type==2 else "flat"),"width":width,"height":height,"layers":layers}
func select(plan_data: Dictionary,catalog) -> Dictionary:
	var layers: Array=[]
	for layer in plan_data.layers:
		if layer==null: continue
		var name:=str(layer.primary)
		if not catalog.has_resource(name,int(layer.type)):
			if plan_data.kind=="armor": continue
			name=str(layer.get("fallback",""))
			if name in ["","****"] or not catalog.has_resource(name,int(layer.type)): failure="Original icon and fallback are unavailable: "+str(layer.primary); return {}
		var selected: Dictionary=layer.duplicate(true); selected.name=name
		selected.palette=plan_data.palettes[layers.size()] if plan_data.kind=="armor" else layer.get("palette")
		layers.append(selected)
	if layers.is_empty() and plan_data.kind=="armor": layers.append({"name":plan_data.fallback,"type":6,"palette":plan_data.palettes[0]})
	var result:=plan_data.duplicate(true); result.layers=layers
	result.model="gui_icon_armr"+str(layers.size())+"l" if plan_data.kind=="armor" else "gui_icon_%sx%sl%s"%[plan_data.width,plan_data.height,"c" if plan_data.kind=="composite" else ""]
	return result
