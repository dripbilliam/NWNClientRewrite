extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const UiSkin=preload("res://systems/native_ui_skin.gd")
const SkinData=preload("res://systems/native_data/ui_skin.gd")
const FontData=preload("res://systems/native_data/font_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Nui=preload("res://systems/server_nui.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<25: failures.append(label)
func wait_until(predicate: Callable) -> bool:
	var began:=Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec()-began<30000: await process_frame
	return predicate.call()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var catalog:=Catalog.new(); check(catalog.mount_install(oracle.install),"Native original UI resource catalog")
	var raw: PackedByteArray=catalog.get_resource("nui_skin",2076); check(Cache.digest(raw)==oracle.skinSha256,"Original skin byte identity")
	var parser:=SkinData.new(); var data:=parser.parse(raw.get_string_from_utf8())
	check(parser.failure.is_empty() and not data.is_empty(),"Original NUI skin parses natively")
	for row in oracle.keys: check(data.tables.get(row.table,{}).get(row.key)==row.value,"Original NUI skin scalar %s/%s"%[row.table,row.key])
	check(data.fonts==oracle.fontSpecs,"Original physical font specifications and ordering")
	var font_shapes: Array=[]
	for sample in oracle.fonts:
		var bytes: PackedByteArray=catalog.get_resource(sample.name,2074); check(Cache.digest(bytes)==sample.sha256,"Original SFNT source identity "+str(sample.name))
		var decoder:=FontData.new(); var font:=decoder.parse(bytes)
		check(decoder.failure.is_empty() and font.tables.size()==int(sample.tables) and font.data==bytes,"Native SFNT directory/ranges preserve original font bytes")
		var invalid:=bytes.duplicate(); invalid[4]=255; invalid[5]=255; check(decoder.parse(invalid).is_empty(),"Invalid original SFNT directory count rejected")
		invalid=bytes.duplicate(); invalid[20]=255; invalid[21]=255; invalid[22]=255; invalid[23]=255; check(decoder.parse(invalid).is_empty(),"Invalid original SFNT table range rejected")
		check(decoder.parse(bytes.slice(0,10)).is_empty(),"Truncated SFNT rejected before FontFile publication")
	for invalid in ["[bad section]\nkey = 1","[window]\nkey = invalid","[window]\nkey = \"unterminated","[[unknown]]\nx=1"]:
		check(parser.parse(invalid).is_empty() and not parser.failure.is_empty(),"Unsupported/malformed original skin syntax rejected")
	var authored:="[window]\ncolor = '#aabbccdd' # comment\ntext = \"a # b\"\namount = 1_024\n[[fonts]]\nname='(default)'\nresref='fnt_maintext'\nfont_size=17\n"
	var values:=parser.parse(authored); check(values.tables.window.color=="#aabbccdd" and values.tables.window.text=="a # b" and values.tables.window.amount==1024 and values.fonts.size()==1,"Quoted hashes, comments, numeric separators and font arrays remain data")
	var cache_path:=ProjectSettings.globalize_path("user://native-skin-check-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var runs: Array=[]
	for pass_index in 2:
		var owner:=UiSkin.new(); root.add_child(owner); owner.configure(catalog,cache_path)
		check(await wait_until(func(): return owner.done),"Original native skin workers finish %d"%pass_index)
		check(owner.stats.errors.is_empty(),"Original font/image preparation errors absent: "+str(owner.stats.errors))
		check(owner.fonts.size()==oracle.fonts.size() and owner.images.size()==oracle.images.size(),"All original skin images/fonts publish natively %d"%pass_index)
		check(owner.stats.cache_hits==(0 if pass_index==0 else 1+oracle.fonts.size()+oracle.images.size()),"Cold/warm original native skin cache reuse %d"%pass_index)
		check(not owner.stats.worker_threads.is_empty() and not owner.stats.worker_threads.has(OS.get_main_thread_id()),"Original skin data preparation stays on native workers")
		for sample in oracle.fonts:
			if not owner.fonts.has(sample.name): continue
			var font: FontFile=owner.fonts[sample.name]; var extent:=font.get_string_size("Native gameplay",HORIZONTAL_ALIGNMENT_LEFT,-1,17)
			check(Cache.digest(font.data)==sample.sha256 and extent.x>0 and extent.y>0 and not font.get_font_name().is_empty(),"FontFile uses exact original bytes and shapes text "+str(sample.name))
			font_shapes.append({"name":sample.name,"family":font.get_font_name(),"width":extent.x,"height":extent.y})
		var theme:=owner.theme(); check(theme.default_font==owner.fonts.get("fnt_maintext") and theme.get_font("font","Button")==owner.fonts.get("fnt_default"),"Gameplay widgets inherit original text/button fonts")
		var overlay:=CanvasLayer.new(); root.add_child(overlay); var manager:=Nui.new(); root.add_child(manager); manager.setup(overlay)
		manager.resources[9000]=owner.fonts.get("fnt_default")
		check(owner.install_nui(manager),"Native original resources install without encoded NUI transfers")
		await process_frame
		check(manager.skin_ready() and manager.transfers.is_empty() and manager.images.size()==27,"NUI renderer resolves original native skin/font/texture objects")
		check(manager.font_for("(default)")==owner.fonts.get("fnt_maintext") and manager.font_for("(monospace)")==owner.fonts.get("jbmonoreg"),"Original named NUI fonts resolve directly")
		var button:=Button.new(); overlay.add_child(button); button.text="Native original skin"; manager.style(button,"button","(default)",null)
		check(button.get_theme_font("font")==owner.fonts.get("fnt_maintext") and button.get_theme_stylebox("normal") is StyleBoxTexture,"NUI widget consumes original native font and skin image")
		check(owner.install_nui(manager) and manager.resources.has(9000) and manager.resources.size()==30,"Replacing a native skin preserves unrelated resources and avoids duplicates")
		manager.reset(); manager.queue_free(); overlay.queue_free(); await process_frame; await process_frame
		runs.append(owner.snapshot()); owner.close()
		check(owner.assets.running.is_empty() and owner.assets.pending.is_empty() and owner.fonts.is_empty() and owner.images.is_empty(),"Native font/image workers and resource maps retire %d"%pass_index)
		owner.queue_free(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"skin_scalars":oracle.keys.size(),"original_fonts":oracle.fonts.size(),"original_images":oracle.images.size(),"font_shapes":font_shapes,"runs":runs,"gpu_verified":false,"full_nui_migration":false,"scope":"Headless original native skin/SFNT/image preparation, cache, FontFile shaping and NUI resource installation. No JS runtime preparation; NUI layout/input projection and graphical fidelity remain pending."},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
