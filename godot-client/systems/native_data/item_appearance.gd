extends RefCounted
# Original CreateItem world-resource rules; used for ground and held/worn items.
const SpellMetadata=preload("res://systems/native_data/spell_metadata.gd")
const MovementRate=preload("res://systems/native_data/native_movement_rate.gd")
var failure:=""
func row(tables: Dictionary,name: String,index: int) -> Dictionary:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
func resource_ref(model_type: int,item_class: String,part: int,number: int) -> String:
	var signed: int=(number&65535)-65536 if (number&32768)!=0 else number&65535
	var model:="-"+str(-signed).pad_zeros(2) if signed<0 else str(signed).pad_zeros(3)
	var suffix:="_"+"BMT"[part] if model_type==2 and part>=0 and part<3 else ""
	return (item_class.split(String.chr(0))[0]+suffix+"_"+model).left(16)
func plan(item: Dictionary,tables: Dictionary) -> Dictionary:
	failure=""
	if not item.has("baseItem"): failure="Original item appearance is absent"; return {}
	var baseitems:Dictionary=tables.get("baseitems",{})
	var model_type:Dictionary=SpellMetadata._integer(baseitems,int(item.baseItem),"ModelType")
	if not bool(model_type.found): failure="Original base-item model type is absent"; return {}
	var type:=int(model_type.value)&255; var parts: Array=item.get("parts",[]); var count:=19 if type==3 else (3 if type==2 else 1)
	if parts.size()<count: failure="Original item model parts are incomplete"; return {}
	var palette: Variant=null
	if type in [1,3]:
		var colors: Array=item.get("colors",[])
		if colors.size()!=6: failure="Original item material colors are incomplete"; return {}
		palette=[0,0,colors[4],colors[5],colors[2],colors[3],colors[0],colors[1],0,0]
	if type==3:
		var ac_entry:Dictionary=MovementRate.native_float_entry(tables.get("parts_chest"),int(parts[7]),"ACBonus")
		if ac_entry.has("error"):failure=str(ac_entry.error);return {}
		var ac:float=float(ac_entry.value)
		var lower:=floori(ac); var rounded:=ceili(ac) if ac-lower>=0.5 else lower
		var model:="gi_armor01" if rounded<2 else ("gi_armor04" if rounded<4 else ("gi_armor03" if rounded<6 else "gi_armor02"))
		return {"modelType":type,"palette":palette,"defaultAnimation":false,"models":[{"primary":model,"fallback":null,"probe":false,"selector":255}]}
	if type not in [0,1,2]: failure="Original item model type is unsupported: "+str(type); return {}
	var prefix:=str(SpellMetadata.native_string_entry(baseitems,int(item.baseItem),"ItemClass").value)
	var fallback:=str(SpellMetadata.native_string_entry(baseitems,int(item.baseItem),"DefaultModel").value)
	var models: Array=[]
	for part in (3 if type==2 else 1):
		models.append({"primary":"gi_cloak01" if type==1 and int(item.baseItem)==80 else resource_ref(type,prefix,part,int(parts[part])),"fallback":fallback,"probe":true,"selector":255-part})
	return {"modelType":type,"palette":palette,"defaultAnimation":true,"models":models}
func select(plan_data: Dictionary,catalog) -> Array:
	var output: Array=[]
	for model in plan_data.get("models",[]):
		var name:=str(model.primary); var used_fallback:=false
		if model.probe and not catalog.has_resource(name,2002):
			name=str(model.get("fallback","")); used_fallback=true
			if name.is_empty() or not catalog.has_resource(name,2002): failure="Original item model and fallback are absent: "+str(model.primary); return []
		output.append({"name":name,"selector":model.selector,"fallback":used_fallback})
	return output
