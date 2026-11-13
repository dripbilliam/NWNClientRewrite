extends Control
# Keep the original portrait plane's UV crop, including its fractional inset.
# The native raster retains original bottom-left row order; these UVs own it.
var texture: Texture2D:
	set(value): texture=value; queue_redraw()
var uv:=PackedVector2Array()
func configure(plan: Dictionary) -> void:
	position=plan.rect.position; size=plan.rect.size; uv=plan.uv; mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	if texture==null or uv.size()!=4: return
	draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]),PackedColorArray([Color.WHITE]),uv,texture)
