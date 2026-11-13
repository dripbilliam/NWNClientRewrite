extends RefCounted
const Rich=preload("res://systems/native_data/rich_text.gd")
const Caption=preload("res://systems/native_data/nameplate_state.gd")
const F=preload("res://systems/native_render/particle_math.gd")
static func project(item: Dictionary,text,actor: int) -> Dictionary:
	# Original inventory shared883340 uses the display name without the gold
	# world-name wrapper, then item primary+16c/+170's override mode/string.
	var name: String=text.raw(item.get("name",{}),actor)
	return Caption.override_caption(name,Caption.integer(item.get("field2b8",0)),str(item.get("field2c0","")))
static func merchant_below(row: Dictionary) -> bool:
	# Repository882580 compares the hovered LOCAL cell row with2. Merchant
	# repositories use10 rows; paged raw item coordinates can exceed that.
	return str(row.get("channel",""))=="M" and int(row.get("y",99))%10<2
static func position_at(pointer: Vector2,viewport: Vector2,dimensions: Vector2,below: bool,ui_scale: float=1.0) -> Vector2:
	# ShowTooltipText1f6df0 returns a left/bottom text-box anchor in logical
	# pixels. The native Control's origin is the top left, hence subtract height.
	var scale_value:=F.f(ui_scale)
	var x:=roundf(F.f(F.f(pointer.x/scale_value)+12.0))
	x=minf(x,roundf(F.f(F.f(viewport.x/scale_value)-dimensions.x)))
	var y:=roundf(F.f(F.f(pointer.y/scale_value)-40.0))
	if y<dimensions.y or below:
		y=roundf(F.f(F.f(F.f(pointer.y/scale_value)+dimensions.y)+14.0))
		y=minf(y,roundf(F.f(viewport.y/scale_value)))
	return Vector2(x,y-dimensions.y)*scale_value
