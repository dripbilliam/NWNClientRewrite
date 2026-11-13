extends RefCounted
# CPU focus/vision sample, not the enhanced fragment-light equation.
# Contract: caller supplies the admitted physical light order and fade factors.
# Native XYZ coordinates retain magnitude operation order. No SceneTree reads.
const F=preload("res://systems/native_render/native_light_policy.gd")
var active:=false
static func vector(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
static func sample(input: Dictionary) -> Vector3:
	var point:=vector(input.point); var result:=Vector3.ZERO
	var excluded: Dictionary={}
	if input.get("exclusion_list",true):
		for index in input.get("excluded",[]): excluded[int(index)]=true
	var lights: Array=input.get("lights",[])
	for index in lights.size():
		if excluded.has(index): continue
		var row: Dictionary=lights[index]
		var distance: float=(vector(row.get("position",[0,0,0]))-point).length()
		if distance==0: distance=F.f(.000001)
		var radius:=F.f(float(row.get("radius",0)))
		if radius==0: radius=F.f(.01)
		var attenuation:=F.f(1.0-F.f(distance/radius))
		if attenuation>=0: result+=vector(row.color)*attenuation*F.f(float(row.get("fade",1)))
	if input.get("headlight",false):
		result+=vector(input.get("headlight_diffuse",[0,0,0])); result+=vector(input.get("headlight_ambient",[0,0,0]))
	for key in ["ambient","diffuse"]:
		var row: Variant=input.get(key)
		if row!=null: result+=vector(row.color)*F.f(float(row.get("fade",1)))
	return Vector3(minf(result.x,1.0),minf(result.y,1.0),minf(result.z,1.0))
func select(value: Vector3,present: bool=true) -> bool:
	# Missing scene returns false without replacing the remembered threshold state.
	if not present: return false
	var magnitude: float=value.length()
	if magnitude<=float(F.f(.35))*1.732: active=true
	elif magnitude>=float(F.f(.5))*1.732: active=false
	return active
