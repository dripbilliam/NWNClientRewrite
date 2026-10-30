extends SceneTree
const Loading=preload("res://systems/native_loading_screen.gd")
const Session=preload("res://native_session_world.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	var art_report: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	root.size=Vector2i(1280,800); var screen:=Loading.new(); root.add_child(screen); screen.begin(1,"Authored area")
	check(screen.blocks_input() and screen.veil.visible,"Loading overlay hides world and captures input")
	for mask in 7:
		screen.advance(1,{"terrain":bool(mask&1),"player":bool(mask&2),"camera":bool(mask&4),"tiles":2,"total_tiles":2})
		check(screen.active and screen.veil.visible,"A missing readiness milestone keeps the overlay: "+str(mask))
	screen.advance(0,{"terrain":true,"player":true,"camera":true}); check(screen.active,"A stale area cannot release the current loading screen")
	var key:=InputEventKey.new(); key.pressed=true; key.keycode=KEY_L; key.ctrl_pressed=true; key.shift_pressed=true; root.push_input(key,true)
	check(screen.active and screen.dismissed and not screen.veil.visible and not screen.blocks_input(),"Ctrl+Shift+L dismisses only the presentation gate early")
	check(screen.milestones.player==true and screen.milestones.terrain==false,"Early dismissal does not fabricate missing world readiness")
	screen.advance(1,{"terrain":true,"player":true,"camera":true,"tiles":2,"total_tiles":2}); check(not screen.active and screen.stats.completed==1,"Background loading still completes after early dismissal")
	screen.begin(2,"Second area"); check(not screen.dismissed and screen.blocks_input(),"The next area restores the loading screen")
	screen.advance(2,{"terrain":true,"player":true,"camera":false,"tiles":2,"total_tiles":2}); check(screen.active,"Camera anchoring is required before automatic reveal")
	screen.advance(2,{"terrain":true,"player":true,"camera":true,"tiles":2,"total_tiles":2}); check(not screen.active and not screen.veil.visible,"All milestones automatically reveal the world")
	screen.begin(3,"Rejected area"); screen.advance(3,{"terrain":false,"player":false,"camera":false,"errors":["Authored tile failure"]})
	check(screen.active and screen.error.contains("tile failure") and screen.details.text.contains("tile failure"),"Required-asset failures remain explicit instead of silently waiting")
	var back:=false; screen.back_requested.connect(func():set_meta("back",true)); screen.back.pressed.emit(); back=has_meta("back"); check(back,"Failed loading offers a connected return action")
	screen.reset(); check(not screen.active and screen.epoch==-1,"Reset retires the prior loading gate")
	if args.has("install"):
		var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original loading art catalog mounts read-only")
		var ui:=Gameplay.new(); root.add_child(ui); ui.configure(catalog,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg"); screen.configure(ui); screen.begin(4,"Prelude",{"loadingScreen":2})
		var deadline:=Time.get_ticks_msec()+30000
		while (screen.table.is_empty() or screen.table_job>=0 or screen.image.texture==null) and Time.get_ticks_msec()<deadline:
			if screen.table_job<0 and screen.art_key.is_empty(): break
			await process_frame
		check(not screen.table.is_empty() and screen.image.texture!=null,"The server-selected original loadscreens row resolves to native artwork")
		art_report={"resource":screen.art_resource,"key":screen.art_key,"model_exists":catalog.has_resource("pnl_loadscreen",2002),"model_names":catalog.resource_names(2002).filter(func(name):return str(name).contains("load")),"model_stats":ui.desktop.art.models.snapshot(),"failed":ui.desktop.art.failed.keys()}
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(str(args.report)+".png")
		screen.begin(5,"Random area",{"loadingScreen":0})
		check(screen.chosen_row>=2 and screen.chosen_row<screen.table.orderedRows.size(),"Native random row zero chooses a physical artwork row two or later")
		screen.begin(6,"Custom text area",{"loadingScreen":1})
		check(screen.art_resource=="ls_load","Custom-text row one uses the explicit normal artwork fallback")
		screen.reset(); ui.close(); ui.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"loading":screen.snapshot(),"art":art_report,"network":false,"scope":"Native loading milestone/input/error/area ownership and original active art; live protocol acceptance separate"}
	screen.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); quit(0 if failures.is_empty() else 1)
