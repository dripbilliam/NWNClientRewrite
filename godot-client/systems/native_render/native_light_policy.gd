extends RefCounted
# Enhanced NWN light inputs: GetLightAdjustedColor/Radius, SetLightGL and
# SetUniforms. Constants are the verified native defaults/current live settings.
# pow() follows Godot's float math boundary; bit-identical native CRT rounding
# is not claimed. Authored multiplier changes range, not RGB energy.
static func f(value: float) -> float: return Vector3(value,0,0).x
static func requested() -> bool: return OS.get_cmdline_user_args().has("--native-lighting=enhanced")
static func linear(value: float) -> float: return f(pow(f(value),f(2.2))) if value>0 and value!=1 else f(value)
static func linear_rgb(value: Array) -> Vector3: return Vector3(linear(value[0]),linear(value[1]),linear(value[2]))
static func point(properties: Dictionary,cutoff: float=2.0,at_range: float=0.2,maximum: float=1.5,fade: float=1.0) -> Dictionary:
	var source: Array=properties.get("color",[1.0,1.0,1.0]); var color:=Vector3(source[0],source[1],source[2])
	var radius:=f(float(properties.get("radius",0))); var multiplier:=f(float(properties.get("multiplier",1)))
	if radius<1000:
		var peak:=maxf(color.x,maxf(color.y,color.z))
		radius=f(radius*multiplier)
		if peak>1: radius=f(radius*peak); color*=f(1.0/peak)
		radius=f(f(cutoff)*radius)
	# SetLightGL multiplies adjusted raw RGB by Part fade before pow(2.2).
	# Fade never shrinks the source's adjusted support radius.
	color=Vector3(f(color.x*f(fade)),f(color.y*f(fade)),f(color.z*f(fade)))
	var inverse:=f(pow(f(maximum),f(-2.2)))
	var factor:=f(f(f(pow(f(at_range),f(-2.2)))-inverse)*f(f(cutoff)*f(cutoff)))
	return {"color":Vector3(linear(color.x),linear(color.y),linear(color.z)),"range":radius,"inverse":inverse,"factor":factor,"ambient":float(properties.get("ambientonly",0))!=0,"enabled":radius>0}
static func attenuation(distance: float,state: Dictionary) -> float:
	if not state.enabled or distance<0: return 0
	var q: float=distance*distance/(state.range*state.range)
	return (1.0-q)/(state.inverse+state.factor*q) if q<1 else 0.0
