extends "res://native_live_world.gd"
# Suppress launcher startup. Actual Root anchor -> Gameplay -> HUD -> Plate;
# controlled Node3D/head metadata, actual installed dialog font, no pixels.
const Plate=preload("res://systems/native_nameplate.gd")
const NativeHud=preload("res://systems/native_hud.gd")
const PopupRegistry=preload("res://systems/native_overhead_popup_registry.gd")
const NativeFonts=preload("res://systems/native_bitmap_fonts.gd")
const PopupResources=preload("res://systems/native_nameplate_resources.gd")
const GuiProjection=preload("res://systems/native_data/gui_projection.gd")
const SourceEvidence="res://reports/native-overhead-chat-lifecycle-anchor-v3.json"
const SourceSha="ab7b65431509e97e782e7bf4a67ef096cfc71720cd5d2f9816a122444d9e4ad1"
class PublicationWorld extends Node3D:
	var area_id:=91
	var closed:=false
	var retiring:=false
	var desired: Dictionary={}
	var instances: Dictionary={}
class SelectionProbe extends RefCounted:
	var entities:={42:{"name":"Inspected source","type":5,"eligible":true,"color":"#8080ff"}}
	var aabb_reads:=0
	var inspection_point:=Vector3.ZERO
	func register_native(_id: int,_row: Dictionary,_instance)->bool:return false
	func nameplate_position(_id: int,_camera: Vector3)->Vector3:aabb_reads+=1;return inspection_point
class Desktop extends Node:
	var art
	var state:={"players":[]}
	func close()->void:pass
class Inventory extends Node:
	var frame_skin
	func close()->void:pass
class FrameSkin extends RefCounted:
	var fonts
class RasterArt extends Node:
	var image: Texture2D
	func bind(target: Object,_name: String)->void:target.texture=image
	func unbind(_target: Object)->void:pass
	func portrait_resource(name: String)->String:return name
var checks:=0
var failures: Array=[]
var projection_samples: Array=[]
var visual_connection: Variant=3
var callback_reads: Array=[]
func _initialize()->void:run_proof.call_deferred()
func native_text_connection()->Variant:return visual_connection
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func frame_wait(count: int=2)->void:
	for _index in count:await process_frame
func wait_layout(plate: Control)->bool:
	var deadline:=Time.get_ticks_msec()+15000
	while not plate.layout_ready and Time.get_ticks_msec()<deadline:await process_frame
	return plate.layout_ready
func actor()->Dictionary:return {"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13,"replicated":{"name":{"text":"Native hover caption"},"portraitRef":"","reaction":1,"damageLevel":0}}
func run_proof()->void:
	var output:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--install="):install=arg.trim_prefix("--install=")
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output):quit(2);return
	root.size=Vector2i(800,600);epoch=7
	check(FileAccess.get_sha256(SourceEvidence)==SourceSha,"Unchanged original lifecycle/anchor source dossier is pinned (766ea0/6e9820 no cull/clamp)")
	catalog=preload("res://systems/native_data/resource_catalog.gd").new();check(catalog.mount_install(install),"Actual installed native font catalog opens read-only")
	var fonts:=NativeFonts.new();root.add_child(fonts);fonts.configure(catalog,output.get_base_dir().path_join("fonts"))
	var resources:=PopupResources.new();root.add_child(resources);resources.configure(catalog,output.get_base_dir().path_join("popups"))
	var art:=RasterArt.new();root.add_child(art);art.image=ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_RGBA8))
	var viewport:=Rect2(0,0,800,600)
	var plate:=Plate.new();root.add_child(plate);plate.configure(art,fonts,resources);plate.set_popup_preferences(1,Plate.FONT);plate.set_content({"available":true,"creature":false,"portrait":"","caption":{"text":"Native fractional coordinates","spans":[]},"color":Color.WHITE})
	check(await wait_layout(plate) and plate.caption.get_meta("native_font_applied","")==Plate.FONT,"Actual Plate prepares and binds installed Default dialog font")
	var cases: Array=[
		[Vector2(-10,-20),Vector2(-9,-20)],
		[Vector2(-10.25,-20.5),Vector2(-9,-21)],
		[Vector2(-0.5,-0.5),Vector2(0,-1)],
		[Vector2(-0.6,0.6),Vector2(0,1)],
		[Vector2(10.5,20.5),Vector2(11,20)],
		[Vector2(1400.125,1500.125),Vector2(1400,1499)],
		[Vector2(-900.875,-600.75),Vector2(-900,-601)]]
	for index in cases.size():
		var test: Array=cases[index];plate.place(test[0],viewport,true)
		check(plate.visible and plate.is_visible_in_tree() and plate.position+Vector2(plate.size.x*0.5,plate.size.y)==test[1],"Actual native Plate rounds once in GUI-up without clipping/clamping: "+str(index))
		projection_samples.append({"raw":[test[0].x,test[0].y],"screen":[test[1].x,test[1].y]})
	plate.place(Vector2(INF,0),viewport,true);check(not plate.visible,"Malformed nonfinite native projection never publishes a view")
	plate.place(Vector2(-10,-20),viewport);check(not plate.visible,"Explicit legacy two-argument inspection path retains its separate viewport containment")
	plate.close();plate.queue_free()
	world=PublicationWorld.new();root.add_child(world);registry=SelectionProbe.new()
	camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,0,5);camera.look_at(Vector3.ZERO);camera.make_current()
	gameplay_ui=GameplayUi.new();root.add_child(gameplay_ui);gameplay_ui.set_process(false);gameplay_ui.generation=7;gameplay_ui.area_id=91;gameplay_ui.controlled_id=42;gameplay_ui.popup_preferences={"mode":1,"largeFont":false}
	gameplay_ui.native_connection_query=func():return visual_connection
	gameplay_ui.overhead_anchor_query=native_text_anchor
	var source:=actor();gameplay_ui.text.objects={42:source};world.desired={42:{"object":source}}
	var desktop:=Desktop.new();gameplay_ui.add_child(desktop);desktop.art=art;gameplay_ui.desktop=desktop
	var inventory:=Inventory.new();gameplay_ui.add_child(inventory);inventory.frame_skin=FrameSkin.new();inventory.frame_skin.fonts=fonts;gameplay_ui.inventory=inventory;gameplay_ui.overhead_popup_source=resources
	var popups:=PopupRegistry.new();gameplay_ui.add_child(popups);popups.automatic=false;popups.configure(gameplay_ui.overhead_context,gameplay_ui.overhead_source,gameplay_ui.popup_settings,gameplay_ui.popup_name_caption,gameplay_ui.popup_restoration);gameplay_ui.overhead_popup_registry=popups
	hud=NativeHud.new();root.add_child(hud);hud.registry=registry;hud.camera=camera;hud.root=Control.new();hud.add_child(hud.root);hud.nameplate_root=Control.new();hud.root.add_child(hud.nameplate_root);hud.bind_gameplay(gameplay_ui)
	var instance:=Node3D.new();world.add_child(instance);instance.set_meta("native_nameplate_height",1.8);world.instances[42]=instance;_profile_instance_ready(42,source,instance)
	check(gameplay_ui.overhead_anchor_query.get_object()==self and gameplay_ui.overhead_anchor_query.get_method()=="native_text_anchor" and instance.get_meta("native_speech_identity",[])==[42,8,13],"Actual HUD projection reader binds Gameplay wrapper to current Root native_text_anchor with real source stamp")
	hud.labels([42],42);var hover: Control=hud.nameplates[42];await wait_layout(hover);hud.labels([42],42)
	var before: int=registry.aabb_reads;var anchor:=native_text_anchor(42,[42,8,13],[3,7,91]);var mapped:=GuiProjection.screen_down(anchor.screen,600)
	check(anchor.ready and hover.visible and hover.position+Vector2(hover.size.x*0.5,hover.size.y)==mapped.screen and registry.aabb_reads==0,"Actual Root head anchor reaches real HUD/Plate without interaction AABB lookup")
	instance.position=Vector3(100,0,0);anchor=native_text_anchor(42,[42,8,13],[3,7,91]);mapped=GuiProjection.screen_down(anchor.screen,600);hud.labels([42],42)
	check(anchor.ready and not viewport.has_point(anchor.screen) and hover.visible and hover.position+Vector2(hover.size.x*0.5,hover.size.y)==mapped.screen and registry.aabb_reads==before,"Offscreen actual native head projection remains visible in Canvas state without footprint clamping")
	instance.position=Vector3(0,0,15);anchor=native_text_anchor(42,[42,8,13],[3,7,91]);hud.labels([42],42)
	check(anchor.ready and camera.is_position_behind(anchor.point) and hover.visible and registry.aabb_reads==before,"Behind-camera native head is not rejected by HUD's inspection policy")
	# Exact fractional adapter boundary: HUD must forward the raw point.
	gameplay_ui.overhead_anchor_query=func(id,witness,scope):
		callback_reads.append([id,witness.duplicate(),scope.duplicate()]);return {"ready":true,"screen":Vector2(-10.25,-20.5)}
	hud.labels([42],42)
	check(hover.visible and hover.position+Vector2(hover.size.x*0.5,hover.size.y)==Vector2(-9,-21) and callback_reads[-1]==[42,[42,8,13],[3,7,91]],"Actual HUD preserves finite raw fractional point, witness and scope for exactly one Plate truncation")
	gameplay_ui.overhead_anchor_query=func(_id,_witness,_scope):return {"ready":false}
	hud.labels([42],42);check(not hover.visible and registry.aabb_reads==before,"Admitted but pending native anchor never falls back to interaction AABB")
	gameplay_ui.overhead_anchor_query=Callable();hud.labels([42],42)
	check(not hover.visible and registry.aabb_reads==before,"Admitted missing native callback remains unavailable rather than borrowing debug placement")
	gameplay_ui.generation=-1;hud.labels([42],42);check(not hover.visible and registry.aabb_reads==before,"Admitted pending generation cannot trigger inspection fallback")
	gameplay_ui.generation=7;gameplay_ui.area_id=-1;hud.labels([42],42);check(not hover.visible and registry.aabb_reads==before,"Admitted pending area cannot trigger inspection fallback")
	gameplay_ui.area_id=91;visual_connection="pending";hud.labels([42],42);check(not hover.visible and registry.aabb_reads==before,"Non-null malformed native connection never counts as explicit offline absence")
	visual_connection=3;gameplay_ui.overhead_anchor_query=native_text_anchor;source.clientKnownLifetime=14;hud.labels([42],42)
	check(not hover.visible and registry.aabb_reads==before,"Stale visual head stamp cannot borrow a current reused raw source or inspection AABB")
	source.clientKnownLifetime=13;gameplay_ui.native_connection_query=func():return null
	registry.inspection_point=Vector3.ZERO;hud.labels([42],42)
	check(hover.visible and registry.aabb_reads==before+1 and hover.position.x>=0 and hover.position.y>=0,"Only explicit no-admitted-connection uses the preserved inspection fallback")
	registry.inspection_point=Vector3(100,0,0);hud.labels([42],42);check(not hover.visible and registry.aabb_reads==before+2,"Offline/debug fallback retains its explicitly limited old offscreen cull")
	hud.clear_nameplates();hud.release_nameplate_source();hud.queue_free();hud=null;gameplay_ui.close();gameplay_ui.queue_free();world.queue_free();camera.queue_free();resources.queue_free();fonts.close();fonts.queue_free();art.queue_free();await frame_wait(4)
	gameplay_ui=null;world=null;camera=null;registry=null;render_pool.clear();catalog=null
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":projection_samples,"scope":"Actual NativeRoot anchor -> Gameplay -> HUD -> actual Plate and installed font; authored canonical source, controlled Node3D/head metadata, real Camera and explicit raw fractional callback supplement. Native negative/offscreen/behind projection and admitted pending/stale fences; explicit separate offline inspection fallback. No live server/model, original lower pixels, GPU, keys/profiles/native builds or user processes."}));file.close();quit(0 if failures.is_empty() else 1)
