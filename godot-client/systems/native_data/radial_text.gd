extends RefCounted
const M=preload("res://systems/native_render/particle_math.gd")
const Trig=preload("res://systems/native_render/particle_trig.gd")
# Original CGuiTextBubble::SetText1fd690 scans g_pBubbleModels in this order.
# Geometry is compiled policy; text metrics/artwork belong to the active catalog.
const BUBBLES=[[100,20,"pnl_bubble1_100"],[150,20,"pnl_bubble1_150"],[100,34,"pnl_bubble2_100"],[150,34,"pnl_bubble2_150"],[100,48,"pnl_bubble3_100"],[150,48,"pnl_bubble3_150"],[300,20,"pnl_bubble1_300"],[300,34,"pnl_bubble2_300"],[300,48,"pnl_bubble3_300"],[300,62,"pnl_bubble4_300"],[300,76,"pnl_bubble5_300"],[300,104,"pnl_bubble7_300"],[300,146,"pnl_bubble10_300"],[300,230,"pnl_bubble16_300"],[300,454,"pnl_bubble32_300"]]
const DIALOG_FONT="ttf fnt_default 14" # CTlkTable::s_szFontName_Dialog_Default.
static func edge_sine(ratio: float) -> float:
	return Trig.sine(M.f(M.f(ratio*M.f(3.1415927))*0.5))
# FixAttachedText1f8ba0 uses integer viewport/center coordinates with Y up.
# Preserve its edge-dependent alignment, including values outside0..1.
static func alignment(slot: int,origin: Vector2,screen: Vector2,dimensions: Vector2,hide_icons: bool,centered: bool,mode: int,scale_value: float=1.0) -> Vector2:
	if centered: return Vector2(0.5,0.5)
	var width:=M.f(scale_value*dimensions.x); var height:=M.f(scale_value*dimensions.y)
	var extent:=int(floor(M.f(scale_value*(100.0 if hide_icons else 155.0))+0.5))
	var corner:=29.0 if hide_icons else 45.0; var weight:=0.0 if hide_icons else 1.0
	var x:=0.5 if slot in [0,4] else 0.0 if slot in [1,2,3] else 1.0
	var y:=0.5
	match slot:
		0:
			var overflow:=M.f(M.f(float(int(origin.y)+extent)+M.f(height*0.5))-float(int(screen.y)))
			if overflow>0:
				var ratio:=M.f(overflow/height); y=M.f(1.0-M.f(ratio+ratio))
		1,3:
			var overflow:=M.f(M.f(M.f(float(int(origin.x)+extent)+width)-corner)-float(int(screen.x)))
			if overflow>0:
				x=M.f(overflow/width); var sine:=edge_sine(x)
				if slot==3: sine=M.f(-sine)
				y=M.f(M.f(sine*weight)+0.5)
		2:
			var overflow:=M.f(M.f(float(int(origin.x)+extent)+width)-float(int(screen.x)))
			if overflow>0:
				x=M.f(overflow/width); var sine:=edge_sine(x)
				y=M.f(M.f(M.f(sine*(-2.5 if mode==1 else -1.5))*weight)+0.5)
		4:
			var overflow:=M.f(float(int(origin.y)-extent)-M.f(height*0.5))
			if overflow<0:
				var ratio:=M.f(-M.f(overflow/height)); y=M.f(ratio+ratio)
		5,7:
			var overflow:=M.f(M.f(float(int(origin.x)-extent)-width)+corner)
			if overflow<0:
				var ratio:=M.f(-M.f(overflow/width)); var sine:=edge_sine(ratio)
				if slot==5: sine=M.f(-sine)
				x=M.f(1.0-ratio); y=M.f(M.f(sine*weight)+0.5)
		6:
			var overflow:=M.f(float(int(origin.x)-extent)-width)
			if overflow<0:
				var ratio:=M.f(-M.f(overflow/width)); var sine:=M.f(edge_sine(ratio)*(-2.5 if mode==1 else -1.5))
				x=M.f(1.0-ratio); y=M.f(M.f(sine*weight)+0.5)
	return Vector2(x,y)
# FixAlignment1fd480 moves the original root in model units, retaining the
# multiplication order before the GUI's100-pixels-per-unit projection.
static func root_offset(value: Vector2,dimensions: Vector2) -> Vector2:
	return Vector2(M.f(M.f(value.x*dimensions.x)*M.f(-0.01)),M.f(M.f(value.y*dimensions.y)*M.f(0.01)))
static func choose(font: Font,size: int,text: String,minimum_lines: int=1,indent: float=0.0) -> Array:
	for bubble in BUBBLES.slice(0,14):
		if minimum_lines>1 and int(float(bubble[1])/maxf(1,font.get_height(size)))<minimum_lines: continue
		var width:=M.f(float(bubble[0])-indent)
		var extent:=font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_CENTER,width,size)
		if extent.x<=width+0.01 and extent.y<=float(bubble[1])+0.01: return bubble
	return BUBBLES[-1]
