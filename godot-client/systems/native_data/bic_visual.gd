extends RefCounted
# Read-only appearance data for a private picker viewport. No effects, scripts,
# inventory ownership or serialized world IDs enter the preview actor.
const Appearance=preload("res://systems/native_data/creature_appearance.gd")
const ARMOR=["ArmorPart_RFoot","ArmorPart_LFoot","ArmorPart_RShin","ArmorPart_LShin","ArmorPart_LThigh","ArmorPart_RThigh","ArmorPart_Pelvis","ArmorPart_Torso","ArmorPart_Belt","ArmorPart_Neck","ArmorPart_RFArm","ArmorPart_LFArm","ArmorPart_RBicep","ArmorPart_LBicep","ArmorPart_RShoul","ArmorPart_LShoul","ArmorPart_RHand","ArmorPart_LHand","ArmorPart_Robe"]
const COLORS=["Leather1Color","Leather2Color","Cloth1Color","Cloth2Color","Metal1Color","Metal2Color"]
static func index_of(document: Dictionary,node: Dictionary) -> int:
	for id in document.get("records",{}):
		if is_same(document.records[id],node): return int(id)
	return -1
static func read(node: Dictionary,types: Dictionary,name: String,type: int,fallback: int=0) -> int:
	var label:=name.left(16)
	return int(node[label]) if types.get(label)==type and node.get(label) is int else fallback
static func extended(node: Dictionary,types: Dictionary,name: String) -> int:
	var full:=("x"+name).left(16)
	return read(node,types,full,2)&65535 if types.get(full)==2 else read(node,types,name,0)&255
static func source(document: Dictionary) -> Dictionary:
	var root: Dictionary=document.get("root",{}); var types: Dictionary=document.get("field_types",{}).get(0,{})
	if types.get("Appearance_Type")!=2: return {"error":"This character record does not include an appearance."}
	var a:={"appearance":read(root,types,"Appearance_Type",2),"head":extended(root,types,"Appearance_Head"),"phenotype":read(root,types,"Phenotype",5)&255,"bodyParts":[],"equipment":[]}
	for pair in [["gender","Gender"],["skin","Color_Skin"],["hair","Color_Hair"],["tattoo1","Color_Tattoo1"],["tattoo2","Color_Tattoo2"]]: a[pair[0]]=read(root,types,pair[1],0)&255
	a.fieldAA4=read(root,types,"Tail_New",4); a.fieldAA8=read(root,types,"Wings_New",4)
	for at in Appearance.BODY.size(): a.bodyParts.append({"index":at,"value":extended(root,types,Appearance.BODY[at])})
	var equipment: Array=[]; var occupied: Dictionary={}
	if root.has("Equip_ItemList") and types.get("Equip_ItemList")!=15: return {"error":"Character equipment has an invalid record type."}
	if types.get("Equip_ItemList")==15:
		for node in root.get("Equip_ItemList",[]):
			var index:=index_of(document,node)
			if index<0 or index>=document.get("struct_types",[]).size(): return {"error":"Character equipment lacks physical GFF identity."}
			var slot:=int(document.struct_types[index]); var item_types: Dictionary=document.field_types.get(index,{})
			if slot<=0 or slot>131072 or slot&(slot-1)!=0 or occupied.has(slot): return {"error":"Character equipment has an invalid or duplicate slot."}
			if item_types.get("BaseItem")!=5: return {"error":"Character equipment has no original base-item ID."}
			occupied[slot]=true
			var item:={"baseItem":read(node,item_types,"BaseItem",5),"modelParts":[],"armorParts":[],"colors":[],"partColors":[]}
			for at in 3: item.modelParts.append(extended(node,item_types,"ModelPart"+str(at+1)))
			for name in ARMOR: item.armorParts.append(extended(node,item_types,name))
			for name in COLORS: item.colors.append(read(node,item_types,name,0)&255)
			for part in ARMOR.size():
				var channels: Array=[]
				for channel in 6: channels.append(read(node,item_types,"APart_"+str(part)+"_Col_"+str(channel),0,255)&255)
				item.partColors.append(channels)
			equipment.append({"slot":slot,"item":item})
	return {"appearance":a,"equipment":equipment,"equipmentComplete":types.get("Equip_ItemList")==15,"race":read(root,types,"Race",0),"native_only":true}
static func actor(value: Dictionary,baseitems: Dictionary) -> Dictionary:
	if value.has("error") or not value.get("appearance") is Dictionary: return {"error":str(value.get("error","Character appearance is unavailable."))}
	var a: Dictionary=value.appearance.duplicate(true); a.equipment=[]; var rows: Array=baseitems.get("orderedRows",[])
	for entry in value.get("equipment",[]):
		var source_item: Dictionary=entry.item; var id:=int(source_item.baseItem)
		if id<0 or id>=rows.size(): return {"error":"Character equipment's active base-item row is unavailable."}
		var text:=str(rows[id].get("ModelType",""))
		if not text.is_valid_int() or int(text) not in [0,1,2,3]: return {"error":"Character equipment's active model type is unavailable."}
		if source_item.has("savedModelType") and int(source_item.savedModelType)!=int(text): return {"error":"Last seen equipment no longer matches this server's item rules."}
		var type:=int(text); var item:={"baseItem":id,"modelType":type,"parts":source_item.armorParts.duplicate() if type==3 else source_item.modelParts.slice(0,3 if type==2 else 1),"colors":source_item.colors.duplicate(),"partColors":source_item.partColors.duplicate(true)}
		a.equipment.append({"slot":entry.slot,"item":item})
	return {"id":1,"areaId":0,"objectType":5,"appearance":a,"replicated":{"position":[0,0,0],"orientation":[0,1,0],"animation":0,"stats":{"racialType":int(value.race)}}}
