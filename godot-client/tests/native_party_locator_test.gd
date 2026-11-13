extends "res://tests/native_party_indicators_test.gd"
const LocatorPolicy=preload("res://systems/native_data/party_locator.gd")
const Quad=preload("res://systems/native_data/gui_quad.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
const Registry=preload("res://systems/entity_registry.gd")
const CameraState=preload("res://systems/game_camera_state.gd")
class WorldUi extends Node:
	var closed:=false
	var presentation_enabled:=true
	var world_camera: Camera3D
	var world_camera_yaw: Callable
	var world_registry
func float_bits(value: float) -> int: return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
func locator_oracle(data: Dictionary) -> void:
	check(data.target==BINARY_SHA and data.times.size()==24 and data.ticks.size()==720,"Pinned original party tick and complete angular GUI clock observations")
	for row in data.times:
		check(float_bits(LocatorPolicy.state_time(float(row.angle),12))==int(row.sample.timeBits),"Unchanged angular GUI sample-time bits "+str(row.angle))
	for row in data.ticks:
		var c: Dictionary=row.case; var point: Variant=Vector2(c.position[0],c.position[1]) if c.present else null
		var actor: Variant=Vector2.ZERO if c.actor else null
		var projected:=LocatorPolicy.decide(bool(c.sameArea),point,actor,float(c.yaw),float(c.cached),bool(c.unknown)); var calls: Array=[]
		for call in row.calls:
			calls.append([call[0],float(call[1])] if call[0]=="angle" else call)
		check(projected.unknown==bool(row.unknown) and same(projected.calls,calls).is_empty(),"Unchanged party tick "+str([c.position,c.yaw,c.sameArea,c.present,c.actor,c.unknown]))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	var observation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); locator_oracle(observation)
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Read-only original catalog")
	var models: Dictionary={}
	for name in Plan.RESOURCES:
		var parser:=Actor.new(); models[name]=parser.parse(catalog.get_resource(name,2002)); check(parser.failure.is_empty(),"Original party resource "+name)
	var definition:=Plan.parse(models); check(str(definition.error).is_empty(),"Original party locator model and Pos hook admitted")
	var source_hash:=Cache.digest(var_to_bytes(models.pb_mbr_pos)); var normal:=Quad.sample(models.pb_mbr_pos,"angle",0); var unknown:=Quad.sample(models.pb_mbr_pos,"angleunknown",0)
	check(str(normal.error).is_empty() and normal.resource=="gui_partylocator" and normal.faces.size()==2 and str(unknown.error).is_empty() and unknown.faces.is_empty(),"Original unknown-area orientation is back-facing; source triangles are culled rather than mirrored")
	check(normal.faces[0].uv==PackedVector2Array([Vector2(0.125,1),Vector2(0.125,0.0000017583399767318),Vector2(0.875,1)]),"Raw original locator UV crop and vertex association are retained")
	var surface:=SubViewport.new(); surface.size=Vector2i(1000,700); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface); surface.notify_mouse_entered()
	var ui_root:=Control.new(); surface.add_child(ui_root); ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var art:=Art.new(); root.add_child(art); art.models=QueuedModels.new(); art.add_child(art.models); art.catalog=RasterCatalog.new(); art.assets=QueuedRasters.new(); art.add_child(art.assets)
	var fonts:=HeadlessFonts.new(); root.add_child(fonts); var painter:=Painter.new(); root.add_child(painter); painter.art=art; painter.fonts=fonts
	var text:=Talk.new(); var rules:=Rules.new(); rules.text=text
	var panel:=Party.new(); ui_root.add_child(panel); panel.setup()
	var frame:=Frame.new(); frame.requested=true; root.add_child(frame); frame.configure(panel,catalog,str(args.report)+".cache",text,painter); frame.models=models; frame.definition=definition; frame.activate()
	var points: Dictionary={43:Vector2(10,0)}; var context:={"area":55,"yaw":0.0,"actor":Vector2.ZERO,"position":func(id):return points.get(id)}; frame.locator_context=func():return context
	var objects:={42:object(42,true,false),43:object(43)}; objects[42].replicated.position=[0,0,0]; objects[43].replicated.position=[10,0,0]
	present(panel,rules,objects,1); await frames(); frame.place(); frame.update_locators()
	var locator=panel.cards[1].get_node("Box/NativeLocator")
	check(locator.visible and locator.position.distance_to(Vector2(49,15))<0.001 and locator.clip=="angle" and locator.faces.size()==2,"Actual native member locator uses original Pos hook and source pose")
	check(float_bits(locator.time)==float_bits(clampf(LocatorPolicy.state_time(-90,12),0,12)),"Actual eastward arrow selects the original camera-relative sample")
	var asset_count: int=art.assets.serial; var model_count: int=art.models.requests.size(); var pose_count: int=locator.poses
	for index in 120: frame.update_locators()
	check(locator.poses==pose_count and art.assets.serial==asset_count and art.models.requests.size()==model_count,"Stationary UI frames reuse geometry and raster without model preparation")
	for index in 120: context.yaw=float(index); frame.update_locators()
	check(locator.poses>pose_count and art.assets.serial==asset_count and art.models.requests.size()==model_count,"Camera movement samples original transforms directly without texture/model jobs")
	objects[43].replicated.areaId=56; present(panel,rules,objects,2); frame.update_locators()
	check(locator.clip=="angleunknown" and locator.faces.is_empty() and bool(locator.get_meta("native_unknown")),"Received area mismatch uses the original hidden/back-facing arrow state")
	pose_count=locator.poses
	for index in 60: context.yaw=float(index); frame.update_locators()
	check(locator.poses==pose_count,"An unchanged other-area state does not keep rebuilding the arrow")
	objects[43].replicated.areaId=55; present(panel,rules,objects,3); context.yaw=45.0; frame.update_locators()
	check(locator.clip=="angle" and locator.faces.size()==2 and not bool(locator.get_meta("native_unknown")),"Returning to the same area restores source directional geometry")
	points.erase(43); frame.update_locators()
	check(float_bits(locator.time)==float_bits(clampf(LocatorPolicy.state_time(-45,12),0,12)),"Missing same-area object follows the original member constructor's cached-bearing default")
	points[43]=Vector2(0,10); context.actor=null; pose_count=locator.poses; frame.update_locators(); check(locator.poses==pose_count,"A missing controlled object does not fabricate a new live bearing")
	context.actor=Vector2.ZERO; context.yaw=0.0
	var card: Control=panel.cards[1]; var old_position:=card.position; card.position.y=-1000; pose_count=locator.poses; frame.update_locators()
	check(not locator.visible and locator.poses==pose_count,"Scrolled-out members do not advance locator geometry")
	card.position=old_position; frame.update_locators(); check(locator.visible,"Visible roster reentry restores its locator")
	var camera:=Camera3D.new(); surface.add_child(camera); camera.position=Vector3(0,10,10); camera.look_at(Vector3.ZERO)
	var ui:=WorldUi.new(); root.add_child(ui); ui.world_camera=camera; ui.world_camera_yaw=func():return 90.0
	var registry:=Registry.new(); surface.add_child(registry); ui.world_registry=registry
	var desktop:=Desktop.new(); desktop.owner_ui=ui; desktop.area_id=55; desktop.actor_id=42; desktop.objects=objects
	var live_context:=desktop.party_locator_context()
	check(live_context.yaw==90.0 and live_context.position.call(43)==Vector2(10,0),"Actual desktop context uses its native camera-yaw owner and received coordinates before visual preparation")
	var instance:=Node3D.new(); surface.add_child(instance); instance.position=Vector3(12,2,-7); registry.native_owners[43]=instance
	check(desktop.party_position(43)==Vector2(12,7),"Desktop locator follows the presented native entity when its model is live")
	objects[43].replicated.areaId=56; check(desktop.party_position(43)==null,"A stale render owner cannot override the received different-area state")
	objects[43].replicated.areaId=55; ui.world_camera_yaw=Callable()
	for yaw in [-170.0,-90.0,0.0,90.0,170.0]:
		var q:=CameraState.quaternion(yaw,45); camera.global_basis=Basis(Quaternion(Vector3.RIGHT,-PI/2)*Quaternion(q[1],q[2],q[3],q[0])); live_context=desktop.party_locator_context()
		check(absf(float(live_context.yaw)-yaw)<0.001,"Fallback camera transform preserves the native coordinate convention "+str(yaw))
	ui.presentation_enabled=false; check(desktop.party_locator_context().is_empty(),"Pregame/loading presentation disables native locator updates")
	ui.presentation_enabled=true; ui.closed=true; check(desktop.party_locator_context().is_empty(),"Retired UI has no live locator context")
	desktop.closed=true; desktop.free(); ui.queue_free(); registry.queue_free(); instance.queue_free()
	var binding:=str(locator.get_instance_id())+":texture"; panel.reset(); check(locator.closed and not art.bindings.has(binding),"Roster retirement releases the live locator's borrowed raster binding")
	var texture:=ImageTexture.create_from_image(Image.create(16,16,false,Image.FORMAT_RGBA8)); art.deliver("gui_partylocator",texture)
	check(locator.texture==null and Cache.digest(var_to_bytes(models.pb_mbr_pos))==source_hash,"Late raster publication cannot restore a retired arrow or mutate the shared model")
	var loading_panel:=Party.new(); ui_root.add_child(loading_panel); loading_panel.setup()
	var loading:=Frame.new(); root.add_child(loading); loading.configure(loading_panel,catalog,str(args.report)+".worker-cache",text,painter); loading.locator_context=func():return context
	present(loading_panel,rules,objects,4)
	var deadline:=Time.get_ticks_msec()+5000
	while not loading.layout_ready and loading.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(loading.layout_ready and loading.failure.is_empty() and loading.models.get("pb_mbr_pos",{}).get("animations",[]).size()==2,"Production party asset requests preserve the locator's original angle clips")
	if loading.layout_ready:
		loading.update_locators(); var worker_locator=loading_panel.cards[1].get_node("Box/NativeLocator")
		check(worker_locator.failure.is_empty() and worker_locator.faces.size()==2,"Actual worker-loaded party member can sample its directional geometry")
	loading.close(); loading.queue_free(); loading_panel.queue_free()
	frame.close(); check(not frame.is_processing(),"Retired party frame stops its continuous locator callback"); panel.queue_free(); frame.queue_free(); painter.queue_free(); art.close(); art.queue_free(); fonts.close(); fonts.queue_free(); surface.queue_free(); text.close(); catalog=null; await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"graphical":false,"publicConnections":0,"scope":"Original party tick/finite atanf and complete angular GUI clock observations; actual source quad/UV/culling, native frame and desktop camera/entity context, scroll/retirement with controlled rasters. No pixels, live server or complete party/UI parity."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); print("NATIVE_PARTY_LOCATOR ",checks," checks, ",failures.size()," failures"); quit(0 if result.success else 1)
