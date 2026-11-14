extends SceneTree
# Isolated installed-content panel comparison. Run in separate control/candidate
# processes at the same resolution; do not treat it as Arelith FPS acceptance.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Owner=preload("res://systems/native_inventory.gd")
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func percentile(values: Array,fraction: float) -> float:
	if values.is_empty():return 0.0
	return float(values[mini(values.size()-1,roundi(float(values.size()-1)*fraction))])
func run() -> void:
	var options: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	if not options.has_all(["install","oracle","report","backend"]) or FileAccess.file_exists(str(options.report)) or str(options.backend) not in ["retained","legacy"]:quit(2);return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	var primary:=DisplayServer.get_primary_screen()
	for screen in DisplayServer.get_screen_count():
		if screen!=primary:
			root.current_screen=screen;root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80);break
	root.size=Vector2i(1100,850)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var catalog:=Catalog.new()
	if not catalog.mount_install(str(options.install)):failures.append("Installed catalog")
	if not catalog.mount_erf(str(options.install).path_join("data/nwm/Prelude.nwm"),100000000):failures.append("Prelude models")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(options.oracle)))
	var selected: Array=[];var seen: Dictionary={}
	for row in oracle.get("cases",[]):
		if row.get("error",false) or int(row.get("gender",-1))!=0 or int(row.get("plan",{}).get("width",0))!=1 or int(row.get("plan",{}).get("height",0))!=1:continue
		var identity:=JSON.stringify(row.get("selected",{}).get("layers",[]))
		if seen.has(identity):continue
		seen[identity]=true;selected.append(row)
		if selected.size()==12:break
	if selected.size()!=12:failures.append("Twelve distinct installed 1x1 icons")
	var tables: Dictionary={}
	for name in ["baseitems","capart","parts_robe","cloakmodel","iprp_spells","encumbrance"]:
		var parser:=Table.new();tables[name]=parser.parse(catalog.get_resource(name,2017).get_string_from_ascii())
		if not parser.failure.is_empty():failures.append("Original table "+name)
	if not failures.is_empty():finish(options,{"success":false,"failures":failures});return
	var text:=Text.new();text.tables=tables
	var surface:=Control.new();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(surface)
	var owner:=Owner.new();root.add_child(owner);owner.configure(surface,catalog,"",text);owner.set_process(false)
	if owner.retained_item_icons!=(str(options.backend)=="retained"):failures.append("Whole-system backend mismatch")
	var actor:={"id":1,"objectType":5,"replicated":{"name":{"text":"Icon panel benchmark"}},"inventoryStats":{"field70":12,"field28c":149},"playerState":{"combat":{"field898":27,"armorClass":13}},"appearance":{"gender":0}}
	var objects: Array=[actor];var entries: Array=[]
	for index in selected.size():
		var id:=100+index
		objects.append({"id":id,"objectType":6,"item":selected[index].item.duplicate(true),"inventoryLocation":{"ownerId":1,"channel":"R","x":index%8,"y":index/8}})
		entries.append({"id":id,"x":index%8,"y":index/8})
	owner.set_world(1,3,1,objects,{"inventories":[["R",{"entries":entries}]],"containers":[]})
	var started:=Time.get_ticks_msec()
	owner.ui.open();owner.refresh()
	var deadline:=started+120000
	while not owner.ui.visible and Time.get_ticks_msec()<deadline:
		await process_frame;owner.refresh()
	var admitted_ms:=Time.get_ticks_msec()-started
	if not owner.ui.visible:failures.append("Inventory panel admission timed out")
	if owner.ui.buttons.size()!=12:failures.append("Twelve visible item controls")
	if str(options.backend)=="retained" and (not is_instance_valid(owner.ui.scene_host) or owner.ui.scene_host.slots.size()!=12 or not owner.ui.scene_host.presentation_ready()):failures.append("Retained twelve-model draw receipt")
	var intervals: Array=[]
	if failures.is_empty():
		for _i in 90:await RenderingServer.frame_post_draw
		for _i in 300:
			var began:=Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			intervals.append(float(Time.get_ticks_usec()-began)/1000.0)
	intervals.sort()
	var sum:=0.0
	for value in intervals:sum+=float(value)
	var report:={"success":failures.is_empty(),"backend":str(options.backend),"checks":{"items":selected.size(),"controls":owner.ui.buttons.size(),"admitted":owner.ui.visible},"failures":failures,"admission_ms":admitted_ms,"frames":intervals.size(),"mean_ms":sum/float(intervals.size()) if not intervals.is_empty() else 0.0,"p50_ms":percentile(intervals,0.5),"p95_ms":percentile(intervals,0.95),"p99_ms":percentile(intervals,0.99),"min_ms":percentile(intervals,0.0),"max_ms":percentile(intervals,1.0),"icons":owner.snapshot().icons,"scope":"Isolated 1100x850 original installed 12-icon panel, Forward+/Vulkan, VSync off; no world, server, Arelith, or Tracy."}
	owner.close();owner.free();surface.free();text.close();await process_frame
	finish(options,report)
func finish(options: Dictionary,report: Dictionary) -> void:
	var file:=FileAccess.open(str(options.report),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	print(JSON.stringify({"success":report.success,"backend":report.get("backend",""),"failures":report.failures,"mean_ms":report.get("mean_ms",0),"p95_ms":report.get("p95_ms",0)}))
	quit(0 if report.success else 1)
