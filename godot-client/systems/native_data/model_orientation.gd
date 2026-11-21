extends RefCounted
# Direct data-only translation of mdl_format.js::decodeModelOrientation.
static func decode(orientation: Variant, format: String="quaternion") -> Array:
	if not orientation is Array or orientation.size()<4:return [0.0,0.0,0.0,1.0]
	for index in 4:
		if not orientation[index] is int and not orientation[index] is float:return [0.0,0.0,0.0,1.0]
		if not is_finite(float(orientation[index])):return [0.0,0.0,0.0,1.0]
	var x:=float(orientation[0]);var y:=float(orientation[1]);var z:=float(orientation[2]);var w:=float(orientation[3])
	if format=="axis-angle":
		var axis_length:=sqrt(x*x+y*y+z*z)
		if axis_length<1e-8 or absf(w)<1e-8:return [0.0,0.0,0.0,1.0]
		var half_angle:=w*0.5;var scale:=sin(half_angle)/axis_length
		return [x*scale,y*scale,z*scale,cos(half_angle)]
	var length:=sqrt(x*x+y*y+z*z+w*w)
	if length<1e-8:return [0.0,0.0,0.0,1.0]
	return [x/length,y/length,z/length,w/length]
