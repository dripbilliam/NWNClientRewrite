extends RefCounted
# CPU inspection of actual FontFile metrics and nontransparent original atlas ink.
static func packed(value:Variant)->Variant:
	if value is Vector2:return [value.x,value.y]
	if value is Rect2:return {"position":packed(value.position),"size":packed(value.size)}
	if value is Color:return [value.r,value.g,value.b,value.a]
	if value is Dictionary:
		var result:Dictionary={}
		for key in value:result[key]=packed(value[key])
		return result
	if value is Array:return value.map(packed)
	return value
static func label_view(label:Label,entry:Dictionary)->Dictionary:
	var font:Font=label.get_theme_font("font");var height:=label.get_theme_font_size("font_size");var missing:Array=[]
	for at in label.text.length():
		if not font.has_char(label.text.unicode_at(at)):missing.append(label.text[at])
	return {"text":label.text,"rect":label.get_rect(),"minimum":label.get_combined_minimum_size(),"shapeSize":font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,height),"fontHeight":font.get_height(height),"fontSize":height,"fontApplied":str(label.get_meta("native_font_applied","")),"fontResource":str(label.get_meta("native_font_resource","")),"color":label.get_theme_color("font_color"),"modulate":label.modulate,"clip":label.clip_text,"missing":missing,"sourceRect":entry.rect,"sourceCaption":entry.get("caption",{}),"sourceHooks":entry.get("model",{}).get("hooks",{})}
static func glyph_ink(label:Label)->Dictionary:
	var font:FontFile=label.get_theme_font("font");var height:=label.get_theme_font_size("font_size");var cache:=Vector2i(height,0);var advance:=0.0;var ink:=Rect2();var present:=false
	var extent:=font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,height);var origin:=Vector2.ZERO
	if label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER:origin.x=(label.size.x-extent.x)*.5
	elif label.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT:origin.x=label.size.x-extent.x
	if label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER:origin.y=(label.size.y-font.get_height(height))*.5
	elif label.vertical_alignment==VERTICAL_ALIGNMENT_BOTTOM:origin.y=label.size.y-font.get_height(height)
	origin+=Vector2(0,font.get_ascent(height))
	for at in label.text.length():
		var glyph:=font.get_glyph_index(height,label.text.unicode_at(at),0);var index:=font.get_glyph_texture_idx(0,cache,glyph);var uv:=font.get_glyph_uv_rect(0,cache,glyph);var offset:=font.get_glyph_offset(0,cache,glyph)
		if index>=0:
			var image:Image=font.get_texture_image(0,cache,index)
			for y in int(uv.size.y):
				for x in int(uv.size.x):
					if image.get_pixel(int(uv.position.x)+x,int(uv.position.y)+y).a<=0:continue
					var pixel:=Rect2(label.position+origin+offset+Vector2(advance+x,y),Vector2.ONE);ink=ink.merge(pixel) if present else pixel;present=true
		advance+=font.get_glyph_advance(0,height,glyph).x
	return {"present":present,"rect":ink}
