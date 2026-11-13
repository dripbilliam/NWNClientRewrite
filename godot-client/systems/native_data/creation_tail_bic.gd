extends RefCounted
# Typed patches for the verified source-tail transaction in the shipping builder.
# Root character fields and the separate private UTI overlay must not be
# conflated: original807950 writes only EquippedRes in the equipped type2 row.
const W=preload("res://systems/native_data/gff_writer.gd")
const Body=preload("res://systems/native_data/creature_appearance.gd")
const ORDER=[9,7,8,6,15,13,11,17,4,3,1,14,12,10,16,5,2,0]
const COLORS={"skin":"Color_Skin","hair":"Color_Hair","tattoo1":"Color_Tattoo1","tattoo2":"Color_Tattoo2"}
static func unavailable(reason:String)->Dictionary:return {"ready":false,"reason":reason}
static func exact(value:Variant,maximum:int,minimum:int=0)->bool:return value is int and value>=minimum and value<=maximum
static func vector(value:Variant,count:int,maximum:int)->bool:return value is Array and value.size()==count and value.all(func(part):return exact(part,maximum))
static func word_and_byte(label:String,value:Variant)->Dictionary:
	if not exact(value,65535) or label.is_empty() or label.length()>16:return unavailable("The native WORDandBYTE label/value is unavailable.")
	for at in label.length():
		if label.unicode_at(at)<32 or label.unicode_at(at)>126:return unavailable("The native field label is not an ASCII GFF label.")
	#1a3790 always writes BOTH. Values>255 write0 in the legacy BYTE, rather
	# than wrapping to a low byte; the extended WORD is authoritative on read.
	return {"ready":true,"fields":{label:W.field(0,int(value) if int(value)<=255 else 0),("x"+label).left(16):W.field(2,int(value))}}
static func source_outfit(value:Dictionary,choice:Dictionary)->Dictionary:
	if not exact(value.get("clothes"),2147483647) or not exact(choice.get("id"),2147483647) or value.clothes!=choice.id or not value.get("clothingResRef") is String or not choice.get("resRef") is String or str(choice.resRef).is_empty() or str(choice.resRef).length()>16 or str(choice.resRef)!=str(value.clothingResRef):return unavailable("The selected physical source outfit is unavailable or has changed.")
	var encoder:=W.new();var encoded:=encoder.text(choice.resRef)
	if not encoder.failure.is_empty() or encoded.size()>16:return unavailable("The original outfit CResRef cannot be encoded.")
	return {"ready":true,"physicalRow":int(choice.id),"resRef":str(choice.resRef)}
static func first_level(appearance_id:Variant,value:Dictionary,choice:Dictionary)->Dictionary:
	if not exact(appearance_id,65535) or not exact(value.get("head"),65535) or not exact(value.get("phenotype"),255) or not vector(value.get("skinParts"),19,65535):return unavailable("The current source head/phenotype/skin-body state is unavailable.")
	var selected:=source_outfit(value,choice)
	if not selected.ready:return selected
	var fields:Dictionary={"Appearance_Type":W.field(2,int(appearance_id)),"Phenotype":W.field(5,int(value.phenotype))}
	for key in COLORS:
		if not exact(value.get(key),255):return unavailable("The native appearance color is unavailable: "+key)
		fields[COLORS[key]]=W.field(0,int(value[key]))
	fields.merge(word_and_byte("Appearance_Head",value.head).fields)
	# The original root reads the SKIN half at appearance-block+26, not the
	# clothed preview's actual19-part half at+0. Robe18 is not written here.
	for index in ORDER:fields.merge(word_and_byte(Body.BODY[index],value.skinParts[index]).fields)
	var pending:Array=[]
	for pair in [["tail","Tail_New"],["wings","Wings_New"]]:
		if not value.has(pair[0]):pending.append(pair[1]);continue
		if not exact(value[pair[0]],4294967295):return unavailable("The current native appendage DWORD is unavailable: "+pair[0])
		fields[pair[1]]=W.field(4,int(value[pair[0]]))
	fields.Equip_ItemList=W.field(15,[W.record({"EquippedRes":W.field(11,selected.resRef)},2)])
	return {"ready":true,"fields":fields,"sourceOutfit":{"physicalRow":selected.physicalRow,"resRef":selected.resRef},"unavailableFields":pending,"scope":"Verified807950 appearance/root and reference-only outfit patch; not a complete BIC or server admission."}
static func information(value:Dictionary)->Dictionary:
	var fields:Dictionary={}
	for entry in [["firstName","FirstName",250],["lastName","LastName",250],["description","Description",8192],["deity","Deity",-1]]:
		if not value.get(entry[0]) is String:return unavailable("The accepted Character Information text is unavailable: "+str(entry[0]))
		var encoder:=W.new();var encoded:=encoder.text(value[entry[0]])
		if not encoder.failure.is_empty():return unavailable(encoder.failure)
		if int(entry[2])>=0 and encoded.size()>int(entry[2]):return unavailable("Character Information has not passed its native byte-limit transaction: "+str(entry[0]))
		fields[entry[1]]=W.field(10 if entry[0]=="deity" else 12,str(value[entry[0]]))
	if not exact(value.get("age"),2147483647,-2147483648) or not exact(value.get("soundset"),65535):return unavailable("The accepted age or physical soundset WORD is unavailable.")
	fields.Age=W.field(5,int(value.age));fields.SoundSetFile=W.field(2,int(value.soundset))
	return {"ready":true,"fields":fields,"scope":"Accepted source text/age/soundset fields; whitespace preserved, no actor/default substitution."}
static func private_outfit(document:Dictionary,value:Dictionary,choice:Dictionary)->Dictionary:
	var selected:=source_outfit(value,choice)
	if not selected.ready:return selected
	if document.get("type")!="UTI " or document.get("version") not in ["V3.2","V3.3"] or not document.get("root") is Dictionary or not document.get("records") is Dictionary or not is_same(document.records.get(0),document.root) or not document.get("field_types") is Dictionary or not document.field_types.get(0) is Dictionary or not document.get("struct_types") is Array or document.struct_types.is_empty():return unavailable("The typed original outfit document is unavailable.")
	if not vector(value.get("bodyParts"),19,65535) or not vector(value.get("materialColors"),6,255):return unavailable("The current private19-part/six-color appearance is unavailable.")
	var writer:=W.new();var typed:=writer.typed(document,document.root)
	if not writer.failure.is_empty():return unavailable(writer.failure)
	typed=typed.duplicate(true)
	for index in ORDER+[18]:typed.fields.merge(word_and_byte(str(Body.BODY[index]).replace("BodyPart_","ArmorPart_"),value.bodyParts[index]).fields,true)
	for index in 6:typed.fields[str(Body.MATERIALS[index])+"Color"]=W.field(0,int(value.materialColors[index]))
	return {"ready":true,"record":typed,"sourceOutfit":{"physicalRow":selected.physicalRow,"resRef":selected.resRef},"scope":"Detached private UTI appearance overlay retaining unrelated typed source data. Never the807950 equipped BIC row; not complete native SaveItem serialization."}
static func merge_fields(base:Dictionary,patch:Dictionary)->Dictionary:
	if patch.get("ready")!=true or not patch.get("fields") is Dictionary:return unavailable("The typed tail patch is unavailable.")
	var result:Dictionary=base.duplicate(true);result.merge(patch.fields.duplicate(true),true)
	return {"ready":true,"fields":result}
