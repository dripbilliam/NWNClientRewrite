extends RefCounted
# Original point-source portion only; ambient/noise WindManager is separate.
const M=preload("res://systems/native_render/particle_math.gd")
static func empty() -> Dictionary: return {"records":[],"capacity":0}
static func add(list: Dictionary,position: Array,radius: float,duration: float,strength: float) -> void:
	if list.records.size()==int(list.capacity): list.capacity=16 if int(list.capacity)==0 else int(list.capacity)*2
	list.records.append({"position":M.values(position),"radius":M.f(radius),"duration":M.f(duration),"remaining":M.f(duration),"strength":M.f(strength)})
static func advance(list: Dictionary,delta: float) -> void:
	delta=M.f(delta); var index:=0
	while index<list.records.size():
		var wind: Dictionary=list.records[index]; wind.remaining=M.f(M.f(wind.remaining)-delta)
		if wind.remaining<0: list.records.remove_at(index)
		else: index+=1
static func sample(list: Dictionary,position: Array) -> Array:
	var result:=[0.0,0.0,0.0]; var point:=M.values(position)
	for wind in list.records:
		var radius:=M.f(wind.radius); var delta:=M.subtract(point,wind.position)
		if absf(delta[0])>radius or absf(delta[1])>radius or absf(delta[2])>radius: continue
		var squared:=M.f(M.f(M.f(delta[1]*delta[1])+M.f(delta[0]*delta[0]))+M.f(delta[2]*delta[2]))
		if not (squared<M.f(radius*radius)): continue
		var distance:=M.f(sqrt(squared)); var direction:=delta
		if distance!=0:
			var reciprocal:=M.f(1.0/distance)
			direction=delta.map(func(value):return M.f(value*reciprocal))
		var unit:=M.normalize(direction)
		var scale_value:=M.f(M.f(M.f(radius-distance)*M.f(wind.strength))/radius)
		for axis in 3: result[axis]=M.f(result[axis]+M.f(scale_value*unit[axis]))
	return result
