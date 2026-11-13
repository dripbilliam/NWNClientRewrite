extends RefCounted
static var scalar_values:=preload("res://systems/native_data/scalar_representation.gd").configured()
static func f(v: float) -> float:return Color(v,0,0,0).r if scalar_values else PackedFloat32Array([v])[0]
static func normalize(v: Array) -> Array:
	var x := f(v[0]);var y := f(v[1]);var z := f(v[2]);var squared := f(f(f(x*x)+f(y*y))+f(z*z))
	if squared == 1 or (squared >= 0.9999899864196777 and squared <= 1.0000100135803223):return [x,y,z]
	if squared == 0:return [1.0,0.0,0.0]
	var scale := f(sqrt(f(1.0/squared)));return [f(x*scale),f(y*scale),f(z*scale)]
static func multiply(l: Array,r: Array) -> Array:
	var a := f(l[0]);var b := f(l[1]);var c := f(l[2]);var d := f(l[3]);var w := f(r[0]);var x := f(r[1]);var y := f(r[2]);var z := f(r[3])
	return [f(f(f(f(a*w)-f(b*x))-f(c*y))-f(d*z)),f(f(f(f(b*w)+f(a*x))+f(c*z))-f(d*y)),f(f(f(f(a*y)-f(b*z))+f(c*w))+f(d*x)),f(f(f(f(b*y)+f(a*z))-f(c*x))+f(d*w))]
static func arc(a: Array,b: Array) -> Array:
	a = normalize(a);b = normalize(b)
	var dot := f(f(f(b[0]*a[0])+f(b[1]*a[1]))+f(b[2]*a[2]))
	if dot <= -1:return [0.0,1.0,0.0,0.0]
	var scale := f(sqrt(f(f(dot+1)*2)))
	return [f(scale*f(0.5)),f(f(f(a[1]*b[2])-f(a[2]*b[1]))/scale),f(f(f(a[2]*b[0])-f(a[0]*b[2]))/scale),f(f(f(a[0]*b[1])-f(a[1]*b[0]))/scale)]
# Gob::ReattachReference140093b50, physical breadth-first ordering. Eligibility
# and callback-driven child replacement are not normalized into mesh traversal.
static func reattach(owner,target,name: String,p: Dictionary) -> void:
	var queue: Array = [p.root.call(owner)]
	assert(queue[0] != null,"Reference reattachment needs a physical root")
	while not queue.is_empty():
		var part = queue.pop_front();var reference = p.asReference.call(part)
		if reference != null:
			var header = reference.header8
			if header != null and (int(header.flags98)&0x11) == 0x11 and int(header.reattachableE0) != 0 and reference.model68 != null:
				p.attach.call(reference.model68,target if target != null else owner,name if target != null else p.name.call(reference),0)
				var child: Array = p.position.call(reference.model68);var position: Array = p.position.call(owner);var q: Array = p.orientation.call(owner)
				q = q.map(func(v):return f(v))
				var w := f(q[0]);var x := f(q[1]);var y := f(q[2]);var z := f(q[3])
				var delta: Array = [0,1,2].map(func(i):return f(f(child[i])-f(position[i])))
				var xx := f(f(x*x)+f(y*y));var horizontal := f(f(z*x)+f(w*y));var vertical := f(f(z*y)-f(w*x))
				p.setOrientation.call(owner,multiply(arc([f(horizontal+horizontal),f(vertical+vertical),f(1-f(xx+xx))],delta),q))
		for child in part.children38:queue.append(child)
