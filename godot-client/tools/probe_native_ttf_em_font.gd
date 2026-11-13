extends SceneTree
const Candidate=preload("res://tools/native_ttf_em_font.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","inputs","oracle"]) or FileAccess.file_exists(args.report): quit(2); return
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.inputs)); var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); var cases: Array=[]; var failures: Array=[]
	for resource in inputs.resources:
		var bytes:=FileAccess.get_file_as_bytes(resource.path); var native: Dictionary={}
		for entry in oracle.fonts: if entry.name==resource.name: native=entry
		if FileAccess.get_sha256(resource.path)!=resource.sha256 or native.font_sha256!=resource.sha256: failures.append("Font source identity"); continue
		for height in [14,16,18,28]:
			var began:=Time.get_ticks_usec(); var packet:=Candidate.make(bytes,height)
			if not packet.success: failures.append(packet.error); continue
			var make_ms:=(Time.get_ticks_usec()-began)/1000.0; var font: FontFile=packet.font; var line:=TextLine.new(); line.add_string("Nibs AV fi ffi",font,height); var metrics: Array=[]; var outlines: Array=[]; var coverage: Array=[]
			for code in [32,65,87,103,105,106,124,233]:
				var glyph:=font.get_glyph_index(height,code,0); font.render_glyph(0,Vector2i(height,0),glyph); metrics.append({"code":code,"glyph":glyph,"advance":font.get_glyph_advance(0,height,glyph).x,"offset":font.get_glyph_offset(0,Vector2i(height,0),glyph),"size":font.get_glyph_size(0,Vector2i(height,0),glyph)})
			for outline in [0,1,2,3,4,6]:
				var glyph:=font.get_glyph_index(height,65,0); var size:=Vector2i(height,outline); font.render_glyph(0,size,glyph); outlines.append({"width":outline,"offset":font.get_glyph_offset(0,size,glyph),"size":font.get_glyph_size(0,size,glyph),"textures":font.get_texture_count(0,size)})
			for code in [65,233,0x3a9,0x416,0x5d0,0x627,0x4e2d,0x1f600,0x10ffff]: coverage.append({"code":code,"has_char":font.has_char(code),"glyph":font.get_glyph_index(height,code,0)})
			var whole:=Candidate.sum32(packet.data,0,packet.data.size()); var source_intact:=bytes==FileAccess.get_file_as_bytes(resource.path)
			cases.append({"font":resource.name,"height":height,"units_before":packet.source_units,"units_after":packet.derived_units,"checksum":whole,"checksum_method":packet.checksum_method,"source_intact":source_intact,"line_height":font.get_height(height),"ascent":font.get_ascent(height),"descent":font.get_descent(height),"textline_width":line.get_line_width(),"textline_height":line.get_line_ascent()+line.get_line_descent(),"glyphs":metrics,"outlines":outlines,"coverage":coverage,"at_other_height":font.get_height(height*2),"make_ms":make_ms,"full_probe_ms":(Time.get_ticks_usec()-began)/1000.0})
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"failures":failures,"cases":cases,"productionChanged":false,"sourceAssetsExported":false,"derivedHeaderPrivateOnly":true,"gpu":false,"serverConnections":0},"  ")+"\n"); output.close(); quit(0 if failures.is_empty() else 1)
