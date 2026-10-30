extends RefCounted
# Original runtime coordinates (Z up), quaternion order WXYZ. Convert only at
# the Godot publication boundary. Arithmetic grouping follows particle_math.js
# and the stored original-reader/runtime observations; no JS runs here.
static func f(value: float) -> float:
	return Vector2(value,0).x
static func cvtt(value: float) -> int:
	value=f(value)
	return int(value) if is_finite(value) and value>=-2147483648.0 and value<2147483648.0 else -2147483648
static func values(source: Array) -> Array:
	return source.map(f)
static func add(a: Array,b: Array) -> Array:
	return [f(f(a[0])+f(b[0])),f(f(a[1])+f(b[1])),f(f(a[2])+f(b[2]))]
static func subtract(a: Array,b: Array) -> Array:
	return [f(f(a[0])-f(b[0])),f(f(a[1])-f(b[1])),f(f(a[2])-f(b[2]))]
static func normalize(value: Array) -> Array:
	var x:=f(value[0]); var y:=f(value[1]); var z:=f(value[2]); var squared:=f(f(f(x*x)+f(y*y))+f(z*z))
	if squared==1 or squared>=0.9999899864196777 and squared<=1.0000100135803223: return [x,y,z]
	if squared==0: return [1.0,0.0,0.0]
	var scale_value:=f(sqrt(f(1/squared)))
	return [f(x*scale_value),f(y*scale_value),f(z*scale_value)]
static func multiply(l: Array,r: Array) -> Array:
	var a:=f(l[0]); var b:=f(l[1]); var c:=f(l[2]); var d:=f(l[3]); var w:=f(r[0]); var x:=f(r[1]); var y:=f(r[2]); var z:=f(r[3])
	return [f(f(f(f(a*w)-f(b*x))-f(c*y))-f(d*z)),f(f(f(f(b*w)+f(a*x))+f(c*z))-f(d*y)),f(f(f(f(a*y)-f(b*z))+f(c*w))+f(d*x)),f(f(f(f(b*y)+f(a*z))-f(c*x))+f(d*w))]
static func cross(l: Array,r: Array) -> Array:
	return [f(f(f(l[1])*f(r[2]))-f(f(l[2])*f(r[1]))),f(f(f(l[2])*f(r[0]))-f(f(l[0])*f(r[2]))),f(f(f(l[0])*f(r[1]))-f(f(l[1])*f(r[0])))]
static func twice(value: float) -> float:
	return f(value+value)
static func axis_x(q: Array) -> Array:
	var w:=f(q[0]); var x:=f(q[1]); var y:=f(q[2]); var z:=f(q[3])
	return [f(1-twice(f(f(z*z)+f(y*y)))),twice(f(f(x*y)+f(w*z))),twice(f(f(x*z)-f(w*y)))]
static func axis_y(q: Array) -> Array:
	var w:=f(q[0]); var x:=f(q[1]); var y:=f(q[2]); var z:=f(q[3]); var a:=f(f(x*y)-f(w*z)); var b:=f(f(z*z)+f(x*x)); var c:=f(f(w*x)+f(z*y))
	return [f(a+a),f(1-f(b+b)),f(c+c)]
static func axis_z(q: Array) -> Array:
	var w:=f(q[0]); var x:=f(q[1]); var y:=f(q[2]); var z:=f(q[3]); var a:=f(f(w*y)+f(x*z)); var b:=f(f(y*z)-f(w*x)); var c:=f(f(y*y)+f(x*x))
	return [f(a+a),f(b+b),f(1-f(c+c))]
static func quaternion_basis(q: Array) -> Array:
	return axis_x(q)+axis_y(q)+axis_z(q)
static func rotate(q: Array,v: Array) -> Array:
	var w:=f(q[0]); var x:=f(q[1]); var y:=f(q[2]); var z:=f(q[3]); var a:=f(v[0]); var b:=f(v[1]); var c:=f(v[2])
	if w==1 or a==0 and b==0 and c==0 or x==0 and y==0 and z==0: return [a,b,c]
	var xx:=f(x*x); var yy:=f(y*y); var zz:=f(z*z); var xy:=f(x*y); var xz:=f(x*z); var yz:=f(y*z); var wx:=f(w*x); var wy:=f(w*y); var wz:=f(w*z)
	return [f(f(f(f(1-twice(f(zz+yy)))*a)+f(twice(f(xy-wz))*b))+f(twice(f(wy+xz))*c)),f(f(f(f(1-twice(f(zz+xx)))*b)+f(twice(f(wz+xy))*a))+f(twice(f(yz-wx))*c)),f(f(f(twice(f(xz-wy))*a)+f(twice(f(yz+wx))*b))+f(f(1-twice(f(yy+xx)))*c))]
static func rotation_arc(a: Array,b: Array) -> Array:
	a=normalize(a); b=normalize(b)
	var dot:=f(f(f(b[0]*a[0])+f(b[1]*a[1]))+f(b[2]*a[2]))
	if dot<=-1: return [0.0,1.0,0.0,0.0]
	var scale_value:=f(sqrt(f(f(dot+1)*2))); var axis:=cross(a,b)
	return [f(scale_value*f(0.5)),f(axis[0]/scale_value),f(axis[1]/scale_value),f(axis[2]/scale_value)]
static func fast_rsqrt(value: float) -> float:
	value=f(value); var bits:=PackedFloat32Array([value]).to_byte_array()
	bits.encode_s32(0,0x5f3759df-(bits.decode_s32(0)>>1)); var estimate:=bits.decode_float(0)
	return f(f(f(1.5)-f(f(f(value*f(0.5))*estimate)*estimate))*estimate)
