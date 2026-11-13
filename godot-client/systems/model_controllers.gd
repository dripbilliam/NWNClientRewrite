extends RefCounted

# Runtime-remapped controller records, not serialized disk type identifiers.
# Sampling/control/hierarchy preserve binary32 grouping from the reviewed
# owners at 1400512c0, 140051530, 140051750, 140051c50 and 14004fe90.
static var scalar_values:=preload("res://systems/native_data/scalar_representation.gd").configured()
static func f(value: float) -> float:
	return Color(value,0,0,0).r if scalar_values else PackedFloat32Array([value])[0]

static func read_value(node: Dictionary, index: int) -> float:
	assert(index >= 0 and index < node.values88.size(), "Native controller storage is unavailable")
	return f(node.values88[index])

static func bezier(a: float, b: float, c: float, d: float, time: float) -> float:
	a = f(a); b = f(b); c = f(c); d = f(d); time = f(time)
	var u := f(1 - time)
	var middle := f(f(u * c) + f(d * time))
	var left := f(f(f(f(u * a) + f(c * time)) * u) + f(middle * time))
	var right := f(f(f(f(u * d) + f(b * time)) * time) + f(middle * u))
	return f(f(left * u) + f(right * time))

static func interval(controller: Dictionary, time: float, node: Dictionary) -> Array:
	var rows := int(controller.rows4) & 65535
	var base := int(controller.timeIndex6) & 65535
	var index := 0
	var t := 1.0
	while index < rows:
		if not (time > read_value(node, base + index)): break
		index += 1
	if index != 0 and index != rows:
		t = f(f(time - read_value(node, base + index - 1)) / f(read_value(node, base + index) - read_value(node, base + index - 1)))
	return [index, t]

static func scalar(controller: Dictionary, time: float, node: Dictionary, output: Array) -> int:
	var flags := int(controller.columnsA) & 255
	if (flags & 15) != 1: return 0
	time = f(time)
	var rows := int(controller.rows4) & 65535
	var base := int(controller.valueIndex8) & 65535
	var range_value := interval(controller, time, node)
	var index: int = range_value[0]
	var t: float = range_value[1]
	var value: float
	if index == 0: value = read_value(node, base)
	elif index == rows:
		if (flags & 240) == 16:
			var at := ((index - 1) * 3 + base) & 65535
			value = bezier(read_value(node, at), read_value(node, at + 3), read_value(node, at + 2), read_value(node, at + 4), time)
		else: value = read_value(node, base + rows - 1)
	elif (flags & 240) == 16:
		var at := ((index - 1) * 3 + base) & 65535
		var a := read_value(node, at)
		var c := read_value(node, at + 2)
		value = bezier(a, f(a + read_value(node, at + 3)), c, f(c + read_value(node, at + 4)), t)
	else: value = f(f(f(1 - t) * read_value(node, base + index - 1)) + f(t * read_value(node, base + index)))
	output[0] = value
	return 1

static func vector(controller: Dictionary, time: float, node: Dictionary, output: Array, position_scale: float) -> int:
	var flags := int(controller.columnsA) & 255
	if (flags & 15) != 3: return 0
	time = f(time)
	var rows := int(controller.rows4) & 65535
	var base := int(controller.valueIndex8) & 65535
	var scale_value := f(position_scale) if int(controller.displacement0) == 16 else 1.0
	var range_value := interval(controller, time, node)
	var index: int = range_value[0]
	var t: float = range_value[1]
	for axis in 3:
		if index == 0: output[axis] = f(read_value(node, (base + axis) & 65535) * scale_value)
		elif (flags & 240) == 16:
			var at := ((index - 1) * 9 + base) & 65535
			var a := read_value(node, at + axis)
			var b := read_value(node, at + 9 + axis)
			output[axis] = f(bezier(a, b, f(a + read_value(node, at + 6 + axis)), f(b + read_value(node, at + 12 + axis)), t) * scale_value)
		else:
			var at := ((index - 1) * 3 + base) & 65535
			var a := read_value(node, (at + axis) & 65535)
			output[axis] = f((a if index == rows else f(f(read_value(node, (at + axis + 3) & 65535) * t) + f(f(1 - t) * a))) * scale_value)
	return 1

static func dot(left: Array, right: Array) -> float:
	return f(f(f(f(f(right[0]) * f(left[0])) + f(f(right[1]) * f(left[1]))) + f(f(right[2]) * f(left[2]))) + f(f(right[3]) * f(left[3])))

static func slerp(left: Array, right: Array, time: float) -> Array:
	time = f(time)
	if dot(left, right) < 0:
		for axis in 4: left[axis] = f(-f(left[axis]))
	var cosine := dot(left, right)
	if absf(cosine) >= 1: return left.map(f)
	var angle := f(acos(cosine))
	if angle == 0: return left.map(f)
	var scaled := f(angle * time)
	var denominator := f(sin(angle))
	var b := f(f(sin(scaled)) / denominator)
	var a := f(f(sin(f(angle - scaled))) / denominator)
	var output: Array = []
	for axis in 4: output.append(f(f(f(right[axis]) * b) + f(f(left[axis]) * a)))
	return output

static func quaternion_at(node: Dictionary, at: int) -> Array:
	return [read_value(node, at + 3), read_value(node, at), read_value(node, at + 1), read_value(node, at + 2)]

static func quaternion(controller: Dictionary, time: float, node: Dictionary, output: Array) -> int:
	if (int(controller.columnsA) & 15) != 4: return 0
	time = f(time)
	var rows := int(controller.rows4) & 65535
	var base := int(controller.valueIndex8) & 65535
	var range_value := interval(controller, time, node)
	var index: int = range_value[0]
	var t: float = range_value[1]
	var value: Array
	if index == 0: value = quaternion_at(node, base)
	elif index == rows: value = quaternion_at(node, base + index * 4 - 4)
	else: value = slerp(quaternion_at(node, base + index * 4 - 4), quaternion_at(node, base + index * 4), t)
	output.assign(value)
	return 1

static func control(node: Dictionary, part: Variant, previous: float, time: float, weight: float, p: Dictionary) -> void:
	previous = f(previous); time = f(time); weight = f(weight)
	var index := 0
	while index < int(node.controllerCount80):
		var controller: Dictionary = node.controllers78[index]
		var kind := int(controller.columnsA) & 15
		var offset := int(controller.displacement0)
		if kind in [1, 3]:
			var output: Array = [0.0] if kind == 1 else [0.0, 0.0, 0.0]
			if kind == 1: scalar(controller, time, node, output)
			else: vector(controller, time, node, output, p.positionScale.call() if offset == 16 else 1.0)
			var values: Array = p.read.call(part, offset, kind)
			for axis in kind: values[axis] = f(f(f(1 - weight) * f(values[axis])) + f(output[axis] * weight))
			p.write.call(part, offset, values)
		elif kind == 4:
			var output: Array = [1.0, 0.0, 0.0, 0.0]
			quaternion(controller, time, node, output)
			p.write.call(part, offset, slerp(p.read.call(part, offset, 4).map(f), output, weight))
		if p.activeMotionRun.call(): p.motion.call(node.controllers78[index], part, node, previous, time)
		index += 1

static func hierarchy(part: Dictionary, node: Dictionary, previous: float, time: float, weight: float, context: Dictionary, p: Dictionary) -> void:
	context.depth = int(context.depth) + 1
	previous = f(previous); time = f(time); weight = f(weight)
	if int(part.dirty60) == 0:
		p.control.call(node, part, previous, time, weight)
		var light: Variant = p.light.call(part)
		if light != null and int(light.field8c) == 0: p.animateStaticLight.call(part.owner50, light)
	if context.depth < 1000:
		for index in int(part.childCount40):
			var count := int(node.childCount70)
			if count <= 0: continue
			var child: Dictionary = part.children38[index]
			for offset in count:
				var candidate: Dictionary = node.children68[(index + offset) % count]
				if int(child.id30) == int(candidate.id34):
					hierarchy(child, candidate, previous, time, weight, context, p)
					break
	context.depth = int(context.depth) - 1

# Child arguments already contain exactly representable binary32 values. Keep
# the original physical walk/callback order while avoiding repeated idempotent
# PackedFloat32Array conversions at every recursive entry. Retain hierarchy()
# unchanged as the measured reference and rollback.
static func hierarchy_root(part: Dictionary,node: Dictionary,previous: float,time: float,weight: float,context: Dictionary,p: Dictionary) -> void:
	_hierarchy_quantized(part,node,f(previous),f(time),f(weight),context,p)
static func _hierarchy_quantized(part: Dictionary,node: Dictionary,previous: float,time: float,weight: float,context: Dictionary,p: Dictionary) -> void:
	context.depth=int(context.depth)+1
	if int(part.dirty60)==0:
		p.control.call(node,part,previous,time,weight)
		var light: Variant=p.light.call(part)
		if light!=null and int(light.field8c)==0: p.animateStaticLight.call(part.owner50,light)
	if context.depth<1000:
		for index in int(part.childCount40):
			var count:=int(node.childCount70)
			if count<=0: continue
			var child: Dictionary=part.children38[index]
			for offset in count:
				var candidate: Dictionary=node.children68[(index+offset)%count]
				if int(child.id30)==int(candidate.id34):
					_hierarchy_quantized(child,candidate,previous,time,weight,context,p)
					break
	context.depth=int(context.depth)-1
