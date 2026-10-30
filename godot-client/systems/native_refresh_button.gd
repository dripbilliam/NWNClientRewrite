extends Button
# Client extension to the original browser header, in its black/brass palette.
# Draw a native vector icon rather than stretching source button artwork or
# relying on a Unicode glyph absent from the game's bitmap font.
func _init() -> void:
	custom_minimum_size=Vector2(30,30); size=custom_minimum_size; focus_mode=Control.FOCUS_NONE
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND; tooltip_text="Refresh servers"
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style:=StyleBoxFlat.new(); style.bg_color=Color("17140d") if state=="pressed" else Color("050604")
		style.border_color=Color("e9d6a3") if state=="hover" else Color("655d49") if state=="disabled" else Color("b9a16b")
		style.set_border_width_all(1); add_theme_stylebox_override(state,style)
func _draw() -> void:
	var center:=size*0.5; var radius:=7.0; var end:=TAU*0.93; var direction:=Vector2(cos(end),sin(end)); var tip:=center+direction*radius; var tangent:=direction.orthogonal()
	var tint:=Color("dfcc94"); if disabled: tint.a=0.35
	draw_arc(center,radius,TAU*0.16,end,32,Color.BLACK,4,true)
	draw_arc(center,radius,TAU*0.16,end,32,tint,2,true)
	draw_colored_polygon(PackedVector2Array([tip+tangent*3.0,tip-tangent*3.0+direction*3.0,tip-tangent*3.0-direction*3.0]),tint)
