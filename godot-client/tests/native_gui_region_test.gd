extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Region=preload("res://systems/native_data/gui_render_region.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
	return value
func wait_for(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func picture(texture: Texture2D,position: Vector2) -> void:
	var image:=TextureRect.new(); root.add_child(image); image.texture=texture; image.position=position; image.size=texture.get_size(); image.mouse_filter=Control.MOUSE_FILTER_IGNORE
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,700); var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original GUI region resources mount read-only")
	var art:=Art.new(); root.add_child(art); art.configure(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var region:=Rect2(10,5,200,40); var target:=TextureRect.new(); root.add_child(target); target.position=Vector2(30,110)
	check(Icons.model_key("PNL_CHRSHT","")=="gui:pnl_chrsht:","Existing whole-model GUI keys stay unchanged")
	check(Icons.model_key("pnl_chrsht","",{},0,"",[],region)!=Icons.model_key("pnl_chrsht",""),"A GUI render region cannot alias the existing whole-model image")
	check(Icons.model_key("pnl_chrsht","",{},0,"",[],region)!=Icons.model_key("pnl_chrsht","",{},0,"",[],Rect2(11,5,200,40)),"Different source positions retain distinct region identities")
	var full:=art.request_model("pnl_chrsht",""); art.bind(target,"pnl_chrsht","texture",true,"",false,{},region)
	var cropped:=Icons.model_key("pnl_chrsht","",{},0,"",[],region)
	check(await wait_for(func():return art.textures.has(full) and target.texture!=null or art.failed.has(full) or art.failed.has(cropped)),"Original whole/cropped GUI preparation and native publication finish")
	var diagnostic: Dictionary={}
	if check(art.textures.has(full) and target.texture!=null and art.failed.is_empty(),"The actual native art binding publishes a cropped model without fallback"):
		var source: Image=art.textures[full].get_image(); var image: Image=target.texture.get_image()
		check(source.get_size()==Vector2i(360,59) and image.get_size()==Vector2i(200,40),"GUI viewport dimensions follow the requested region without stretching the model")
		check(not target.flip_v and art.bounds[cropped].pixels_per_unit==100.0,"Bounded original GUI art preserves its orientation and native pixel density")
		var mismatch:=0; var max_delta:=0
		for y in range(2,38):
			for x in range(2,198):
				var a: Color=source.get_pixel(x+10,y+5); var b: Color=image.get_pixel(x,y)
				var delta:=maxi(maxi(absi(roundi(a.r*255)-roundi(b.r*255)),absi(roundi(a.g*255)-roundi(b.g*255))),maxi(absi(roundi(a.b*255)-roundi(b.b*255)),absi(roundi(a.a*255)-roundi(b.a*255))))
				max_delta=maxi(max_delta,delta)
				if delta>2: mismatch+=1
		check(mismatch==0,"Cropped original artwork matches the same region of a full native render within two byte values of GPU precision")
		diagnostic={"compared_pixels":196*36,"mismatched_pixels":mismatch,"maximum_channel_delta":max_delta,"region_bounds":art.bounds[cropped]}
		picture(art.textures[full],Vector2(30,30)); target.size=target.texture.get_size()
	var body:=art.request_model("pnl_chrsht_char","",{},0,"gui_boxes_ingame",[],Rect2(0,0,360,409))
	check(await wait_for(func():return art.textures.has(body) or art.failed.has(body)),"Tall original character-page art prepares through the bounded GUI viewport")
	if check(art.textures.has(body),"Tall character-page art publishes without an oversized whole-model fallback"):
		check(art.textures[body].get_size()==Vector2(360,409) and art.bounds[body].pixels_per_unit==100.0,"The visible character page renders at360 by409 original pixels")
		check(absf(float(art.bounds[body].source_geometry_max[1])-float(art.bounds[body].source_geometry_min[1]))>30,"Region rendering retains the original tall source geometry rather than resizing its vertices")
		picture(art.textures[body],Vector2(460,90))
	var outside:=art.request_model("pnl_chrsht","",{},0,"",[],Rect2(-10,0,20,59))
	check(await wait_for(func():return art.textures.has(outside) or art.failed.has(outside)),"A source region outside model bounds still finishes its native draw")
	if art.textures.has(outside): check(art.textures[outside].get_image().get_pixel(4,5).a==0,"Region space outside authored geometry stays transparent")
	check(not Region.valid(Rect2(0,0,-1,20)) and not Region.valid(Rect2(0,0,5000,20)) and not Region.valid(Rect2(0,0,NAN,20)),"Invalid or oversized GUI view regions fail explicitly")
	var pending_before: int=art.models.pending.size(); check(art.models.request_model("pnl_chrsht","",{},0,"",[],Rect2(0,0,-1,20)).is_empty() and art.models.pending.size()==pending_before,"Invalid regions do not create resource or render jobs")
	var reused:=art.request_model("pnl_chrsht","",{},0,"",[],region); check(reused==cropped and not art.models.pending.has(reused),"Repeated GUI regions reuse their completed native texture")
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")
	art.models.set_process(false); var late:=art.request_model("pnl_chrsht_char","",{},0,"gui_boxes_ingame",[],Rect2(0,0,360,420))
	if check(await wait_for(func():return not art.models.queue.is_empty()),"A distinct region can reach the real render queue before retirement"):
		art.models._profile_process(0); var model: WeakRef=weakref(art.models.pending_draw.model); art.close()
		check(model.get_ref()==null and not RenderingServer.frame_post_draw.is_connected(art.models.frame_rendered),"Closing a pending region retires its native model and post-draw callback")
		await process_frame; await process_frame
		check(not art.models.active and art.models.assets.running.is_empty() and art.models.assets.pending.is_empty(),"No region owner resumes after close or retains preparation workers")
	else: art.close()
	art.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"publicConnections":0,"scope":"Opt-in native GUI source-region rendering and binding, whole-model compatibility, original artwork coordinate comparison and active-region retirement. No character-sheet window or original-client visual/action parity accepted."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
