extends SceneTree
var checks := 0
var failures: Array[String] = []
var report_path := ""
var font_path := "res://fixture-font.ttf"
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path=argument.substr(9)
		if argument.begins_with("--font="): font_path=argument.substr(7)
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func snapshot(image: Image) -> Image:
	return Image.create_from_data(image.get_width(),image.get_height(),image.has_mipmaps(),image.get_format(),image.get_data())
func run() -> void:
	if report_path.is_empty() or FileAccess.file_exists(report_path): quit(2); return
	var ts := TextServerManager.get_primary_interface()
	check(ts.get_class()=="TextServerAdvanced","actual Advanced text server selected")
	var bytes := FileAccess.get_file_as_bytes(font_path)
	check(not bytes.is_empty(),"pinned actual TrueType bytes available")
	if bytes.is_empty(): finish(ts.get_name()); return
	# This is the Image COW ownership contract used by the actual C++ helper.
	# Headless texture updates themselves are no-ops, so this is not GPU proof.
	for format in [Image.FORMAT_LA8,Image.FORMAT_RGBA8,Image.FORMAT_RGBAF]:
		var image := Image.create(16,16,false,format); image.fill(Color(0.2,0.4,0.6,0.8))
		var copied := snapshot(image); var expected := copied.get_data()
		check(copied!=image,"distinct upload Image "+str(format))
		image.fill(Color(1,0,0,1))
		check(copied.get_data()==expected,"canonical write detaches COW bytes "+str(format))
		check(copied.get_format()==format and copied.get_size()==image.get_size(),"dimensions/format retained "+str(format))
		var weak := weakref(copied); copied=null
		check(weak.get_ref()==null,"unowned transient snapshot retires "+str(format))
	var manual := ts.create_font(); var size := Vector2i(16,0)
	ts.font_set_allow_system_fallback(manual,false)
	var atlas := Image.create(16,16,false,Image.FORMAT_RGBA8); atlas.fill(Color(1,1,1,0.5))
	ts.font_set_texture_image(manual,size,0,atlas)
	check(ts.font_get_texture_count(manual,size)==1,"manual bitmap atlas count")
	var canonical := ts.font_get_texture_image(manual,size,0)
	check(canonical==atlas,"canonical bitmap atlas ownership unchanged")
	canonical.set_pixel(0,0,Color(1,0,0,1))
	check(atlas.get_pixel(0,0)==Color(1,0,0,1),"public canonical atlas remains mutable")
	ts.font_set_glyph_texture_idx(manual,size,65,0)
	var manual_rid := ts.font_get_glyph_texture_rid(manual,size,65)
	check(manual_rid.is_valid(),"manual atlas texture RID present")
	for turn in 4:
		check(ts.font_get_glyph_texture_rid(manual,size,65)==manual_rid,"clean manual query retains RID "+str(turn))
	var manual_weak := weakref(atlas); atlas=null; canonical=null
	ts.free_rid(manual)
	await process_frame
	check(manual_weak.get_ref()==null,"manual canonical atlas retires with font")
	var dynamic := ts.create_font(); ts.font_set_data(dynamic,bytes)
	ts.font_set_allow_system_fallback(dynamic,false); ts.font_set_generate_mipmaps(dynamic,false)
	ts.font_set_multichannel_signed_distance_field(dynamic,false)
	var dynamic_size := Vector2i(24,0); var textures: Dictionary={}
	for code in range(65,91):
		var glyph := ts.font_get_glyph_index(dynamic,24,code,0)
		check(glyph>0,"actual font contains ASCII "+str(code))
		ts.font_render_glyph(dynamic,dynamic_size,glyph)
		var index := ts.font_get_glyph_texture_idx(dynamic,dynamic_size,glyph)
		var rid := ts.font_get_glyph_texture_rid(dynamic,dynamic_size,glyph)
		check(index>=0 and rid.is_valid(),"dirty glyph publishes actual atlas "+str(code))
		if textures.has(index): check(textures[index]==rid,"dirty upload retains atlas RID "+str(code))
		else: textures[index]=rid
		var image := ts.font_get_texture_image(dynamic,dynamic_size,index)
		check(image!=null and not image.is_empty(),"canonical generated atlas remains present "+str(code))
		check(ts.font_get_glyph_texture_rid(dynamic,dynamic_size,glyph)==rid,"clean glyph query retains RID "+str(code))
	var final_image := ts.font_get_texture_image(dynamic,dynamic_size,0)
	var dynamic_weak := weakref(final_image); final_image=null
	ts.free_rid(dynamic); textures.clear(); bytes=PackedByteArray()
	await process_frame; await process_frame
	check(dynamic_weak.get_ref()==null,"generated canonical atlas retires with font")
	finish(ts.get_name())
func finish(text_server: String) -> void:
	var result := {"success":failures.is_empty(),"checks":checks,"failures":failures,"text_server":text_server,"gpu":false,"scope":"Actual Advanced font API, dirty/clean RID retention, canonical atlas ownership/retirement and Image COW contract. Dummy texture updates are no-ops; no queued GPU race acceptance."}
	var file := FileAccess.open(report_path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print(JSON.stringify({"suite":"native_perf140_render_font_atlas_test","checks":checks,"failures":failures.size()}))
	quit(0 if failures.is_empty() else 1)
