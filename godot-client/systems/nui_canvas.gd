extends Control
var element
var order := 1
var commands: Array = []
var chart: Array = []
var image_id := -1
var image_aspect := 0
var image_halign := 0
var image_valign := 0

func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
# The JS NUI renderer uses truthiness for draw-list fill, including bound JSON
# values. GDScript's bool constructor rejects null, strings and containers.
static func draw_fill(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL: return false
		TYPE_BOOL: return value
		TYPE_INT, TYPE_FLOAT: return value != 0 and not is_nan(float(value))
		TYPE_STRING: return not value.is_empty()
		TYPE_ARRAY, TYPE_DICTIONARY: return true
	return false
static func draw_number(value: Variant, fallback: float = 0.0) -> float:
	var result := fallback
	if value is int or value is float: result = float(value)
	elif value is bool: result = 1.0 if value else 0.0
	elif value is String:
		var text: String = value.strip_edges()
		if text.is_empty(): result = 0.0
		elif text.is_valid_float(): result = text.to_float()
	return result if is_finite(result) else fallback
static func draw_integer(value: Variant, fallback: int = 0) -> int:
	# Draw enums/handles are 32-bit fields. Avoid overflowing an int constructor.
	return int(clampf(draw_number(value, fallback), -2147483648.0, 2147483647.0))
static func _svg_number(value: Variant, nullish_default: float=0.0) -> float:
	if value==null:return nullish_default
	if value is bool:return 1.0 if value else 0.0
	if value is int or value is float:return float(value)
	if value is String:
		var source: String=value.strip_edges()
		if source.is_empty():return 0.0
		if source.is_valid_float():return source.to_float()
	return NAN
func rgba(value: Variant) -> Color:
	if not value is Dictionary: return Color.WHITE
	return Color(clampf(draw_number(value.get("r"),255),0,255)/255,clampf(draw_number(value.get("g"),255),0,255)/255,clampf(draw_number(value.get("b"),255),0,255)/255,clampf(draw_number(value.get("a"),255),0,255)/255)
func vector(value: Variant) -> Vector2:
	return Vector2(draw_number(value.get("x")), draw_number(value.get("y"))) if value is Dictionary else Vector2.ZERO
func rectangle(value: Variant) -> Rect2:
	return Rect2(vector(value), Vector2(maxf(0, draw_number(value.get("w"))), maxf(0, draw_number(value.get("h"))))) if value is Dictionary else Rect2()
static func supported_type(value: Variant) -> bool:
	var kind:=draw_number(value,-1)
	return is_finite(kind) and kind==floor(kind) and kind>=0 and kind<=7
static func admitted(item: Dictionary,pass_order: int,hovered: bool,pointer_button: int) -> bool:
	if (-1 if draw_number(item.get("order"),1.0)==-1.0 else 1)!=pass_order:return false
	var render:=draw_number(item.get("render"))
	if render==1 and hovered or render==2 and not hovered:return false
	if render>=3:
		var buttons:={3:0,4:2,5:1}
		if buttons.has(int(render)) and render==floor(render):return pointer_button==buttons[int(render)]
		return pointer_button==-1
	return true
func _admitted(item: Dictionary) -> bool:
	return admitted(item,order,element.hovered,element.pointer_button)
static func unsupported_command(item: Dictionary) -> String:
	var original: Variant=item.get("source_type","undefined")
	var error_key:="undefined" if original is StringName else "null" if original==null else "true" if original is bool and original else "false" if original is bool else "[object Object]" if original is Dictionary else str(original)
	return "Unsupported NUI draw command "+error_key
static func _ellipse_segments(radius: float) -> int:
	if radius<=0 or not is_finite(radius):return 0
	if radius>1000000.0:return 2048
	return clampi(ceili(PI/acos(1.0-minf(1.0,0.25/radius))),24,2048)
static func _flat_cubic(a: Vector2,c0: Vector2,c1: Vector2,b: Vector2) -> bool:
	var chord:=b-a
	if chord.length_squared()<0.000001:return maxf(a.distance_to(c0),a.distance_to(c1))<=0.25
	var length:=chord.length()
	return maxf(absf(chord.cross(c0-a))/length,absf(chord.cross(c1-a))/length)<=0.25
static func _append_cubic(points: PackedVector2Array,a: Vector2,c0: Vector2,c1: Vector2,b: Vector2,depth: int=0) -> PackedVector2Array:
	if depth>=12 or _flat_cubic(a,c0,c1,b):points.append(b);return points
	var q0:=(a+c0)*0.5;var q1:=(c0+c1)*0.5;var q2:=(c1+b)*0.5
	var r0:=(q0+q1)*0.5;var r1:=(q1+q2)*0.5;var middle:=(r0+r1)*0.5
	points=_append_cubic(points,a,q0,r0,middle,depth+1)
	return _append_cubic(points,middle,r1,q2,b,depth+1)
func _stroke(points: PackedVector2Array,tint: Color,thickness: float,closed: bool=false) -> void:
	if points.size()<2 or not is_finite(thickness) or thickness<=0:return
	var outline:=points.duplicate()
	if closed:outline.append(points[0])
	draw_polyline(outline,tint,thickness,true)
func _shape(points: PackedVector2Array,tint: Color,fill: bool,thickness: float,closed: bool) -> void:
	if fill and points.size()>=3:draw_colored_polygon(points,tint)
	_stroke(points,tint,thickness,closed)
func _arc_points(item: Dictionary,fill: bool) -> PackedVector2Array:
	var center:=vector(item.get("c"));var radius:=_svg_number(item.get("radius"));var start:=_svg_number(item.get("amin"));var finish:=_svg_number(item.get("amax"))
	var points:=PackedVector2Array()
	if not is_finite(radius) or radius<0 or not is_finite(start) or not is_finite(finish):return points
	var first:=center+Vector2(cos(start),sin(start))*radius
	var last:=center+Vector2(cos(finish),sin(finish))*radius
	points.append(first)
	var chord:=last-first
	if radius>0 and chord.length_squared()>0.00000001:
		# SVG's A command chooses its circle from the two endpoints plus large
		# arc/sweep flags. This also handles authored angles outside one turn.
		var length:=chord.length();var effective_radius:=maxf(radius,length*0.5)
		var midpoint:=(first+last)*0.5
		var rise:=sqrt(maxf(0.0,effective_radius*effective_radius-length*length*0.25))
		var normal:=Vector2(-chord.y,chord.x)/length
		var sweep:=finish>=start;var large:=absf(finish-start)>PI
		var chosen:=midpoint+normal*rise;var sweep_angle:=0.0
		for candidate in [midpoint+normal*rise,midpoint-normal*rise]:
			var a0:=atan2(first.y-candidate.y,first.x-candidate.x)
			var a1:=atan2(last.y-candidate.y,last.x-candidate.x)
			var amount:=fposmod(a1-a0,TAU) if sweep else -fposmod(a0-a1,TAU)
			chosen=candidate;sweep_angle=amount
			if (absf(amount)>PI)==large:break
		var segments:=maxi(1,ceili(absf(sweep_angle)/TAU*_ellipse_segments(effective_radius)))
		var angle:=atan2(first.y-chosen.y,first.x-chosen.x)
		for step in range(1,segments+1):
			var at:=angle+sweep_angle*step/segments
			points.append(chosen+Vector2(cos(at),sin(at))*effective_radius)
	elif first!=last:points.append(last)
	if fill:points.append(center)
	return points
static func _stroke_width(value: Variant) -> float:
	if value==null:return 1.0
	if value is float or value is int:return float(value) if is_finite(float(value)) else 0.0
	if value is String:
		var source: String=value.strip_edges()
		if source.is_empty():return 0.0
		if not source.is_valid_float():return 0.0
		return float(source) if is_finite(float(source)) else 0.0
	return draw_number(value,1.0)
func picture(id: int, box: Rect2, aspect: int = 0, halign: int = 0, valign: int = 0) -> void:
	var texture = element.manager.resources.get(id)
	if not texture is Texture2D or box.size.x <= 0 or box.size.y <= 0: return
	var source: Vector2 = texture.get_size()
	if aspect == 5: draw_texture_rect(texture, box, false); return
	var scale := maxf(box.size.x / source.x, box.size.y / source.y) if aspect == 1 else minf(box.size.x / source.x, box.size.y / source.y)
	if aspect in [3, 4]: scale = 1
	elif aspect == 2: scale = minf(1, scale)
	var extent := source * scale
	var offset := Vector2((box.size.x - extent.x) * (0.5 if halign == 0 else (0 if halign == 1 else 1)), (box.size.y - extent.y) * (0.5 if valign == 0 else (0 if valign == 1 else 1)))
	if aspect == 1: draw_texture_rect_region(texture, box, Rect2(-offset / scale, box.size / scale))
	else: draw_texture_rect(texture, Rect2(box.position + offset, extent), false)
func _draw() -> void:
	if element == null: return
	if image_id >= 0: picture(image_id, Rect2(Vector2.ZERO, size), image_aspect, image_halign, image_valign)
	if not chart.is_empty(): draw_chart()
	# The browser checks unsupported command types only after the current
	# order/hover/button filter. Validate the same admitted layer before drawing
	# any shape, since a thrown SVG layer never gets appended to its host.
	for item in commands:
		if not item is Dictionary or not _admitted(item):continue
		if not supported_type(item.get("type")):
			element.manager.fail(unsupported_command(item))
			return
	for item in commands:
		if not item is Dictionary: continue
		if not _admitted(item):continue
		var tint := rgba(item.get("color")); var fill := draw_fill(item.get("fill")); var thickness := _stroke_width(item.get("line_thickness"))
		var box := rectangle(item.get("rect")); var a := vector(item.get("a")); var b := vector(item.get("b")); var points := PackedVector2Array()
		match int(item.get("type")):
			0:
				var raw: Array = item.points if item.get("points") is Array else []
				if not raw.is_empty() and (raw[0] is float or raw[0] is int):
					for index in floori(raw.size() / 2.0): points.append(Vector2(draw_number(raw[index * 2]), draw_number(raw[index * 2 + 1])))
				else:
					for value in raw: points.append(vector(value))
				_shape(points,tint,fill,thickness,fill)
			1:
				var c := vector(item.get("ctrl0")); var d := vector(item.get("ctrl1"))
				points.append(a);points=_append_cubic(points,a,c,d,b)
				# SVG's cubic path explicitly overrides fill to none.
				_stroke(points,tint,thickness)
			2:
				var raw_rect: Dictionary=item.get("rect",{}) if item.get("rect") is Dictionary else {}
				var xy:=vector(raw_rect);var width:=_svg_number(raw_rect.get("w"));var height:=_svg_number(raw_rect.get("h"))
				if not is_finite(width) or not is_finite(height):continue
				var ellipse_center:=xy+Vector2(width,height)*0.5;var radii:=Vector2(maxf(0,width*0.5),maxf(0,height*0.5))
				if radii.x>0 and radii.y>0:
					var segments:=_ellipse_segments(maxf(radii.x,radii.y))
					for index in segments:
						var angle:=index*TAU/segments;points.append(ellipse_center+Vector2(cos(angle),sin(angle))*radii)
					_shape(points,tint,fill,thickness,true)
			3:
				points=_arc_points(item,fill)
				_shape(points,tint,fill,thickness,fill)
			4:
				# SVG text inherits the host font when the draw command's font is
				# falsy. The authored skin font size can be fractional even though
				# Godot's glyph raster size is an integer.
				var font_value: Variant=item.get("font")
				var font_name:=str(font_value) if draw_fill(font_value) else str(element.values.get("font","(default)"))
				var font: Font=element.manager.font_for(font_name)
				var pixel_size: int=element.manager.font_size(font_name)
				var authored_size:=draw_number(element.manager.font_row(font_name).get("font_size",17),17.0)
				if authored_size==0.0:authored_size=17.0
				if authored_size>0.0:
					var factor:=authored_size/float(pixel_size)
					draw_set_transform(box.position,0.0,Vector2(factor,factor))
					draw_string(font,Vector2(0,font.get_ascent(pixel_size)),str(item.get("text","")),HORIZONTAL_ALIGNMENT_LEFT,-1,pixel_size,tint)
					draw_set_transform(Vector2.ZERO)
			5: picture(draw_integer(item.get("image"), -1), box, 5 if draw_number(item.get("image_aspect"))==5.0 else 0)
			6:
				if thickness>0:draw_line(a,b,tint,thickness,true)
			7:
				if box.size.x>0 and box.size.y>0:
					if fill:draw_rect(box,tint,true)
					if thickness>0:draw_rect(box,tint,false,thickness,true)
func draw_chart() -> void:
	if size.x<=0.0 or size.y<=0.0:return
	# The source chart uses viewBox="0 0 300 120" with
	# preserveAspectRatio="none". Transform the whole SVG coordinate frame,
	# including its authored 2-unit strokes and 4-unit point discs.
	draw_set_transform(Vector2.ZERO,0.0,size/Vector2(300.0,120.0))
	var minimum := 0.0; var maximum := 1.0
	for slot in chart:
		if not slot is Dictionary or not slot.get("data") is Array: continue
		for value in slot.data:
			if value==null:continue
			var number:=draw_number(value,NAN)
			if is_finite(number):minimum=minf(minimum,number);maximum=maxf(maximum,number)
	for slot in chart:
		if not slot is Dictionary: continue
		var data: Array = slot.data if slot.get("data") is Array else []; var segment := PackedVector2Array(); var dots := PackedVector2Array(); var tint: Color = rgba(slot.get("color"))
		var bars:=draw_number(slot.get("type"))==1.0
		for index in data.size():
			var number:=draw_number(data[index],NAN) if data[index]!=null else NAN
			if not is_finite(number):
				if not bars:_stroke(segment,tint,2.0)
				segment.clear()
				continue
			var point := Vector2(10 + index * 280.0 / maxi(1, data.size() - 1), 110 - (number - minimum) / (maximum - minimum) * 100)
			if bars:
				var width := 280.0 / maxi(1, data.size())
				draw_rect(Rect2(Vector2(10+index*width,point.y),Vector2(maxf(0,width-2),110-point.y)),tint)
			else:segment.append(point);dots.append(point)
		if not bars:
			_stroke(segment,tint,2.0)
			for point in dots:
				var disc:=PackedVector2Array()
				var circle_segments:=_ellipse_segments(4.0)
				for corner in circle_segments:
					var angle:=TAU*corner/circle_segments
					disc.append(point+Vector2(cos(angle)*4,sin(angle)*4))
				draw_colored_polygon(disc,tint)
	draw_set_transform(Vector2.ZERO)
