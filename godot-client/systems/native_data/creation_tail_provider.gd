extends RefCounted
# Detached first-level tail projections. Call only at an owned draft/catalog
# publication boundary. Resource I/O, async cancellation and draft commits stay
# with the creator; this service owns no world, Nodes, or second table store.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Appearance=preload("res://systems/native_data/creature_appearance.gd")
const Private=preload("res://systems/native_data/creation_appearance_state.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Names=preload("res://systems/native_data/creation_character_names.gd")
const PALETTES={"skin":"pal_skin01","hair":"pal_hair01","tattoo1":"pal_tattoo01","tattoo2":"pal_tattoo01"}
static func pending(reason:String,extra:Dictionary={})->Dictionary:
	var result:Dictionary={"ready":false,"reason":reason};result.merge(extra);return result
static func whole(value:Variant,maximum:int,minimum:int=0)->bool:
	return (value is int or value is float) and is_finite(float(value)) and int(value)==value and value>=minimum and value<=maximum
static func present_table(tables:Dictionary,name:String)->bool:
	return tables.get(name) is Dictionary and tables[name].get("orderedRows") is Array
static func text_cell(table:Dictionary,index:int,column:String,lookup:Dictionary={})->Dictionary:
	var value:=Tables.cell(table,index,column,lookup)
	# Project2DA dictionaries retain the lexical missing marker. Native string
	# storage is empty for that normalized missing cell; invalid lookup writes
	# the table default but still returns false (original1a68f0).
	var output:String="" if str(value.text)=="****" else str(value.text)
	return {"ready":true,"ok":bool(value.found) and not output.is_empty(),"value":output}
static func resource_name(value:String)->String:return value.left(16).to_lower()
static func alignment(law_chaos:int,good_evil:int)->String:
	var result:String=("L" if law_chaos>69 else "C" if law_chaos<31 else "N")+("G" if good_evil>69 else "E" if good_evil<31 else "N")
	return "TN" if result=="NN" else result
static func clothing_candidates(table:Dictionary,selection:Dictionary)->Dictionary:
	if not table.get("orderedRows") is Array:return pending("The active ChargenClothes table is unavailable.")
	if not selection.get("classes") is Array or selection.classes.any(func(id):return not whole(id,255)) or not whole(selection.get("raceId"),65535) or not whole(selection.get("gender"),255) or not whole(selection.get("lawChaos"),65535) or not whole(selection.get("goodEvil"),65535):return pending("The native class/race/gender/alignment restriction inputs are unavailable.")
	var columns:=Tables.columns(table);var result:Array=[];var retained_item:="";var code:=alignment(int(selection.lawChaos),int(selection.goodEvil))
	for index in table.orderedRows.size():
		var allowed:=true
		for field in ["ClassRestrict","RaceRestrict","GenderRestrict"]:
			var read:=Tables.integer(table,index,field,columns)
			if not read.ready:return read
			if not read.ok:continue
			if field=="ClassRestrict":allowed=selection.classes.has(int(read.value)&255)
			elif field=="RaceRestrict":allowed=(int(read.value)&0xffffffff)==int(selection.raceId)
			else:allowed=(int(read.value)&0xffffffff)==int(selection.gender)
			if not allowed:break
		if not allowed:continue
		var restriction:=text_cell(table,index,"AlignmentRestrict",columns)
		if not restriction.ready:return restriction
		if restriction.ok and str(restriction.value)!=code:continue
		var item:=text_cell(table,index,"ItemResRef",columns)
		if not item.ready:return item
		#8e8410 ignores the return code, but the getter writes its output on
		# every path: a valid missing cell clears, invalid lookup writes default.
		retained_item=str(item.value)
		result.append({"id":index,"rawResRef":retained_item,"resRef":resource_name(retained_item)})
	return {"ready":true,"candidates":result,"alignment":code}
static func byte_field(document:Dictionary,label:String)->Dictionary:
	if not document.get("root") is Dictionary or not document.get("field_types") is Dictionary or not document.field_types.get(0) is Dictionary:return pending("Typed native GFF root metadata is unavailable.")
	var types:Dictionary=document.field_types[0]
	if int(types.get(label,-1))!=0:return {"ready":true,"value":0,"source":"native_byte_default"}
	var value:Variant=document.root.get(label)
	return {"ready":true,"value":int(value),"source":label} if whole(value,255) else pending("A typed native BYTE field is invalid: "+label)
static func word_or_byte(document:Dictionary,label:String)->Dictionary:
	if not document.get("root") is Dictionary or not document.get("field_types") is Dictionary or not document.field_types.get(0) is Dictionary:return pending("Typed native GFF root metadata is unavailable.")
	var extended:=("x"+label).left(16);var types:Dictionary=document.field_types[0]
	if int(types.get(extended,-1))==2:
		var value:Variant=document.root.get(extended)
		return {"ready":true,"value":int(value),"source":extended} if whole(value,65535) else pending("A typed native extended WORD field is invalid: "+extended)
	return byte_field(document,label)
static func garment(document:Dictionary,id:int,resref:String)->Dictionary:
	if document.get("type")!="UTI " or not document.get("version") in ["V3.2","V3.3"]:return pending("A successfully loaded native UTI document is required.")
	var parts:Array=[];var colors:Array=[];var fields:Array=[]
	for label in Appearance.BODY:
		var read:=word_or_byte(document,str(label).replace("BodyPart_","ArmorPart_"))
		if not read.ready:return read
		parts.append(int(read.value));fields.append(str(read.source))
	for material in Appearance.MATERIALS:
		var read:=byte_field(document,str(material)+"Color")
		if not read.ready:return read
		colors.append(int(read.value));fields.append(str(read.source))
	return {"ready":true,"value":{"id":id,"resRef":resource_name(resref),"bodyParts":parts,"colors":colors},"fieldSources":fields}
static func clothing(table:Dictionary,selection:Dictionary,loads:Dictionary)->Dictionary:
	var admitted:=clothing_candidates(table,selection)
	if not admitted.ready:return admitted
	var rows:Array=[];var seen:Dictionary={};var requests:Dictionary={};var sources:Array=[]
	for candidate in admitted.candidates:
		if seen.has(candidate.rawResRef):continue
		var name:String=candidate.resRef
		if name.is_empty():continue
		var loaded:Variant=loads.get(name)
		if not loaded is Dictionary or str(loaded.get("status","pending"))=="pending":requests[name]=true;continue
		if str(loaded.get("status")) in ["absent","native-load-failed"]:continue
		if str(loaded.get("status"))!="ready":return pending("The outfit resource read/decode result is unavailable: "+name)
		var value:=garment(loaded.get("document",{}),int(candidate.id),name)
		if not value.ready:return value
		rows.append(value.value);sources.append({"physicalRow":candidate.id,"rawResRef":candidate.rawResRef,"fieldSources":value.fieldSources,"sha256":str(loaded.get("sha256",""))})
		# Only successful loads enter the original case-sensitive raw-string
		# dedupe list. Canonical resource reuse does not collapse distinct rows.
		seen[candidate.rawResRef]=true
	if not requests.is_empty():return pending("Native outfit resources are still preparing.",{"requests":requests.keys()})
	return {"ready":true,"choices":rows,"provenance":sources,"alignment":admitted.alignment}
static func head_name(prefix:String,id:int)->String:return resource_name(prefix+("%03d"%id))
static func head_prefix(tables:Dictionary,appearance_id:int,gender:int)->Dictionary:
	if not present_table(tables,"appearance") or not present_table(tables,"gender"):return pending("Active appearance/gender rows are unavailable.")
	var race:=text_cell(tables.appearance,appearance_id,"RACE");var sex:=text_cell(tables.gender,1 if gender==1 else 0,"GENDER")
	#97b080 ignores the getter status and consumes its written default/empty
	# string. A known missing RACE cell is different from unavailable tables.
	if not race.ready or not sex.ready:return pending("Native head model prefix data is unavailable.")
	return {"ready":true,"value":("P"+str(sex.value)+str(race.value)+"0_HEAD").to_lower()}
static func heads(tables:Dictionary,appearance_id:int,gender:int,model_names:Array)->Dictionary:
	var prepared:=head_prefix(tables,appearance_id,gender)
	if not prepared.ready:return prepared
	var prefix:String=prepared.value;var found:Dictionary={};var lookup:Dictionary={}
	for name in model_names:lookup[resource_name(str(name))]=true
	if prefix.length()+5<=16:
		for name in lookup:
			if not str(name).begins_with(prefix):continue
			var suffix:=str(name).substr(prefix.length())
			if suffix.is_valid_int():
				var id:=int(suffix)
				if id>=0 and id<=65535 and head_name(prefix,id)==name:found[id]=true
	else:
		# Rare long prefixes can alias after native CResRef truncation. This is
		# a bounded one-time provider job, never a UI frame or per-input scan.
		for id in 65536:
			if lookup.has(head_name(prefix,id)):found[id]=true
	if found.size()==65536:return pending("The original head scan has no missing resource and cannot terminate safely.")
	return {"ready":true,"heads":found,"prefix":prefix,"indexComplete":true,"boundedLongPrefix":prefix.length()+5>16}
static func palette_sizes(metadata:Dictionary)->Dictionary:
	var result:Dictionary={}
	for field in PALETTES:
		var value:Variant=metadata.get(PALETTES[field])
		if not value is Dictionary or value.get("format")!="rgba8" or value.get("width")!=256 or not whole(value.get("height"),65535,1):return pending("The active palette dimensions/pixels are unavailable: "+PALETTES[field])
		result[field]=int(value.height)
	return {"ready":true,"value":result}
static func appearance(tables:Dictionary,selection:Dictionary,model_names:Array,loads:Dictionary,palettes:Dictionary)->Dictionary:
	if not present_table(tables,"racialtypes") or not present_table(tables,"appearance") or not present_table(tables,"chargenclothes"):return pending("Active native appearance tables are unavailable.")
	if selection.get("mode") not in [0,1] or not whole(selection.get("raceId"),65535) or not whole(selection.get("gender"),255):return pending("The native appearance selection is unavailable.")
	var appearance_id:=Tables.integer(tables.racialtypes,int(selection.raceId),"Appearance")
	if not appearance_id.ready or not appearance_id.ok:return pending("The active race appearance ID is unavailable.")
	var id:int=int(appearance_id.value)&65535;var model_type:=text_cell(tables.appearance,id,"MODELTYPE")
	if not model_type.ready or not model_type.ok:return pending("The selected appearance has no valid native MODELTYPE.")
	var editable:bool=str(model_type.value).to_upper()=="P"
	var head_set:Dictionary
	if editable:head_set=heads(tables,id,int(selection.gender),model_names)
	else:
		var prefix:=head_prefix(tables,id,int(selection.gender))
		if not prefix.ready:return prefix
		# Non-P controls are all disabled. Only the original single current-head
		# presence check is needed; do not scan/publish a fake choice index.
		head_set={"ready":true,"prefix":prefix.value,"heads":{}}
	var sizes:=palette_sizes(palettes) if editable else {"ready":true,"value":{}}
	if not head_set.ready:return head_set
	if not sizes.ready:return sizes
	var value:Dictionary={}
	for field in ["phenotype","head","skin","hair","tattoo1","tattoo2"]:
		if not whole(selection.get(field),65535 if field=="head" else 255):return pending("The native appearance field is unavailable: "+field)
		value[field]=int(selection[field])
	var mask:int=Values.cfg(tables,"CHARGEN_ENABLED_PHENOTYPES",5)&0xffffffff
	if value.phenotype==255:
		var initial:Variant=null
		for bit in 32:
			if (mask>>bit)&1:initial=bit;break
		if initial==null:return pending("No native initial phenotype is enabled.")
		value.phenotype=initial
	if value.head==65535:value.head=1
	if editable:
		if not head_set.heads.has(value.head):value.head=1
	elif not model_names.any(func(name):return resource_name(str(name))==head_name(str(head_set.prefix),int(value.head))):value.head=1
	var choices:Array=[];var provenance:Array=[]
	if selection.mode==0:
		var outfits:=clothing(tables.chargenclothes,selection,loads)
		if not outfits.ready:return outfits
		if outfits.choices.is_empty():return pending("No native outfit successfully loaded; the original first-variation access is unsafe.")
		choices=outfits.choices;provenance=outfits.provenance
		var seed:Array=[];seed.resize(19);seed.fill(1);var skin:=Private.tattoo_parts(0,seed)
		value.skinParts=skin.skinParts;value.bodyParts=choices[0].bodyParts.duplicate();value.materialColors=choices[0].colors.duplicate();value.clothingIndex=0;value.clothes=choices[0].id;value.clothingResRef=choices[0].resRef;value.tattooPattern=0
		for part in 19:
			if int(value.bodyParts[part])==1 and Private.TATTOO_ENABLED[part]:value.bodyParts[part]=value.skinParts[part]
	else:
		for field in ["bodyParts","skinParts","materialColors"]:
			var list:Variant=selection.get(field);var count:=6 if field=="materialColors" else 19
			if not list is Array or list.size()!=count or not list.all(func(item):return whole(item,255 if field=="materialColors" else 65535)):return pending("Existing native appearance data is unavailable: "+field)
			value[field]=list.duplicate()
		value.tattooPattern=0
	return {"ready":true,"context":{"appearanceValid":true,"modelType":str(model_type.value),"customizeMode":int(selection.mode),"enabledPhenotypes":mask,"headIndexComplete":editable,"heads":head_set.heads if editable else {},"paletteSizes":sizes.value,"clothing":choices,"value":value},"provenance":{"appearanceId":id,"headPrefix":head_set.prefix,"outfits":provenance,"phenotypeRule":"CHARGEN_ENABLED_PHENOTYPES","controlsDisabledForNonP":not editable}}
static func voices(table:Dictionary,gender:int,text)->Dictionary:
	if not table.get("orderedRows") is Array or text==null or not text.has_method("raw"):return pending("Active soundset metadata/text is unavailable.")
	var result:Array=[];var lookup:=Tables.columns(table);var count:int=table.orderedRows.size()&65535
	for id in count:
		var resource:=text_cell(table,id,"RESREF",lookup)
		if not resource.ready:return resource
		if not resource.ok or str(resource.value).is_empty():continue
		var kind:=Tables.integer(table,id,"TYPE",lookup);var sex:=Tables.integer(table,id,"GENDER",lookup)
		if not kind.ready or not sex.ready or not kind.ok or not sex.ok:return pending("A soundset type/gender conversion is unavailable.")
		if (int(kind.value)&255) not in [0,2] or (int(sex.value)&255)!=(gender&255):continue
		var name:=Tables.integer(table,id,"STRREF",lookup)
		if not name.ready or not name.ok:return pending("A soundset name reference is unavailable.")
		result.append({"id":id,"name":text.raw({"strRef":int(name.value)&0xffffffff}),"resRef":resource_name(str(resource.value))})
	return {"ready":true,"entries":result}
static func character_info(tables:Dictionary,selection:Dictionary,text)->Dictionary:
	if not present_table(tables,"soundset") or not present_table(tables,"packages") or not whole(selection.get("gender"),255) or not whole(selection.get("packageId"),2147483647):return pending("Native Character Information choices are unavailable.")
	var rows:=voices(tables.soundset,int(selection.gender),text)
	if not rows.ready:return rows
	var value:Dictionary={}
	for pair in [["firstName","firstName"],["lastName","lastName"],["biography","description"],["deity","deity"]]:
		var field:Variant=selection.get(pair[0])
		if not field is String:return pending("The owned Character Information field is unavailable: "+str(pair[0]))
		var encoder:=Writer.new();encoder.text(field)
		if not encoder.failure.is_empty():return pending(encoder.failure)
		value[pair[1]]=field
	if not whole(selection.get("age"),2147483647,-2147483648):return pending("The native signed age is unavailable.")
	value.ageText="" if int(selection.age)==0 else str(int(selection.age))
	var initial:Variant=null
	if not rows.entries.is_empty():
		var index:=Tables.integer(tables.packages,int(selection.packageId),"SoundSet")
		# Original8ecc60 ignores GetINTEntry BOOL and consumes its output.
		# Literal ****/empty writes known0; unresolved conversion stays pending.
		if not index.ready:return pending("The package's initial native voice index is unavailable.")
		if int(index.value)>=0:
			if int(index.value)>=rows.entries.size():return pending("The original package voice index exceeds the admitted soundset list.")
			initial=int(rows.entries[int(index.value)].id);value.soundset=initial
	elif whole(selection.get("soundset"),65535):value.soundset=int(selection.soundset)
	var name_plan:=Names.plan({"status":"ready","value":tables.racialtypes} if present_table(tables,"racialtypes") else {},selection.get("raceId"),selection.gender)
	# Random stays disabled until a scoped resource/worker owner has prepared
	# every active letter table and established optional NameFilter status.
	return {"ready":true,"context":{"value":value,"voices":rows.entries,"randomReady":false,"namePlan":name_plan},"provenance":{"packageVoiceIndex":null if rows.entries.is_empty() else int(Tables.integer(tables.packages,int(selection.packageId),"SoundSet").value),"selectedPhysicalSoundset":initial,"randomNames":"prepared_resource_owner_required"}}
