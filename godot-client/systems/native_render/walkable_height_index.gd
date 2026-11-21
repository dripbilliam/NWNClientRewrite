extends RefCounted

# Direct source port of NetworkScene's WalkableHeightIndex. TerrainSurface owns
# the WOKs; this owner only projects their walkable faces into network motion.
const TileSurface=preload("res://systems/native_data/tile_surface.gd")
var surface: Node
var source: Array=[]
var source_count:=0
var cells: Dictionary={}
var overflow: Array=[]
var overflow_triangles: Array=[]
var references:=0
var closed:=false
var queries:=0
var candidates:=0
var full_scans:=0
var coordinate_limit:=1.0
var fallback:=false
var built:=false
var cell_size:=10.0
var max_references:=1000000

func configure(value: Node)->void:
	surface=value

func _project()->void:
	if built or closed or not is_instance_valid(surface) or not surface.done or surface.table.is_empty():return
	var definition: Dictionary=surface.definition
	for index in definition.tiles.size():
		var tile: Dictionary=definition.tiles[index]
		if not surface.meshes.has(str(tile.model)):continue
		var mesh: Dictionary=surface.meshes[str(tile.model)]
		var tile_x: int=index%int(definition.width)
		var tile_y:=floori(float(index)/float(definition.width))
		var origin_x:=TileSurface.f(float(tile_x)*10.0)
		var origin_y:=TileSurface.f(float(tile_y)*10.0)
		var elevation:=TileSurface.f(float(tile.height)*float(definition.transition))
		var vertices: Array=[]
		for vertex in mesh.vertices:
			# The WOK vertex is canonical; area.js rotates it into the placed tile.
			# Height/camera queries use the opposite, world-to-canonical turn.
			var local: Array=TileSurface.canonical([TileSurface.f(origin_x+TileSurface.f(float(vertex[0])))-origin_x,TileSurface.f(origin_y+TileSurface.f(float(vertex[1])))-origin_y],posmod(4-int(tile.orientation),4))
			vertices.append([TileSurface.f(origin_x+float(local[0])),TileSurface.f(float(vertex[2])+elevation),-TileSurface.f(origin_y+float(local[1]))])
		for face_index in mesh.faces.size():
			if not TileSurface.walkable(surface.table,int(mesh.materials[face_index])):continue
			var face: Array=mesh.faces[face_index]
			source.append({"vertices":[vertices[int(face[0])],vertices[int(face[1])],vertices[int(face[2])]],"surfaceType":int(mesh.materials[face_index])})
	source_count=source.size()
	for index in source_count:
		var triangle: Dictionary=source[index]
		var points: Array=triangle.vertices
		var a: Array=points[0];var b: Array=points[1];var c: Array=points[2]
		var min_x:=minf(float(a[0]),minf(float(b[0]),float(c[0])))
		var max_x:=maxf(float(a[0]),maxf(float(b[0]),float(c[0])))
		var min_z:=minf(float(a[2]),minf(float(b[2]),float(c[2])))
		var max_z:=maxf(float(a[2]),maxf(float(b[2]),float(c[2])))
		var extent:=maxf(max_x-min_x,max_z-min_z)
		var magnitude:=maxf(maxf(absf(min_x),absf(max_x)),maxf(absf(min_z),absf(max_z)))
		var u: float=(float(b[2])-float(c[2]))*(float(a[0])-float(c[0]))
		var v: float=(float(c[0])-float(b[0]))*(float(a[2])-float(c[2]))
		var denominator:=u+v
		if is_finite(magnitude):coordinate_limit=maxf(coordinate_limit,magnitude*2.0+1.0)
		if absf(denominator)<1e-8:continue
		if not is_finite(denominator) or not is_finite(magnitude) or magnitude>1e8 or absf(denominator)<maxf(maxf(absf(u),absf(v)),extent*extent)*1e-8:
			overflow.append(index);continue
		var margin:=3e-5*extent+64.0*2.220446049250313e-16*maxf(1.0,magnitude)
		var left:=floori((min_x-margin)/cell_size);var right:=floori((max_x+margin)/cell_size)
		var bottom:=floori((min_z-margin)/cell_size);var top:=floori((max_z+margin)/cell_size)
		var count: int=(right-left+1)*(top-bottom+1)
		if count>4096:
			overflow.append(index);continue
		if references+count>max_references:fallback=true;break
		for cx in range(left,right+1):
			for cz in range(bottom,top+1):
				var key:=Vector2i(cx,cz)
				if not cells.has(key):cells[key]=[]
				cells[key].append(index)
		references+=count
	var total_cells:=cells.size()
	for index in overflow:overflow_triangles.append(source[int(index)])
	if references+overflow.size()*total_cells>max_references:fallback=true
	if fallback:
		cells.clear();references=0;overflow.clear();overflow_triangles.clear()
	else:
		for key in cells:
			var indices: Array=cells[key].duplicate()
			indices.append_array(overflow);indices.sort()
			var merged: Array=[]
			for index in indices:merged.append(source[int(index)])
			cells[key]=merged
	built=true

func _height(triangles: Array,x: float,z: float,reference_height: float,max_delta: float)->Variant:
	var best_height: Variant=null
	var best_distance:=INF
	for triangle in triangles:
		var points: Array=triangle.vertices
		var a: Array=points[0];var b: Array=points[1];var c: Array=points[2]
		var denominator: float=(float(b[2])-float(c[2]))*(float(a[0])-float(c[0]))+(float(c[0])-float(b[0]))*(float(a[2])-float(c[2]))
		if absf(denominator)<1e-8:continue
		var weight_a: float=((float(b[2])-float(c[2]))*(x-float(c[0]))+(float(c[0])-float(b[0]))*(z-float(c[2])))/denominator
		var weight_b: float=((float(c[2])-float(a[2]))*(x-float(c[0]))+(float(a[0])-float(c[0]))*(z-float(c[2])))/denominator
		var weight_c:=1.0-weight_a-weight_b
		if minf(weight_a,minf(weight_b,weight_c))< -1e-5:continue
		var height: float=weight_a*float(a[1])+weight_b*float(b[1])+weight_c*float(c[1])
		var distance:=absf(height-reference_height) if is_finite(reference_height) else -height
		if distance>max_delta or distance>=best_distance:continue
		best_height=height;best_distance=distance
	return best_height

func height(point: Vector3,previous: float)->float:
	_project()
	if not built or closed:return previous
	queries+=1
	var x:=float(point.x);var z: float=-point.y
	var full:=fallback or source.size()!=source_count or not is_finite(x) or not is_finite(z) or absf(x)>coordinate_limit or absf(z)>coordinate_limit
	var triangles: Array=source if full else cells.get(Vector2i(floori(x/cell_size),floori(z/cell_size)),overflow_triangles)
	if full:full_scans+=1
	candidates+=triangles.size()
	var selected: Variant=_height(triangles,x,z,previous,INF)
	return float(selected) if selected!=null else previous

func snapshot()->Dictionary:
	return {"triangles":source_count,"cells":cells.size(),"references":references,"overflow":overflow.size(),"queries":queries,"candidates":candidates,"fullScans":full_scans,"fallback":fallback,"closed":closed}

func close()->void:
	cells.clear();overflow.clear();overflow_triangles.clear();source.clear();references=0;closed=true;surface=null
