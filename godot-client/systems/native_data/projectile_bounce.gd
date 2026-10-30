extends RefCounted
# Original builders986db0/985f20. Scene rays and object membership remain
# explicit services; nodes/timing/finite CRT/random order are native behavior.
const M=preload("res://systems/native_render/particle_math.gd")
const Orientation=preload("res://systems/native_data/projectile_orientation.gd")
const INVALID=0x7f000000
static func magnitude(v: Array) -> float:
	var square:=M.f(M.f(M.f(v[0]*v[0])+M.f(v[1]*v[1]))+M.f(v[2]*v[2]))
	return 0.0 if square<=0 else M.f(sqrt(square))
static func cvtt(value: float) -> int:
	return (int(value)&0xffffffff) if is_finite(value) and value>=-2147483648.0 and value<2147483648.0 else 0x80000000
static func divide(a: float,b: float) -> float:
	if b!=0: return M.f(a/b)
	if a==0 or is_nan(a): return NAN
	return -INF if Orientation.negative(a)!=Orientation.negative(b) else INF
static func append(s: Dictionary,point: Array,duration: int,target: int,p: Dictionary) -> void:
	var n:={"point":M.values(point),"attachment":M.values(point),"targetId":target&0xffffffff,"childPath":0,"duration":duration&0xffffffff,"threshold":0,"radius":-1.0,"spawnCount":0,"kind":2}
	p.allocateNode.call(n); s.nodes.append(n)
static func floor_point(x: float,y: float,scene: bool,p: Dictionary) -> Array:
	var point: Array=[x,y,0.0]
	if scene:
		var hit: Dictionary=p.trace.call([x,y,1000.0],[x,y,-1000.0])
		if hit.get("hit",false): point[2]=M.f(hit.position[2])
	return point
static func duration(s: Dictionary,from: Array,to: Array,speed_fraction: float) -> int:
	var base:=magnitude(M.subtract(M.values(s.position),M.values(s.endpoint))); var length:=magnitude(M.subtract(from,to))
	var speed:=divide(base,M.f(int(s.totalTime)&0xffffffff))
	speed=divide(speed,2.5) if speed_fraction==2.5 else M.f(speed*M.f(speed_fraction))
	return cvtt(divide(length,speed))
static func build(s: Dictionary,path: int,p: Dictionary) -> void:
	var point: Array=M.values(s.endpoint) if int(s.targetId)==INVALID or p.clientObject.call(int(s.targetId))==null else [0.0,0.0,0.0]
	var scene: bool=p.sceneAvailable.call(); append(s,point,int(s.totalTime),int(s.targetId),p)
	if path==13:
		var angle:=M.f(M.f(M.f(float(int(p.random.call())%1570)/1000.0)+Orientation.atanf(divide(M.f(-s.orientation[1]),M.f(-s.orientation[0]))))+M.f(0.7853982))
		angle=angle if angle<=M.f(2.3561945) else M.f(2.3561945)
		var x:=Orientation.trig(angle,true); var y:=Orientation.trig(angle,false)
		if M.f(-s.orientation[0])<0: x=M.f(-x); y=M.f(-y)
		point=floor_point(M.f(M.f(x*3)+M.f(s.endpoint[0])),M.f(M.f(y*3)+M.f(s.endpoint[1])),scene,p)
		append(s,point,duration(s,M.values(s.endpoint),point,2.5),INVALID,p)
		return
	var x:=M.f(-s.orientation[0]) if path==11 else M.f(s.orientation[0]); var y:=M.f(-s.orientation[1]) if path==11 else M.f(s.orientation[1])
	point=floor_point(M.f(M.f(x*1.5)+M.f(s.endpoint[0])),M.f(M.f(y*1.5)+M.f(s.endpoint[1])),scene,p)
	append(s,point,duration(s,M.values(s.endpoint),point,0.125),INVALID,p)
	var next:=floor_point(M.f(M.f(x*M.f(0.7))+point[0]),M.f(M.f(y*M.f(0.7))+point[1]),scene,p)
	append(s,next,duration(s,point,next,0.0625),INVALID,p)
