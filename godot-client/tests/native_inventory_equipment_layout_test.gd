extends "res://tests/native_particle_schedule_test.gd"
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Model=preload("res://systems/native_data/actor_model.gd")
const Layout=preload("res://systems/native_data/inventory_equipment_layout.gd")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original inventory resources mount read-only")
	var gff:=Gff.new(); var document:=gff.parse(catalog.get_resource("inv_equip",2047),"GUI ")
	check(gff.failure.is_empty(),"Original INV_EQUIP GUI parses natively")
	var models: Dictionary={}
	for child in document.root.Obj_ChildList:
		var name:=str(child.get("Obj_ResRef","")).to_lower()
		if name.is_empty() or models.has(name): continue
		var parser:=Model.new(); models[name]=parser.parse(catalog.get_resource(name,2002)); check(parser.failure.is_empty(),"Original slot model "+name)
	var result:=Layout.parse(document.root,models)
	check(str(result.error).is_empty() and result.slots.size()==14,"All fourteen compiled slot tags resolve active GUI positions and models")
	var definition: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-inventory-equipment-definitions-v1.json"))
	check(definition.binarySha256==BINARY_SHA and same(Layout.SLOTS,definition.rows).is_empty(),"Slot flags/icon dimensions match original constructor table140e4ffa0")
	var by_slot: Dictionary={}
	for slot in result.slots: by_slot[int(slot.slot)]=slot
	check(by_slot[1024].rect.size.distance_to(Vector2(66,68))<0.001 and by_slot[1024].icon.distance_to(Vector2(203,-34))<0.001,"Original horizontal belt box and icon attachment")
	check(by_slot[8].rect.size.distance_to(Vector2(66,52))<0.001 and by_slot[8].icon.distance_to(Vector2(268,-95))<0.001,"Original horizontal glove box and icon attachment")
	check(by_slot[512].rect.position.x>by_slot[128].rect.position.x and absf(by_slot[512].rect.position.y-by_slot[256].rect.position.y)>1,"Amulet remains in its active GUI lower-right column")
	check(result.labels.has("armorclasslabel") and result.labels.armorclasslabel.rect.position.distance_to(Vector2(88,-90))<0.001,"Original armor label keeps its own attachment coordinates")
	var bad: Dictionary=document.root.duplicate(true); bad.Obj_ChildList.pop_back(); check(not str(Layout.parse(bad,models).error).is_empty(),"Missing physical slot tag rejected")
	bad=document.root.duplicate(true); bad.Obj_ChildList.append(bad.Obj_ChildList[0].duplicate(true)); check(not str(Layout.parse(bad,models).error).is_empty(),"Duplicate slot tag rejected")
	var incomplete:=models.duplicate(); incomplete.erase(str(result.slots[0].resource)); check(not str(Layout.parse(document.root,incomplete).error).is_empty(),"Missing slot resource rejected")
	check(not str(Layout.model({"nodes":[{"parent":0,"position":[0,0,0],"orientation":[0,0,0,1]}]}).error).is_empty(),"Cyclic model parent rejected")
	var shifted: Dictionary=document.root.duplicate(true); shifted.Obj_ChildList[0].Obj_X+=1
	var moved:=Layout.parse(shifted,models)
	check(absf(moved.slots[7].rect.position.x-result.slots[7].rect.position.x-100)<0.001,"Active GUI offsets change the layout without compiled coordinates")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"bounds":str(result.get("bounds")),"scope":"Original fourteen-slot constructor metadata, installed GUI/MDL transforms, distinct icon anchors and rejected malformed hierarchy. No real server/GPU outcome here."},"\t")); file.close()
	print("NATIVE_INVENTORY_EQUIPMENT_LAYOUT ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
