extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Party=preload("res://systems/server_party.gd")
const Frame=preload("res://systems/native_party_frame.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var install:="";var graphical:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="):install=arg.trim_prefix("--install=")
		elif arg=="--graphical":graphical=true
	if install.is_empty():quit(2);return
	if graphical:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		var primary:=DisplayServer.get_primary_screen()
		for screen in DisplayServer.get_screen_count():
			if screen!=primary:
				root.current_screen=screen;root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80);break
		root.size=Vector2i(900,700)
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):quit(3);return
	catalog.build_resource_index()
	var portraits: Array[String]=[]
	for name in catalog.resource_names(3):
		var key:=str(name)
		if key.begins_with("po_") and key.ends_with("s") and not catalog.raster_location(key).is_empty():portraits.append(key)
		if portraits.size()>=2:break
	if portraits.size()<2:quit(4);return
	var painter:=Painter.new();root.add_child(painter);painter.configure_source(catalog,"")
	var art:=Art.new();root.add_child(art);art.configure(catalog,"")
	var text:=Text.new();text.base.open_file(install.path_join("lang/en/data/dialog.tlk"))
	var host:=Control.new();root.add_child(host);host.size=root.size
	var party:=Party.new();host.add_child(party);party.setup()
	var frame:=Frame.new();root.add_child(frame);frame.configure(party,catalog,"",text,painter)
	var actions: Array=[]
	for index in ["map","inventory","journal","character","rest","spells","options","pvp"].size():
		var name: String=["map","inventory","journal","character","rest","spells","options","pvp"][index]
		actions.append({"index":index,"id":name,"label":name,"key":null})
	var self_row:={"entryId":0,"id":11,"self":true,"available":true,"label":"Installed portrait","portraitKey":portraits[0],"health":null,"canLevelUp":false,"indicators":{}}
	party.receive({"kind":"party-view","viewId":1,"actorId":11,"rows":[self_row],"actions":actions})
	art.bind_portrait(party.cards[0].get_node("Box/Portrait/Image"),portraits[0])
	var premature: bool=party.visible and not frame.cohort_snapshot().ready
	var deadline:=Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline and not party.visible and party.art_error.is_empty():await process_frame
	var cohort: Dictionary=frame.cohort_snapshot()
	var shared: Dictionary=catalog.ui_asset_owner().lookup("raster",painter.art.portrait_resource(portraits[0]))
	var first_portrait: Texture2D=party.cards[0].get_node("Box/Portrait/Image").texture
	var success: bool=graphical and not premature and party.visible and party.art_error.is_empty() and cohort.ready and not shared.is_empty() and cohort.images_ready==cohort.images_expected
	success=success and str(party.cards[0].get_meta("portrait_key",""))==portraits[0]
	party.receive({"kind":"party-state","viewId":1,"rows":[{"entryId":0,"health":{"current":10,"maximum":10,"clip":"percentage"},"canLevelUp":false}]})
	var first_health_gated: bool=not party.visible and party.art_pending
	deadline=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline and not party.visible and party.art_error.is_empty():await process_frame
	success=success and first_health_gated and party.visible and frame.cohort_snapshot().ready
	party.receive({"kind":"party-view","viewId":2,"actorId":11,"rows":[self_row],"actions":actions})
	art.bind_portrait(party.cards[0].get_node("Box/Portrait/Image"),portraits[0])
	var cached_visible: bool=party.visible and not party.art_pending
	success=success and cached_visible
	var changed: Dictionary=self_row.duplicate(true);changed.portraitKey=portraits[1]
	party.receive({"kind":"party-view","viewId":3,"actorId":11,"rows":[changed],"actions":actions})
	art.bind_portrait(party.cards[0].get_node("Box/Portrait/Image"),portraits[1])
	var rebind_gated: bool=not party.visible and party.art_pending
	deadline=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline and not party.visible and party.art_error.is_empty():await process_frame
	var second_shared: Dictionary=catalog.ui_asset_owner().lookup("raster",painter.art.portrait_resource(portraits[1]))
	success=success and rebind_gated and party.visible and frame.cohort_snapshot().ready and not second_shared.is_empty()
	var portrait_image: TextureRect=party.cards[0].get_node("Box/Portrait/Image")
	var current_portrait: Texture2D=portrait_image.texture
	portrait_image.texture=first_portrait
	var stale_portrait_rejected: bool=not frame.cohort_snapshot().ready
	portrait_image.texture=current_portrait
	success=success and stale_portrait_rejected and frame.cohort_snapshot().ready
	var missing: Dictionary=self_row.duplicate(true);missing.portraitKey="po_nwn84_absent_s"
	party.receive({"kind":"party-view","viewId":4,"actorId":11,"rows":[missing],"actions":actions})
	art.bind_portrait(party.cards[0].get_node("Box/Portrait/Image"),str(missing.portraitKey))
	deadline=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline and party.art_error.is_empty():await process_frame
	var missing_explicit: bool=party.visible and party.art_notice.visible and party.art_notice.text.contains("po_nwn84_absent_") and not party.scroll.visible and not frame.stage.visible
	success=success and missing_explicit
	print(JSON.stringify({"success":success,"portraits":portraits,"initial_cohort":cohort,"first_health_gated":first_health_gated,"cached_visible":cached_visible,"rebind_gated":rebind_gated,"stale_portrait_rejected":stale_portrait_rejected,"missing_explicit":missing_explicit,"shared_portraits":not shared.is_empty() and not second_shared.is_empty(),"art_error":party.art_error,"frame_failure":frame.failure}))
	party.reset();frame.close();frame.free();party.free();host.free();art.close();art.free();painter.close();painter.free()
	quit(0 if success else 1)
