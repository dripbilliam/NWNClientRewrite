extends SceneTree
const Visual=preload("res://systems/native_data/bic_visual.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const AppearanceCache=preload("res://systems/native_data/character_appearance_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func expected(row: Dictionary,name: String,fallback: int=0) -> int:
	return int(row.fields.get(("x"+name).left(16),row.fields.get(name,fallback)))
func authored(fields: Dictionary) -> Dictionary:
	var writer:=Writer.new(); var bytes:=writer.write("BIC ",Writer.record(fields)); var reader:=Gff.new(); return reader.parse(bytes,"BIC ")
func run() -> void:
	var output:=""; var install:=""; var fixture_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--fixture="): fixture_path=arg.substr(10)
	if output.is_empty() or install.is_empty() or fixture_path.is_empty() or FileAccess.file_exists(output): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture_path)); var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed original catalog mounts read-only")
	var assets:=Assets.new(); var raw_table: PackedByteArray=catalog.get_resource("baseitems",2017); var table: Dictionary=assets.decode(raw_table,2017,"2da","")
	check(str(table.error).is_empty(),"Preview resolves model types from actual original baseitems2DA")
	var equipment_count:=0
	for row in fixture.rows:
		var bytes:=FileAccess.get_file_as_bytes(row.file); var parser:=Gff.new(); var document:=parser.parse(bytes,"BIC "); var before:=Cache.digest(var_to_bytes(document)); var source:=Visual.source(document)
		check(Cache.digest(bytes)==row.sha256 and parser.failure.is_empty() and not source.has("error"),"Actual original BIC decodes visual fields: "+str(row.file).get_file())
		if source.has("error"): continue
		var a: Dictionary=source.appearance
		check(a.appearance==row.fields.Appearance_Type and a.head==expected(row,"Appearance_Head") and a.phenotype==int(row.fields.get("Phenotype",0))&255,"Appearance, extended head and phenotype retain raw identity")
		check(a.gender==int(row.fields.get("Gender",0)) and a.skin==int(row.fields.get("Color_Skin",0)) and a.hair==int(row.fields.get("Color_Hair",0)) and a.tattoo1==int(row.fields.get("Color_Tattoo1",0)) and a.tattoo2==int(row.fields.get("Color_Tattoo2",0)),"Actual serialized skin/hair/tattoo palette indices remain unchanged")
		check(a.bodyParts.size()==19 and range(19).all(func(at):return a.bodyParts[at].index==at and a.bodyParts[at].value==expected(row,Visual.Appearance.BODY[at])),"Physical body-part ordering agrees with raw original GFF fields")
		check(source.equipment.size()==row.equipment.size(),"Original equipped-list membership is preserved")
		for index in source.equipment.size():
			var item: Dictionary=source.equipment[index].item; var raw: Dictionary=row.equipment[index]; equipment_count+=1
			check(source.equipment[index].slot==int(raw.slot) and item.baseItem==int(raw.fields.BaseItem),"Equipment uses its actual GFF struct ID and base-item ID")
			check(range(3).all(func(at):return item.modelParts[at]==expected(raw,"ModelPart"+str(at+1))) and range(19).all(func(at):return item.armorParts[at]==expected(raw,Visual.ARMOR[at])),"Actual item model and armor parts retain their original ordering and extended values")
			check(range(6).all(func(at):return item.colors[at]==int(raw.fields.get(Visual.COLORS[at],0))) and range(19).all(func(part):return range(6).all(func(ch):return item.partColors[part][ch]==int(raw.fields.get(("APart_"+str(part)+"_Col_"+str(ch)).left(16),255)))),"Original whole-item and per-part palette colors survive native extraction")
		var actor:=Visual.actor(source,table.value)
		check(not actor.has("error") and actor.appearance.equipment.size()==source.equipment.size() and actor.replicated.stats.racialType==int(row.fields.get("Race",0)),"Native visual input is accepted by active base-item metadata")
		var last_seen:=AppearanceCache.visual(actor); var restored:=Visual.actor(last_seen,table.value)
		check(not last_seen.is_empty() and restored==actor,"Last-seen visual data reproduces every original body, equipment part, slot and color under the same active rules")
		check(Cache.digest(var_to_bytes(document))==before and not source.has("EffectList") and not source.has("ScriptHeartbeat") and actor.id==1,"Source bytes/records stay immutable and saved scripts/effects/world IDs are excluded")
	check(fixture.rows.size()==39 and equipment_count==102,"Corpus covers39 original BICs and102 actual equipped records")
	var fields:={"Appearance_Type":Writer.field(2,6),"Appearance_Head":Writer.field(0,5),"xAppearance_Head":Writer.field(2,1234),"Race":Writer.field(0,6),"Equip_ItemList":Writer.field(15,[Writer.record({"BaseItem":Writer.field(5,16),"ArmorPart_RShoul":Writer.field(0,1),("xArmorPart_RShoul").left(16):Writer.field(2,456)},2)])}
	var source:=Visual.source(authored(fields)); check(source.appearance.head==1234 and source.equipment[0].item.armorParts[14]==456,"Extended WORD fields override byte fields with original16-byte GFF label truncation")
	var overridden: Dictionary=table.value.duplicate(true); overridden.orderedRows[16].ModelType="1"
	check(Visual.actor(source,overridden).appearance.equipment[0].item.parts.size()==1 and Visual.actor(source,table.value).appearance.equipment[0].item.parts.size()==19,"An active server model-type override changes preview planning without hardcoded item categories")
	fields.Appearance_Type=Writer.field(4,6); check(Visual.source(authored(fields)).has("error"),"A missing or incorrectly typed appearance cannot silently render another creature")
	fields.Appearance_Type=Writer.field(2,6); fields.Equip_ItemList.value.append(fields.Equip_ItemList.value[0]); check(Visual.source(authored(fields)).has("error"),"Duplicate physical equipment slots fail explicitly")
	fields.erase("Equip_ItemList"); var partial:=Visual.source(authored(fields)); check(partial.equipment.is_empty() and not partial.equipmentComplete,"An omitted equipment field is incomplete, rather than proof of a naked character")
	fields.Equip_ItemList=Writer.field(15,[]); check(Visual.source(authored(fields)).equipmentComplete,"An explicitly empty equipped list is complete and may legitimately show an unclothed character")
	fields.Equip_ItemList=Writer.field(0,0); check(Visual.source(authored(fields)).has("error"),"An incorrectly typed equipment field is refused rather than silently discarded")
	check(Visual.actor(source,{"orderedRows":[]}).has("error"),"Missing active server rules report unavailable preview data rather than guessing a model type")
	assets.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"corpus":fixture.rows.size(),"equipment":equipment_count,"publicConnections":0,"native_only":true,"renderedPreviewAccepted":false,"fullUiParity":false,"scope":"Actual original BIC visual field/slot/color extraction against independent raw GFF decoding, typed extended fields, active base-item overrides and missing/invalid data. No GPU model, online reply completeness or live picker integration accepted."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
