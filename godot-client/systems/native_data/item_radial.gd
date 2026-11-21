extends RefCounted
# Original item wheel59d0/7ee0, equipment6af0, powers71a0/6450/5fe0.
# Rule/text providers are native active-catalog projections, never JS models.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
var rules
var warnings: Array=[]
func text(ref: int) -> String: return rules.text.raw({"strRef":ref})
func row(slot: int,icon: String,ref: int,action: String,payload: int=0) -> Dictionary:
	return {"slot":slot,"icon":icon.to_lower(),"label":text(ref),"action":action,"payload":payload,"disabled":false}
func children(id: int) -> Array:
	# The original compacts successful numeric reads, including negative IDs.
	# Filtering missing spells or duplicates here changes the high-WORD variant.
	var result: Array=[]; var spell: Dictionary=rules.row("spells",id)
	for n in range(1,9):
		var value:=Rules.number(Rules.cell(spell,"SubRadSpell"+str(n)),-2147483648)
		if value!=-2147483648: result.append(value)
	return result
func property_spell(property: Dictionary) -> int:
	return Rules.number(Rules.cell(rules.row("iprp_spells",int(property.get("subtype",-1))&65535),"SpellIndex"),-1) if int(property.get("type",-1))==15 else -1
func cached_uses(item: Dictionary,index: int) -> int:
	var values: Array=item.get("propertyUses",item.get("field351",[]))
	return int(values[index] if values[index]!=null else 0)&65535 if index>=0 and index<mini(8,values.size()) else 0
static func common(base: int) -> bool: return base in [49,54,75,104]
func power(item: Dictionary,index: int,slot: int,assignment: bool=false,child: int=-1) -> Dictionary:
	var properties: Array=item.get("properties",[])
	if index<0 or index>=properties.size(): return {}
	var property: Dictionary=properties[index]; var id:=property_spell(property); var variants:=children(id)
	var variant:=255
	if child>=0:
		if child>=variants.size(): return {}
		variant=child; id=int(variants[child])
	elif not variants.is_empty(): variant=0
	var spell: Dictionary=rules.row("spells",id)
	if spell.is_empty(): return {}
	var icon:=str(Rules.cell(spell,"IconResRef",""))
	if icon.is_empty() or icon=="****": return {}
	var ref:=67530 if assignment and not common(int(item.get("baseItem",-1))) else 554
	var name_ref:=Rules.number(Rules.cell(spell,"Name"),-1) if child>=0 else Rules.number(Rules.cell(rules.row("iprp_spells",int(property.get("subtype",-1))),"Name"),-1)
	var result:=row(slot,icon,ref,"variants" if child<0 and not variants.is_empty() else "use",index|(variant<<16))
	result.label=text(ref)+" : "+text(name_ref); result.index=index; result.spellId=id
	result.uses="*" if int(property.get("costValue",0))&65535 in [7,13] else str(cached_uses(item,index))
	result.disabled=int(property.get("remaining",1))==0
	return result
func powers(item: Dictionary,assignment: bool=false,learning: bool=false) -> Array:
	var result: Array=[]; var base: Dictionary=rules.row("baseitems",int(item.get("baseItem",-1))); var properties: Array=item.get("properties",[])
	if base.is_empty() or properties.is_empty(): return result
	var first: Dictionary=properties[0]; var special: Array={70:["IR_TRAP",285],55:["ISK_OLOCK",278],80:["IR_HEAL",273]}.get(int(first.get("type",-1))&65535,[])
	if not special.is_empty():
		var value:=row(3,str(special[0]),554,"use",16711680); value.label=text(554)+" : "+text(int(special[1])); value.index=0; return [value]
	if Rules.number(Rules.cell(base,"Stacking"),0)&65535!=1 and not (properties.size()==1 and int(first.get("costValue",0))&65535 in [1,7,13]):
		var warning:="Stackable items are only allowed to have single or infinite use properties on them."
		if not warnings.has(warning): warnings.append(warning)
	var total:=properties.filter(func(property):return int(property.get("type",-1))&65535==15).size(); var ordinal:=0
	for index in properties.size():
		if int(properties[index].get("type",-1))&65535!=15: continue
		if total>3 and ordinal==2: break
		var slot: int=[3,5,7][ordinal]; ordinal+=1
		var value:=power(item,index,slot,assignment)
		if value.is_empty(): continue
		if common(int(item.get("baseItem",-1))) and int(properties[index].get("costValue",0))&65535 not in [7,13]: value.erase("uses")
		if assignment: value.disabled=false
		result.append(value)
	if total>3: result.append(row(7,"IR_USE",67530 if assignment and not common(int(item.get("baseItem",-1))) else 554,"more",2))
	if int(item.get("baseItem",-1))==75 and learning:
		result=result.filter(func(value):return int(value.slot)!=5); result.append(row(5,"IR_LEARNSCROLL",53135,"learn"))
	return result
func page(item: Dictionary,start: int,assignment: bool=false) -> Array:
	var result: Array=[]; var skipped:=0; var slot:=0; var properties: Array=item.get("properties",[])
	for index in properties.size():
		if int(properties[index].get("type",-1))&65535!=15: continue
		if skipped<start: skipped+=1; continue
		if slot==7: result.append(row(7,"IR_USE",67530 if assignment else 554,"more",start+7)); break
		var value:=power(item,index,slot,assignment); slot+=1
		if not value.is_empty(): result.append(value)
	return result
func variants(item: Dictionary,index: int,assignment: bool=false) -> Array:
	var properties: Array=item.get("properties",[]); var result: Array=[]
	if index<0 or index>=properties.size(): return result
	for variant in children(property_spell(properties[index])).size():
		var value:=power(item,index,variant,assignment,variant)
		if not value.is_empty(): result.append(value)
	return result
func equipment(item: Dictionary,context: Dictionary) -> Array:
	var result: Array=[]; var mask:=int(context.get("slots",0))&4294967295
	if mask==0 or not context.get("can_interact",true): return result
	if mask&0x30==0x30: result=[row(2,"IR_EQUIP_R",551,"equip",16),row(6,"IR_EQUIP_L",552,"equip",32)]
	elif mask&32: result=[row(6,"IR_EQUIP_L",552,"equip",32)]
	else:
		var slot:=0
		for candidate in [16,1,2,4,8,64,128,256,512,1024,2048,4096,8192]:
			if mask&candidate:
				slot=candidate
				if candidate in [128,256] and context.get("ring_filled",false): slot=256 if candidate==128 else 128
				break
		if slot: result=[row(2,"IR_EQUIP_R",551 if slot==16 else 945,"equip",slot)]
	if not item.get("canUse",false):
		for value in result: value.disabled=true
	return result
func root(item: Dictionary,context: Dictionary) -> Array:
	var entries: Dictionary={}; var channel:=str(context.get("channel","R")); var owned:=bool(context.get("owned",false)); var store:=bool(context.get("store",false)); var merchant:=channel=="M"
	var repository:=channel in ["R","M"] or bool(context.get("container_owned",false))
	entries[0]=row(0,"IR_EXAMINE",549,"examine")
	if not merchant: entries[1]=row(1,"IR_CAST",557,"spells",1)
	if channel=="I":
		if owned: entries[4]=row(4,"IR_DROP",553,"drop")
		if store: entries[2]=row(2,"IR_SELL",6381,"sell")
		for value in powers(item,false,bool(context.get("learning",false))): entries[int(value.slot)]=value
		entries[6]=row(6,"IR_UNEQUIP",550,"unequip")
	else:
		if not repository and store: return entries.values()
		if store: entries[2]=row(2,"IR_BUY" if merchant else "IR_SELL",6380 if merchant else 6381,"buy" if merchant else "sell")
		if merchant and store:
			if context.get("pending",false): entries[2].disabled=true
			return entries.values()
		if repository and context.get("container",false) and context.get("can_interact",true): entries[2]=row(2,"IR_CLOSE" if context.get("container_open",false) else "IR_OPEN",1466 if context.get("container_open",false) else 744,"open")
		if owned: entries[4]=row(4,"IR_DROP",553,"drop")
		elif not repository and context.get("can_interact",true): entries[4]=row(4,"IR_PICKUP",555,"pickup")
		if int(context.get("stack",1))>1 and (repository or channel=="C"):
			entries[6]=row(6,"IR_SPLIT",6616,"split"); entries[6].disabled=not repository
		if repository and owned and item.get("canUse",false):
			for value in powers(item,false,bool(context.get("learning",false))): entries[int(value.slot)]=value
		if not store:
			for value in equipment(item,context): entries[int(value.slot)]=value
			if int(context.get("slots",0))!=0 and not item.get("canUse",false):
				for slot in [2,6]:
					if entries.has(slot): entries[slot].disabled=true
	if context.get("pending",false):
		for value in entries.values():
			if value.action!="examine": value.disabled=true
	return entries.values()
