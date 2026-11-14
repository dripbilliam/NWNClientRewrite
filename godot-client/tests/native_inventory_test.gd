extends SceneTree
const Plan=preload("res://systems/native_data/item_icon.gd")
const Palette=preload("res://systems/native_data/palette_texture.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Owner=preload("res://systems/native_inventory.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<25: failures.append(label)
func canonical(value: Variant) -> Variant:
	if value is float: return int(value) if value==floor(value) else value
	if value is Array: return value.map(canonical)
	if value is Dictionary:
		var result: Dictionary={}; var keys: Array=value.keys(); keys.sort()
		for key in keys: result[key]=canonical(value[key])
		return result
	return value
func equal(a: Variant,b: Variant) -> bool: return JSON.stringify(canonical(a))==JSON.stringify(canonical(b))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var catalog:=Catalog.new()
	check(catalog.mount_install(oracle.install),"Native original icon catalog")
	check(catalog.mount_erf(str(oracle.install).path_join("data/nwm/Prelude.nwm"),100000000),"Native Prelude original icon resources")
	var tables: Dictionary={}
	for name in ["baseitems","capart","parts_robe","cloakmodel","iprp_spells","encumbrance"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2017); var parser:=Table.new(); tables[name]=parser.parse(Binary.new(bytes).text(0,bytes.size())); check(parser.failure.is_empty(),"Original item table "+name)
	var armor: Dictionary={}; var flat: Dictionary={}
	for index in oracle.cases.size():
		var source: Dictionary=oracle.cases[index]; var decoder:=Plan.new(); var plan:=decoder.plan(source.item,tables,int(source.gender))
		if not equal(plan,source.get("plan",{})): print(JSON.stringify({"index":index,"actual":plan,"expected":source.get("plan",{}),"error":decoder.failure}))
		check(equal(plan,source.get("plan",{})),"Original icon plan %d"%index)
		if plan.is_empty(): continue
		var selected:=decoder.select(plan,catalog)
		check((not decoder.failure.is_empty())==bool(source.error),"Original icon absence/fallback result %d"%index)
		if not source.error:
			check(equal(selected,source.selected),"Original compacted layers/GUI resource selection %d"%index)
			if selected.kind=="armor" and armor.is_empty(): armor=source
			if selected.kind=="flat" and flat.is_empty(): flat=source
		for pixel in source.pixels:
			var result:=Palette.new().prepare(catalog,str(pixel.name),pixel.palette,"",true)
			check(str(result.get("error","")).is_empty(),"Native original icon PLT preparation")
			if str(result.get("error","")).is_empty(): check(Cache.digest(result.value.mips[0].data)==pixel.sha256,"Exact original icon metal palette RGBA pixels")
	check(not armor.is_empty() and not flat.is_empty(),"Original icon corpus includes armor and flat icons")
	# Native controls and ownership use authored item identities, while icon
	# selection/dimensions above use the actual original tables.
	var text:=Text.new(); text.tables=tables
	var parent:=Control.new(); root.add_child(parent)
	var owner:=Owner.new(); root.add_child(owner); owner.configure(parent,catalog,"",text); owner.set_process(false); owner.icons.set_process(false)
	var commands: Array=[]; owner.request.connect(func(value): commands.append(value.duplicate(true)))
	var actor:={"id":1,"objectType":5,"replicated":{"name":{"text":"Native inventory test"}},"inventoryStats":{"field70":12,"field28c":149},"playerState":{"combat":{"field898":27,"armorClass":13}}}
	var item: Dictionary=armor.item.duplicate(true); item.name={"text":"Authored armor"}; item.stackSize=1
	var equipped:={"id":11,"objectType":6,"item":item,"inventoryLocation":{"ownerId":1,"channel":"I","slot":2}}
	var later_item:={"id":12,"objectType":6,"item":flat.item.duplicate(true),"inventoryLocation":{"ownerId":1,"channel":"R","x":0,"y":6}}
	var raw:={"inventories":[["I",{"entries":[{"id":11,"slot":2}]}],["R",{"entries":[{"id":12,"x":0,"y":6}]}]],"containers":[]}
	owner.set_world(1,3,1,[actor,equipped,later_item],raw); owner.prewarm_icons()
	check(owner.prewarm_cursor==2 and owner.icons.pending.size()==2,"Closed inventory prewarms equipment and later page item icons")
	owner.ui.open(); owner.refresh()
	check(not owner.ui.visible and owner.ui.items.is_empty(),"Cold first opening waits for the item icon before displaying inventory rows")
	var key:=Cache.digest(var_to_bytes(Plan.new().plan(item,tables,0)))
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8); image.fill(Color.RED); var texture:=ImageTexture.create_from_image(image)
	owner.icons.textures[key]=texture; owner.refresh()
	check(commands[-1].kind=="inventory-open" and owner.ui.items.has(11),"Open native inventory requests real replication and displays server membership")
	check(owner.ui.visible and owner.ui.textures.get(11)==texture,"First visible inventory view already contains its item icon")
	check(not owner.ui.creature_slots and owner.ui.equipment.custom_minimum_size.y==240,"Creature equipment defaults hidden")
	check(owner.ui.state.summary.gold==27 and owner.ui.state.summary.weight==15,"Native replicated gold and rounded decipounds")
	check(owner.ui.install_native_icon(owner.view_serial,11,texture),"Direct Texture2D icon binding")
	check(not owner.ui.install_native_icon(owner.view_serial-1,11,texture),"Retired icon view cannot overwrite current item")
	var before: Dictionary=equipped.duplicate(true)
	owner.ui.operation(11,"unequip"); check(commands[-1].operation=="unequip" and commands[-1].itemId==11,"Native inventory action retains actual item identity")
	check(equipped==before and owner.inventories.I.entries.size()==1,"Sending item action never fabricates authoritative transfer")
	owner.receive({"kind":"inventory-result","itemId":11,"operation":"unequip","success":false}); owner.refresh()
	check(owner.ui.notice.text=="The server rejected that item action.","Server rejection survives ordinary inventory refresh")
	var obsolete:=owner.view_serial
	owner.set_world(2,4,1,[actor,equipped,later_item],raw); owner.input_request({"kind":"inventory-action","viewId":obsolete,"entryId":11,"operation":"drop"})
	check(commands[-1].operation=="unequip" and owner.stats.stale_input>0,"Old area view cannot send an item command")
	owner.close(); check(owner.icons.assets.running.is_empty() and owner.icons.assets.pending.is_empty(),"Native icon work drains at ownership retirement")
	owner.free(); parent.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"passed":failures.is_empty(),"checks":checks,"failures":failures,"icon_cases":oracle.cases.size(),"gpu_verified":false,"live_server_verified":false,"scope":"Native original-table icon planning/selection/palette pixels and authored inventory ownership/UI commands. GPU icon rendering and server item transfer require separate live checks."},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
