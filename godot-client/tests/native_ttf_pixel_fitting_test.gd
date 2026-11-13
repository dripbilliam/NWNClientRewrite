extends SceneTree
# Executed only in an owned copied project containing the proposed guarded
# adapter. The real worktree nameplate fitter and shipping defaults are unedited.
const Candidate=preload("res://systems/native_data/ttf_pixel_height.gd")
const Fitting=preload("res://systems/native_data/nameplate_text.gd")
const F=preload("res://systems/native_render/particle_math.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,why: String) -> void:
	checks+=1
	if not value: failures.append(why)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","inputs","oracle"]) or FileAccess.file_exists(args.report): quit(2); return
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.inputs)); var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); var cases: Array=[]
	for resource in inputs.resources:
		var bytes:=FileAccess.get_file_as_bytes(resource.path); check(FileAccess.get_sha256(resource.path)==resource.sha256,"Original font identity"); var native: Dictionary={}
		for entry in oracle.fonts: if entry.name==resource.name: native=entry
		check(not native.is_empty() and native.font_sha256==resource.sha256,"Original metric oracle identity")
		var legacy:=FontFile.new(); legacy.data=bytes; legacy.allow_system_fallback=false
		for size in native.sizes:
			var height:=int(size.requested_height); var packet:=Candidate.make(bytes,height); check(packet.success,"Candidate font available"); var font: FontFile=packet.font; var matched:=0; var unavailable:=0
			for row in size.glyphs:
				var code:=int(row.codepoint)
				if code==0: continue # No NUL String or replacement-character measurement.
				var character:=String.chr(code); var result:=Fitting.font_metrics(font,height,character); var expected:=0.0
				if character in ["\n","\r","\t"]: pass
				elif font.has_char(code): expected=F.f(Candidate.f32(float(row.native_advance_pixels))*0.01); matched+=1
				else: expected=F.f(font.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,height).x*0.01); unavailable+=1
				check(result.glyphs[character]==expected,"Exact native/raw or explicit draw-consistent fallback byte "+str(row.byte))
			for value in ["A","Nibs","Uninjured","WWWWiiii 1234","ΩЖ","😀","\n\r\t"]:
				var unchanged:=Fitting.font_metrics(legacy,height,value)
				for index in value.length():
					var character: String=value.substr(index,1); var expected:=0.0 if character in ["\n","\r","\t"] else F.f(legacy.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,height).x*0.01)
					check(unchanged.glyphs[character]==expected,"Unmarked default font behavior unchanged")
			var mismatch:=Fitting.font_metrics(font,height*2,"A"); check(mismatch.glyphs.A==F.f(font.get_string_size("A",HORIZONTAL_ALIGNMENT_LEFT,-1,height*2).x*0.01),"Unprepared size cannot claim exact native cached advances")
			var unsupported:=Fitting.font_metrics(font,height,"😀"); check(unsupported.glyphs["😀"]==F.f(font.get_string_size("😀",HORIZONTAL_ALIGNMENT_LEFT,-1,height).x*0.01),"Unsupported text keeps the actual drawing fallback's width")
			var line:=TextLine.new(); line.add_string("Nibs",font,height); var raw:=Fitting.font_metrics(font,height,"Nibs"); check(font.get_height(height)==height and line.get_line_ascent()+line.get_line_descent()==height,"Corrected drawing and fitting use one prepared-size font")
			cases.append({"font":resource.name,"height":height,"matched_original_slots":matched,"fallback_slots":unavailable,"Nibs_metrics":raw,"Nibs_textline_width":line.get_line_width(),"missing_rendering_parity":false})
		var bitmap:=FontFile.new(); bitmap.fixed_size=14; bitmap.set_cache_ascent(0,14,11); bitmap.set_cache_descent(0,14,3); bitmap.set_glyph_advance(0,14,65,Vector2(7.25,0))
		check(Fitting.font_metrics(bitmap,14,"A").glyphs.A==F.f(bitmap.get_string_size("A",HORIZONTAL_ALIGNMENT_LEFT,-1,14).x*0.01),"Unmarked bitmap metrics retain their existing adapter")
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"headless":true,"gpu":false,"serverConnections":0,"runtimeWritesProduction":false,"ordinaryDefaultsChanged":false,"integratedGuardedAdapter":true,"originalPixelsAccepted":false,"sourceAssetsExported":false},"  ")+"\n"); output.close(); print("NATIVE_TTF_FITTING_ADAPTER ",checks," checks; ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
