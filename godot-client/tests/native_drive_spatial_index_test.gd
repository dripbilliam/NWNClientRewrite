extends SceneTree
const Index=preload("res://systems/native_render/drive_spatial_index.gd")
var checks:=0
var failures: Array=[]
var random_queries:=0
var narrow_comparisons:=0
func check(value: bool,label: String)->void:
	checks+=1
	if not value and failures.size()<60:failures.append(label)
func _initialize()->void:call_deferred("run")
func audit_node(index,id: int,parent: int,seen: Dictionary)->Dictionary:
	if seen.has(id) or not index._nodes.has(id):
		check(false,"Tree has no cycles or missing child")
		return {"height":0,"min_x":0.0,"min_y":0.0,"max_x":0.0,"max_y":0.0}
	seen[id]=true
	var node: Dictionary=index._nodes[id]
	check(int(node.parent)==parent,"Child points to exact parent")
	if int(node.left)<0:
		check(int(node.right)<0 and int(node.height)==0,"Leaf height/children")
		check(index._rows.has(int(node.id)) and int(index._rows[int(node.id)].leaf)==id,"Leaf belongs to exactly its source row")
		return node
	var left:=audit_node(index,int(node.left),id,seen)
	var right:=audit_node(index,int(node.right),id,seen)
	check(int(node.height)==1+maxi(int(left.height),int(right.height)),"Branch height is exact")
	check(absi(int(left.height)-int(right.height))<=1,"Branch remains height balanced")
	check(float(node.min_x)==minf(left.min_x,right.min_x) and float(node.min_y)==minf(left.min_y,right.min_y) and float(node.max_x)==maxf(left.max_x,right.max_x) and float(node.max_y)==maxf(left.max_y,right.max_y),"Branch is exact union of both children")
	return node
func audit(index)->void:
	var seen: Dictionary={}
	if index._root>=0:audit_node(index,index._root,-1,seen)
	check(seen.size()==index._nodes.size(),"No detached tree nodes remain")
	check(index._nodes.size()==maxi(0,index._rows.size()*2-1),"Binary tree storage has one leaf per live source")
static func bounds(minimum: Vector3,maximum: Vector3)->Dictionary:
	return {"min_x":float(minimum.x),"min_y":float(minimum.y),"max_x":float(maximum.x),"max_y":float(maximum.y),"min_z":float(minimum.z),"max_z":float(maximum.z)}
static func point_bounds(point: Vector2,radius: float)->Dictionary:
	return {"min_x":float(point.x)-radius,"min_y":float(point.y)-radius,"max_x":float(point.x)+radius,"max_y":float(point.y)+radius,"min_z":0.0,"max_z":0.0}
func oracle(rows: Array,from: Vector3,to: Vector3,radius: float,exclude: int,creatures: bool,vertical: Variant)->Array:
	var found: Array=[]
	for row in rows:
		if int(row.id)==exclude or row.kind=="creature" and not creatures:continue
		var expansion:=0.0 if row.kind=="pending" else radius
		var box: Dictionary=row.bounds
		if float(box.min_x)>maxf(from.x,to.x)+expansion or float(box.max_x)<minf(from.x,to.x)-expansion or float(box.min_y)>maxf(from.y,to.y)+expansion or float(box.max_y)<minf(from.y,to.y)-expansion:continue
		if vertical!=null and row.kind in ["pwk","dwk","static"] and (float(box.min_z)>vertical.y or float(box.max_z)<vertical.x):continue
		found.append(row)
	found.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		return int(a.order)<int(b.order))
	return found.map(func(row):return int(row.id))
static func point_distance(point: Vector2,a: Vector2,b: Vector2)->float:
	var direction:=b-a
	var fraction:=clampf((point-a).dot(direction)/direction.length_squared(),0,1) if direction.length_squared()>0 else 0.0
	return point.distance_squared_to(a+direction*fraction)
static func cross(a: Vector2,b: Vector2)->float:return a.x*b.y-a.y*b.x
static func edges_cross(a: Vector2,b: Vector2,c: Vector2,d: Vector2)->bool:
	var den:=cross(b-a,d-c)
	if den==0:return false
	var t:=cross(c-a,d-c)/den
	var u:=cross(c-a,b-a)/den
	return t>=0 and t<=1 and u>=0 and u<=1
static func inside(point: Vector2,a: Vector2,b: Vector2,c: Vector2)->bool:
	var x:=cross(b-a,point-a)
	var y:=cross(c-b,point-b)
	var z:=cross(a-c,point-c)
	return (x>=0 and y>=0 and z>=0) or (x<=0 and y<=0 and z<=0)
static func triangle_hit(a: Vector2,b: Vector2,vertices: Array,radius: float)->bool:
	if inside(a,vertices[0],vertices[1],vertices[2]) or inside(b,vertices[0],vertices[1],vertices[2]):return true
	for i in 3:
		var c: Vector2=vertices[i]
		var d: Vector2=vertices[(i+1)%3]
		if edges_cross(a,b,c,d):return true
		if minf(minf(point_distance(a,c,d),point_distance(b,c,d)),minf(point_distance(c,a,b),point_distance(d,a,b)))<=radius*radius:return true
	return false
func blocked(rows: Array,selected: Variant,from: Vector3,to: Vector3,radius: float,exclude: int,creatures: bool,vertical: Vector2)->bool:
	var a:=Vector2(from.x,from.y)
	var b:=Vector2(to.x,to.y)
	for row in rows:
		if selected!=null and not selected.has(int(row.id)):continue
		if int(row.id)==exclude or row.kind=="creature" and not creatures:continue
		if row.kind=="pending":
			if point_distance(row.point,a,b)<144.0:return true
		elif row.kind=="creature":
			if point_distance(row.point,a,b)<=(radius+float(row.radius))*(radius+float(row.radius)):return true
		elif float(row.bounds.min_z)<=vertical.y and float(row.bounds.max_z)>=vertical.x and triangle_hit(a,b,row.triangle,radius):return true
	return false
func basics()->void:
	var index:=Index.new()
	var source_scope: Array=[101,2,91]
	var ticket:=index.begin(source_scope)
	source_scope[0]=999
	check(ticket.ready and index.snapshot().scope==[101,2,91],"Scope is detached from caller")
	check(index.query(ticket,Vector3.ZERO,Vector3.ONE,0).ready,"Empty bound index is ready")
	var life: Array=[5,9]
	check(index.upsert_shape(ticket,1,life,1,"pwk",Vector3(-3,-1,0),Vector3(-2,1,2),false,30).accepted,"Noninteractable PWK is indexed without interaction flags")
	life[1]=100
	check(index.upsert_pending(ticket,2,[6,10],1,Vector2(10,0),false,10).accepted,"Pending resource has native fixed12m neighborhood")
	check(index.upsert_creature(ticket,3,[7,11],1,Vector2(4,0),0.5,false,20).accepted,"Moving creature owns its personal-space bounds")
	var hit:=index.query(ticket,Vector3(-4,0,50),Vector3(4,0,50),0.2)
	check(hit.ids==[2,3,1],"Candidates follow explicit desired-source order rather than spatial traversal")
	hit.rows[2].witness[1]=99;hit.rows[2].bounds.min_x=9999
	check(index.query(ticket,Vector3(-4,0,0),Vector3(-2,0,0),0).ids.has(1),"Returned rows and witness arrays are detached")
	check(not index.upsert_shape(ticket,1,[5,100],2,"pwk",Vector3.ZERO,Vector3.ONE).accepted,"Input witness mutation cannot replace accepted lifetime")
	check(index.query(ticket,Vector3(-4,0,50),Vector3(4,0,50),0.2,-1,true,Vector2(49,51)).ids==[2,3],"Static Z pruning requires explicit height interval; pending/creature stay2D")
	check(not index.query(ticket,Vector3(4,0,0),Vector3(4,0,0),0,-1,false).ids.has(3),"Acknowledgment query can exclude all creatures")
	check(not index.query(ticket,Vector3(4,0,0),Vector3(4,0,0),0,3,true).ids.has(3),"Controlled source can be excluded exactly")
	check(index.upsert_creature(ticket,3,[7,11],2,Vector2(100,100),0.5).accepted,"Moving source updates the same leaf")
	check(not index.query(ticket,Vector3(4,0,0),Vector3(4,0,0),0).ids.has(3),"Old creature location no longer occupies query")
	check(index.query(ticket,Vector3(100,100,-99),Vector3(100,100,-99),0).ids.has(3),"Creature XY admission is independent of visual height/model")
	check(index.upsert_shape(ticket,1,[5,9],2,"pwk",Vector3(-3,-1,0),Vector3(-2,1,2),false,0).accepted,"Order-only publication accepts a fresh owner revision")
	check(index.query(ticket,Vector3(-4,0,0),Vector3(100,100,0),0).ids[0]==1,"Order-only update changes candidate ordering without losing bounds")
	audit(index)
func lifecycle()->void:
	var index:=Index.new()
	var ticket:=index.begin([101,2,91])
	check(index.upsert_pending(ticket,7,[1,1],1,Vector2.ZERO).accepted,"Initial pending publication")
	check(index.upsert_shape(ticket,7,[1,1],2,"dwk",Vector3.ZERO,Vector3.ONE).accepted,"Completed DWK replaces pending state on newer revision")
	check(not index.upsert_pending(ticket,7,[1,1],1,Vector2.ZERO).accepted,"Late resource result cannot regress accepted geometry")
	check(index.withdraw(ticket,7,[1,1],3).accepted,"Known-empty open door withdraws geometry without retiring source")
	check(index.query(ticket,Vector3.ZERO,Vector3.ONE,0).ids.is_empty(),"Open door has no candidate leaf")
	check(index.upsert_shape(ticket,7,[1,1],4,"dwk",Vector3.ZERO,Vector3.ONE).accepted,"Closing door republishes geometry in the same lifetime")
	check(index.query(ticket,Vector3.ZERO,Vector3.ONE,0).ids==[7],"Reclosed door is a current candidate")
	check(index.remove(ticket,7,[1,1],5).accepted,"Current removal retires geometry")
	check(not index.upsert_pending(ticket,7,[1,1],999,Vector2.ZERO).accepted,"Removed lifetime cannot revive at a newer callback revision")
	check(not index.upsert_pending(ticket,7,[1,2],4,Vector2.ZERO).accepted,"ID reuse requires explicit accepted lifetime replacement")
	check(index.upsert_pending(ticket,7,[1,2],6,Vector2.ZERO,true).accepted,"Explicit current ID reuse replaces retired witness")
	check(not index.remove(ticket,7,[1,1],1000).accepted,"Old removal cannot erase reused ID")
	check(not index.upsert_pending(ticket,7,[1,1],1000,Vector2(900,900)).accepted,"Old asynchronous callback cannot retarget new lifetime")
	check(index.remove(ticket,55,[8,8],10).accepted,"Removal-before-first-publication records a tombstone")
	check(not index.upsert_pending(ticket,55,[8,8],11,Vector2.ZERO).accepted,"Late first publication is blocked by removal tombstone")
	check(index.upsert_pending(ticket,55,[8,9],12,Vector2.ZERO,true).accepted,"New lifetime after early removal is explicit")
	var before:=index.snapshot()
	check(not index.upsert_shape(ticket,55,[8,9],13,"pwk",Vector3.ONE,Vector3.ZERO).accepted,"Inverted bounds rejected atomically")
	check(index.snapshot()==before,"Malformed geometry changes no state")
	check(not index.query(ticket,Vector3(NAN,0,0),Vector3.ZERO,0).ready,"Nonfinite query is unavailable, never clear")
	check(not index.query(ticket,Vector3.ZERO,Vector3.ZERO,-1).ready,"Negative radius is unavailable")
	check(not index.query(ticket,Vector3.ZERO,Vector3.ZERO,0,-1,true,Vector2(2,1)).ready,"Inverted vertical interval is unavailable")
	check(index.clear(ticket),"Current clear retires the index")
	check(not index.query(ticket,Vector3.ZERO,Vector3.ONE,0).ready,"Clear invalidates old query ticket")
	var replacement:=index.begin([101,2,91])
	check(replacement.epoch!=ticket.epoch,"Resetting identical external scope still issues a new epoch")
	check(not index.upsert_pending(ticket,99,[1,1],1,Vector2.ZERO).accepted,"Old ticket cannot populate reset same-scope index")
	check(index.upsert_pending(replacement,99,[1,1],1,Vector2.ZERO).accepted,"New scope ticket admits current source")
	check(not index.begin([0,2,91]).ready,"Unknown scope rejected")
	check(index.query(replacement,Vector3.ZERO,Vector3.ZERO,0).ready,"Rejected scope transition preserves current state")
	var bad_object:=RefCounted.new()
	check(not index.upsert_pending(replacement,99,[bad_object,1],2,Vector2.ZERO).accepted,"Object cannot enter lifetime storage")
	check(not index.begin([bad_object,2,91]).ready,"Object cannot enter scope storage")
	audit(index)
func edges_and_structure()->void:
	var index:=Index.new()
	var ticket:=index.begin([-100,0,0xffffffff])
	check(index.upsert_shape(ticket,0xffffffff,[1,1],1,"static",Vector3(-100000000,-100000000,-5),Vector3(100000000,100000000,5)).accepted,"Huge bounds and unsigned entity ID need no grid overflow cap")
	check(index.query(ticket,Vector3(-99999992,0,0),Vector3(-99999992,0,0),0).ids.has(0xffffffff),"Negative far coordinate remains queryable")
	check(index.upsert_shape(ticket,1,[2,2],1,"pwk",Vector3(-11,-2,0),Vector3(-10,2,1)).accepted,"Negative boundary shape")
	check(index.query(ticket,Vector3(-9.5,0,0),Vector3(-9.5,0,0),0.5).ids.has(1),"Capsule boundary touch is conservatively retained")
	check(index.upsert_pending(ticket,2,[3,3],1,Vector2(20,0)).accepted,"Pending radius test source")
	check(not index.query(ticket,Vector3(7,0,0),Vector3(7,0,0),100).ids.has(2),"Mover radius does not change fixed pending12m rule")
	check(index.query(ticket,Vector3(8,0,0),Vector3(8,0,0),0).ids.has(2),"Pending exact12m touch is an allowed conservative false positive")
	for i in 2048:
		var x:=float(i%64)*20.0+1000.0
		var y:=float(i/64)*20.0+1000.0
		index.upsert_shape(ticket,100+i,[100+i,1],1,"pwk",Vector3(x,y,0),Vector3(x+1,y+1,2))
	audit(index)
	var local:=index.query(ticket,Vector3(1000,1000,0),Vector3(1001,1001,0),0)
	check(local.ready and local.ids.has(100),"Dense deterministic distribution returns nearby source")
	check(int(local.tested_leaves)<int(index.snapshot().entries),"Local query does not enumerate all live rows")
	check(int(local.visited_nodes)<int(index.snapshot().nodes),"Tree prunes nonoverlapping branches")
	check(int(index.snapshot().height)<=24,"Ordered insertion remains height bounded for2048 leaves")
	var all:=index.query(ticket,Vector3(-200000000,-200000000,0),Vector3(200000000,200000000,0),0)
	check(all.ids.size()==int(index.snapshot().entries),"Wide query has no arbitrary result cap")
	for i in range(0,2048,2):index.remove(ticket,100+i,[100+i,1],2)
	audit(index)
	check(int(index.snapshot().entries)==1027,"Interleaved removals preserve other sources")
func randomized()->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=0x5a17c011
	var index:=Index.new()
	var ticket:=index.begin([701,3,91])
	var rows: Array=[]
	for i in 240:
		var point:=Vector2(rng.randf_range(-150,150),rng.randf_range(-150,150))
		var kind: String=["pwk","dwk","static","pending","creature"][i%5]
		var row: Dictionary={"id":i,"kind":kind,"order":239-i,"point":point,"radius":rng.randf_range(0,2)}
		if kind=="pending":
			row.bounds=point_bounds(point,12)
			index.upsert_pending(ticket,i,[i+1,1],1,point,false,int(row.order))
		elif kind=="creature":
			row.bounds=point_bounds(point,float(row.radius))
			index.upsert_creature(ticket,i,[i+1,1],1,point,float(row.radius),false,int(row.order))
		else:
			var extent:=Vector2(rng.randf_range(0.1,12),rng.randf_range(0.1,12))
			var z:=rng.randf_range(-3,4)
			row.bounds=bounds(Vector3(point.x,point.y,z),Vector3(point.x+extent.x,point.y+extent.y,z+2))
			row.triangle=[point,point+Vector2(extent.x,0),point+extent]
			index.upsert_shape(ticket,i,[i+1,1],1,kind,Vector3(point.x,point.y,z),Vector3(point.x+extent.x,point.y+extent.y,z+2),false,int(row.order))
		rows.append(row)
	audit(index)
	for sample in 600:
		var from:=Vector3(rng.randf_range(-160,160),rng.randf_range(-160,160),0)
		var to:=from+Vector3(rng.randf_range(-35,35),rng.randf_range(-35,35),0)
		var radius:=rng.randf_range(0,3)
		var exclude:=rng.randi_range(-1,239)
		var creatures: bool=sample%3!=0
		var vertical:=Vector2(-0.1,1.9)
		var result:=index.query(ticket,from,to,radius,exclude,creatures,vertical)
		check(result.ready and result.ids==oracle(rows,from,to,radius,exclude,creatures,vertical),"Seeded brute-force AABB candidate/order equality "+str(sample))
		random_queries+=1
		check(blocked(rows,null,from,to,radius,exclude,creatures,vertical)==blocked(rows,result.ids,from,to,radius,exclude,creatures,vertical),"Seeded independent triangle/circle/pending blocked equivalence "+str(sample))
		narrow_comparisons+=1
		if sample%50==0:
			var creature_id:=4+(sample/50)*5
			var moved:=Vector2(rng.randf_range(-150,150),rng.randf_range(-150,150))
			rows[creature_id].point=moved;rows[creature_id].bounds=point_bounds(moved,float(rows[creature_id].radius))
			index.upsert_creature(ticket,creature_id,[creature_id+1,1],2,moved,float(rows[creature_id].radius),false,int(rows[creature_id].order))
			audit(index)
	for row in rows:index.remove(ticket,int(row.id),[int(row.id)+1,1],3)
	audit(index)
	check(index.snapshot().entries==0 and index.snapshot().nodes==0,"Complete removal leaves no tree or row storage")
func bulk_publication()->void:
	var values: Array=[-1.0e300,-1.0e38,-10.0,-0.0,0.0,0.1,1.0,1.1,1.0e38,1.0e300]
	var keys: Array[Vector3i]=[]
	for i in range(values.size()-1,-1,-1):keys.append(Index._centroid_key(values[i],i))
	keys.sort()
	for i in keys.size():check(keys[i].z==i,"Native centroid sort preserves finite double order including signedzero")
	var index:=Index.new()
	var ticket:=index.begin([702,3,91])
	check(index.begin_batch(ticket),"Bulk publication opens only current scope")
	for i in 200:
		check(index.upsert_shape(ticket,i,[i+1,1],1,"pwk",Vector3(i%20,i/20,0),Vector3(i%20+0.5,i/20+0.5,2),false,199-i).accepted,"Bulk retains exact row")
	check(not index.query(ticket,Vector3.ZERO,Vector3.ONE,0).ready,"Reentrant query cannot see partial synchronous bulk tree")
	check(index.end_batch(ticket),"Bulk tree completes before returning to frame")
	audit(index)
	for i in 20:
		var a:=Vector3(i-5,i%7-2,0)
		var b:=a+Vector3(3,4,0)
		check(index.query(ticket,a,b,0.3).ids==index.query_flat_control(ticket,a,b,0.3).ids,"Bulk tree/retained-flat candidate order equality")
	check(index.begin_batch(ticket) and index.begin_batch(ticket),"Nested same-turn cohort opens")
	for i in 40:index.remove(ticket,i,[i+1,1],2)
	for i in range(40,80):index.upsert_shape(ticket,i,[i+1,1],2,"dwk",Vector3(-i,0,0),Vector3(-i+1,1,2))
	check(index.end_batch(ticket) and not index.query(ticket,Vector3.ZERO,Vector3.ONE,0).ready,"Inner batch cannot expose incomplete outer publication")
	check(index.end_batch(ticket),"Outer publication completes once")
	audit(index)
	check(index.snapshot().entries==160,"Bulk removal and moved geometry retain exact membership")
	index.upsert_creature(ticket,201,[202,1],1,Vector2(3,4),0.5)
	audit(index)
	check(index.query(ticket,Vector3(2,4,0),Vector3(4,4,0),0.3).ids==index.query_flat_control(ticket,Vector3(2,4,0),Vector3(4,4,0),0.3).ids,"Incremental movement remains valid after bulk publication")
func run()->void:
	basics();lifecycle();edges_and_structure();randomized();bulk_publication()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"random_queries":random_queries,"narrow_comparisons":narrow_comparisons,"seed":0x5a17c011,"scope":"Pure scoped broadphase tree over authored geometry and independent brute-force candidate/narrow geometry oracles. No live world, original collision execution, native movement, GPU or performance acceptance."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"  ")+"\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
