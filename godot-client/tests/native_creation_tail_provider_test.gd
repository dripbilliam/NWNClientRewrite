extends SceneTree
const Provider=preload("res://systems/native_data/creation_tail_provider.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const W=preload("res://systems/native_data/gff_writer.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Info=preload("res://systems/native_data/creation_character_info_state.gd")
var checks:=0
var failures:Array=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message)
func _initialize()->void:run.call_deferred()
func save(path:String,bytes:PackedByteArray)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
func source(table:Dictionary)->String:
	var result:="2DA V2.0\n\n"+" ".join(table.columns)+"\n"
	for index in table.rows.size():result+=str(900+index*13)+" "+" ".join(table.rows[index])+"\n"
	return result
func read_table(catalog,name:String)->Dictionary:
	var bytes:PackedByteArray=catalog.get_resource(name,2017);var parser:=Table.new();var value:=parser.parse(preload("res://systems/native_data/binary_data.gd").new(bytes).text(0,bytes.size()));check(parser.failure.is_empty(),"Actual active table parses: "+name);return value
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var directory:String=str(args.report)+".active";DirAccess.make_dir_recursive_absolute(directory)
	var definitions:Dictionary={
		"racialtypes":{"columns":["Appearance"],"rows":[["1"],["0"]]},
		"appearance":{"columns":["MODELTYPE","RACE"],"rows":[["P","z"],["S","static"]]},
		"gender":{"columns":["GENDER"],"rows":[["m"],["f"]]},
		"ruleset":{"columns":["Label","Value"],"rows":[["CHARGEN_ENABLED_PHENOTYPES","20"]]},
		"packages":{"columns":["SoundSet"],"rows":[["1"]]},
		"soundset":{"columns":["RESREF","TYPE","GENDER","STRREF"],"rows":[["not_selectable","1","1","1000"],["female_voice_a","2","1","1001"],["female_voice_b","0","1","1002"],["male_voice","0","0","1003"],["npc_voice","3","1","1004"],["wrapped_type","256","1","1005"]]},
		"chargenclothes":{"columns":["ClassRestrict","RaceRestrict","GenderRestrict","AlignmentRestrict","ItemResRef"],"rows":[["259","1","0","TN","UPPER_ROBE"],["****","****","****","****","UPPER_ROBE"],["****","****","****","****","upper_robe"],["****","****","****","****","****"],["5","****","****","****","wrong_class"],["****","-1","****","****","wrong_race"],["****","****","-1","****","wrong_gender"],["****","****","****","tn","wrong_alignment"],["****","****","****","****","absent_outfit"],["****","****","****","****","absent_outfit"],["****","****","****","****","extended_robe"]]}
	}
	for name in definitions:save(directory.path_join(str(name)+".2da"),source(definitions[name]).to_ascii_buffer())
	var body:Dictionary={};for label in Provider.Appearance.BODY:body[str(label).replace("BodyPart_","ArmorPart_")]=W.field(0,1)
	body.xArmorPart_Torso=W.field(2,302);body.ArmorPart_Torso=W.field(0,7)
	body[("xArmorPart_Pelvis").left(16)]=W.field(0,9);body.ArmorPart_Pelvis=W.field(0,4)
	body.ArmorPart_RShin=W.field(2,444)
	for material in Provider.Appearance.MATERIALS:body[str(material)+"Color"]=W.field(0,17)
	body.Leather1Color=W.field(2,333)
	var writer:=W.new();var bytes:=writer.write("UTI ",W.record(body));check(writer.failure.is_empty(),"Authored active UTI has exact native field widths")
	save(directory.path_join("upper_robe.uti"),bytes);save(directory.path_join("extended_robe.uti"),bytes)
	var catalog:=Catalog.new();check(catalog.mount_install(args.install) and catalog.mount_directory(directory,99999999),"Private active catalog mounts owned overrides above installed resources")
	var tables:Dictionary={}
	for name in definitions:tables[name]=read_table(catalog,name)
	var loads:Dictionary={"absent_outfit":{"status":"absent"}}
	for name in ["upper_robe","extended_robe"]:
		var parser:=Gff.new();var original:=catalog.get_resource(name,2025);var document:=parser.parse(original,"UTI ");check(parser.failure.is_empty(),"Actual native GFF parser reads typed active outfit: "+name);loads[name]={"status":"ready","document":document,"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(original)}
	var selection:Dictionary={"mode":0,"classes":[3],"raceId":1,"gender":0,"lawChaos":50,"goodEvil":50,"phenotype":255,"head":300,"skin":12,"hair":13,"tattoo1":14,"tattoo2":15}
	var admitted:=Provider.clothing_candidates(tables.chargenclothes,selection);check(admitted.ready and admitted.candidates.map(func(row):return int(row.id))==[0,1,2,3,8,9,10],"Original restrict checks keep lowBYTE class/fullUINT race and case-sensitive alignment in physical order")
	check(admitted.candidates[3].rawResRef.is_empty(),"A valid missing ItemResRef cell clears the native getter output instead of retaining another outfit")
	var choices:=Provider.clothing(tables.chargenclothes,selection,loads);check(choices.ready and choices.choices.map(func(row):return int(row.id))==[0,2,10],"Only successfully loaded outfits are case-sensitive deduplicated; canonical-case aliases retain distinct rows")
	if not choices.ready:
		print("TAIL_PROVIDER_DIAGNOSTIC ",JSON.stringify({"choices":choices,"documentKeys":loads.upper_robe.document.keys(),"fieldTypes":loads.upper_robe.document.get("field_types"),"type":loads.upper_robe.document.get("type"),"version":loads.upper_robe.document.get("version")}));quit(1);return
	var garment:Dictionary=choices.choices[0];check(garment.bodyParts[7]==302 and garment.bodyParts[6]==4 and garment.bodyParts[2]==0,"Original typed extended WORD overrides BYTE; wrong extended type falls back; normal WORD is rejected")
	check(garment.colors==[0,17,17,17,17,17],"Material fields accept BYTE only and retain original loaded-UTI default0")
	var delayed:=loads.duplicate(true);delayed.erase("extended_robe");var waiting:=Provider.clothing(tables.chargenclothes,selection,delayed);check(not waiting.ready and waiting.requests==["extended_robe"],"Pending resources cannot publish a partial original clothes list")
	var empty_doc:={"type":"UTI ","version":"V3.2","root":{},"field_types":{0:{}}};var empty:=Provider.garment(empty_doc,0,"empty");check(empty.ready and empty.value.bodyParts.size()==19 and empty.value.bodyParts.all(func(part):return part==0),"Known loaded empty UTI uses explicit native defaults")
	check(not Provider.garment({"type":"UTI ","version":"V3.2","root":{}},0,"missing").ready,"Missing field-type metadata is unavailable, not a fabricated default outfit")
	var models:Array=["pmz0_head001","pmz0_head002","pmz0_head300","pmz4_head099","pfz0_head003"]
	var heads:=Provider.heads(tables,0,0,models);check(heads.ready and heads.prefix=="pmz0_head" and heads.heads.has(300) and not heads.heads.has(99),"Native head lookup uses phenotype0 and preserves extended WORD IDs")
	var other_gender:=Provider.heads(tables,0,2,models);check(other_gender.ready and other_gender.heads==heads.heads,"Original head prefix selects gender row by gender==1, not arbitrary row ID")
	var palettes:Dictionary={};for name in Provider.PALETTES.values():palettes[name]={"width":256,"height":176,"format":"rgba8"}
	var appearance:=Provider.appearance(tables,selection,models,loads,palettes);check(appearance.ready and appearance.context.value.phenotype==2 and appearance.context.value.head==300 and appearance.context.value.clothes==0 and appearance.context.value.bodyParts[7]==302,"Complete current active appearance context uses native mask init/head/outfit order")
	check(appearance.context.value.skinParts[8]==0 and appearance.context.value.skinParts[14]==0 and appearance.context.value.skinParts[7]==1,"New source draft skin parts use explicit original initialization")
	var changed:Dictionary=appearance.context.value;changed.bodyParts[7]=999;check(loads.upper_robe.document.root.xArmorPart_Torso==302 and choices.choices[0].bodyParts[7]==302,"Returned private appearance cannot mutate typed source documents or another projection")
	for model in ["F","C"]:
		var nonp_tables:=tables.duplicate(true);nonp_tables.appearance.orderedRows[0].MODELTYPE=model;nonp_tables.appearance.orderedCells[0][0]=model
		nonp_tables.appearance.orderedRows[0].RACE="****";nonp_tables.appearance.orderedCells[0][1]="****"
		var nonp:=Provider.appearance(nonp_tables,selection,[],loads,{})
		check(nonp.ready and nonp.context.modelType==model and nonp.context.value.head==1 and nonp.context.heads.is_empty() and not nonp.context.headIndexComplete and nonp.context.paletteSizes.is_empty(),"Known non-P "+model+" with missing RACE and unused palettes stays operable without invented choices")
		var disabled:=Provider.Private.new();disabled.reset(nonp.context)
		check(["body","head","tattoo","clothes","skin","hair","tattoo1","tattoo2"].all(func(kind):return not disabled.editable(kind)),"Original non-P "+model+" disables every P-specific action")
		var present_head:=Provider.appearance(nonp_tables,selection,["pm0_head300"],loads,{})
		check(present_head.ready and present_head.context.value.head==300 and present_head.context.heads.is_empty(),"Original non-P current-head existence check uses written empty RACE without publishing a head-choice index")
	var old:=selection.duplicate(true);old.mode=1;old.bodyParts=garment.bodyParts.duplicate();old.skinParts=appearance.context.value.skinParts.duplicate();old.materialColors=garment.colors.duplicate();var existing:=Provider.appearance(tables,old,models,{},palettes);check(existing.ready and existing.context.clothing.is_empty() and existing.context.value.bodyParts==old.bodyParts,"Existing customization preserves owned appearance without loading a new outfit")
	old.erase("skinParts");check(not Provider.appearance(tables,old,models,{},palettes).ready,"Existing missing native skin state is explicit rather than inferred from equipment")
	var text:=Text.new();text.overrides={1001:"Active voice A",1002:"Active voice B",1005:"Wrapped native byte"}
	var voice:=Provider.voices(tables.soundset,1,text);check(voice.ready and voice.entries.map(func(row):return int(row.id))==[1,2,5] and voice.entries[0].name=="Active voice A","Active voice filter accepts TYPE0/2, exact gender and current TLK strings with physical IDs")
	var fields:Dictionary={"raceId":1,"gender":1,"packageId":0,"firstName":"é".repeat(250),"lastName":"Native","age":-7,"biography":"  Source biography  ","deity":"Active deity","soundset":99}
	var info:=Provider.character_info(tables,fields,text);check(info.ready and info.context.value.soundset==2 and info.provenance.packageVoiceIndex==1 and info.context.value.ageText=="-7","Package visible index maps to filtered physical soundset; age stays native signed integer")
	check(not info.context.randomReady and info.context.namePlan.ready and info.context.namePlan.resources==["elff","elfl"],"Info exposes the source name route but cannot enable Random before resource-worker preparation")
	var private_info:=Info.new();private_info.reset(info.context);var result:=private_info.result();check(result.available and result.value.firstName.length()==250 and result.value.description=="  Source biography  " and result.value.age== -7,"Info staged result uses actual CP1252 byte width and preserves biography/age")
	check(Info.native_prefix("€".repeat(251),250).text.length()==250,"CP1252 exceptional characters consume one original byte")
	check(not Info.native_prefix(String.chr(0x1f642),250).ready,"Unencodable text remains unavailable and cannot become empty submitted data")
	text.overrides[1002]="New publication";var newer:=Provider.character_info(tables,fields,text);check(newer.ready and newer.context.voices[1].name=="New publication" and info.context.voices[1].name=="Active voice B","Each publication resolves fresh active text without mutating detached prior views")
	var revised:=tables.duplicate(true);revised.packages.orderedCells[0][0]="0";revised.packages.orderedRows[0].SoundSet="0"
	var replacement:=Provider.character_info(revised,fields,text);check(replacement.ready and replacement.context.value.soundset==1 and info.context.value.soundset==2,"A replacement active package changes only its new detached initial voice")
	revised.packages.orderedCells[0][0]="99";revised.packages.orderedRows[0].SoundSet="99";check(not Provider.character_info(revised,fields,text).ready,"Unsafe native out-of-range visible voice index stays explicit rather than selecting another soundset")
	var unavailable_names:=fields.duplicate();unavailable_names.erase("raceId");var no_route:=Provider.character_info(tables,unavailable_names,text);check(no_route.ready and not no_route.context.namePlan.ready and not no_route.context.randomReady,"Unknown race disables Random without inventing a race or blocking other known fields")
	check(Provider.text_cell({"columns":["ItemResRef"],"orderedRows":[{}],"orderedCells":[["****"]],"defaultValue":"NonemptyDefault"},0,"ItemResRef").value=="" and not Provider.text_cell({"columns":[],"orderedRows":[],"defaultValue":"NonemptyDefault"},1,"ItemResRef").ok,"Literal missing token clears despite a nonempty default; invalid lookup keeps failed-getter status")
	var invalid:=fields.duplicate();invalid.age=null;check(not Provider.character_info(tables,invalid,text).ready,"Missing age is never presented as0")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"activeCatalog":true,"gpu":false,"serverConnections":0,"scope":"Detached staged tail provider with actual owned active2DA/typedUTI catalog parsing, physical-row restrictions, extended field ownership, head/phenotype/palette projection, source-proven voice index and name plan, text/age mapping and publication/mutation isolation. No live creator/BIC/UI/preview/server integration."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
