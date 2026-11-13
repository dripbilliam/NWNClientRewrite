extends RefCounted
# Presentation adaptation over the unchanged original conversation flow/poses.
# The parent's canvas transform, rather than physical viewport pixels, determines
# how much logical UI space remains after user interface scaling.
const MARGIN:=4.0
const NATIVE_MINIMUM:=Vector2(360,404)
static func space(viewport: Rect2,parent_canvas: Transform2D,native_minimum: Vector2=NATIVE_MINIMUM) -> Dictionary:
	if not viewport.position.is_finite() or not viewport.size.is_finite() or viewport.size.x<=0 or viewport.size.y<=0 or not native_minimum.is_finite() or native_minimum.x<=0 or native_minimum.y<=0 or not is_finite(parent_canvas.determinant()) or is_zero_approx(parent_canvas.determinant()):return {}
	var bounds: Rect2=parent_canvas.affine_inverse()*viewport
	if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x<=0 or bounds.size.y<=0:return {}
	var margin:=minf(MARGIN,minf(bounds.size.x,bounds.size.y)*0.1)
	bounds=bounds.grow(-margin)
	var fit:=minf(1.0,minf(bounds.size.x/native_minimum.x,bounds.size.y/native_minimum.y))
	return {"bounds":bounds,"scale":maxf(0.001,fit)}
static func clearance(space_value: Dictionary,position: Vector2) -> float:
	if space_value.is_empty():return 0
	var bounds: Rect2=space_value.bounds
	return maxf(0,(bounds.end.y-clampf(position.y,bounds.position.y,bounds.end.y))/float(space_value.scale)-MARGIN)
static func clamp_position(space_value: Dictionary,position: Vector2,native_size: Vector2) -> Vector2:
	if space_value.is_empty():return position
	var bounds: Rect2=space_value.bounds
	return position.clamp(bounds.position,(bounds.end-native_size*float(space_value.scale)).max(bounds.position))
static func reply_width(viewport_width: float) -> Dictionary:
	var total:=maxf(1,viewport_width)
	var indent:=minf(20,maxf(0,total-1))
	return {"total":total,"indent":indent,"text":maxf(1,total-indent),"number":minf(16,indent)}
