extends Control
# Canvas equivalent of NativeBitmapFont.render's pixel-sized canvas. Layout is
# computed by native_data/bitmap_font.gd and colored atlas images are owned by
# the font instance, so all floating rows share its 64-tint insertion cache.
var font_owner
var font_name: String=""
var glyphs: Array=[]
var colored: Dictionary={}
var failure: String=""
func configure(owner,name: String,layout: Dictionary) -> void:
	font_owner=owner; font_name=name; glyphs=layout.get("glyphs",[])
	custom_minimum_size=Vector2(float(layout.get("width",1)),float(layout.get("height",1)))
	size=custom_minimum_size
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for glyph in glyphs:
		if int(glyph.sw)==0 or int(glyph.sh)==0:continue
		var color:=str(glyph.color).to_lower()
		if colored.has(color):continue
		var tinted: Dictionary=font_owner.tinted_atlas(font_name,color)
		if tinted.has("error"):
			failure=str(tinted.error)
			return
		colored[color]=tinted.texture
	queue_redraw()
func _draw() -> void:
	if not failure.is_empty():return
	for glyph in glyphs:
		if int(glyph.sw)==0 or int(glyph.sh)==0:continue
		var texture: Texture2D=colored.get(str(glyph.color).to_lower())
		if texture==null:continue
		draw_texture_rect_region(texture,Rect2(float(glyph.x),float(glyph.y),float(glyph.width),float(glyph.height)),Rect2(float(glyph.sx),float(glyph.sy),float(glyph.sw),float(glyph.sh)))
