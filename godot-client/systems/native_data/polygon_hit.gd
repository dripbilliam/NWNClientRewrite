extends RefCounted
# Original polyhit231810: front-to-back, inclusive edges and distinct dot-sum
# orders. Native coordinates/FLOAT; no barycentric epsilon or normalized ray.
const M=preload("res://systems/native_render/particle_math.gd")
const Surface=preload("res://systems/native_data/tile_surface.gd")
static func plane(vertices: Array) -> Dictionary:
	var normal:=Surface.normal(vertices[0],vertices[1],vertices[2]); var v: Array=vertices[0]
	return {"normal":normal,"constant":M.f(-M.f(M.f(M.f(v[1]*normal[1])+M.f(v[0]*normal[0]))+M.f(v[2]*normal[2])))}
static func hit(vertices: Array,n: Array,c: float,start: Array,end: Array) -> Variant:
	var from:=M.f(M.f(M.f(M.f(n[1]*start[1])+M.f(n[0]*start[0]))+M.f(n[2]*start[2]))+c)
	if from<0: return null
	var to:=M.f(M.f(M.f(M.f(n[0]*end[0])+M.f(n[1]*end[1]))+M.f(n[2]*end[2]))+c)
	if to>0 or from==to: return null
	var t:=M.f(from/M.f(from-to)); var a:=M.f(1-t)
	var point: Array=[M.f(M.f(a*start[0])+M.f(t*end[0])),M.f(M.f(a*start[1])+M.f(t*end[1])),M.f(M.f(t*end[2])+M.f(a*start[2]))]
	for i in vertices.size():
		var d:=M.subtract(vertices[(i+1)%vertices.size()],vertices[i]); var p:=M.subtract(point,vertices[i])
		var x:=M.f(M.f(d[1]*p[2])-M.f(p[1]*d[2])); var z:=M.f(M.f(d[0]*p[1])-M.f(d[1]*p[0])); var y:=M.f(M.f(p[0]*d[2])-M.f(d[0]*p[2]))
		if not M.f(M.f(M.f(y*n[1])+M.f(x*n[0]))+M.f(z*n[2]))>=0: return null
	return point
