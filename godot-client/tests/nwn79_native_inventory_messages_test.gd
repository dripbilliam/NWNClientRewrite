extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Rules=preload("res://systems/native_data/native_object_rules.gd")
const Updates=preload("res://systems/native_data/native_object_updates.gd")
const World=preload("res://systems/native_data/native_network_world.gd")

func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/local-network-renderer-v20.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:fail("Original inventory session unavailable");return
	var catalog:=Catalog.new()
	if not catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")):fail("Original install catalog unavailable");return
	var tables: Dictionary={}
	for name in ["baseitems","classes","visualeffects","skills"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2017)
		if bytes.is_empty():fail("Original "+name+" table unavailable");return
		tables[name]=Parser.new().parse(bytes.get_string_from_utf8())
	var rules:=Rules.new()
	if not rules.configure(tables):fail("Original object rule schema unavailable");return
	var build: Dictionary={"number":8193,"revision":37,"postfix":17}
	var object_packets:=0;var inventory: Array[Dictionary]=[];var world:=World.new()
	for hex in fixture.wireMessages:
		var bytes:=str(hex).hex_decode()
		if bytes.size()<3 or bytes[0]!=80 or bytes[1]!=5 or bytes[2]!=1:continue
		var decoded: Dictionary=Updates.decode_packet(bytes,build,rules.providers())
		if decoded.has("error") or not decoded.get("complete",false):fail("Original object-update packet "+str(object_packets)+" incomplete: "+str(decoded.get("error",decoded.get("unhandled",{}))));return
		if not world.apply_updates(decoded):fail("Original inventory world update rejected: "+world.error);return
		object_packets+=1
		for record in decoded.records:
			if record.get("action")=="inventory":inventory.append(record)
	if object_packets!=7 or inventory.size()!=8:fail("Original inventory record count differs: "+str(object_packets)+" packets, "+str(inventory.size())+" inventory entries");return
	var equipment:=0;var backpack:=0
	for item in inventory:
		if item.get("channel")=="I":equipment+=1
		if item.get("channel")=="R":backpack+=1
	if equipment!=3 or backpack!=5:fail("Original equipment/backpack ownership differs");return
	if world.inventories.get("I",{}).get("entries",[]).size()!=3 or world.inventories.get("R",{}).get("entries",[]).size()!=5:fail("Godot inventory state did not retain original items");return
	print("NWN79 Godot native inventory messages PASS (7 object packets, 3 equipped, 5 backpack)")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot inventory messages failed: "+reason)
	quit(1)
