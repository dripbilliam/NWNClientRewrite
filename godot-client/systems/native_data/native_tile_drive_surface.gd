extends RefCounted

# Client-drive projection of the original WOK's classified collision faces.
# The shared tile parser retains every source face for height and rendering.
const BORDER:=-2
const NO_NEIGHBOR:=-3
static func f(value: float)->float:return Vector3(value,0.0,0.0).x
static func _inside(x: float,y: float,low_x: float,low_y: float,high_x: float,high_y: float)->bool:
	return x>=low_x and x<=high_x and y>=low_y and y<=high_y
static func _clip_endpoint(entry: bool,x1: float,y1: float,x2: float,y2: float,low_x: float,low_y: float,high_x: float,high_y: float)->Variant:
	var x:=x1 if entry else x2;var y:=y1 if entry else y2
	if _inside(x,y,low_x,low_y,high_x,high_y):return [x,y]
	var vertical:=x1==x2;var horizontal:=y1==y2
	var edge_x:=x2;var at_y:=x2
	if not vertical:
		edge_x=(high_x if x2<x1 else low_x) if entry else (high_x if x1<x2 else low_x)
		at_y=f(f(f(f(y2-y1)/f(x2-x1))*f(edge_x-x1))+y1)
	if not vertical and at_y>=low_y and at_y<=high_y:return [edge_x,at_y]
	var edge_y:=x2;var at_x:=x2
	if not horizontal:
		edge_y=(high_y if y2<y1 else low_y) if entry else (high_y if y1<y2 else low_y)
		at_x=f(f(f(f(x2-x1)/f(y2-y1))*f(edge_y-y1))+x1)
	if not horizontal and at_x>=low_x and at_x<=high_x:return [at_x,edge_y]
	return null
static func clip_tile_line(tile_x: int,tile_y: int,start: Array,end: Array)->Dictionary:
	for value in start+end:
		if not is_finite(float(value)):return {"error":"Native tile clipping inputs are unavailable"}
	var x1:=f(float(start[0]));var y1:=f(float(start[1]));var x2:=f(float(end[0]));var y2:=f(float(end[1]))
	var low_x:=f(f(float(tile_x))*10.0);var low_y:=f(f(float(tile_y))*10.0)
	var high_x:=f(10.0+low_x);var high_y:=f(10.0+low_y)
	var entry: Variant=_clip_endpoint(true,x1,y1,x2,y2,low_x,low_y,high_x,high_y)
	var exit_point: Variant=_clip_endpoint(false,x1,y1,x2,y2,low_x,low_y,high_x,high_y)
	return {"status":1 if entry!=null and exit_point!=null else 0,"entry":entry,"exit":exit_point}
static func _atoi(value: Variant)->int:
	var expression:=RegEx.create_from_string("^\\s*([+-]?\\d+)")
	var match_result:=expression.search("" if value==null else str(value))
	if match_result==null:return 0
	var narrowed:=int(match_result.get_string(1))&0xffffffff
	return narrowed-4294967296 if narrowed>=2147483648 else narrowed
static func _walk(table: Dictionary,material: int)->bool:
	var rows: Array=table.get("orderedRows",[])
	var row: Variant=rows[material] if material>=0 and material<rows.size() else null
	var value: Variant=null
	if row is Dictionary:
		for key in row:
			if str(key).to_lower()=="walk":value=row[key];break
	if row==null or value==null:return _atoi(table.get("defaultValue",""))!=0
	if str(value) in ["","****"]:return false
	var text:=str(value)
	if text.to_lower().begins_with("0x"):
		var hexadecimal:=RegEx.create_from_string("^0[xX][0-9a-fA-F]+")
		var match_result:=hexadecimal.search(text)
		if match_result!=null:return (match_result.get_string().hex_to_int()&0xffffffff)!=0
	return _atoi(value)!=0

static func adjacency(vertices: Array,faces: Array)->Array:
	var low:=f(0.0001);var high:=f(9.9999)
	var boundary: Array=[]
	for vertex in vertices:
		var x:=f(float(vertex[0]));var y:=f(float(vertex[1]))
		boundary.append(x<=low or y<=low or x>=high or y>=high)
	var result: Array=[]
	for _face in faces:result.append([NO_NEIGHBOR,NO_NEIGHBOR,NO_NEIGHBOR])
	for face in faces.size():
		for edge in 3:
			if int(result[face][edge])!=NO_NEIGHBOR:continue
			var a:=int(faces[face][edge]);var b:=int(faces[face][(edge+1)%3])
			if boundary[a] and boundary[b] and (float(vertices[a][0])<=low and float(vertices[b][0])<=low or float(vertices[a][0])>=high and float(vertices[b][0])>=high or float(vertices[a][1])<=low and float(vertices[b][1])<=low or float(vertices[a][1])>=high and float(vertices[b][1])>=high):
				result[face][edge]=BORDER
				continue
			for candidate in range(face+1,faces.size()):
				for other_edge in 3:
					var c:=int(faces[candidate][other_edge]);var d:=int(faces[candidate][(other_edge+1)%3])
					if a==c and b==d or a==d and b==c:
						result[candidate][other_edge]=face
						result[face][edge]=candidate
	return result

static func _partition(mesh: Dictionary,selected: Array)->Dictionary:
	var used: Dictionary={}
	for index in selected:
		for vertex in mesh.faces[int(index)]:used[int(vertex)]=true
	var indices: Array=[]
	for index in mesh.vertices.size():
		if used.has(index):indices.append(index)
	var remap: Dictionary={}
	for mapped in indices.size():remap[indices[mapped]]=mapped
	var vertices: Array=[];var faces: Array=[];var normals: Array=[];var constants: Array=[];var materials: Array=[]
	for index in indices:vertices.append(mesh.vertices[int(index)])
	for index in selected:
		var source: Array=mesh.faces[int(index)]
		faces.append([remap[int(source[0])],remap[int(source[1])],remap[int(source[2])]])
		normals.append(mesh.normals[int(index)]);constants.append(mesh.constants[int(index)]);materials.append(mesh.materials[int(index)])
	return {"vertices":vertices,"faces":faces,"normals":normals,"constants":constants,"materials":materials,"sourceFaces":selected}

static func classify(mesh: Dictionary,surface_table: Dictionary)->Dictionary:
	if not _validate(mesh) or not mesh.get("materials") is Array or not mesh.get("normals") is Array or not mesh.get("constants") is Array or mesh.materials.size()!=mesh.faces.size() or mesh.normals.size()!=mesh.faces.size() or mesh.constants.size()!=mesh.faces.size():return {"error":"Native tile surface geometry is unavailable or invalid"}
	var walkable: Array=[];var denied: Array=[]
	for index in mesh.faces.size():
		if _walk(surface_table,int(mesh.materials[index])):walkable.append(index)
		else:denied.append(index)
	var result: Dictionary=_partition(mesh,walkable)
	result.denied=_partition(mesh,denied)
	result.adjacency=adjacency(result.vertices,result.faces)
	var aabb: Variant=null
	var stack: Array=[]
	for source in mesh.get("aabb_rows",[]):
		var row: Dictionary=source
		var node: Dictionary=row.duplicate(true)
		node.left=null;node.right=null
		if int(node.sourceFace)!=-1:
			var face:=int(node.sourceFace)
			if face<0 or face>=mesh.faces.size():return {"error":"Native tile AABB face outside triangle array"}
			node.denied=not _walk(surface_table,int(mesh.materials[face]))
			node.face=(denied if node.denied else walkable).find(face)
		if aabb==null:aabb=node
		else:
			if stack.is_empty():return {"error":"Invalid native tile AABB tree structure"}
			var parent: Dictionary=stack.back()
			if parent.left==null:parent.left=node
			else:parent.right=node;stack.pop_back()
		if int(node.sourceFace)==-1:stack.append(node)
	if not stack.is_empty():return {"error":"Truncated native tile AABB tree"}
	result.aabb=aabb
	return result

static func _sides(triangle: Array,point: Array)->Array:
	var result: Array=[]
	for edge in 3:
		var a: Array=triangle[edge];var b: Array=triangle[(edge+1)%3]
		result.append(f(f(f(float(b[0])-float(a[0]))*f(float(point[1])-float(a[1])))+f(f(float(a[1])-float(b[1]))*f(float(point[0])-float(a[0]))))>=0)
	return result
static func _include_height(result: Dictionary,height: float)->void:
	if height>=float(result.maxHeight):result.maxHeight=height
	elif height<=float(result.minHeight):result.minHeight=height
static func _plane_height(normal: Array,constant: float,point: Array)->float:
	var nx:=f(float(normal[0]));var ny:=f(float(normal[1]));var nz:=f(float(normal[2]))
	return 0.0 if nz==0.0 else f(-f(f(f(ny*f(float(point[1])))+f(f(nx*f(float(point[0])))+f(constant)))/nz))
static func _rotate(tile: Dictionary,point: Array,to_canonical: bool)->Variant:
	var orientation:=int(tile.get("orientation",-1))
	if orientation<0 or orientation>3:return {"error":"Native tile orientation/location is unavailable"}
	var origin_x:=f(f(float(tile.x))*10.0);var origin_y:=f(f(float(tile.y))*10.0)
	var x:=f(f(float(point[0]))-origin_x);var y:=f(f(float(point[1]))-origin_y)
	var local: Array=[x,y]
	if orientation!=0:
		if orientation==(1 if to_canonical else 3):local=[y,f(10.0-x)]
		elif orientation==2:local=[f(10.0-x),f(10.0-y)]
		else:local=[f(10.0-y),x]
	return [f(origin_x+float(local[0])),f(origin_y+float(local[1]))]
static func _validate(mesh: Dictionary)->bool:
	if not mesh.get("vertices") is Array or not mesh.get("faces") is Array:return false
	for vertex in mesh.vertices:
		if not vertex is Array or vertex.size()!=3:return false
		for value in vertex:
			if not is_finite(float(value)):return false
	for face in mesh.faces:
		if not face is Array or face.size()!=3:return false
		for index in face:
			if typeof(index)!=TYPE_INT or index<0 or index>=mesh.vertices.size():return false
	return true
static func _between(value: float,a: float,b: float)->bool:
	return value>=minf(a,b) and value<=maxf(a,b)
static func _intersect(start: Array,end: Array,edge_start: Array,edge_end: Array)->Variant:
	var x1:=f(float(start[0]));var y1:=f(float(start[1]));var x2:=f(float(end[0]));var y2:=f(float(end[1]))
	var x3:=f(float(edge_start[0]));var y3:=f(float(edge_start[1]));var z3:=f(float(edge_start[2]))
	var x4:=f(float(edge_end[0]));var y4:=f(float(edge_end[1]));var z4:=f(float(edge_end[2]))
	var x:=0.0;var y:=0.0
	if x1!=x2:
		var slope:=f(f(y2-y1)/f(x2-x1))
		if x3==x4:
			x=x3;y=f(f(y1-f(x1*slope))+f(x3*slope))
			if not _between(y,y1,y2) or not _between(x,x1,x2) or not _between(y,y3,y4):return null
		else:
			var edge_slope:=f(f(y4-y3)/f(x4-x3))
			if slope==edge_slope:return null
			var edge_constant:=f(y3-f(x3*edge_slope))
			x=f(f(edge_constant-f(y1-f(x1*slope)))*f(1.0/f(slope-edge_slope)))
			y=f(f(x*edge_slope)+edge_constant)
			if not _between(x,x3,x4) or not _between(x,x1,x2):return null
	else:
		if x3==x4:return null
		x=x1
		var slope:=f(f(y4-y3)/f(x4-x3))
		y=f(f(y3-f(x3*slope))+f(x1*slope))
		if not _between(y,y3,y4) or not _between(x,x3,x4) or not _between(y,y1,y2):return null
	var fraction:=f(f(y-y3)/f(y4-y3)) if absf(f(x3-x4))<absf(f(y3-y4)) else f(f(x-x3)/f(x4-x3))
	return [x,y,f(f(f(z4-z3)*fraction)+z3)]

static func clipped_tile_line(mesh: Dictionary,tile_x: int,tile_y: int,start: Array,end: Array,on_warning: Callable=Callable())->Dictionary:
	if not _validate(mesh) or not mesh.get("adjacency") is Array or mesh.adjacency.size()!=mesh.faces.size() or not mesh.get("normals") is Array or mesh.normals.size()!=mesh.faces.size() or not mesh.get("constants") is Array or mesh.constants.size()!=mesh.faces.size():
		return {"error":"Native tile mesh adjacency or cached planes are unavailable"}
	var clipped: Dictionary=clip_tile_line(tile_x,tile_y,start,end)
	if clipped.has("error"):return clipped
	var result: Dictionary=clipped.duplicate()
	result.status=0;result.minHeight=0.0;result.maxHeight=0.0
	if int(clipped.status)==0:return result
	var origin_x:=f(f(float(tile_x))*10.0);var origin_y:=f(f(float(tile_y))*10.0)
	var destination: Array=[f(f(float(end[0]))-origin_x),f(f(float(end[1]))-origin_y),0.0]
	var current: Array=[f(float(clipped.entry[0])-origin_x),f(float(clipped.entry[1])-origin_y),0.0]
	var face:=-1
	for index in mesh.faces.size():
		var triangle: Array=[]
		for vertex in mesh.faces[index]:triangle.append(mesh.vertices[int(vertex)])
		if _sides(triangle,current).all(func(value):return bool(value)):face=index;break
	if face<0:return result
	current[2]=_plane_height(mesh.normals[face],float(mesh.constants[face]),current)
	var count:=0
	while face>=0:
		if count>=512:
			if on_warning.is_valid():on_warning.call("Native tile triangle walk exceeded 512 iterations")
			return result
		var triangle: Array=[]
		for vertex in mesh.faces[face]:triangle.append(mesh.vertices[int(vertex)])
		if count==0:result.minHeight=current[2];result.maxHeight=current[2]
		else:_include_height(result,float(current[2]))
		var inside: Array=_sides(triangle,destination)
		var total:=0
		for value in inside:
			if value:total+=1
		if total==0:return result
		if total==3:
			_include_height(result,_plane_height(mesh.normals[face],float(mesh.constants[face]),destination))
			result.status=1
			return result
		var next: Variant=null;var neighbor:=NO_NEIGHBOR
		for edge in range(2,-1,-1):
			if inside[edge]:continue
			next=_intersect(current,destination,triangle[edge],triangle[(edge+1)%3])
			if next!=null:neighbor=int(mesh.adjacency[face][edge]);break
			if total==2:return result
		if next==null:return result
		current=next;face=neighbor
		if face>=mesh.faces.size():return {"error":"Native tile adjacency is invalid"}
		if face<0 and count+1>=512:
			if on_warning.is_valid():on_warning.call("Native tile triangle walk exceeded 512 iterations")
			return result
		count+=1
	if face==BORDER:_include_height(result,float(current[2]));result.status=1
	return result

static func clipped_area_tile_line(tile: Dictionary,start: Array,end: Array,on_warning: Callable=Callable())->Dictionary:
	if not tile.get("mesh") is Dictionary:return {"error":"Native area tile surface mesh is unavailable"}
	if not is_finite(float(tile.get("heightOffset",NAN))):return {"error":"Native tile height offset is unavailable"}
	var canonical_start: Variant=_rotate(tile,start,true);var canonical_end: Variant=_rotate(tile,end,true)
	if canonical_start is Dictionary:return canonical_start
	if canonical_end is Dictionary:return canonical_end
	var result: Dictionary=clipped_tile_line(tile.mesh,int(tile.x),int(tile.y),canonical_start,canonical_end,on_warning)
	if result.has("error"):return result
	if result.entry!=null:result.entry=_rotate(tile,result.entry,false)
	if result.exit!=null:result.exit=_rotate(tile,result.exit,false)
	result.minHeight=f(float(result.minHeight)+f(float(tile.heightOffset)))
	result.maxHeight=f(float(result.maxHeight)+f(float(tile.heightOffset)))
	return result

static func no_denied_tile_polygons(mesh: Dictionary,start: Array,end: Array,low: float,high: float,radius: float,flag: int,initial_inside: Variant=[null,null,null],clamp_radius: bool=true,intersect: Callable=Callable(),scratch_label: String="tile")->Variant:
	if not mesh.get("denied") is Dictionary or not _validate(mesh.denied):return {"error":"Native denied tile surface geometry is unavailable"}
	if not initial_inside is Array or initial_inside.size()!=3:return {"error":"Native tile collision flags are unavailable"}
	var x1:=f(float(start[0]));var y1:=f(float(start[1]));var x2:=f(float(end[0]));var y2:=f(float(end[1]))
	low=f(low);high=f(high);radius=f(radius)
	if clamp_radius and flag==0 and radius>f(0.1) and radius<=f(0.65):radius=f(0.1)
	if x1==x2 and y1==y2 or low>high:return 1
	var dx:=f(x2-x1);var dy:=f(y2-y1);var length:=f(sqrt(f(f(dx*dx)+f(dy*dy))))
	var sx:=f(f(dx/length)*radius);var sy:=f(f(dy/length)*radius)
	var rectangle: Array=[[f(x1-sy),f(sx+y1)],[f(f(x2-sy)+sx),f(f(sx+y2)+sy)],[f(f(sy+x2)+sx),f(f(y2-sx)+sy)],[f(sy+x1),f(y1-sx)]]
	var quadrant:=3 if x2<x1 and y2<y1 else 2 if x2<x1 else 1 if y1<=y2 else 0
	var max_x:=float(rectangle[(quadrant+1)&3][0]);var max_y:=float(rectangle[quadrant][1])
	var min_x:=float(rectangle[(quadrant-1)&3][0]);var min_y:=float(rectangle[(quadrant-2)&3][1])
	var inside: Array=initial_inside.duplicate()
	var uncertain:=false
	for indices in mesh.denied.faces:
		var triangle: Array=[]
		for index in indices:triangle.append(mesh.denied.vertices[int(index)])
		var reaches_min_x:=false;var reaches_min_y:=false;var reaches_max_x:=false;var reaches_max_y:=false;var reaches_low:=false;var reaches_high:=false
		for vertex in triangle:
			if float(vertex[0])<=max_x:reaches_min_x=true
			if float(vertex[1])<=max_y:reaches_min_y=true
			if float(vertex[0])>=min_x:reaches_max_x=true
			if float(vertex[1])>=min_y:reaches_max_y=true
			if float(vertex[2])<=high:reaches_low=true
			if float(vertex[2])>=low:reaches_high=true
		if not (reaches_min_x and reaches_min_y and reaches_max_x and reaches_max_y and reaches_low and reaches_high):continue
		var edges: Array=[1,1,1]
		for edge in 4:
			var a: Array=rectangle[edge];var b: Array=rectangle[(edge+1)&3]
			var side: Array=[]
			for vertex in triangle:
				side.append(f(f(f(float(vertex[1])-float(a[1]))*f(float(a[0])-float(b[0])))+f(f(float(vertex[0])-float(a[0]))*f(float(b[1])-float(a[1]))))>=0)
			for vertex in 3:
				if not side[vertex]:inside[vertex]=0
				if not side[vertex] and not side[(vertex+1)%3]:edges[vertex]=0
		for vertex in 3:
			if inside[vertex]==1:return 0
			if inside[vertex]==null:uncertain=true
			if edges[vertex]!=1:continue
			for edge in 4:
				var start_edge: Array=rectangle[edge]+[0.0]
				var end_edge: Array=rectangle[(edge+1)&3]+[0.0]
				var crossing: Variant=intersect.call(start_edge,end_edge,triangle[vertex],triangle[(vertex+1)%3]) if intersect.is_valid() else _intersect(start_edge,end_edge,triangle[vertex],triangle[(vertex+1)%3])
				if crossing!=null:return 0
		if _sides(triangle,rectangle[0]).all(func(value):return bool(value)):return 0
	if uncertain:return {"error":"Native "+scratch_label+" collision result depends on uninitialized inside-flag stack state"}
	return 1

static func _local(tile: Dictionary,point: Array)->Variant:
	var x:=f(f(float(point[0]))-f(f(float(tile.x))*10.0));var y:=f(f(float(point[1]))-f(f(float(tile.y))*10.0))
	match int(tile.get("orientation",-1)):
		0:return [x,y]
		1:return [y,f(10.0-x)]
		2:return [f(10.0-x),f(10.0-y)]
		3:return [f(10.0-y),x]
	return {"error":"Native tile orientation is unavailable"}
static func no_denied_area_tile_polygons(tile: Dictionary,start: Array,end: Array,low: float,high: float,radius: float,flag: int,initial_inside: Array=[null,null,null])->Variant:
	if not tile.get("mesh") is Dictionary or not is_finite(float(tile.get("heightOffset",NAN))):return {"error":"Native area tile collision mesh is unavailable"}
	var local_start: Variant=_local(tile,start);var local_end: Variant=_local(tile,end)
	if local_start is Dictionary:return local_start
	if local_end is Dictionary:return local_end
	return no_denied_tile_polygons(tile.mesh,local_start,local_end,f(f(low)-float(tile.heightOffset)),f(f(high)-float(tile.heightOffset)),radius,flag,initial_inside)
