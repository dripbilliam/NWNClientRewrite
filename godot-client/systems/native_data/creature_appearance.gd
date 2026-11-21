extends RefCounted
# Native selection from original physical 2DA rows and raw creature replication.
# This prepares names, anchors and colors only; the native model owner consumes
# the plan. No JS-created scene or geometry is part of the contract.
const BODY=["ArmorPart_RFoot","BodyPart_LFoot","BodyPart_RShin","BodyPart_LShin","BodyPart_LThigh","BodyPart_RThigh","BodyPart_Pelvis","BodyPart_Torso","BodyPart_Belt","BodyPart_Neck","BodyPart_RFArm","BodyPart_LFArm","BodyPart_RBicep","BodyPart_LBicep","BodyPart_RShoul","BodyPart_LShoul","BodyPart_RHand","BodyPart_LHand","BodyPart_Robe"]
const MATERIALS=["Leather1","Leather2","Cloth1","Cloth2","Metal1","Metal2"]
const CHANNELS=[6,7,4,5,2,3]
var failure:=""
var warnings: Array=[]
func row(tables: Dictionary, name: String, index: int) -> Dictionary:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
func equipped(object: Dictionary, slot: int) -> Dictionary:
	for entry in object.get("appearance",{}).get("equipment",[]):
		if int(entry.get("slot",-1))==slot: return entry
	return {}
func appearance(object: Dictionary) -> Dictionary:
	var a: Dictionary=object.get("appearance",{})
	if not a.has("appearance"): return {}
	var stats: Dictionary=object.get("replicated",{}).get("stats",{})
	var data:={"Appearance_Type":int(a.appearance),"Appearance_Head":int(a.get("head",0)),"Phenotype":int(a.get("phenotype",0)),"Gender":int(a.get("gender",0)),"Race":int(stats.get("racialType",stats.get("fieldD20",0))),"Color_Skin":int(a.get("skin",0)),"Color_Hair":int(a.get("hair",0)),"Color_Tattoo1":int(a.get("tattoo1",0)),"Color_Tattoo2":int(a.get("tattoo2",0))}
	for part in a.get("bodyParts",[]):
		var index:=int(part.get("index",-1))
		if index>=0 and index<BODY.size(): data[BODY[index]]=int(part.value)
	var armor: Dictionary=equipped(object,2).get("item",{})
	if int(armor.get("modelType",-1))==3:
		for index in mini(BODY.size(),armor.get("parts",[]).size()): data[BODY[index]]=int(armor.parts[index])
		for index in mini(MATERIALS.size(),armor.get("colors",[]).size()): data["Color_"+MATERIALS[index]]=int(armor.colors[index])
	return data
func number(value: Variant, fallback: float=1.0) -> float:
	var text:=str(value)
	return float(text) if text.is_valid_float() and is_finite(float(text)) else fallback
func append_tail_wings(result: Dictionary, a: Dictionary, cloak_row: Dictionary, original: Dictionary, tables: Dictionary, colors: Array) -> void:
	for pair in [["fieldAA4","tailmodel","tail",253,"HIDETAIL"],["fieldAA8","wingmodel","wings",252,"HIDEWING"]]:
		var id:=int(a.get(pair[0],0))
		if id==0 or number(cloak_row.get(pair[4],"0"),0)!=0: continue
		var original_part:=row(tables,pair[1],id)
		if original_part.is_empty(): warnings.append("Original "+pair[1]+" row is unavailable: "+str(id)); continue
		var name:=str(original_part.get("MODEL","")).to_lower().left(16)
		if name in ["","****"]: continue
		result.attachments.append({"model":name,"node":pair[2],"nativeVisualScope":pair[3],"paletteColors":colors.duplicate(),"scale":number(original.get("WING_TAIL_SCALE","1")),"pltCandidates":[name]})
func plan(object: Dictionary, tables: Dictionary) -> Dictionary:
	failure=""; warnings=[]
	var data:=appearance(object)
	if data.is_empty(): failure="Raw creature appearance is unavailable"; return {}
	var original:=row(tables,"appearance",int(data.Appearance_Type)); var race:=str(original.get("RACE","")).to_lower()
	if original.is_empty() or race.is_empty() or race=="****": failure="Original creature appearance row is unavailable"; return {}
	var colors: Array=[]
	for name in ["Skin","Hair","Metal1","Metal2","Cloth1","Cloth2","Leather1","Leather2","Tattoo1","Tattoo2"]: colors.append(int(data.get("Color_"+name,0)))
	var result:={"model":race,"parts":[],"paletteColors":colors,"sourceIndex":int(object.id),"attachments":[]}
	var a: Dictionary=object.appearance; var cloak: Dictionary=equipped(object,64).get("item",{})
	var cloak_parts: Array=cloak.get("parts",[]); var cloak_row:=row(tables,"cloakmodel",int(cloak_parts[0])) if not cloak_parts.is_empty() else {}
	if str(original.get("MODELTYPE",""))!="P":
		append_tail_wings(result,a,cloak_row,original,tables,colors)
		return result
	var gender:=str(row(tables,"gender",int(data.Gender)).get("GENDER","")).to_lower()
	if gender.is_empty() or gender=="****" or row(tables,"racialtypes",int(data.Race)).is_empty(): failure="Original creature race/gender rules are unavailable"; return {}
	var pheno:=str(row(tables,"phenotype",int(data.Phenotype)).get("DefaultPhenoType",str(data.Phenotype)))
	var prefix:="p"+gender+race
	result.model=prefix+str(data.Phenotype); result.fallbackModel=prefix+pheno
	if equipped(object,1).is_empty() and int(data.Appearance_Head)>0:
		var suffix:="_head"+str(data.Appearance_Head).pad_zeros(3)
		var head_palettes: Array=[]
		for name in [result.model+suffix,result.fallbackModel+suffix,"p"+gender+"h"+str(data.Phenotype)+suffix,"p"+gender+"h"+pheno+suffix]:
			if not head_palettes.has(name): head_palettes.append(name)
		result.parts.append({"model":result.model+suffix,"fallbackModel":result.fallbackModel+suffix,"pltCandidates":head_palettes,"node":"head_g","nativeVisualScope":254,"paletteColors":colors.duplicate()})
	var armor: Dictionary=equipped(object,2).get("item",{}); var robe:=int(data.get("BodyPart_Robe",0))
	for index in BODY.size():
		var id:=int(data.get(BODY[index],0))
		if index==18:
			if id<=2: continue
		elif robe>2:
			var columns: Array=tables.get("parts_robe",{}).get("columns",[])
			var hide: Variant=row(tables,"parts_robe",robe).get(columns[index+2]) if columns.size()>index+2 else null
			if hide==null or not str(hide).is_valid_int() or int(hide)==1: continue
		if id==0: continue
		var capart:=row(tables,"capart",index); var name:=str(capart.get("MDLNAME","")); var anchor:=str(capart.get("NODENAME",""))
		if name in ["","****"] or anchor in ["","****"]: failure="Original CAPart model/anchor is unavailable: "+str(index); return {}
		var suffix:="_"+name.to_lower()+str(id).pad_zeros(3); var palette:=colors.duplicate()
		var per_part: Array=armor.get("partColors",[])
		if index<per_part.size() and per_part[index] is Array:
			for channel in mini(CHANNELS.size(),per_part[index].size()):
				var value:=int(per_part[index][channel])
				if value!=255: palette[CHANNELS[channel]]=value
		var part:={"model":(str(result.model)+suffix).left(16),"fallbackModel":(str(result.fallbackModel)+suffix).left(16),"pltCandidates":candidates(result.model,result.fallbackModel,gender,pheno,suffix),"node":null if index==18 else anchor,"partIndex":index,"paletteColors":palette}
		if index==18: part.nativeVisualScope=18
		result.parts.append(part)
	var cloak_model:=int(cloak_row.get("MODEL",0))
	if cloak_model>0:
		var cloak_suffix:="_cloak_"+str(cloak_model).pad_zeros(3)
		var cloak_texture:=int(cloak_row.get("TEXTURE",0))
		var cloak_palette:=colors.duplicate()
		var item_colors: Array=cloak.get("colors",[])
		if item_colors.size()==6:
			for channel in MATERIALS.size(): cloak_palette[CHANNELS[channel]]=int(item_colors[channel])
		result.attachments.append({"model":(str(result.model)+cloak_suffix).left(16),"fallbackModel":(str(result.fallbackModel)+cloak_suffix).left(16),"node":"","nativeVisualScope":243,"paletteColors":cloak_palette,"pltCandidates":["cloak_"+str(cloak_texture).pad_zeros(3)] if cloak_texture>0 else []})
	append_tail_wings(result,a,cloak_row,original,tables,colors)
	return result
func candidates(primary: String, fallback: String, gender: String, pheno: String, suffix: String) -> Array:
	var output: Array=[]
	for name in [primary+suffix,fallback+suffix,"p"+gender+"h"+pheno+suffix,"pmh0"+suffix]:
		var bounded: String=name.left(16)
		if not output.has(bounded): output.append(bounded)
	return output
