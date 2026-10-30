extends SceneTree
const Properties=preload("res://systems/native_data/item_property_text.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Content=preload("res://systems/native_data/examine_content.gd")
var checks:=0
var failures: Array=[]
var sources: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func read_table(catalog,text,name: String) -> void:
	var bytes: PackedByteArray=catalog.get_resource(name,2017); var parser:=Table.new()
	text.tables[name]=parser.parse(Binary.new(bytes).text(0,bytes.size())); sources[name]=FileAccess.get_sha256(ProjectSettings.globalize_path("res://systems/native_data/two_da.gd"))
	check(catalog.failure.is_empty() and parser.failure.is_empty() and not bytes.is_empty(),"Active native original table loads "+name)
	var digest:=HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(bytes); sources[name]=digest.finish().hex_encode()
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var install:=ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed original resources mount read-only")
	var text:=Talk.new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original English TLK opens read-only")
	for name in ["itempropdef","iprp_costtable","iprp_paramtable","baseitems","armor"]: read_table(catalog,text,name)
	# Same disclosed Greater Magic Bag tuple retained in original-server v94
	# examination evidence; plus an ordinary ability-bonus property.
	var samples: Array=[{"type":32,"subtype":0,"costValue":4,"uses":255,"usable":false},{"type":0,"subtype":0,"costValue":2,"uses":255,"usable":false}]
	for stage in 5:
		var needed:=Properties.dependencies(samples,text.tables)
		if needed.is_empty(): break
		for name in needed: read_table(catalog,text,name)
	var output:=Properties.project(samples,text,0)
	check(output.missing.is_empty() and output.warnings.is_empty() and output.properties.size()==2,"Original property/subtype/cost text resolves without hard-coded rules")
	check(output.properties.size()>0 and output.properties[0].rich.text.contains("-80%"),"Historical real server Greater Magic Bag tuple displays original -80% label")
	check(output.properties.size()>1 and output.properties[1].rich.text.contains("Strength") and output.properties[1].rich.text.contains("+2"),"Ordinary original ability bonus displays Strength and +2")
	text.objects={20:{"item":{"baseItem":0}}}
	var message:={"description":{"text":"Disclosed sword description."},"identified":true,"charges":4,"weight":15,"value":25,"minimumLevel":9,"canUse":false}
	var content:=Content.item(message,text,20); var body:=str(content.rich.text)
	check(body.begins_with("Disclosed sword description.\n\nBase Damage: 1d6\nBase Critical Threat: 19-20/x2"),"Original item description precedes the active base-item stat block with its native blank line")
	check(body.contains("Base Item: ") and body.contains("\nCharges: 4\nWeight: 1\nValue GP: 25\n\nLevel Required: 9\n"),"Original localized labels and binary field order retain the requested whole-number game display, including weight")
	check(content.property_heading.text=="Special Properties:" and not body.contains("Cannot use") and not body.contains("Item type:"),"Original property heading replaces generic UI labels without inventing a use-permission field")
	message.identified=false; message.value=4294967295; body=Content.item(message,text,20).rich.text
	check(not body.contains("Charges:") and not body.contains("Level Required:") and not body.contains("Value GP:") and not body.contains("Unidentified"),"Original disclosure and sentinel gates omit charges, required level, absent value and invented identification text")
	message.description={"text":""}; body=Content.item(message,text,20).rich.text
	check(body.begins_with(text.resolve({"strRef":1684},20)),"Empty received description uses the active original base-item description")
	var parts: Array=[]; parts.resize(19); parts.fill(0)
	text.objects[20].item={"baseItem":16,"field35c":1,"parts":parts}; body=Content.item(message,text,20).rich.text
	check(body.begins_with(text.resolve({"strRef":1728},20)) and body.contains("Base Armor Class: 1\nMaximum Dexterity Bonus: 8"),"Armor description and stat block use the server-disclosed armor category even when appearance parts differ")
	text.objects[20].item.field35c=0; body=Content.item(message,text,20).rich.text
	check(body.begins_with(text.resolve({"strRef":1727},20)) and body.contains("Base Armor Class: 0"),"Server-disclosed zero armor category selects the original clothing description")
	text.objects[20].item.erase("field35c"); body=Content.item(message,text,20).rich.text
	check(not body.contains("Base Armor Class:"),"Missing server armor category cannot be fabricated from visible model parts")
	var server_base: Dictionary=text.tables.baseitems.orderedRows[0].duplicate(); server_base.Description="16777217"; server_base.BaseItemStatRef="16777218"; server_base.Name="16777219"; text.tables.baseitems.orderedRows[0]=server_base
	text.overrides.merge({16777217:"Server description",16777218:"Server statistics",16777219:"Server base name",0x15bf:"Server mass:"}); text.objects[20].item={"baseItem":0}; body=Content.item(message,text,20).rich.text
	check(body.begins_with("Server description\n\nServer statistics\nBase Item: Server base name\nServer mass: 1") and not body.contains("Server mass: 1."),"Server-selected 2DA/TLK references and label overrides remain authoritative with whole-number game fields")
	text.close(); catalog=null
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"tablesSha256":sources,"output":output,"publicConnections":0,"scope":"Read-only installed original 2DA/TLK property labels; historical server-disclosed bag tuple and ordinary ability bonus. No live server or GPU acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
