extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Sources=preload("res://systems/native_data/item_icon_sources.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Owner=preload("res://systems/native_inventory.gd")
const Plan=preload("res://systems/native_data/item_icon.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var options: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: options[pair[0]]=pair[1]
	if not options.has_all(["install","oracle","report"]) or FileAccess.file_exists(options.report): quit(2); return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	var primary:=DisplayServer.get_primary_screen()
	for screen in DisplayServer.get_screen_count():
		if screen!=primary:
			root.current_screen=screen; root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80); break
	root.size=Vector2i(1100,850)
	var catalog:=Catalog.new()
	check(catalog.mount_install(str(options.install)),"Installed original catalog")
	check(catalog.mount_erf(str(options.install).path_join("data/nwm/Prelude.nwm"),100000000),"Original Prelude icon templates")
	var sources: Dictionary=Sources.preload_all(catalog)
	check(sources.failures.is_empty() and sources.completed>5000,"All original item icon source bytes resident")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(options.oracle)))
	var tables: Dictionary={}
	for name in ["baseitems","capart","parts_robe","cloakmodel","iprp_spells","encumbrance"]:
		var parser:=Table.new(); tables[name]=parser.parse(catalog.get_resource(name,2017).get_string_from_ascii())
		check(parser.failure.is_empty(),"Original item table "+name)
	var armor: Dictionary={}; var flat: Dictionary={}
	for row in oracle.cases:
		if row.get("error",false): continue
		if str(row.get("selected",{}).get("kind",""))=="armor" and armor.is_empty(): armor=row
		if str(row.get("selected",{}).get("kind",""))=="flat" and flat.is_empty(): flat=row
	check(not armor.is_empty() and not flat.is_empty(),"Original armor and flat item cases")
	if armor.is_empty() or flat.is_empty(): quit(1); return
	var text:=Text.new(); text.tables=tables
	var surface:=Control.new(); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(surface)
	var owner:=Owner.new(); root.add_child(owner); owner.configure(surface,catalog,"",text); owner.set_process(false)
	var actor:={"id":1,"objectType":5,"replicated":{"name":{"text":"Original icon test"}},"inventoryStats":{"field70":12,"field28c":149},"playerState":{"combat":{"field898":27,"armorClass":13}},"appearance":{"gender":0}}
	var equipped:={"id":11,"objectType":6,"item":armor.item.duplicate(true),"inventoryLocation":{"ownerId":1,"channel":"I","slot":2}}
	var later:={"id":12,"objectType":6,"item":flat.item.duplicate(true),"inventoryLocation":{"ownerId":1,"channel":"R","x":0,"y":6}}
	var raw:={"inventories":[["I",{"entries":[{"id":11,"slot":2}]}],["R",{"entries":[{"id":12,"x":0,"y":6}]}]],"containers":[]}
	owner.set_world(1,3,1,[actor,equipped,later],raw); owner.prewarm_icons()
	var armor_key:=Cache.digest(var_to_bytes(Plan.new().plan(equipped.item,tables,0)))
	var flat_key:=Cache.digest(var_to_bytes(Plan.new().plan(later.item,tables,0)))
	var deadline:=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline and (not owner.icons.textures.has(armor_key) or not owner.icons.textures.has(flat_key)): await process_frame
	check(owner.icons.textures.has(armor_key) and owner.icons.textures.has(flat_key),"Real original armor and later-page flat GPU icons are prepared before opening")
	var requests_before:=int(owner.icons.stats.requested)
	owner.ui.open(); owner.refresh()
	check(owner.ui.visible and owner.ui.items.has(11) and owner.ui.textures.get(11)==owner.icons.textures.get(armor_key),"First visible inventory frame has its original armor icon")
	owner.page=1; owner.signature=""; owner.refresh()
	check(owner.ui.textures.get(12)==owner.icons.textures.get(flat_key),"Later-page icon is resident at first page publication")
	owner.ui.close_inventory(); owner.ui.open(); owner.refresh()
	check(owner.ui.visible and int(owner.icons.stats.requested)==requests_before,"Reopening inventory makes no new icon asset requests")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"sources":sources,"icons":owner.icons.snapshot(),"owner":owner.snapshot(),"scope":"Installed original armor and flat item GPU images, closed-inventory prewarm, first visible view, later page and reopen. No live Arelith or FPS measurement."}
	owner.close(); owner.free(); surface.free(); text.close(); await process_frame
	var file:=FileAccess.open(options.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
