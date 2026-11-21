extends RefCounted
# Original client7b1670 receives world-space vertices, raises Z by0.05;
#86f940 derives the center from these vertices. Never guess from a visual model.
static func network_transition_trigger(object: Variant) -> bool:
	return object is Dictionary and int(object.get("objectType",0))==7 and not bool(object.get("replicationRemoved",false)) and bool(object.get("replicated",{}).get("hasTransition",false)) and not bool(object.get("replicated",{}).get("isTrap",false))
static func network_trigger_surface(object: Variant) -> Variant:
	if not network_transition_trigger(object):return null
	var prepared: Dictionary=prepare(object)
	if prepared.is_empty():return null
	var points: Array=object.get("replicated",{}).get("vertices",[]).duplicate(true)
	if points.size()>3 and points[0]==points[-1]:points.pop_back()
	var minimum: Array=[INF,INF,INF]
	var maximum: Array=[-INF,-INF,-INF]
	for point in points:
		for axis in range(3):
			minimum[axis]=minf(minimum[axis],float(point[axis]))
			maximum[axis]=maxf(maximum[axis],float(point[axis]))
	var center: Array=[]
	for axis in range(3):center.append((minimum[axis]+maximum[axis])/2.0)
	var vertices: Array=[]
	for point in points:vertices.append([point[0],float(point[2])+0.05,-float(point[1])])
	var triangles: Array=[]
	var indices: PackedInt32Array=prepared.indices
	for offset in range(0,indices.size(),3):triangles.append([indices[offset],indices[offset+1],indices[offset+2]])
	return {"vertices":vertices,"triangles":triangles,"center":[center[0],center[2]+0.05,-center[1]],"destination":prepared.destination}

# ShapeUtils.triangulateShape in Three r180 calls Earcut 3.0.1 with one ring
# and no holes. Its ear order determines the approach point for concave triggers.
# Earcut 3.0.1, Copyright (c) 2024, Mapbox. ISC License.
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
# IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
class RingNode:
	extends RefCounted
	var index: int
	var xy: Vector2
	var prev
	var next
	func _init(value_index: int,value_xy: Vector2)->void:
		index=value_index;xy=value_xy

static func _ring_area(a: RingNode,b: RingNode,c: RingNode)->float:
	return (b.xy.y-a.xy.y)*(c.xy.x-b.xy.x)-(b.xy.x-a.xy.x)*(c.xy.y-b.xy.y)
static func _ring_equal(a: RingNode,b: RingNode)->bool:return a.xy==b.xy
static func _ring_insert(index: int,xy: Vector2,last: RingNode,nodes: Array)->RingNode:
	var node:=RingNode.new(index,xy);nodes.append(node)
	if last==null:node.prev=node;node.next=node
	else:
		node.next=last.next;node.prev=last
		last.next.prev=node;last.next=node
	return node
static func _ring_remove(node: RingNode)->void:
	node.next.prev=node.prev;node.prev.next=node.next
static func _ring_filter(start: RingNode,end: RingNode=null)->RingNode:
	if start==null:return null
	if end==null:end=start
	var p:=start
	while true:
		var again:=false
		if _ring_equal(p,p.next) or _ring_area(p.prev,p,p.next)==0.0:
			_ring_remove(p);p=p.prev;end=p
			if p==p.next:break
			again=true
		else:p=p.next
		if not again and p==end:break
	return end
static func _point_in_triangle(a: Vector2,b: Vector2,c: Vector2,p: Vector2)->bool:
	return (c.x-p.x)*(a.y-p.y)>=(a.x-p.x)*(c.y-p.y) and (a.x-p.x)*(b.y-p.y)>=(b.x-p.x)*(a.y-p.y) and (b.x-p.x)*(c.y-p.y)>=(c.x-p.x)*(b.y-p.y)
static func _ring_ear(node: RingNode)->bool:
	var a: RingNode=node.prev;var c: RingNode=node.next
	if _ring_area(a,node,c)>=0.0:return false
	var low:=Vector2(minf(a.xy.x,minf(node.xy.x,c.xy.x)),minf(a.xy.y,minf(node.xy.y,c.xy.y)))
	var high:=Vector2(maxf(a.xy.x,maxf(node.xy.x,c.xy.x)),maxf(a.xy.y,maxf(node.xy.y,c.xy.y)))
	var p: RingNode=c.next
	while p!=a:
		if p.xy.x>=low.x and p.xy.x<=high.x and p.xy.y>=low.y and p.xy.y<=high.y and not _ring_equal(p,a) and _point_in_triangle(a.xy,node.xy,c.xy,p.xy) and _ring_area(p.prev,p,p.next)>=0.0:return false
		p=p.next
	return true
static func _ring_sign(value: float)->int:return 1 if value>0.0 else -1 if value<0.0 else 0
static func _ring_on_segment(a: RingNode,b: RingNode,c: RingNode)->bool:
	return b.xy.x<=maxf(a.xy.x,c.xy.x) and b.xy.x>=minf(a.xy.x,c.xy.x) and b.xy.y<=maxf(a.xy.y,c.xy.y) and b.xy.y>=minf(a.xy.y,c.xy.y)
static func _ring_intersects(a: RingNode,b: RingNode,c: RingNode,d: RingNode)->bool:
	var ab_c:=_ring_sign(_ring_area(a,b,c));var ab_d:=_ring_sign(_ring_area(a,b,d))
	var cd_a:=_ring_sign(_ring_area(c,d,a));var cd_b:=_ring_sign(_ring_area(c,d,b))
	if ab_c!=ab_d and cd_a!=cd_b:return true
	return ab_c==0 and _ring_on_segment(a,c,b) or ab_d==0 and _ring_on_segment(a,d,b) or cd_a==0 and _ring_on_segment(c,a,d) or cd_b==0 and _ring_on_segment(c,b,d)
static func _ring_locally_inside(a: RingNode,b: RingNode)->bool:
	if _ring_area(a.prev,a,a.next)<0.0:return _ring_area(a,b,a.next)>=0.0 and _ring_area(a,a.prev,b)>=0.0
	return _ring_area(a,b,a.prev)<0.0 or _ring_area(a,a.next,b)<0.0
static func _ring_cure(start: RingNode,triangles: PackedInt32Array)->RingNode:
	var p:=start
	while true:
		var a: RingNode=p.prev;var b: RingNode=p.next.next
		if not _ring_equal(a,b) and _ring_intersects(a,p,p.next,b) and _ring_locally_inside(a,b) and _ring_locally_inside(b,a):
			triangles.append_array(PackedInt32Array([a.index,p.index,b.index]))
			_ring_remove(p);_ring_remove(p.next);p=b;start=b
		p=p.next
		if p==start:break
	return _ring_filter(p)
static func _ring_intersects_polygon(a: RingNode,b: RingNode)->bool:
	var p:=a
	while true:
		if p.index!=a.index and p.next.index!=a.index and p.index!=b.index and p.next.index!=b.index and _ring_intersects(p,p.next,a,b):return true
		p=p.next
		if p==a:break
	return false
static func _ring_middle_inside(a: RingNode,b: RingNode)->bool:
	var middle: Vector2=(a.xy+b.xy)*0.5
	var inside:=false;var p:=a
	while true:
		if (p.xy.y>middle.y)!=(p.next.xy.y>middle.y) and p.next.xy.y!=p.xy.y and middle.x<(p.next.xy.x-p.xy.x)*(middle.y-p.xy.y)/(p.next.xy.y-p.xy.y)+p.xy.x:inside=not inside
		p=p.next
		if p==a:break
	return inside
static func _ring_valid_diagonal(a: RingNode,b: RingNode)->bool:
	if a.next.index==b.index or a.prev.index==b.index or _ring_intersects_polygon(a,b):return false
	return (_ring_locally_inside(a,b) and _ring_locally_inside(b,a) and _ring_middle_inside(a,b) and (_ring_area(a.prev,a,b.prev)!=0.0 or _ring_area(a,b.prev,b)!=0.0)) or (_ring_equal(a,b) and _ring_area(a.prev,a,a.next)>0.0 and _ring_area(b.prev,b,b.next)>0.0)
static func _ring_split(a: RingNode,b: RingNode,nodes: Array)->RingNode:
	var a2:=RingNode.new(a.index,a.xy);var b2:=RingNode.new(b.index,b.xy)
	nodes.append(a2);nodes.append(b2)
	var an: RingNode=a.next;var bp: RingNode=b.prev
	a.next=b;b.prev=a
	a2.next=an;an.prev=a2
	b2.next=a2;a2.prev=b2
	bp.next=b2;b2.prev=bp
	return b2
static func _ring_split_earcut(start: RingNode,triangles: PackedInt32Array,nodes: Array)->void:
	var a:=start
	while true:
		var b: RingNode=a.next.next
		while b!=a.prev:
			if a.index!=b.index and _ring_valid_diagonal(a,b):
				var c:=_ring_split(a,b,nodes)
				a=_ring_filter(a,a.next);c=_ring_filter(c,c.next)
				_ring_cut(a,triangles,nodes,0);_ring_cut(c,triangles,nodes,0)
				return
			b=b.next
		a=a.next
		if a==start:break
static func _ring_cut(ear: RingNode,triangles: PackedInt32Array,nodes: Array,stage: int)->void:
	if ear==null:return
	var stop:=ear
	while ear.prev!=ear.next:
		var previous: RingNode=ear.prev;var following: RingNode=ear.next
		if _ring_ear(ear):
			triangles.append_array(PackedInt32Array([previous.index,ear.index,following.index]))
			_ring_remove(ear);ear=following.next;stop=ear
			continue
		ear=following
		if ear==stop:
			if stage==0:_ring_cut(_ring_filter(ear),triangles,nodes,1)
			elif stage==1:_ring_cut(_ring_cure(_ring_filter(ear),triangles),triangles,nodes,2)
			else:_ring_split_earcut(ear,triangles,nodes)
			return
static func _earcut_single_ring(points: PackedVector2Array)->PackedInt32Array:
	var triangles:=PackedInt32Array();var count:=points.size()
	if count<3:return triangles
	var signed:=0.0;var j:=count-1
	for i in range(count):
		signed+=(points[j].x-points[i].x)*(points[i].y+points[j].y);j=i
	var nodes: Array=[];var last: RingNode=null
	if signed>0.0:
		for i in range(count):last=_ring_insert(i,points[i],last,nodes)
	else:
		for i in range(count-1,-1,-1):last=_ring_insert(i,points[i],last,nodes)
	if last!=null and _ring_equal(last,last.next):
		_ring_remove(last);last=last.next
	if last!=null and last.next!=last.prev:_ring_cut(last,triangles,nodes,0)
	for node in nodes:node.prev=null;node.next=null
	return triangles
static func prepare(object: Dictionary) -> Dictionary:
	var source: Variant=object.get("replicated",{}).get("vertices")
	if not source is Array or source.size()<3 or source.size()>255: return {}
	for point in source:
		if not point is Array or point.size()!=3 or not point.all(func(v):return (v is int or v is float) and is_finite(float(v))):return {}
	var points: Array=source.duplicate()
	if points.size()>3 and points[0]==points[-1]: points.pop_back()
	var polygon:=PackedVector2Array(); var vertices:=PackedVector3Array()
	for point in points:
		polygon.append(Vector2(point[0],point[1])); vertices.append(Vector3(point[0],point[2]+0.05,-point[1]))
	var indices:=_earcut_single_ring(polygon)
	if indices.is_empty(): return {}
	var area:=-1.0; var destination: Array=[]; var faces:=PackedVector3Array(); var bounds:=AABB(vertices[0],Vector3.ZERO)
	for vertex in vertices: bounds=bounds.expand(vertex)
	for offset in range(0,indices.size(),3):
		var a: int=indices[offset]; var b: int=indices[offset+1]; var c: int=indices[offset+2]
		faces.append(vertices[a]); faces.append(vertices[b]); faces.append(vertices[c])
		var size:=absf((polygon[b]-polygon[a]).cross(polygon[c]-polygon[a]))
		if size>area:
			area=size; destination=[(points[a][0]+points[b][0]+points[c][0])/3.0,(points[a][1]+points[b][1]+points[c][1])/3.0,(points[a][2]+points[b][2]+points[c][2])/3.0]
	return {"vertices":vertices,"indices":indices,"faces":faces,"bounds":bounds,"destination":destination} if area>0 else {}
