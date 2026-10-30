extends RefCounted
# Original809220 edits an existing BIC. Never rebuild a high-level character
# through the first-level creation writer. UI/rule validation and atomic vault
# storage are separate owners; this layer has no filesystem/network actions.
const Patch=preload("res://systems/native_data/gff_root_patch.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const TYPES={"FirstName":12,"LastName":12,"Description":12,"DisplayName":10,"Subrace":10,"Deity":10,"Age":5,"SoundSetFile":2,"Portrait":11,"Color_Skin":0,"Color_Hair":0,"Color_Tattoo1":0,"Color_Tattoo2":0,"Phenotype":5,"Appearance_Type":2,"Tail_New":4,"Wings_New":4}
const EXTENDED=["Appearance_Head","BodyPart_Neck","BodyPart_Torso","BodyPart_Belt","BodyPart_Pelvis","BodyPart_LShoul","BodyPart_LBicep","BodyPart_LFArm","BodyPart_LHand","BodyPart_LThigh","BodyPart_LShin","BodyPart_LFoot","BodyPart_RShoul","BodyPart_RBicep","BodyPart_RFArm","BodyPart_RHand","BodyPart_RThigh","BodyPart_RShin","ArmorPart_RFoot"]
var failure:=""
static func extended_fields(label: String,value: int) -> Dictionary:
	return {label:Writer.field(0,value if value<256 else 0),("x"+label).left(16):Writer.field(2,value)}
func apply(source: PackedByteArray,changes: Dictionary) -> PackedByteArray:
	failure=""; var fields: Dictionary={}
	for label in changes:
		var value: Variant=changes[label]
		if EXTENDED.has(label):
			if not value is int or value<0 or value>65535: failure="Extended appearance part is outside its original WORD range."; return PackedByteArray()
			# Original WriteFieldWORDandBYTE1a3790: old byte is zero for values
			# above255, and the complete WORD is stored under ("x"+label)[:16].
			fields.merge(extended_fields(label,value))
		elif TYPES.has(label):
			if TYPES[label] in [10,11,12] and not value is String: failure="Character information requires native text."; return PackedByteArray()
			if TYPES[label]==12:
				value={"strRef":4294967295,"entries":[{"languageId":0,"text":value}]}
			fields[label]=Writer.field(TYPES[label],value)
		else: failure="This field is not editable through original character customization: "+str(label); return PackedByteArray()
	var patch:=Patch.new(); var result:=patch.apply(source,fields)
	failure=patch.failure; return result
