extends SceneTree
const Candidate=preload("res://systems/native_data/ttf_pixel_height.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok: failures.append(why)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","inputs","oracle"]) or FileAccess.file_exists(args.report): quit(2); return
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.inputs)); var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); var cases: Array=[]
	for resource in inputs.resources:
		var bytes:=FileAccess.get_file_as_bytes(resource.path); check(FileAccess.get_sha256(resource.path)==resource.sha256,"Original source identity")
		var native: Dictionary={}
		for entry in oracle.fonts: if entry.name==resource.name: native=entry
		check(not native.is_empty() and native.font_sha256==resource.sha256,"Original metric oracle identity")
		var original:=FontFile.new(); original.data=bytes; original.allow_system_fallback=false
		for size in native.sizes:
			var height:=int(size.requested_height); var start:=Time.get_ticks_usec(); var packet:=Candidate.make(bytes,height); var construction_ms:=(Time.get_ticks_usec()-start)/1000.0; check(packet.success,"Candidate construction")
			if not packet.success: continue
			var font: FontFile=packet.font; var contours: Array=[]; var raw_error:=0.0; var shaped_error:=0.0
			check(font.get_height(height)==height and font.get_ascent(height)==packet.baseline,"Original logical line/baseline")
			for row in size.glyphs:
				var built: Dictionary=packet.rows[int(row.byte)]; check(int(built.glyph)==int(row.glyph),"Original mapped glyph byte "+str(row.byte)); var expected:=Candidate.f32(float(row.native_advance_pixels)); var actual:=font.get_glyph_advance(0,height,int(row.glyph)).x
				check(float(built.advance)==expected and actual==expected,"Original binary32 advance byte "+str(row.byte)); raw_error=maxf(raw_error,absf(actual-expected))
				if int(row.byte)>=32 and int(row.byte)<127:
					var line:=TextLine.new(); line.add_string(String.chr(int(row.codepoint)),font,height)
					var glyphs:=TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid())
					if not glyphs.is_empty(): shaped_error=maxf(shaped_error,absf(float(glyphs[0].advance)-expected))
			for outline in [0,1,2,3,4,6]:
				var shape_size:=Vector2i(height,outline); var glyph:=font.get_glyph_index(height,65,0); font.render_glyph(0,shape_size,glyph); var extent:=font.get_glyph_size(0,shape_size,glyph)
				check(extent.x>0 and extent.y>0 and font.get_glyph_texture_idx(0,shape_size,glyph)>=0,"Demand-render requested outline "+str(outline)); contours.append({"outline":outline,"size":extent,"offset":font.get_glyph_offset(0,shape_size,glyph)})
			check(shaped_error<1.0/64.0,"Native-size HarfBuzz per-glyph quantization is below1/64px")
			var coverage: Array=[]
			for code in [65,233,0x20ac,0x3a9,0x416,0x5d0,0x627,0x4e2d,0x1f600,0x10ffff]:
				check(font.has_char(code)==original.has_char(code) and font.get_glyph_index(height,code,0)==original.get_glyph_index(height,code,0),"Original/current glyph availability preserved "+str(code)); coverage.append({"code":code,"available":font.has_char(code),"glyph":font.get_glyph_index(height,code,0)})
			var text:=RichTextLabel.new(); text.bbcode_enabled=true; text.fit_content=true; text.autowrap_mode=TextServer.AUTOWRAP_OFF; text.size=Vector2(400,100); text.text="Nibs\nUninjured"; text.add_theme_font_override("normal_font",font); text.add_theme_font_size_override("normal_font_size",height); text.add_theme_constant_override("outline_size",3); root.add_child(text); await process_frame
			check(text.get_theme_font("normal_font")==font and text.get_content_height()==height*2,"Actual rich control draws and measures the same candidate with outline3")
			var scales: Array=[]
			for scale in [1.0,1.25,1.5,2.0]:
				text.scale=Vector2.ONE*scale; check(text.get_global_rect().size==text.size*scale,"Fractional control transform keeps geometry and bounds together"); scales.append({"scale":scale,"logical":text.size,"physical":text.get_global_rect().size})
			var different:=Candidate.make(bytes,height+1); check(different.font!=font and different.font.get_height(height+1)==height+1 and font.get_height(height)==height,"Per-requested-height font identity and baseline caches remain independent")
			var weak: WeakRef=weakref(different.font); different.clear(); check(weak.get_ref()==null,"Unbound private dynamic font and derived byte storage retire without a global reference")
			cases.append({"font":resource.name,"height":height,"construction_ms":construction_ms,"raw_advance_max_error":raw_error,"shape_quantization_max_error":shaped_error,"outlines":contours,"coverage":coverage,"scales":scales,"unprepared_double_height":font.get_height(height*2)})
			text.free()
		var first:=Candidate.derive(bytes); check(Candidate.sum32(bytes,0,bytes.size())==Candidate.sum32(first.data,0,first.data.size()),"Private header adaptation preserves actual whole-font checksum")
		check(bytes==FileAccess.get_file_as_bytes(resource.path),"Original source bytes remain unchanged")
		var changed:=bytes.duplicate(); var detached:=Candidate.make(changed,14); var preserved: float=detached.font.get_glyph_advance(0,14,36).x; changed.fill(0); check(detached.font.get_glyph_advance(0,14,36).x==preserved,"Supplied array mutation does not change published font")
		check(not Candidate.make(bytes,0).success and not Candidate.make(bytes,513).success and not Candidate.make(bytes.slice(0,16),14).success,"Invalid sizes/truncated data reject explicitly")
		var cff:=bytes.duplicate(); Candidate.w32(cff,0,0x4f54544f); var cff_result:=Candidate.derive(cff)
		check(not cff_result.success and str(cff_result.error).contains("CFF"),"CFF adaptation declines before creating a FontFile")
	await process_frame
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"headless":true,"gpu":false,"runtimeWritesProduction":false,"ordinaryDefaultsChanged":false,"serverConnections":0,"derivedHeaderPrivateOnly":true,"sourceAssetsExported":false,"originalPixelsAccepted":false},"  ")+"\n"); output.close(); print("NATIVE_TTF_EM_GATES ",checks," checks; ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
