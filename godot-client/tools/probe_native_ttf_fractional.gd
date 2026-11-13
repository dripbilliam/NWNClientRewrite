extends SceneTree
const Candidate=preload("res://tools/native_ttf_em_font.gd")
func _initialize() -> void: call_deferred("run")
func view(font: FontFile) -> Dictionary:
	var glyph:=font.get_glyph_index(14,65,0); font.render_glyph(0,Vector2i(14,0),glyph); var texture:=font.get_glyph_texture_idx(0,Vector2i(14,0),glyph); var image:=font.get_texture_image(0,Vector2i(14,0),texture)
	return {"line_height":font.get_height(14),"ascent":font.get_ascent(14),"advance":font.get_glyph_advance(0,14,glyph).x,"offset":font.get_glyph_offset(0,Vector2i(14,0),glyph),"size":font.get_glyph_size(0,Vector2i(14,0),glyph),"uv":font.get_glyph_uv_rect(0,Vector2i(14,0),glyph),"image_size":image.get_size(),"image_format":image.get_format(),"font_oversampling":font.oversampling}
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","inputs"]) or FileAccess.file_exists(args.report): quit(2); return
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.inputs)); var cases: Array=[]; var ts:=TextServerManager.get_primary_interface()
	for resource in inputs.resources:
		var bytes:=FileAccess.get_file_as_bytes(resource.path); ts.font_set_global_oversampling(1.0); var packet:=Candidate.make(bytes,14); var font: FontFile=packet.font; var rows: Array=[]
		for factor in [1.0,1.25,1.5,2.0,1.0]:
			ts.font_set_global_oversampling(factor); rows.append({"factor":factor,"existing_font":view(font),"fresh_font":view(Candidate.make(bytes,14).font),"explicit_raster_scale":view(Candidate.make(bytes,14,factor).font)})
		cases.append({"font":resource.name,"global_oversampling":rows})
	ts.font_set_global_oversampling(1.0)
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"cases":cases,"headless":true,"gpu":false,"serverConnections":0,"productionChanged":false,"sourceAssetsExported":false},"  ")+"\n"); output.close(); quit(0)
