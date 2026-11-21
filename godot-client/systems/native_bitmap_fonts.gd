extends Node
# Shared native legacy-font ownership. Resource work is bounded; FontFile and
# atlas images publish on the main thread, scoped to the active catalog.
signal loaded(name: String)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Metrics=preload("res://systems/native_data/bitmap_font.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const TtfHeight=preload("res://systems/native_data/ttf_pixel_height.gd")
var assets
var catalog
var ttf_pixel_height_enabled:=false # Read once by configure; ordinary owners keep the existing method.
var _ttf_pixel_height_active:=false
var _ttf_pixel_height_diagnostics:={"attempted":0,"published":0,"fallbacks":0,"last_fallback":{}}
var fonts: Dictionary={}
var metrics: Dictionary={}
var pending: Dictionary={}
var failed: Dictionary={}
var jobs: Dictionary={}
var bindings: Dictionary={}
var serial:=0
var closed:=false
var stats:={"published":0,"stale":0,"native_only":true,"full_font_parity":false}
func configure(source,cache_path: String) -> void:
	_ttf_pixel_height_active=ttf_pixel_height_enabled
	catalog=source; assets=Assets.new(); add_child(assets); assets.configure(source); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
func request(name: String) -> void:
	if closed or name.is_empty() or fonts.has(name) or pending.has(name) or failed.has(name): return
	var parts:=name.split(" ",false)
	if parts.size()==3 and parts[0]=="ttf" and parts[2].is_valid_int() and int(parts[2])>0 and int(parts[2])<=512:
		if not catalog.has_resource(parts[1],2074): fail(name,"Original explicit TTF font is unavailable"); return
		pending[name]={"mode":"ttf","height":int(parts[2])}; job(name,parts[1],2074,"font-v1","ttf"); return
	var location: Dictionary=catalog.raster_location(name)
	if not catalog.has_resource(name,2022) or location.is_empty(): fail(name,"Original bitmap-font metadata or atlas is unavailable"); return
	pending[name]={"mode":"bitmap"}
	job(name,name,2022,"bitmap-font-v1","metrics")
	if not failed.has(name): job(name,name,int(location.type),"raster","atlas")
func job(name: String,resource: String,type: int,decoder: String,kind: String) -> void:
	var id: int=assets.request(resource,type,decoder)
	if id<0: fail(name,str(assets.failure)); return
	jobs[id]={"name":name,"kind":kind}
func unbind(control: Control) -> void:
	if is_instance_valid(control): bindings.erase(control.get_instance_id())
func bind(control: Control,name: String) -> void:
	if closed or name.is_empty(): return
	serial+=1; var id:=control.get_instance_id(); bindings[id]={"target":weakref(control),"name":name,"serial":serial}
	if control.has_meta("native_font_applied") and str(control.get_meta("native_font_applied"))!=name:
		restore_bitmap_style(control)
		if control is RichTextLabel:
			for key in ["normal_font","bold_font","italics_font","bold_italics_font","mono_font"]: control.remove_theme_font_override(key)
			for key in ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"]: control.remove_theme_font_size_override(key)
		else: control.remove_theme_font_override("font"); control.remove_theme_font_size_override("font_size")
		control.remove_meta("native_font_applied")
	control.set_meta("native_font_resource",name)
	if fonts.has(name): apply(control,name); bindings.erase(id)
	elif not failed.has(name): request(name)
	else: bindings.erase(id)
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var job: Dictionary=jobs[id]; jobs.erase(id); var name:=str(job.name)
	if failed.has(name): return
	if not str(result.get("error","")).is_empty(): fail(name,str(result.error)); return
	if job.kind=="ttf":
		var font: FontFile
		if _ttf_pixel_height_active:
			_ttf_pixel_height_diagnostics.attempted+=1
			var candidate:=TtfHeight.make(result.value.data,int(pending[name].height))
			if candidate.success:
				font=candidate.font; _ttf_pixel_height_diagnostics.published+=1
			else:
				var source_hash:=HashingContext.new(); source_hash.start(HashingContext.HASH_SHA256); source_hash.update(result.value.data)
				_ttf_pixel_height_diagnostics.fallbacks+=1
				_ttf_pixel_height_diagnostics.last_fallback={"resource":name.substr(0,256),"height":int(pending[name].height),"source_sha256":source_hash.finish().hex_encode(),"reason":str(candidate.get("error","Unsupported font adaptation")).substr(0,256)}
		if font==null:
			font=FontFile.new(); font.data=result.value.data; font.allow_system_fallback=false; font.generate_mipmaps=false; font.multichannel_signed_distance_field=false
		fonts[name]=font; metrics[name]={"height":pending[name].height,"mode":"ttf"}; publish(name); return
	pending[name][str(job.kind)]=result.value
	if pending[name].has("metrics") and pending[name].has("atlas"):
		var data: Dictionary=pending[name].metrics; var atlas: Dictionary=pending[name].atlas
		var format: int={"rgba8":Image.FORMAT_RGBA8,"dxt1_rgb":Image.FORMAT_DXT1,"dxt1_rgba":Image.FORMAT_DXT1,"dxt3":Image.FORMAT_DXT3,"dxt5":Image.FORMAT_DXT5,"etc1":Image.FORMAT_ETC}.get(str(atlas.format),-1)
		if format<0 or atlas.mips.is_empty(): fail(name,"Original font atlas upload format is unavailable"); return
		var image:=Image.create_from_data(int(atlas.width),int(atlas.height),false,format,atlas.mips[0].data)
		if image==null or image.is_empty(): fail(name,"Original font atlas image failed"); return
		if image.is_compressed() and image.decompress()!=OK: fail(name,"Original font atlas decompression failed"); return
		image.flip_y()
		var parser:=Metrics.new(); var glyphs:=parser.glyphs(data,image.get_width(),image.get_height())
		if not parser.failure.is_empty(): fail(name,parser.failure); return
		var height:=maxi(1,roundi(float(data.height))); var size:=Vector2i(height,0); var font:=FontFile.new()
		font.font_name=name; font.fixed_size=height; font.fixed_size_scale_mode=TextServer.FIXED_SIZE_SCALE_DISABLE; font.allow_system_fallback=false; font.generate_mipmaps=false; font.multichannel_signed_distance_field=false; font.modulate_color_glyphs=true
		font.antialiasing=TextServer.FONT_ANTIALIASING_NONE; font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED; font.hinting=TextServer.HINTING_NONE
		font.set_cache_ascent(0,height,float(data.baseline)); font.set_cache_descent(0,height,float(data.height)-float(data.baseline)); font.set_cache_scale(0,height,1.0); font.set_texture_image(0,size,0,image)
		for byte in maxi(256,glyphs.size()):
			var code: int=Binary.CP1252_HIGH[byte-128] if byte>=128 and byte<160 else byte
			var glyph: Dictionary=glyphs[byte if byte<glyphs.size() else 0]
			font.set_glyph_advance(0,height,code,Vector2(float(glyph.advance),0)); font.set_glyph_offset(0,size,code,Vector2(0,-float(data.baseline)-float(data.spacing_b))); font.set_glyph_size(0,size,code,glyph.size); font.set_glyph_uv_rect(0,size,code,glyph.rect); font.set_glyph_texture_idx(0,size,code,0)
		fonts[name]=font; metrics[name]=data.duplicate(); metrics[name].mode="bitmap"; publish(name)
func publish(name: String) -> void:
	pending.erase(name); stats.published+=1
	for id in bindings.keys():
		var row: Dictionary=bindings[id]
		if str(row.name)!=name: continue
		var control: Object=row.target.get_ref()
		if is_instance_valid(control) and not control.is_queued_for_deletion(): apply(control,name)
		else: stats.stale+=1
		bindings.erase(id)
	loaded.emit(name)
func apply(control: Control,name: String) -> void:
	var font: FontFile=fonts[name]; var height:=maxi(1,roundi(float(metrics[name].height)))
	control.set_meta("native_font_applied",name)
	if control is RichTextLabel:
		for key in ["normal_font","bold_font","italics_font","bold_italics_font","mono_font"]: control.add_theme_font_override(key,font)
		for key in ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"]: control.add_theme_font_size_override(key,height)
	else: control.add_theme_font_override("font",font); control.add_theme_font_size_override("font_size",height)
	if metrics[name].mode=="bitmap":
		if not control.has_meta("native_bitmap_style"):
			control.set_meta("native_bitmap_style",{"filter":control.texture_filter,"outline":control.get_theme_constant("outline_size") if control.has_theme_constant("outline_size") else 0,"shadow_x":control.get_theme_constant("shadow_offset_x") if control.has_theme_constant("shadow_offset_x") else 0,"shadow_y":control.get_theme_constant("shadow_offset_y") if control.has_theme_constant("shadow_offset_y") else 0,"shadow_color":control.get_theme_color("font_shadow_color") if control.has_theme_color("font_shadow_color") else Color.TRANSPARENT})
		control.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		control.add_theme_constant_override("outline_size",0); control.add_theme_constant_override("shadow_offset_x",0); control.add_theme_constant_override("shadow_offset_y",0); control.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	else: restore_bitmap_style(control)
func restore_bitmap_style(control: Control) -> void:
	if not control.has_meta("native_bitmap_style"): return
	var original: Dictionary=control.get_meta("native_bitmap_style"); control.remove_meta("native_bitmap_style")
	control.texture_filter=int(original.filter); control.add_theme_constant_override("outline_size",int(original.outline)); control.add_theme_constant_override("shadow_offset_x",int(original.shadow_x)); control.add_theme_constant_override("shadow_offset_y",int(original.shadow_y)); control.add_theme_color_override("font_shadow_color",original.shadow_color)
func fail(name: String,reason: String) -> void:
	failed[name]=reason; pending.erase(name)
	for id in bindings.keys():
		if bindings[id].name==name: bindings.erase(id)
func snapshot() -> Dictionary:
	var out:=stats.duplicate(); out.merge({"fonts":fonts.keys(),"pending":pending.size(),"bindings":bindings.size(),"failed":failed.duplicate(),"ttf_pixel_height":_ttf_pixel_height_diagnostics.duplicate(true)}); out.ttf_pixel_height.enabled=_ttf_pixel_height_active; return out
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets): assets.close()
	fonts.clear(); metrics.clear(); pending.clear(); jobs.clear(); bindings.clear(); catalog=null
func _exit_tree() -> void: close()
