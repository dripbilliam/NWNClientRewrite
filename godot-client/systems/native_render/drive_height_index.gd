extends RefCounted
# Share conservative per-face XY bounds across a single preview search's
# varying end-height samples. The original height route remains available.
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Terrain=preload("res://systems/native_render/terrain_surface.gd")
const PAD:=0.001
const MIN_FACES:=90
const MAX_TILES:=64
static var total_builds:=0
static var total_samples:=0
static var total_fallbacks:=0
static var mismatch_fallbacks:=0
var source: WeakRef
var definition: Dictionary
var meshes: Dictionary
var table: Dictionary
var rows: Array
var default_walk: Variant
var plans: Dictionary={}
var built:=0
var candidate_faces:=0
var rejected_faces:=0
var fallback:=0

static func worthwhile(surface,minimum: Vector3,maximum: Vector3)->bool:
	if not is_instance_valid(surface) or surface.get_script()!=Terrain or not surface.ready():return false
	var definition: Dictionary=surface.definition
	var width:=int(definition.get("width",0));var height:=int(definition.get("height",0))
	if width<=0 or height<=0:return false
	if not definition.get("tiles") is Array or definition.tiles.size()<width*height:return false
	var left:=maxi(0,floori(minimum.x/10.0));var right:=mini(width-1,floori(maximum.x/10.0))
	var bottom:=maxi(0,floori(minimum.y/10.0));var top:=mini(height-1,floori(maximum.y/10.0))
	if right<left or top<bottom or (right-left+1)*(top-bottom+1)>MAX_TILES:return false
	for y in range(bottom,top+1):
		for x in range(left,right+1):
			var tile: Variant=definition.tiles[y*width+x]
			if not tile is Dictionary:return false
			var mesh: Variant=surface.meshes.get(str(tile.model))
			if mesh is Dictionary and mesh.get("faces") is Array and mesh.faces.size()>=MIN_FACES:return true
	return false

func configure(surface)->bool:
	if not is_instance_valid(surface) or surface.get_script()!=Terrain or not surface.ready():return false
	var ordered: Variant=surface.table.get("orderedRows",[])
	if not ordered is Array:return false
	source=weakref(surface);definition=surface.definition;meshes=surface.meshes;table=surface.table;rows=ordered;default_walk=table.get("defaultValue","0")
	return true

func current(surface)->bool:
	return source!=null and is_instance_valid(surface) and source.get_ref()==surface and surface.get_script()==Terrain and not surface.closed and surface.ready() and is_same(surface.definition,definition) and is_same(surface.meshes,meshes) and is_same(surface.table,table) and is_same(surface.table.get("orderedRows",[]),rows) and surface.table.get("defaultValue","0")==default_walk

func make_plan(mesh: Dictionary)->Dictionary:
	if not mesh.get("faces") is Array or not mesh.get("vertices") is Array or not mesh.get("materials") is Array or not mesh.get("normals") is Array or not mesh.get("constants") is Array:return {}
	var faces: Array=mesh.faces;var vertices: Array=mesh.vertices;var materials: Array=mesh.materials
	if faces.size()!=materials.size() or faces.size()!=mesh.normals.size() or faces.size()!=mesh.constants.size() or faces.size()>4096:return {}
	var bounds:=PackedFloat64Array();bounds.resize(faces.size()*4)
	for i in faces.size():
		var face: Variant=faces[i]
		if not face is Array or face.size()!=3:return {}
		for j in 3:
			if int(face[j])<0 or int(face[j])>=vertices.size():return {}
		var a: Variant=vertices[int(face[0])];var b: Variant=vertices[int(face[1])];var c: Variant=vertices[int(face[2])]
		if not a is Array or not b is Array or not c is Array or a.size()<2 or b.size()<2 or c.size()<2:return {}
		var x0:=float(a[0]);var y0:=float(a[1]);var x1:=float(b[0]);var y1:=float(b[1]);var x2:=float(c[0]);var y2:=float(c[1])
		var valid:=is_finite(x0) and is_finite(y0) and is_finite(x1) and is_finite(y1) and is_finite(x2) and is_finite(y2)
		if not valid:return {}
		var area: float=(x1-x0)*(y2-y0)-(y1-y0)*(x2-x0)
		var uncullable:=maxf(absf(x0),maxf(absf(y0),maxf(absf(x1),maxf(absf(y1),maxf(absf(x2),absf(y2))))))>1000.0 or absf(area)<0.001
		var base:=i*4
		bounds[base]= -INF if uncullable else minf(x0,minf(x1,x2))-PAD
		bounds[base+1]=INF if uncullable else maxf(x0,maxf(x1,x2))+PAD
		bounds[base+2]= -INF if uncullable else minf(y0,minf(y1,y2))-PAD
		bounds[base+3]=INF if uncullable else maxf(y0,maxf(y1,y2))+PAD
	built+=1
	total_builds+=1
	return {"faces_ref":faces,"vertices_ref":vertices,"faces_snapshot":faces.duplicate(true),"vertices_snapshot":vertices.duplicate(true),"materials_ref":materials,"normals_ref":mesh.normals,"constants_ref":mesh.constants,"size":faces.size(),"bounds":bounds}

func height(surface,point: Vector3,previous: float)->float:
	if not current(surface):fallback+=1;total_fallbacks+=1;return surface.height(point,previous)
	var x:=floori(point.x/10.0);var y:=floori(point.y/10.0)
	if x<0 or y<0 or x>=int(definition.width) or y>=int(definition.height):
		surface.stats.queries+=1;surface.stats.outside_queries+=1;return previous
	var tile: Dictionary=definition.tiles[y*int(definition.width)+x];var key:=str(tile.model)
	var mesh: Variant=meshes.get(key)
	if not mesh is Dictionary:fallback+=1;total_fallbacks+=1;return surface.height(point,previous)
	if not mesh.get("faces") is Array or mesh.faces.size()<MIN_FACES:return surface.height(point,previous)
	var plan: Dictionary=plans.get(key,{})
	if plan.is_empty():
		plan=make_plan(mesh)
		if plan.is_empty():fallback+=1;total_fallbacks+=1;return surface.height(point,previous)
		plans[key]=plan
	# A retained query_preview Callable can be invoked again in the same frame.
	# Exact deep equality of the geometry snapshot detects in-place edits as well
	# as Array replacement before reusing bounds. Live material/plane data are
	# read on each query and never cached by this candidate.
	if not is_same(mesh.faces,plan.faces_ref) or not is_same(mesh.vertices,plan.vertices_ref) or not is_same(mesh.materials,plan.materials_ref) or not is_same(mesh.normals,plan.normals_ref) or not is_same(mesh.constants,plan.constants_ref) or mesh.faces.size()!=int(plan.size) or mesh.faces!=plan.faces_snapshot or mesh.vertices!=plan.vertices_snapshot:
		fallback+=1;total_fallbacks+=1;mismatch_fallbacks+=1;return surface.height(point,previous)
	surface.stats.queries+=1
	total_samples+=1
	var local: Array=Surface.canonical([Surface.f(Surface.f(point.x)-Surface.f(Surface.f(x)*10)),Surface.f(Surface.f(point.y)-Surface.f(Surface.f(y)*10))],int(tile.orientation))
	var px:=Surface.f(local[0]);var py:=Surface.f(local[1]);var bounds: PackedFloat64Array=plan.bounds
	for allowed in [true,false]:
		for index in mesh.faces.size():
			var base: int=index*4
			if px<bounds[base] or px>bounds[base+1] or py<bounds[base+2] or py>bounds[base+3]:rejected_faces+=1;continue
			if Surface.walkable(table,int(mesh.materials[index]))!=allowed:continue
			candidate_faces+=1
			var face: Array=mesh.faces[index];var a: Array=mesh.vertices[face[0]];var b: Array=mesh.vertices[face[1]];var c: Array=mesh.vertices[face[2]]
			if Surface.edge(a,b,px,py)>=0 and Surface.edge(b,c,px,py)>=0 and Surface.edge(c,a,px,py)>=0:
				var n: Array=mesh.normals[index]
				var value:=0.0 if n[2]==0 else Surface.f(-Surface.f(Surface.f(Surface.f(n[1]*py)+Surface.f(Surface.f(n[0]*px)+Surface.f(mesh.constants[index]))))/n[2])
				return Surface.f(value+Surface.f(tile.position.y))
	return Surface.f(0.0+Surface.f(tile.position.y))
