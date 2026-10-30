extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Owner=preload("res://systems/native_inventory.gd")
const UiSkin=preload("res://systems/native_ui_skin.gd")
var checks:=0
var failures: Array=[]
var requests: Array=[]
var additional_evidence: Dictionary={}
func additional_checks(_owner,_output: String,_fixture: Dictionary) -> void: pass
func parent_surface() -> Node: return root
func event_surface() -> Viewport: return root
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label)
	return value
func wait_for(predicate: Callable) -> bool:
	var until:=Time.get_ticks_msec()+60000
	while not predicate.call() and Time.get_ticks_msec()<until: await process_frame
	return predicate.call()
func click(point: Vector2,button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=button; event.pressed=down; event_surface().push_input(event,true); await process_frame
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1424,921)
	var original:=ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")
	var catalog:=Catalog.new(); check(catalog.mount_install(original),"Original inventory catalog mounts read-only")
	var text:=Text.new(); check(text.base.open_file(original.path_join("lang/en/data/dialog.tlk")),"Original inventory labels resolve native TLK")
	for name in ["baseitems","capart","parts_robe","cloakmodel","iprp_spells","encumbrance"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2017); var parser:=Table.new(); text.tables[name]=parser.parse(Binary.new(bytes).text(0,bytes.size())); check(parser.failure.is_empty(),"Native inventory table "+name)
	var parent:=Control.new(); parent_surface().add_child(parent); parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); parent.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var skin:=UiSkin.new(); root.add_child(skin); skin.configure(catalog,ProjectSettings.globalize_path("res://.cache/native-inventory-equipment-ui"))
	var owner:=Owner.new(); root.add_child(owner); owner.configure(parent,catalog,ProjectSettings.globalize_path("res://.cache/native-inventory-equipment-ui"),text,output+".layout.cfg"); owner.request.connect(func(message):requests.append(message.duplicate(true)))
	check(await wait_for(func():return skin.announced),"Original fonts finish native preparation"); parent.theme=skin.theme()
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-item-icon-oracle-v1.json"))
	var armor: Dictionary=oracle.cases.filter(func(c):return not c.error and int(c.gender)==0 and c.plan.get("kind","")=="armor")[0]
	var weapon: Dictionary=oracle.cases.filter(func(c):return not c.error and c.plan.get("kind","")=="flat")[0]
	var armor_item: Dictionary=armor.item.duplicate(true); armor_item.name={"text":"Original armor"}; armor_item.stackSize=1
	var weapon_item: Dictionary=weapon.item.duplicate(true); weapon_item.name={"text":"Original weapon"}; weapon_item.stackSize=1
	var actor:={"id":1,"objectType":5,"appearance":{"gender":0},"replicated":{"name":{"text":"Native equipment"}},"inventoryStats":{"field70":12,"field28c":149},"playerState":{"combat":{"field898":27,"armorClass":19}}}
	var equipped:={"id":11,"objectType":6,"item":armor_item,"inventoryLocation":{"ownerId":1,"channel":"I","slot":2}}
	var held:={"id":12,"objectType":6,"item":weapon_item,"inventoryLocation":{"ownerId":1,"channel":"I","slot":16}}
	var packed:={"id":13,"objectType":6,"item":weapon_item.duplicate(true),"inventoryLocation":{"ownerId":1,"channel":"R","x":0,"y":0}}
	var raw:={"inventories":[["I",{"entries":[{"id":11,"slot":2},{"id":12,"slot":16}]}],["R",{"entries":[{"id":13,"x":0,"y":0}]}]],"containers":[]}
	owner.set_world(1,3,1,[actor,equipped,held,packed],raw); owner.ui.open(); owner.refresh()
	check(await wait_for(func():return owner.equipment_skin.layout_ready and owner.frame_skin.layout_ready and owner.ui.buttons.has(11) and owner.ui.buttons[11].image.texture!=null and owner.ui.buttons[12].image.texture!=null and owner.equipment_skin.art.waiting.is_empty() and owner.equipment_skin.art.models.pending.is_empty() and not owner.equipment_skin.art.models.active),"Original box meshes, empty-slot icon models and real item icons prepare natively")
	var equipment=owner.equipment_skin
	check(equipment.failure.is_empty() and equipment.art.failed.is_empty(),"No missing original equipment artwork")
	check(not owner.ui.creature_slots and owner.ui.equipment.custom_minimum_size.y==198 and equipment.background.get_child_count()==14,"Default equipment uses fourteen original boxes with creature slots hidden")
	check(owner.ui.buttons[11].size.distance_to(Vector2(99,130))<0.001,"Equipped armor occupies its original GUI box")
	check((owner.ui.buttons[11].image.position+owner.ui.buttons[11].image.size*0.5-owner.ui.buttons[11].native_icon_center).length()<0.001,"Actual armor texture centers on the model icon hook")
	var empty: Array=owner.ui.equipment.get_children().filter(func(node):return node is Button and node.row.is_empty())
	check(empty.size()==12 and empty.all(func(button):return button.image.texture!=null),"All empty equipment slots display original icons")
	var ring_one: Texture2D=empty.filter(func(button):return button.slot==128)[0].image.texture
	var ring_two: Texture2D=empty.filter(func(button):return button.slot==256)[0].image.texture
	var sling: Texture2D=empty.filter(func(button):return button.slot==4096)[0].image.texture
	check(ring_one==ring_two and ring_one!=sling,"Identical original icon overrides share a raster while same-size distinct icons remain isolated")
	check(owner.ui.buttons[11].get_theme_stylebox("normal") is StyleBoxEmpty,"Original slot frame remains visible behind the item")
	await click(owner.ui.buttons[11].get_global_rect().get_center())
	check(owner.ui.selected==11,"Actual pointer selects the authoritative equipped item")
	await click(owner.ui.buttons[11].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(owner.item_context.wheel.active and owner.item_context.wheel.stage.visible,"Original-slot right click opens the original native item wheel"); owner.item_context.cancel()
	var before:=equipped.duplicate(true); owner.ui.operation(11,"unequip")
	check(requests.back().kind=="item-action" and requests.back().itemId==11 and requests.back().operation=="unequip" and equipped==before,"Equipment action keeps actual item identity and never predicts a transfer")
	owner.receive({"kind":"inventory-result","itemId":11,"operation":"unequip","success":false}); owner.refresh()
	owner.ui.creature_slots=true; owner.ui.render(); await process_frame
	check(owner.ui.equipment.custom_minimum_size.y==278 and owner.ui.equipment.get_children().filter(func(node):return node is Button).size()==18,"Opt-in creature slots append below the native layout")
	owner.ui.creature_slots=false; owner.ui.render()
	check(await wait_for(func():return equipment.art.waiting.is_empty()),"Rebuilds finish without stale icon bindings")
	check(equipment.background.get_child_count()==14,"View rebuilds retain one original frame set")
	await additional_checks(owner,output,{"actor":actor,"equipped":equipped,"held":held,"packed":packed,"weapon_item":weapon_item,"raw":raw})
	for frame in 3: await process_frame
	var image:=root.get_texture().get_image(); image.save_png(output.trim_suffix(".json")+".png")
	var state: Dictionary=equipment.snapshot(); owner.close()
	check(equipment.assets.running.is_empty() and equipment.assets.pending.is_empty() and equipment.art.models.assets.running.is_empty(),"Retirement drains native equipment/icon workers")
	owner.free(); skin.close(); skin.free(); parent.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"equipment":state,"additional":additional_evidence,"scope":"Original GUI/MDL/icon artwork with actual native pointer selection, item menu, authored typed actions, rebuilds and worker retirement; additional frame scope is reported separately. Live server transfer remains separate acceptance."},"\t")); file.close()
	print("NATIVE_INVENTORY_EQUIPMENT_UI ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
