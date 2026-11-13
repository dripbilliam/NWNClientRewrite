extends TextureRect
# One native model raster, cropped at original pixel density while a pane
# resizes. Only the flat background may widen; glyphs and bar endcaps do not.
var source_texture: Texture2D:
	set(value): source_texture=value; crop()
var desired:=Vector2.ZERO
var art
func configure(owner,resource: String,region: Rect2) -> void:
	art=owner; mouse_filter=Control.MOUSE_FILTER_IGNORE; expand_mode=TextureRect.EXPAND_IGNORE_SIZE; stretch_mode=TextureRect.STRETCH_SCALE
	art.bind(self,resource,"source_texture",true,"",false,{},region)
func resize_background(extent: Vector2) -> void:
	desired=extent; size=extent; crop()
func crop() -> void:
	if source_texture==null or desired.y<=0: texture=null; return
	var atlas:=AtlasTexture.new(); atlas.atlas=source_texture; atlas.region=Rect2(0,0,source_texture.get_width(),minf(desired.y,source_texture.get_height())); texture=atlas
func close() -> void:
	if is_instance_valid(art): art.unbind(self,"source_texture")
	source_texture=null; art=null
