extends SceneTree
const Tail=preload("res://systems/native_data/creation_tail_bic.gd")
const W=preload("res://systems/native_data/gff_writer.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Provider=preload("res://systems/native_data/creation_tail_provider.gd")
var checks:=0
var failures:Array=[]
var artifacts:Dictionary={}
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message)
func _initialize()->void:run.call_deferred()
func integer_fields(source:Dictionary)->Dictionary:
	var result:Dictionary={}
	for label in source:result[label]={"type":int(source[label].type),"value":int(source[label].value)}
	return result
func fields_equal(actual:Dictionary,expected:Dictionary)->bool:
	for label in expected:
		if not actual.has(label) or actual[label].type!=expected[label].type or actual[label].value!=expected[label].value:return false
	return true
func native_value(source:Dictionary)->Dictionary:
	var result:=source.duplicate(true)
	for key in result:
		if result[key] is float:result[key]=int(result[key])
		elif result[key] is Array:result[key]=result[key].map(func(value):return int(value))
	return result
func parsed(kind:String,record:Dictionary)->Dictionary:
	var writer:=W.new();var bytes:=writer.write(kind,record);check(writer.failure.is_empty(),"Native typed writer accepts "+kind+": "+writer.failure)
	artifacts[kind]=bytes
	var parser:=Gff.new();var document:=parser.parse(bytes,kind);check(parser.failure.is_empty(),"Native parser reads written "+kind+": "+parser.failure)
	return document
func typed_outfit()->Dictionary:
	var body:Dictionary={"Tag":W.field(10,"Physical outfit tag"),"BaseItem":W.field(5,16),"ObjectId":W.field(4,0xf0000012),"LocalizedName":W.field(12,{"strRef":12345,"entries":[{"languageId":0,"text":"Unchanged é outfit"}]}),"SourceQword":W.field(6,{"unsigned64_low":0xfedcba98,"unsigned64_high":0xfedcba98}),"PrivateData":W.field(13,PackedByteArray([7,8,9])),"APart_7_Col_2":W.field(0,37),"PropertiesList":W.field(15,[W.record({"PropertyName":W.field(2,321),"Subtype":W.field(2,456)},0)])}
	for index in 19:
		var label:String=Tail.Body.BODY[index].replace("BodyPart_","ArmorPart_");body[label]=W.field(0,1)
	for material in Tail.Body.MATERIALS:body[str(material)+"Color"]=W.field(0,3)
	return parsed("UTI ",W.record(body))
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-tail-appearance-save-original-v1.json"))
	check(oracle.success and oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Typed save oracle is the pinned original binary")
	for row in oracle.primitives:
		var result:=Tail.word_and_byte(str(row.label),int(row.value));var expected:=integer_fields(row.fields)
		check(result.ready and result.fields==expected and result.fields.size()==2,"Complete original WORDandBYTE case: "+str(row.label)+" "+str(row.value))
	for row in oracle.clients:
		var value:=native_value(row.input);value.clothes=313;var choice:Dictionary={"id":313,"resRef":str(value.clothingResRef)}
		# Keep clothed actual parts deliberately unlike the naked source half.
		value.bodyParts=range(500,519);value.materialColors=[1,2,3,4,5,6]
		var result:=Tail.first_level(int(value.appearanceId),value,choice);var expected:=integer_fields(row.fields)
		check(result.ready and fields_equal(result.fields,expected) and result.fields.size()==expected.size()+1 and result.unavailableFields.is_empty(),"Original client appearance slice uses exact types/skin half for head "+str(value.head))
		var equipment:Dictionary=result.fields.Equip_ItemList.value[0]
		check(equipment.type==int(row.equipment.structType) and equipment.fields.size()==1 and equipment.fields.EquippedRes.type==11 and equipment.fields.EquippedRes.value==row.equipment.value,"Original first-level equipped record contains ONLY source EquippedRes at structtype2")
		check(result.sourceOutfit.physicalRow==313 and not result.fields.has("BodyPart_Robe") and not result.fields.has("xBodyPart_Robe"),"Physical source row is retained as provenance; root does not serialize Robe")
	var source:=typed_outfit();var source_snapshot:Dictionary=source.root.duplicate(true);var source_types:Dictionary=source.field_types.duplicate(true)
	for row in oracle.outfits:
		var value:=native_value(row.input);value.clothes=997;value.clothingResRef="active_outfit"
		var result:=Tail.private_outfit(source,value,{"id":997,"resRef":"active_outfit"});var expected:=integer_fields(row.fields)
		check(result.ready and fields_equal(result.record.fields,expected),"Original model3 item appearance slice writes all19parts/sixBYTE colors")
		var restored:=parsed("UTI ",result.record);var actual:=Provider.garment(restored,997,"active_outfit")
		check(actual.ready and actual.value.bodyParts==value.bodyParts and actual.value.colors==value.materialColors,"Private UTI roundtrip preserves all19 extended parts and six colors through actual typed getter")
		check(restored.root.Tag==source.root.Tag and restored.root.ObjectId==source.root.ObjectId and restored.root.LocalizedName==source.root.LocalizedName and restored.root.SourceQword==source.root.SourceQword and restored.root.PropertiesList==source.root.PropertiesList and restored.root.PrivateData==source.root.PrivateData and restored.root.APart_7_Col_2==37,"Unrelated source typed metadata/localized/list/qword/binary/per-part fields survive private overlay")
		result.record.fields.Tag.value="Caller mutation";result.record.fields.PropertiesList.value[0].fields.Subtype.value=999
	check(source.root==source_snapshot and source.field_types==source_types,"Private overlays and caller mutations never change source UTI values or metadata")
	var value:Dictionary={"head":300,"phenotype":2,"skin":12,"hair":14,"tattoo1":17,"tattoo2":19,"skinParts":range(290,309),"bodyParts":range(400,419),"materialColors":[255,254,253,252,251,250],"clothes":887,"clothingResRef":"physical_outfit"}
	var patch:=Tail.first_level(301,value,{"id":887,"resRef":"physical_outfit"})
	check(patch.ready and patch.fields.Appearance_Head.value==0 and patch.fields.xAppearance_Head.type==2 and patch.fields.xAppearance_Head.value==300 and patch.unavailableFields==["Tail_New","Wings_New"],"Unknown appendages are explicit; extended head300 always has normalBYTE0 plus fullWORD")
	var info:Dictionary={"firstName":"  é".repeat(1)+"€".repeat(247),"lastName":" Last ","description":"  Biography é €  ","deity":" deity é ","age":-7,"soundset":50001}
	var text:=Tail.information(info);check(text.ready,"Accepted source CP1252 information is a typed patch")
	var base:Dictionary={"ClassList":W.field(15,[W.record({"Class":W.field(5,77),"ClassLevel":W.field(3,1)},0)]),"Untouched":W.field(4,0xfeedbeef),"Appearance_Head":W.field(0,1),"Equip_ItemList":W.field(15,[W.record({"OldLegacyClone":W.field(0,1)},2)])};var before:=base.duplicate(true)
	var combined:=Tail.merge_fields(base,patch);combined=Tail.merge_fields(combined.fields,text);var document:=parsed("BIC ",W.record(combined.fields))
	check(document.root.xAppearance_Head==300 and document.field_types[0].Appearance_Head==0 and document.field_types[0].xAppearance_Head==2 and document.root.BodyPart_Torso==0 and document.root.xBodyPart_Torso==297,"Parsed native BIC contains full extended head/skin torso with correct legacyBYTE zero")
	check(document.root.FirstName.entries[0].text==info.firstName and document.root.LastName.entries[0].text==" Last " and document.root.Description.entries[0].text==info.description and document.root.Deity==info.deity and document.root.Age== -7 and document.root.SoundSetFile==50001,"Parsed actual BIC preserves CP1252, whitespace, signed age and physical soundsetWORD")
	check(document.root.Equip_ItemList.size()==1 and document.root.Equip_ItemList[0]=={"EquippedRes":"physical_outfit"} and document.struct_types[2]==2 and document.root.ClassList[0].Class==77 and document.root.Untouched==0xfeedbeef,"Staged source overlay keeps generic unrelated fields while replacing only the equipped reference shape")
	check(base==before and value.skinParts==range(290,309),"Applying source patches leaves the generic input and accepted private appearance unchanged")
	var missing:=value.duplicate(true);missing.erase("skinParts");check(not Tail.first_level(301,missing,{"id":887,"resRef":"physical_outfit"}).ready,"Missing skin half cannot fall back to clothed preview or zero body parts")
	check(not Tail.first_level(301,value,{"id":888,"resRef":"physical_outfit"}).ready and not Tail.first_level(301,value,{"id":887,"resRef":"other"}).ready,"Changed physical outfit/resource is rejected instead of borrowing another variation")
	var unknown:=info.duplicate();unknown.soundset=null;check(not Tail.information(unknown).ready,"Unavailable soundset is never serialized as0")
	unknown=info.duplicate();unknown.firstName="€".repeat(251);check(not Tail.information(unknown).ready,"Unprocessed names beyond native byte limit must return through the Info transaction")
	unknown=info.duplicate();unknown.firstName=String.chr(0x1f642);check(not Tail.information(unknown).ready,"Unencodable text cannot silently become an empty BIC field")
	check(not Tail.word_and_byte("Appearance_Head",null).ready and not Tail.word_and_byte("Appearance_Head",65536).ready and not Tail.word_and_byte("Náme",1).ready,"Missing/overflow WORD values and non-ASCII field labels are explicit")
	var invalid:=source.duplicate(true);invalid.erase("field_types");check(not Tail.private_outfit(invalid,value,{"id":887,"resRef":"physical_outfit"}).ready,"A source UTI without typed metadata cannot be reconstructed with guessed field widths")
	var final_outfit:=Tail.private_outfit(source,value,{"id":887,"resRef":"physical_outfit"});parsed("UTI ",final_outfit.record)
	for pair in [["BIC ",".bic"],["UTI ",".uti"]]:
		var output:=FileAccess.open(str(args.report)+str(pair[1]),FileAccess.WRITE);output.store_buffer(artifacts[pair[0]]);output.close()
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"nativeBuilds":0,"originalPrimitiveCases":oracle.primitives.size(),"originalClientSlices":oracle.clients.size(),"originalOutfitSlices":oracle.outfits.size(),"scope":"Staged typed patch and actual GFF writer/parser BIC/UTI roundtrip; complete original WORDandBYTE and bounded client/item appearance slice comparison. Reference-only first-level outfit and separate private19part/6color overlay remain distinct. No shipping builder integration, creator completion, full original BIC byte parity or authoritative server admission."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
