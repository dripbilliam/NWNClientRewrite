extends RefCounted

# CNWArea client-drive polygon query against NativeAreaCollisionStore's
# physical arrays. Door surfaces remain a separate callback.
static func f(value: float)->float:return Vector3(value,0.0,0.0).x
static func _between(value: float,a: float,b: float)->bool:return value>=minf(a,b) and value<=maxf(a,b)
static func intersect_area_segments(start: Array,end: Array,edge_start: Array,edge_end: Array)->Variant:
	var x1:=f(float(start[0]));var y1:=f(float(start[1]));var x2:=f(float(end[0]));var y2:=f(float(end[1]))
	var x3:=f(float(edge_start[0]));var y3:=f(float(edge_start[1]));var x4:=f(float(edge_end[0]));var y4:=f(float(edge_end[1]))
	var x:=0.0;var y:=0.0
	if x1==x2:
		if x3==x4:return null
		x=x1
		var slope:=f(f(y4-y3)/f(x4-x3))
		y=f(f(y3-f(slope*x3))+f(slope*x1))
		if not _between(y,y3,y4) or not _between(x,x3,x4) or not _between(y,y1,y2):return null
	else:
		var slope:=f(f(y2-y1)/f(x2-x1))
		if x3==x4:
			x=x3;y=f(f(y1-f(slope*x1))+f(slope*x3))
			if not _between(y,y1,y2) or not _between(x,x1,x2) or not _between(y,y3,y4):return null
		else:
			var edge_slope:=f(f(y4-y3)/f(x4-x3));var difference:=f(slope-edge_slope)
			if difference==0:return null
			var constant:=f(y3-f(edge_slope*x3))
			x=f(f(constant-f(y1-f(slope*x1)))*f(1.0/difference))
			y=f(f(x*edge_slope)+constant)
			if not _between(x,x3,x4) or not _between(x,x1,x2):return null
	return [x,y]

static func is_excluded(id: int,excluded: Variant)->Variant:
	if excluded==null:return 0
	if not excluded is Array:return {"error":"Native collision exclusion list is invalid"}
	for object in excluded:
		if not object is Dictionary or typeof(object.get("id"))!=TYPE_INT:return {"error":"Native collision exclusion object is unavailable"}
		if int(object.id)==id:return 1
	return 0
static func _inputs(start: Array,end: Array,low: float,high: float,radius: float)->Dictionary:
	if start.size()<2 or end.size()<2:return {"error":"Native area collision query geometry is unavailable"}
	for value in start.slice(0,2)+end.slice(0,2)+[low,high,radius]:
		if not is_finite(float(value)) or not is_finite(f(float(value))):return {"error":"Native area collision query geometry is unavailable"}
	radius=f(radius)
	if radius>f(0.1) and radius<=f(0.65):radius=f(0.1)
	var from: Array=[];var to: Array=[]
	for value in start:from.append(f(float(value)))
	for value in end:to.append(f(float(value)))
	return {"from":from,"to":to,"low":f(low),"high":f(high),"radius":radius}
static func _overlaps(bounds: Array,min_x: float,max_x: float,min_y: float,max_y: float,low: float,high: float)->bool:
	return float(bounds[0])<=max_x and min_x<=float(bounds[3]) and float(bounds[1])<=max_y and min_y<=float(bounds[4]) and float(bounds[2])<=high and low<=float(bounds[5])
static func _triangle_overlaps(triangle: Array,min_x: float,max_x: float,min_y: float,max_y: float,low: float,high: float)->bool:
	var a:=false;var b:=false;var c:=false;var d:=false;var e:=false;var g:=false
	for vertex in triangle:
		if float(vertex[0])<=max_x:a=true
		if min_x<=float(vertex[0]):b=true
		if float(vertex[1])<=max_y:c=true
		if min_y<=float(vertex[1]):d=true
		if float(vertex[2])<=high:e=true
		if low<=float(vertex[2]):g=true
	return a and b and c and d and e and g

static func no_non_walk_polys_detailed(store: Variant,start: Array,end: Array,low: float,high: float,radius: float,ignored_id: int,output: Dictionary,door_flag: int,excluded: Variant,transparent_flag: int,providers: Dictionary)->Variant:
	var input:=_inputs(start,end,low,high,radius)
	if input.has("error"):return input
	var from: Array=input.from;var to: Array=input.to;low=float(input.low);high=float(input.high);radius=float(input.radius)
	if from[0]==to[0] and from[1]==to[1] or low>high:return 1
	var dx:=f(float(to[0])-float(from[0]));var dy:=f(float(to[1])-float(from[1]))
	var length:=f(sqrt(f(f(dx*dx)+f(dy*dy))));var ux:=f(dx/length);var uy:=f(dy/length)
	if not is_finite(length) or length==0:return {"error":"Native area collision direction is unsupported"}
	var sx:=f(ux*radius);var sy:=f(uy*radius);var reach:=f(length+radius)
	var rectangle: Array=[[f(float(from[0])-sy),f(sx+float(from[1]))],[f(f(float(to[0])-sy)+sx),f(f(sx+float(to[1]))+sy)],[f(f(sy+float(to[0]))+sx),f(f(float(to[1])-sx)+sy)],[f(sy+float(from[0])),f(float(from[1])-sx)]]
	var quadrant:=3 if float(to[0])<float(from[0]) and float(to[1])<float(from[1]) else 2 if float(to[0])<float(from[0]) else 1 if float(from[1])<=float(to[1]) else 0
	var max_x:=float(rectangle[(quadrant+1)&3][0]);var max_y:=float(rectangle[quadrant][1])
	var min_x:=float(rectangle[(quadrant-1)&3][0]);var min_y:=float(rectangle[(quadrant-2)&3][1])
	var remaining: int=excluded.size() if excluded is Array else 0
	for slot in store.object_count:
		if int(store.face_counts[slot])==0:continue
		if remaining>0:
			var excluded_result: Variant=is_excluded(int(store.object_ids[slot]),excluded)
			if excluded_result is Dictionary:return excluded_result
			if int(excluded_result)!=0:remaining-=1;continue
		var bounds: Array=[]
		for axis in 6:bounds.append(store.bounds[slot*6+axis])
		if not _overlaps(bounds,min_x,max_x,min_y,max_y,low,high):continue
		for face in range(int(store.face_starts[slot]),int(store.face_starts[slot])+int(store.face_counts[slot])):
			var triangle: Array=[]
			for corner in 3:
				var index:=int(store.indices[face*3+corner])
				triangle.append([store.vertices[index*3],store.vertices[index*3+1],store.vertices[index*3+2]])
			if not _triangle_overlaps(triangle,min_x,max_x,min_y,max_y,low,high):continue
			var offsets: Array=[]
			for vertex in triangle:offsets.append([f(float(vertex[0])-float(from[0])),f(float(vertex[1])-float(from[1]))])
			var right:=0;var left:=0;var middle:=0;var back:=0;var beyond:=0
			for vertex in 3:
				var distance:=f(f(float(offsets[vertex][0])*-uy)+f(float(offsets[vertex][1])*ux))
				if distance>radius:right|=1<<vertex
				elif distance< -radius:left|=1<<vertex
				else:middle|=1<<vertex
			if right==7 or left==7:continue
			for vertex in 3:
				var forward:=f(f(uy*float(offsets[vertex][1]))+f(ux*float(offsets[vertex][0])))
				if forward>reach:beyond|=1<<vertex
				elif forward<0:back|=1<<vertex
				elif (middle&(1<<vertex))!=0:return 0
			if back==7 or beyond==7:continue
			var masks: Array=[right,beyond,left,back]
			for vertex in 3:
				for edge in 4:
					var next:=(vertex+1)%3;var bits:=(1<<vertex)^(1<<next)
					if (int(masks[edge])&bits)!=0 and intersect_area_segments(triangle[vertex],triangle[next],rectangle[edge],rectangle[(edge+1)&3])!=null:return 0
			var a: Array=triangle[0];var b: Array=triangle[1];var c: Array=triangle[2];var x:=float(rectangle[0][0]);var y:=float(rectangle[0][1])
			if f(f(f(float(b[0])-float(a[0]))*f(y-float(a[1])))+f(f(x-float(a[0]))*f(float(a[1])-float(b[1]))))>=0 and f(f(f(float(c[0])-float(b[0]))*f(y-float(b[1])))+f(f(x-float(b[0]))*f(float(b[1])-float(c[1]))))>=0 and f(f(f(float(a[0])-float(c[0]))*f(y-float(c[1])))+f(f(float(c[1])-float(a[1]))*f(x-float(c[0]))))>=0:return 0
	return no_non_walk_polys_in_doors(store,from,to,low,high,radius,ignored_id,output,door_flag,excluded,transparent_flag,providers)

static func no_non_walk_polys_in_doors(store: Variant,start: Array,end: Array,low: float,high: float,radius: float,ignored_id: int,output: Dictionary,door_flag: int,excluded: Variant,transparent_flag: int,providers: Dictionary)->Variant:
	var input:=_inputs(start,end,low,high,radius)
	if input.has("error"):return input
	var from: Array=input.from;var to: Array=input.to;low=float(input.low);high=float(input.high);radius=float(input.radius)
	var min_x:=f(minf(float(from[0]),float(to[0]))-radius);var max_x:=f(maxf(float(from[0]),float(to[0]))+radius)
	var min_y:=f(minf(float(from[1]),float(to[1]))-radius);var max_y:=f(maxf(float(from[1]),float(to[1]))+radius)
	for index in store.door_count:
		var bounds: Array=[]
		for axis in 6:bounds.append(store.door_bounds[index*6+axis])
		if not (float(bounds[0])<=min_x or float(bounds[0])<=max_x) or not (max_x<=float(bounds[3]) or min_x<=float(bounds[3])) or not (float(bounds[1])<=min_y or float(bounds[1])<=max_y) or not (max_y<=float(bounds[4]) or min_y<=float(bounds[4])) or not (float(bounds[2])<=low or float(bounds[2])<=high) or not (high<=float(bounds[5]) or low<=float(bounds[5])):continue
		var id:=int(store.door_ids[index])
		var excluded_result: Variant=is_excluded(id,excluded)
		if excluded_result is Dictionary:return excluded_result
		if int(excluded_result)!=0:continue
		if not providers.get("doorPolygons") is Callable:return {"error":"Native area collision provider doorPolygons is unavailable"}
		var door_result: Variant=providers.doorPolygons.call(id,from,to,low,high,radius)
		if door_result is Dictionary:return door_result
		if int(door_result)!=0:continue
		output.id=id
		if transparent_flag!=1:return 0
		return {"error":"Native transparent-door provider is unavailable on client drive"}
	return 1
