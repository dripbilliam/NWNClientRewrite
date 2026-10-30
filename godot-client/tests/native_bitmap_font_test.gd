extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
const Metrics=preload("res://systems/native_data/bitmap_font.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var glyph_diagnostic: Dictionary={}
var pixel_diagnostic: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func wait_for(predicate: Callable,seconds: float=30) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<until: await process_frame
	return predicate.call()
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(900,400); var background:=ColorRect.new(); background.color=Color(0.15,0.18,0.2); background.size=root.size; root.add_child(background)
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original font catalog mounts read-only")
	var fonts:=Fonts.new(); root.add_child(fonts); fonts.configure(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var label:=Label.new(); label.position=Vector2(20,20); label.text="Original Galahad: ABC abc 0123 !? É € —\nExamine • Identify • Close"; label.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; label.add_theme_constant_override("outline_size",2); root.add_child(label); fonts.bind(label,"fnt_galahad14")
	check(await wait_for(func():return fonts.fonts.has("fnt_galahad14") or fonts.failed.has("fnt_galahad14")),"Original bitmap metadata and atlas finish native loading")
	check(fonts.failed.is_empty() and fonts.fonts.has("fnt_galahad14"),"Original Galahad FontFile publishes without a fallback")
	if fonts.fonts.has("fnt_galahad14"):
		var font: FontFile=fonts.fonts.fnt_galahad14; var data: Dictionary=fonts.metrics.fnt_galahad14
		check(absf(font.get_height(17)-17)<0.01 and absf(font.get_ascent(17)-14)<0.01,"Original17-pixel line height and14-pixel baseline are retained")
		check(label.get_theme_font("font")==font and label.get_theme_font_size("font_size")==17,"Label binds the original font using metrics rather than the resource-name digits")
		check(font.get_glyph_index(17,65,0)==65 and font.has_char(65),"Bitmap glyph cache is addressable by the actual text shaper")
		glyph_diagnostic={"a_index":font.get_glyph_index(17,65,0),"a_present":font.has_char(65),"euro_index":font.get_glyph_index(17,0x20ac,0),"euro_present":font.has_char(0x20ac),"glyphs":font.get_glyph_list(0,Vector2i(17,0)),"sizes":font.get_size_cache_list(0),"fixed_size":font.fixed_size,"backend_fixed_size":TextServerManager.get_primary_interface().font_get_fixed_size(font.get_rids()[0]),"backend":TextServerManager.get_primary_interface().get_name()}
		check(font.has_char(0x20ac) and font.has_char(0x2014) and font.get_glyph_index(17,0x20ac,0)==0x20ac,"CP1252 byte glyphs map to the Unicode text projection")
		var text:="Inventory: Native visitor"; var width:=0.0; var parser:=Metrics.new(); var glyphs:=parser.glyphs(data,256,256)
		for index in text.length(): width+=float(glyphs[text.unicode_at(index)].advance)
		check(absf(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x-width)<0.01,"Shaped label width equals original per-glyph advances")
		check(label.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and label.get_theme_constant("outline_size")==0,"Original bitmap glyph pixels avoid added font smoothing or outline dilation")
	var stale:=Label.new(); root.add_child(stale); fonts.bind(stale,"fnt_floaty_smal"); stale.free()
	check(await wait_for(func():return fonts.fonts.has("fnt_floaty_smal") or fonts.failed.has("fnt_floaty_smal")),"Second original bitmap font loads after its bound control retires")
	check(fonts.stats.stale==1 and fonts.bindings.is_empty(),"Late font delivery discards freed controls")
	if fonts.fonts.has("fnt_floaty_smal"): check(fonts.fonts.fnt_floaty_smal.has_char(255),"Bytes absent from a short original atlas use its original glyph-zero fallback")
	fonts.bind(label,"ttf fnt_default 18")
	check(await wait_for(func():return fonts.fonts.has("ttf fnt_default 18") or fonts.failed.has("ttf fnt_default 18")),"Original explicit ttf-font-size syntax resolves the named installed font")
	check(fonts.fonts.has("ttf fnt_default 18") and label.get_theme_font_size("font_size")==18,"Explicit TTF font binding preserves the requested size")
	check(label.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR and label.get_theme_constant("outline_size")==2,"Switching from a bitmap font restores the control's original filter and text effects")
	fonts.bind(label,"ttf fnt_default 19"); fonts.bind(label,"fnt_galahad14")
	check(await wait_for(func():return fonts.fonts.has("ttf fnt_default 19")) and label.get_theme_font("font")==fonts.fonts.fnt_galahad14 and label.get_theme_font_size("font_size")==17,"Late delivery for a previously selected font cannot overwrite the current bitmap font")
	fonts.bind(label,"fnt_galahad14"); await process_frame
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-bitmap-font-oracle-v5.json"))
	for original in oracle.fonts:
		check(fonts.fonts.has(original.name),"Original font referenced by the independent oracle is loaded")
		if not fonts.fonts.has(original.name): continue
		var original_font: FontFile=fonts.fonts[original.name]; var font_height:=roundi(float(fonts.metrics[original.name].height)); var cache_size:=Vector2i(font_height,0)
		var image: Image=original_font.get_texture_image(0,cache_size,0)
		var selected: Dictionary=catalog.raster_location(original.name)
		check(int(selected.type)==int(original.atlasType),"Native font atlas uses the original catalog format selection rather than forcing TGA")
		var selected_parser:=preload("res://systems/native_data/texture_data.gd").new(); var selected_atlas:=selected_parser.parse(catalog.get_resource(original.name,int(selected.type)),int(selected.type))
		check(Cache.digest(catalog.get_resource(original.name,int(selected.type)))==str(original.atlasSha256),"Selected native font source bytes agree with independent original resource lookup")
		if int(selected.type)!=3: check(Cache.digest(selected_atlas.mips[0].data)==str(original.mipSha256),"Selected compressed font mip bytes agree with the independent DDS decoder")
		var selected_format: int={"rgba8":Image.FORMAT_RGBA8,"dxt1_rgb":Image.FORMAT_DXT1,"dxt1_rgba":Image.FORMAT_DXT1,"dxt3":Image.FORMAT_DXT3,"dxt5":Image.FORMAT_DXT5,"etc1":Image.FORMAT_ETC}.get(str(selected_atlas.format),-1)
		var selected_image:=Image.create_from_data(int(selected_atlas.width),int(selected_atlas.height),false,selected_format,selected_atlas.mips[0].data)
		if selected_image.is_compressed(): selected_image.decompress()
		selected_image.flip_y()
		var raw_parser:=preload("res://systems/native_data/texture_data.gd").new(); raw_parser.use_native=false
		var raw_atlas:=raw_parser.parse(catalog.get_resource(original.name,3),3); var source_image:=Image.create_from_data(int(raw_atlas.width),int(raw_atlas.height),false,Image.FORMAT_RGBA8,raw_atlas.mips[0].data); source_image.flip_y()
		var compiled_parser:=preload("res://systems/native_data/texture_data.gd").new(); var compiled_atlas:=compiled_parser.parse(catalog.get_resource(original.name,3),3); var compiled_image:=Image.create_from_data(int(compiled_atlas.width),int(compiled_atlas.height),false,Image.FORMAT_RGBA8,compiled_atlas.mips[0].data); compiled_image.flip_y()
		check(image.get_width()==int(original.width) and image.get_height()==int(original.height),"Original atlas dimensions agree with the offline reference")
		for glyph in original.glyphs:
			var byte:=int(glyph.byte); var code: int=preload("res://systems/native_data/binary_data.gd").CP1252_HIGH[byte-128] if byte>=128 and byte<160 else byte
			var rect:=original_font.get_glyph_uv_rect(0,cache_size,code)
			check(rect.position.distance_to(Vector2(glyph.sx,glyph.sy))<0.001 and rect.size.distance_to(Vector2(glyph.sw,glyph.sh))<0.001,"Native glyph UV rectangle agrees with independent original TXI reference")
			var pixels:=PackedByteArray()
			if int(glyph.sw)>0 and int(glyph.sh)>0: pixels=image.get_region(Rect2i(int(glyph.sx),int(glyph.sy),int(glyph.sw),int(glyph.sh))).get_data()
			var region:=Rect2i(int(glyph.sx),int(glyph.sy),int(glyph.sw),int(glyph.sh)); var nonempty:=region.size.x>0 and region.size.y>0
			var source_pixels:=source_image.get_region(region).get_data() if nonempty else PackedByteArray()
			var compiled_pixels:=compiled_image.get_region(region).get_data() if nonempty else PackedByteArray()
			var selected_pixels:=selected_image.get_region(region).get_data() if nonempty else PackedByteArray()
			check(Cache.digest(source_pixels)==str(glyph.tgaSha256) and source_pixels==compiled_pixels,"Both native TGA decoders agree with independent original glyph-region hashes")
			check(pixels==selected_pixels,"FontFile publication preserves the catalog-selected atlas pixels after native decompression")
			if int(selected.type)==3: check(Cache.digest(pixels)==str(glyph.tgaSha256),"Selected TGA font publication exactly matches independent glyph-region pixels")
	fonts.bind(label,"missing_native_font"); check(fonts.failed.has("missing_native_font") and fonts.bindings.is_empty() and not label.has_meta("native_font_applied"),"Unavailable font records an explicit failure without a stale binding or prior font override")
	fonts.bind(label,"fnt_galahad14")
	var metadata:=catalog.get_resource("fnt_galahad14",2022).get_string_from_ascii()
	for malformed in ["",metadata.replace("numchars 256","numchars 257"),metadata.replace("fontheight 0.170000","fontheight NaN"),metadata.replace("baselineheight 0.140000","baselineheight INF")]:
		var parser:=Metrics.new(); parser.parse(malformed); check(not parser.failure.is_empty(),"Malformed original font metadata fails explicitly")
	var parser:=Metrics.new(); var broken:=parser.parse(metadata); broken.lower[65][0]=2; parser.glyphs(broken,256,256); check(not parser.failure.is_empty(),"An out-of-atlas original glyph cannot publish")
	await RenderingServer.frame_post_draw
	if not OS.get_cmdline_args().has("--headless"): root.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")
	var snapshot:=fonts.snapshot(); fonts.close(); check(fonts.assets.running.is_empty() and fonts.assets.pending.is_empty() and fonts.bindings.is_empty(),"Original font retirement drains workers and weak bindings"); fonts.free(); label.free(); background.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"fonts":snapshot,"glyph_diagnostic":glyph_diagnostic,"pixel_diagnostic":pixel_diagnostic,"metadata_sha256":Cache.digest(metadata.to_ascii_buffer()),"scope":"Original bitmap font metadata, glyph shaping/metrics, native image publication and font binding. Original-client screenshot comparison, complete TTF raster parity, double-byte fonts and all UI surfaces remain open."},"\t")); file.close(); print("NATIVE_BITMAP_FONT ",checks," checks / ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
