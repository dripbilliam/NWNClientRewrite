extends "res://native_session_world.gd"
const Pregame=preload("res://systems/native_pregame_menu.gd")
var checks:=0
var failures: Array=[]
class UiStub:
	extends Node
	var ui_owner
	var closed:=false
	var owner_live_at_close:=false
	func close() -> void:
		owner_live_at_close=not ui_owner.closed
		closed=true

func _initialize() -> void: call_deferred("run_lifecycle")
func check(value: bool,label_text: String) -> void:
	checks+=1
	if not value: failures.append(label_text)
func test_catalog(identity: String):
	var result=Catalog.new()
	result.layers=[{"binding_identity":identity,"entries":{}}]
	result.build_resource_index()
	return result
func run_lifecycle() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	label=Label.new(); root.add_child(label)
	var image:=Image.create(2,2,false,Image.FORMAT_RGBA8); image.fill(Color.RED)
	var texture:=ImageTexture.create_from_image(image)
	var pre_catalog=test_catalog("pregame")
	var server_catalog=test_catalog("server-one")
	var worker_fork=server_catalog.fork()
	check(worker_fork.ui_asset_owner()==null,"A payload-reader fork cannot own or last-release GPU UI images")
	var pre_owner=pre_catalog.ui_asset_owner()
	var server_owner=server_catalog.ui_asset_owner()
	check(pre_owner!=server_owner,"Pregame and server catalogs have separate resident scopes")
	pre_owner.retain("raster","menu",texture)
	server_owner.retain("raster","server",texture)
	var worker_after=server_catalog.fork()
	check(worker_after.ui_asset_owner()==null,"Worker fork after first UI request still cannot retain the GPU owner")
	var pregame:=Pregame.new(); root.add_child(pregame); pregame.catalog=pre_catalog
	var pre_ui:=UiStub.new(); pre_ui.ui_owner=pre_owner; pregame.add_child(pre_ui); pregame.painter=pre_ui
	catalog=server_catalog
	var session_ui:=UiStub.new(); session_ui.ui_owner=server_owner; root.add_child(session_ui); gameplay_ui=session_ui
	reset_session()
	check(session_ui.closed and session_ui.owner_live_at_close and server_owner.closed,"Session reset closes UI before releasing the server image scope")
	check(not pre_owner.closed and pre_owner.lookup("raster","menu").get("texture")==texture,"Server reset does not release independent pregame images")
	check(catalog!=server_catalog and not catalog.ui_asset_owner().closed,"Reconnect begins with a new usable catalog scope")
	var next_catalog=test_catalog("server-two")
	catalog=next_catalog; var next_owner=next_catalog.ui_asset_owner(); next_owner.retain("raster","new-server",texture)
	var next_ui:=UiStub.new(); next_ui.ui_owner=next_owner; root.add_child(next_ui); gameplay_ui=next_ui
	reset_session()
	check(next_ui.closed and next_ui.owner_live_at_close and next_owner.closed and server_owner.closed,"Second connection retires only its own UI scope")
	check(not pre_owner.closed,"Reconnect still leaves pregame scope live")
	pregame.close()
	check(pre_ui.closed and pre_ui.owner_live_at_close and pre_owner.closed,"Pregame closes child painter before releasing its catalog scope")
	check(pre_owner.lookup("raster","menu").is_empty(),"Pregame release drops its retained image")
	worker_fork=null; worker_after=null; pregame.free(); session_ui.free(); next_ui.free()
	label.free(); label=null; catalog=null; render_pool.clear()
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual SessionWorld reset and pregame close ordering with distinct catalog scopes; worker forks cannot retain UI GPU owner. No server, FPS, visual, or all-assets claim."},"  "))
	file.close(); quit(0 if failures.is_empty() else 1)
