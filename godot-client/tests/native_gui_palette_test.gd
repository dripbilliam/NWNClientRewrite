extends SceneTree
const Gui=preload("res://systems/native_data/gui_palette_texture.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Raster=preload("res://systems/native_data/texture_data.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Keys=preload("res://systems/native_item_icons.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);print("FAIL: ",message)
func pixels_match(plt:PackedByteArray,pixels:PackedByteArray,row:PackedByteArray)->bool:
	if pixels.size()!=(plt.size()-24)*2:return false
	for pixel in pixels.size()/4:
		var index:int=int(plt[24+pixel*2])*4
		for channel in 4:
			if pixels[pixel*4+channel]!=row[index+channel]:return false
	return true
func run()->void:
	var args:Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed original swatch resources mount read-only")
	var plt:PackedByteArray=catalog.get_resource("gui_cg_color_tmp",6)
	check(Cache.digest(plt)=="711989d37d3c7a20301ef0d7d7286c40836f46cd4d23d8356bb0f52b4af2d90e","Actual one-layer GUI swatch template is pinned")
	var metadata:Dictionary={};var sources:Dictionary={}
	for name in Gui.NAMES.values():
		var bytes:PackedByteArray=catalog.get_resource(name,3);var parser:=Raster.new();metadata[name]=parser.parse(bytes,3);sources[name]=Cache.digest(bytes)
		check(catalog.failure.is_empty() and parser.failure.is_empty(),"Actual palette decodes: "+name)
	var published:=Gui.rows(metadata,sources);check(published.ready and published.rows.size()==528,"All three actual176-row palettes publish distinct packed selectors")
	var identities:Dictionary={}
	for kind in Gui.NAMES:
		for index in [0,2,64,175]:
			var selector:int=(int(kind)<<8)|index;var descriptor:Dictionary={"resource":"gui_cg_color_tmp","palette":[selector]}
			var result:=Gui.prepare(catalog,descriptor)
			check(result.get("ready",false) and result.get("error","").is_empty(),"Packed native selector prepares: "+str(selector))
			if not result.get("ready",false):continue
			check(pixels_match(plt,result.value.mips[0].data,published.rows[selector]),"Every original PLT intensity/alpha samples the selected file/row: "+str(selector))
			check(result.palette_source==sources[Gui.NAMES[kind]] and not identities.has(result.sha256),"Selector/source participates in distinct content identity: "+str(selector));identities[result.sha256]=true
			var explicit:=descriptor.duplicate(true);explicit.palette_row=published.rows[selector];explicit.palette_source=published.sources[selector]
			var active:=Gui.prepare(catalog,explicit)
			check(active.get("ready",false) and active.sha256==result.sha256 and active.value==result.value,"Active detached row and base resource resolve identically: "+str(selector))
	var packed:int=0x0602;var changed:PackedByteArray=published.rows[packed].duplicate()
	for index in changed.size():changed[index]=255 if index%4==3 else (index*7+29)&255
	var override:Dictionary={"resource":"gui_cg_color_tmp","palette":[packed],"palette_row":changed,"palette_source":"a".repeat(64)}
	var first:=Gui.prepare(catalog,override,str(args.report)+".palette-cache");var second:=Gui.prepare(catalog,override,str(args.report)+".palette-cache")
	check(first.get("ready",false) and second.get("cache_hit",false) and first.value==second.value,"Persistent GUI pixels revalidate content and selector")
	check(pixels_match(plt,first.value.mips[0].data,changed),"Active palette override changes actual pixels without reading base palette")
	check(Keys.model_key("ctl_cg_btn_col","up",{"gui_replace01":override})!=Keys.model_key("ctl_cg_btn_col","up",{"gui_replace01":{"resource":"gui_cg_color_tmp","palette":[2]}}),"Rendered model keys distinguish nested selector/active row data")
	var before:PackedByteArray=published.rows[2].duplicate();metadata.pal_skin01.mips[0].data[2*1024]=metadata.pal_skin01.mips[0].data[2*1024]^255
	check(published.rows[2]==before,"Published selected rows are detached from mutable palette pixels")
	for invalid in [{},{"resource":"bad","palette":[2]},{"resource":"gui_cg_color_tmp","palette":[]},{"resource":"gui_cg_color_tmp","palette":[-1]},{"resource":"gui_cg_color_tmp","palette":[65536]},{"resource":"gui_cg_color_tmp","palette":[1.5]},{"resource":"gui_cg_color_tmp","palette":[0x0700]},{"resource":"gui_cg_color_tmp","palette":[176]},{"resource":"gui_cg_color_tmp","palette":[2],"palette_row":PackedByteArray([1]),"palette_source":"b".repeat(64)}]:
		check(not Gui.prepare(catalog,invalid).get("ready",false),"Invalid/unknown palette input remains explicit: "+str(invalid))
	var service:=Assets.new();root.add_child(service);service.configure(catalog);service.maximum_workers=0
	var replies:Dictionary={};service.completed.connect(func(id,result):replies[id]=result)
	var expected:PackedByteArray=changed.duplicate();var options:Dictionary={"texture_overrides":{"gui_replace01":override},"gui_texture_info":"gui-packed-palette-test-v1"}
	var request:int=service.request("ctl_cg_btn_col",2002,"actor-model",options)
	override.palette_row[0]=override.palette_row[0]^255;override.palette[0]=3
	service.maximum_workers=1;service.pump()
	var deadline:=Time.get_ticks_msec()+15000
	while not replies.has(request) and Time.get_ticks_msec()<deadline:await process_frame
	check(replies.has(request),"Actual native asset worker finishes typed GUI override")
	if replies.has(request):
		var result:Dictionary=replies[request];check(result.get("error","").is_empty(),"Actual typed GUI worker has no error: "+str(result.get("error","")))
		if result.get("error","").is_empty():
			check(result.textures.has_all(["gui_replace01","gui_boxes_chrgen"]),"Override preserves the separate original frame texture")
			check(pixels_match(plt,result.textures.gui_replace01.value.mips[0].data,expected),"Actual queued worker owns a detached selector and active palette row")
			check(result.textures.gui_replace01.has("gui_sampler"),"Original GUI sampler metadata remains attached to the replacement")
	var legacy:int=service.request("ctl_cg_btn_col",2002,"actor-model",{"texture_overrides":{"gui_replace01":"gui_boxes_chrgen"}})
	deadline=Time.get_ticks_msec()+15000
	while not replies.has(legacy) and Time.get_ticks_msec()<deadline:await process_frame
	check(replies.has(legacy) and replies[legacy].get("error","").is_empty(),"Legacy string texture overrides still prepare")
	if replies.has(legacy) and replies[legacy].get("error","").is_empty():check(replies[legacy].textures.gui_replace01.sha256==replies[legacy].textures.gui_boxes_chrgen.sha256,"Legacy override replacement/source bytes are unchanged")
	service.close();service.free();await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"serverConnections":0,"gpu":false,"scope":"Actual PLT/palette byte equivalence, packed WORD selectors, detached active rows, content cache, malformed input and actual asset-worker typed/legacy override behavior; no rendered pixels or live server claim."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
