extends RefCounted
# Original LightManager::PrioritizeLights14007ff60. Executed original corpus
# verifies the explicit float32 boundaries; this is not a renderer/view test.
static func f(value: float) -> float:return Vector3(value,0,0).x
static func rank(properties: Dictionary,position: Array,focus: Array,override_value: int=0,only_owner: bool=false) -> Dictionary:
	var d: Array=[]
	for index in 3:d.append(f(f(position[index])-f(focus[index])))
	var distance:=f(sqrt(f(f(f(d[1]*d[1])+f(d[0]*d[0]))+f(d[2]*d[2]))))
	var colour: Array=properties.get("color",[0,0,0]);var peak:=maxf(absf(f(colour[0])),maxf(absf(f(colour[1])),absf(f(colour[2]))))
	var radius:=f(float(properties.get("radius",0)));var multiplier:=f(float(properties.get("multiplier",1)));var score:=100000.0
	if peak>0 and radius>0 and multiplier>0:
		if only_owner:score=-1
		else:
			var priority:=override_value if override_value!=0 else int(properties.get("lightpriority",4))
			var strength:=f(f(multiplier*radius)*peak) if float(properties.get("fadinglight",0))!=0 else 20.0
			score=f(f(f(float(priority+1))*distance)/f(f(float(int(properties.get("isdynamic",0))+4))*f(strength+1)))
	return {"distance":distance,"priority":score}
static func casts(properties: Dictionary) -> bool:
	# PrioritizeShadow1400801b0: raw positive RGB, shadow and nonambient.
	var colour: Array=properties.get("color",[0,0,0])
	return float(properties.get("shadow",0))!=0 and float(properties.get("ambientonly",0))==0 and (f(colour[0])>f(.1) or f(colour[1])>f(.1) or f(colour[2])>f(.1))
