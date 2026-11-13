extends RefCounted
# Isolated broadphase candidate. Coordinates are NWN X/Y horizontal, Z height.
# Does not own geometry, entities, received rows, Nodes, collision or movement.
const SHAPES=["pwk","dwk","static"]
const PENDING_RADIUS:=12.0
const STAGE_CHUNK:=256
var _epoch:=0
var _scope: Array=[]
var _active:=false
var _root:=-1
var _next_node:=0
var _next_order:=0
var _nodes: Dictionary={}
var _rows: Dictionary={}
var _ledger: Dictionary={}
var _last_query: Dictionary={}
var _batch_depth:=0
var _last_bulk_ms:=0.0
var _finalize: Dictionary={}
var stage_build_max_us:=0

static func _valid_scope(value: Array)->bool:
	return value.size()==3 and value[0] is int and value[0]!=0 and value[1] is int and value[1]>=0 and value[2] is int and value[2]>=0 and value[2]<=0xffffffff
static func _valid_source(id: int,witness: Array,revision: int)->bool:
	return id>=0 and id<=0xffffffff and revision>=0 and witness.size()==2 and witness[0] is int and witness[0]>0 and witness[1] is int and witness[1]>0
static func _finite3(value: Vector3)->bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
static func _finite2(value: Vector2)->bool:
	return is_finite(value.x) and is_finite(value.y)
func _current(ticket: Dictionary)->bool:
	return _active and ticket.get("epoch") is int and ticket.epoch==_epoch and ticket.get("scope") is Array and ticket.scope==_scope
func _reset_storage()->void:
	_root=-1;_next_node=0;_next_order=0
	_batch_depth=0
	_finalize={}
	_nodes.clear();_rows.clear();_ledger.clear();_last_query.clear()
func begin(scope: Array)->Dictionary:
	if not _valid_scope(scope):return {"ready":false,"reason":"invalid-scope"}
	if _epoch==0x7fffffffffffffff:return {"ready":false,"reason":"epoch-exhausted"}
	_epoch+=1;_reset_storage();_scope=scope.duplicate();_active=true
	return {"ready":true,"epoch":_epoch,"scope":_scope.duplicate()}
func clear(ticket: Dictionary)->bool:
	if not _current(ticket):return false
	_reset_storage();_scope=[];_active=false
	return true
static func _reject(reason: String)->Dictionary:
	return {"accepted":false,"changed":false,"reason":reason}
func begin_batch(ticket: Dictionary)->bool:
	if not _current(ticket):return false
	_batch_depth+=1;return true
func end_batch(ticket: Dictionary)->bool:
	if not _current(ticket) or _batch_depth<1:return false
	_batch_depth-=1
	if _batch_depth>0:return true
	var began:=Time.get_ticks_usec()
	# Synchronous publication only: no frame can observe a half-updated tree.
	# Normal isolated updates continue using the incremental balanced tree.
	_nodes.clear();_next_node=0;_root=-1
	var leaves: Array=[]
	for row in _rows.values():
		var leaf:=_allocate_node();row.leaf=leaf
		var b: Dictionary=row.bounds
		_nodes[leaf]={"parent":-1,"left":-1,"right":-1,"height":0,"id":row.id,"min_x":b.min_x,"min_y":b.min_y,"max_x":b.max_x,"max_y":b.max_y}
		leaves.append(leaf)
	if leaves.is_empty():_last_bulk_ms=(Time.get_ticks_usec()-began)/1000.0;return true
	var whole: Dictionary=_nodes[leaves[0]].duplicate()
	for leaf in leaves:
		var b: Dictionary=_nodes[leaf]
		whole.min_x=minf(whole.min_x,b.min_x);whole.min_y=minf(whole.min_y,b.min_y);whole.max_x=maxf(whole.max_x,b.max_x);whole.max_y=maxf(whole.max_y,b.max_y)
	var use_x: bool=float(whole.max_x)-float(whole.min_x)>=float(whole.max_y)-float(whole.min_y)
	# Native lexicographic Vector3i sort avoids one GDScript comparator call
	# per O(N log N) comparison. Exact double bits are ordered into two signed
	# words; the final word indexes an Array (already signed32 sized).
	var keys: Array[Vector3i]=[]
	for i in leaves.size():
		var b: Dictionary=_nodes[leaves[i]]
		var center: float=float(b.min_x)*0.5+float(b.max_x)*0.5 if use_x else float(b.min_y)*0.5+float(b.max_y)*0.5
		keys.append(_centroid_key(center,i))
	keys.sort()
	var ordered: Array=[]
	for key in keys:ordered.append(leaves[key.z])
	_root=_build_balanced(ordered,0,ordered.size());_last_bulk_ms=(Time.get_ticks_usec()-began)/1000.0;return true
func begin_staged_end_batch(ticket: Dictionary)->bool:
	if not _current(ticket) or _batch_depth!=1 or not _finalize.is_empty():return false
	# Retain the publishing fence while rebuilding one bounded unit at a time.
	_nodes.clear();_next_node=0;_root=-1
	_finalize={"phase":"leaves","ids":_rows.keys(),"index":0,"leaves":[],"leaf_ids":{},"dirty":{},"began":Time.get_ticks_usec()}
	return true
func staged_end_batch_step(ticket: Dictionary)->bool:
	if not _current(ticket) or _finalize.is_empty():return false
	var state: Dictionary=_finalize;var index:=int(state.index)
	match str(state.phase):
		"leaves":
			if index<state.ids.size():
				var stop:=mini(index+STAGE_CHUNK,state.ids.size())
				while index<stop:
					var id:=int(state.ids[index]);index+=1
					if _rows.has(id):
						var row: Dictionary=_rows[id]
						var leaf:=_allocate_node();_rows[id].leaf=leaf
						var b: Dictionary=row.bounds
						_nodes[leaf]={"parent":-1,"left":-1,"right":-1,"height":0,"id":id,"min_x":b.min_x,"min_y":b.min_y,"max_x":b.max_x,"max_y":b.max_y}
						state.leaves.append(leaf);state.leaf_ids[id]=leaf
				state.index=index
				return false
			state.phase="whole";state.index=0
			if state.leaves.is_empty():state.phase="reconcile"
		"whole":
			if index==0:state.whole=_nodes[state.leaves[0]].duplicate()
			if index<state.leaves.size():
				var stop:=mini(index+STAGE_CHUNK,state.leaves.size())
				while index<stop:
					var b: Dictionary=_nodes[state.leaves[index]];var whole: Dictionary=state.whole
					whole.min_x=minf(whole.min_x,b.min_x);whole.min_y=minf(whole.min_y,b.min_y);whole.max_x=maxf(whole.max_x,b.max_x);whole.max_y=maxf(whole.max_y,b.max_y)
					index+=1
				state.index=index;return false
			state.use_x=float(state.whole.max_x)-float(state.whole.min_x)>=float(state.whole.max_y)-float(state.whole.min_y)
			state.phase="centroids";state.index=0;state.centroids=Array()
		"centroids":
			if index<state.leaves.size():
				var stop:=mini(index+STAGE_CHUNK,state.leaves.size())
				while index<stop:
					var b: Dictionary=_nodes[state.leaves[index]]
					var center: float=float(b.min_x)*0.5+float(b.max_x)*0.5 if state.use_x else float(b.min_y)*0.5+float(b.max_y)*0.5
					state.centroids.append(_centroid_key(center,index));index+=1
				state.index=index;return false
			state.phase="sort"
		"sort":
			state.centroids.sort();state.phase="ordered";state.index=0;state.ordered=Array()
		"ordered":
			if index<state.centroids.size():
				var stop:=mini(index+STAGE_CHUNK,state.centroids.size())
				while index<stop:state.ordered.append(state.leaves[state.centroids[index].z]);index+=1
				state.index=index;return false
			state.phase="build"
		"build":
			var build_began:=Time.get_ticks_usec()
			if not state.has("build_stack") and not state.ordered.is_empty():state.build_stack=[{"first":0,"last":state.ordered.size(),"stage":0,"left":-1,"right":-1}]
			if state.has("build_stack") and not _staged_build_step(state):
				stage_build_max_us=maxi(stage_build_max_us,Time.get_ticks_usec()-build_began)
				return false
			stage_build_max_us=maxi(stage_build_max_us,Time.get_ticks_usec()-build_began)
			state.phase="reconcile"
		"reconcile":
			if not state.dirty.is_empty():
				var id:=int(state.dirty.keys()[0]);state.dirty.erase(id)
				_reconcile_staged_row(id,state)
				return false
			_batch_depth=0;_last_bulk_ms=(Time.get_ticks_usec()-int(state.began))/1000.0;_finalize={}
			return true
	return false
func _staged_build_step(state: Dictionary)->bool:
	var stack: Array=state.build_stack
	var actions:=0
	while actions<STAGE_CHUNK and not stack.is_empty():
		var frame: Dictionary=stack.back()
		var first:=int(frame.first);var last:=int(frame.last)
		if last-first>1 and int(frame.stage)==0:
			frame.stage=1;stack.append({"first":first,"last":(first+last)/2,"stage":0,"left":-1,"right":-1});actions+=1;continue
		if last-first>1 and int(frame.stage)==2:
			frame.stage=3;stack.append({"first":(first+last)/2,"last":last,"stage":0,"left":-1,"right":-1});actions+=1;continue
		var node_id: int
		if last-first==1:node_id=int(state.ordered[first])
		else:
			node_id=_allocate_node()
			var left:=int(frame.left);var right:=int(frame.right)
			_nodes[node_id]={"parent":-1,"left":left,"right":right,"height":1,"id":-1}
			_nodes[left].parent=node_id;_nodes[right].parent=node_id;_pull(node_id)
		stack.pop_back()
		if stack.is_empty():_root=node_id
		else:
			var parent: Dictionary=stack.back()
			if int(parent.stage)==1:parent.left=node_id;parent.stage=2
			else:parent.right=node_id;parent.stage=4
		actions+=1
	return stack.is_empty()
func _reconcile_staged_row(id: int,state: Dictionary)->void:
	var leaf:=int(state.leaf_ids.get(id,-1));var row: Dictionary=_rows.get(id,{})
	if leaf>=0 and row.is_empty():
		_remove_leaf(leaf);_nodes.erase(leaf);state.leaf_ids.erase(id);return
	if row.is_empty():return
	if leaf<0:
		leaf=_allocate_node();state.leaf_ids[id]=leaf
		_nodes[leaf]={"parent":-1,"left":-1,"right":-1,"height":0,"id":id}
	else:
		var old: Dictionary=_nodes[leaf];var bounds: Dictionary=row.bounds
		if old.min_x==bounds.min_x and old.min_y==bounds.min_y and old.max_x==bounds.max_x and old.max_y==bounds.max_y:
			row.leaf=leaf;return
		_remove_leaf(leaf)
	var b: Dictionary=row.bounds
	_nodes[leaf].min_x=b.min_x;_nodes[leaf].min_y=b.min_y;_nodes[leaf].max_x=b.max_x;_nodes[leaf].max_y=b.max_y
	row.leaf=leaf;_insert_leaf(leaf)
func abort_batch_for_rebuild(ticket: Dictionary)->bool:
	if not _current(ticket) or _batch_depth<1:return false
	_finalize={};_batch_depth=0;_nodes.clear();_next_node=0;_root=-1
	for row in _rows.values():row.leaf=-1
	return true
static func _centroid_key(value: float,index: int)->Vector3i:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
	var low:=int(bytes.decode_u32(0));var high:=int(bytes.decode_u32(4))
	if high&0x80000000:high=(~high)&0xffffffff;low=(~low)&0xffffffff
	else:high=high^0x80000000
	return Vector3i(high-0x80000000,low-0x80000000,index)
func _build_balanced(leaves: Array,first: int,last: int)->int:
	if last-first==1:return int(leaves[first])
	var middle: int=(first+last)/2
	var left:=_build_balanced(leaves,first,middle)
	var right:=_build_balanced(leaves,middle,last)
	var at:=_allocate_node()
	_nodes[at]={"parent":-1,"left":left,"right":right,"height":1,"id":-1}
	_nodes[left].parent=at;_nodes[right].parent=at;_pull(at)
	return at
func upsert_shape(ticket: Dictionary,id: int,witness: Array,revision: int,kind: String,minimum: Vector3,maximum: Vector3,replace_lifetime: bool=false,source_order: int=-1)->Dictionary:
	if kind not in SHAPES or not _finite3(minimum) or not _finite3(maximum) or minimum.x>maximum.x or minimum.y>maximum.y or minimum.z>maximum.z:return _reject("invalid-shape")
	return _upsert(ticket,id,witness,revision,kind,{"min_x":float(minimum.x),"min_y":float(minimum.y),"max_x":float(maximum.x),"max_y":float(maximum.y),"min_z":float(minimum.z),"max_z":float(maximum.z)},replace_lifetime,source_order)
func upsert_pending(ticket: Dictionary,id: int,witness: Array,revision: int,point: Vector2,replace_lifetime: bool=false,source_order: int=-1)->Dictionary:
	if not _finite2(point):return _reject("invalid-pending-point")
	return _upsert(ticket,id,witness,revision,"pending",{"min_x":float(point.x)-PENDING_RADIUS,"min_y":float(point.y)-PENDING_RADIUS,"max_x":float(point.x)+PENDING_RADIUS,"max_y":float(point.y)+PENDING_RADIUS,"min_z":0.0,"max_z":0.0},replace_lifetime,source_order)
func upsert_creature(ticket: Dictionary,id: int,witness: Array,revision: int,point: Vector2,radius: float,replace_lifetime: bool=false,source_order: int=-1)->Dictionary:
	if not _finite2(point) or not is_finite(radius) or radius<0:return _reject("invalid-creature")
	return _upsert(ticket,id,witness,revision,"creature",{"min_x":float(point.x)-radius,"min_y":float(point.y)-radius,"max_x":float(point.x)+radius,"max_y":float(point.y)+radius,"min_z":0.0,"max_z":0.0},replace_lifetime,source_order)
func _upsert(ticket: Dictionary,id: int,witness: Array,revision: int,kind: String,bounds: Dictionary,replace_lifetime: bool,source_order: int)->Dictionary:
	if not _current(ticket):return _reject("scope")
	if not _valid_source(id,witness,revision) or source_order< -1:return _reject("invalid-source")
	for field in bounds:
		if not is_finite(float(bounds[field])):return _reject("bounds-overflow")
	var prior: Dictionary=_ledger.get(id,{})
	var replacing:=false
	if not prior.is_empty():
		if prior.witness!=witness:
			if not replace_lifetime or revision<=int(prior.revision):return _reject("lifetime")
			replacing=true
		elif prior.retired:return _reject("retired-lifetime")
		elif revision<int(prior.revision):return _reject("revision")
		elif revision==int(prior.revision):
			var previous: Dictionary=_rows.get(id,{})
			if not previous.is_empty() and previous.kind==kind and previous.bounds==bounds and (source_order<0 or int(previous.order)==source_order):return {"accepted":true,"changed":false}
			return _reject("conflicting-revision")
	var row: Dictionary=_rows.get(id,{})
	var retained: bool=not replacing and not prior.is_empty() and prior.has("sequence")
	var sequence: int=row.sequence if not row.is_empty() and not replacing else prior.sequence if retained else _next_order
	var order: int=source_order if source_order>=0 else row.order if not row.is_empty() and not replacing else prior.order if retained else sequence
	if (row.is_empty() and not retained) or replacing:_next_order+=1
	if not row.is_empty() and not replacing and row.kind==kind and row.bounds==bounds:
		row.order=order;row.revision=revision;_ledger[id].revision=revision;_ledger[id].order=order
		if not _finalize.is_empty():_finalize.dirty[id]=true
		return {"accepted":true,"changed":true}
	var leaf: int=row.leaf if not row.is_empty() else _allocate_node() if _batch_depth==0 else -1
	if not row.is_empty() and _batch_depth==0:_remove_leaf(leaf)
	if _batch_depth==0:_nodes[leaf]={"parent":-1,"left":-1,"right":-1,"height":0,"id":id,"min_x":bounds.min_x,"min_y":bounds.min_y,"max_x":bounds.max_x,"max_y":bounds.max_y}
	_rows[id]={"id":id,"witness":witness.duplicate(),"revision":revision,"kind":kind,"bounds":bounds.duplicate(),"order":order,"sequence":sequence,"leaf":leaf}
	_ledger[id]={"witness":witness.duplicate(),"revision":revision,"retired":false,"order":order,"sequence":sequence}
	if not _finalize.is_empty():_finalize.dirty[id]=true
	if _batch_depth==0:_insert_leaf(leaf)
	return {"accepted":true,"changed":true}
func withdraw(ticket: Dictionary,id: int,witness: Array,revision: int,replace_lifetime: bool=false,source_order: int=-1)->Dictionary:
	# Geometry can become known-empty while the source lifetime stays alive
	# (an open DWK state or temporarily absent motion). remove() is retirement.
	if not _current(ticket):return _reject("scope")
	if not _valid_source(id,witness,revision) or source_order< -1:return _reject("invalid-source")
	var prior: Dictionary=_ledger.get(id,{})
	var same: bool=not prior.is_empty() and prior.witness==witness
	if not prior.is_empty():
		if not same and (not replace_lifetime or revision<=int(prior.revision)):return _reject("lifetime")
		if same and prior.retired:return _reject("retired-lifetime")
		if same and revision<int(prior.revision):return _reject("revision")
		if same and revision==int(prior.revision):
			if _rows.has(id):return _reject("conflicting-revision")
			return {"accepted":true,"changed":false}
	var changed:=_rows.has(id)
	var sequence: int=prior.sequence if same and prior.has("sequence") else _next_order
	var order: int=source_order if source_order>=0 else prior.order if same and prior.has("order") else sequence
	if not same or not prior.has("sequence"):_next_order+=1
	if changed:
		var leaf: int=_rows[id].leaf
		if _batch_depth==0:_remove_leaf(leaf)
		if _finalize.is_empty():_nodes.erase(leaf)
		_rows.erase(id)
		if not _finalize.is_empty():_finalize.dirty[id]=true
	_ledger[id]={"witness":witness.duplicate(),"revision":revision,"retired":false,"order":order,"sequence":sequence}
	return {"accepted":true,"changed":changed}
func remove(ticket: Dictionary,id: int,witness: Array,revision: int)->Dictionary:
	if not _current(ticket):return _reject("scope")
	if not _valid_source(id,witness,revision):return _reject("invalid-source")
	var prior: Dictionary=_ledger.get(id,{})
	if not prior.is_empty():
		if prior.witness!=witness:return _reject("lifetime")
		if revision<int(prior.revision):return _reject("revision")
		if revision==int(prior.revision) and not prior.retired:return _reject("conflicting-revision")
	var changed:=_rows.has(id)
	if changed:
		var leaf: int=_rows[id].leaf
		if _batch_depth==0:_remove_leaf(leaf)
		if _finalize.is_empty():_nodes.erase(leaf)
		_rows.erase(id)
		if not _finalize.is_empty():_finalize.dirty[id]=true
	# Also records removals before the first asynchronous geometry publication.
	_ledger[id]={"witness":witness.duplicate(),"revision":revision,"retired":true}
	return {"accepted":true,"changed":changed}
static func _overlap(a: Dictionary,b: Dictionary)->bool:
	return a.min_x<=b.max_x and a.max_x>=b.min_x and a.min_y<=b.max_y and a.max_y>=b.min_y
static func _measure(a: Dictionary)->float:
	# Scalar double arithmetic avoids Vector2 subtraction overflow at large scale.
	return (float(a.max_x)-float(a.min_x))+(float(a.max_y)-float(a.min_y))
static func _union(a: Dictionary,b: Dictionary)->Dictionary:
	return {"min_x":minf(a.min_x,b.min_x),"min_y":minf(a.min_y,b.min_y),"max_x":maxf(a.max_x,b.max_x),"max_y":maxf(a.max_y,b.max_y)}
func _allocate_node()->int:
	_next_node+=1
	return _next_node
func _pull(id: int)->void:
	var node: Dictionary=_nodes[id]
	if int(node.left)<0:return
	var left: Dictionary=_nodes[node.left]
	var right: Dictionary=_nodes[node.right]
	node.min_x=minf(left.min_x,right.min_x);node.min_y=minf(left.min_y,right.min_y);node.max_x=maxf(left.max_x,right.max_x);node.max_y=maxf(left.max_y,right.max_y)
	node.height=1+maxi(int(left.height),int(right.height))
func _replace_parent(old: int,next: int,parent: int)->void:
	if parent<0:_root=next
	elif int(_nodes[parent].left)==old:_nodes[parent].left=next
	else:_nodes[parent].right=next
	_nodes[next].parent=parent
func _balance(id: int)->int:
	var a: Dictionary=_nodes[id]
	if int(a.left)<0 or int(a.height)<2:return id
	var b_id: int=a.left
	var c_id: int=a.right
	var b: Dictionary=_nodes[b_id]
	var c: Dictionary=_nodes[c_id]
	var difference:=int(c.height)-int(b.height)
	if difference>1:
		var f_id: int=c.left
		var g_id: int=c.right
		var parent: int=a.parent
		_replace_parent(id,c_id,parent);c.left=id;a.parent=c_id
		if int(_nodes[f_id].height)>int(_nodes[g_id].height):
			c.right=f_id;a.right=g_id;_nodes[f_id].parent=c_id;_nodes[g_id].parent=id
		else:
			c.right=g_id;a.right=f_id;_nodes[g_id].parent=c_id;_nodes[f_id].parent=id
		_pull(id);_pull(c_id)
		return c_id
	if difference< -1:
		var d_id: int=b.left
		var e_id: int=b.right
		var parent: int=a.parent
		_replace_parent(id,b_id,parent);b.right=id;a.parent=b_id
		if int(_nodes[d_id].height)>int(_nodes[e_id].height):
			b.left=d_id;a.left=e_id;_nodes[d_id].parent=b_id;_nodes[e_id].parent=id
		else:
			b.left=e_id;a.left=d_id;_nodes[e_id].parent=b_id;_nodes[d_id].parent=id
		_pull(id);_pull(b_id)
		return b_id
	return id
func _refit(start: int)->void:
	var cursor:=start
	while cursor>=0:
		_pull(cursor);cursor=_balance(cursor);cursor=int(_nodes[cursor].parent)
func _insert_leaf(leaf: int)->void:
	if _root<0:_root=leaf;return
	var sibling:=_root
	# Always select a leaf, then use AVL-style height rotations on refit.
	# This avoids a large subtree/leaf insertion requiring an unbounded rebuild.
	while int(_nodes[sibling].left)>=0:
		var node: Dictionary=_nodes[sibling]
		var left: int=node.left
		var right: int=node.right
		var left_cost:=_measure(_union(_nodes[left],_nodes[leaf]))-_measure(_nodes[left])
		var right_cost:=_measure(_union(_nodes[right],_nodes[leaf]))-_measure(_nodes[right])
		if left_cost<right_cost or left_cost==right_cost and int(_nodes[left].height)<=int(_nodes[right].height):sibling=left
		else:sibling=right
	var previous: int=_nodes[sibling].parent
	var parent:=_allocate_node()
	_nodes[parent]={"parent":previous,"left":sibling,"right":leaf,"height":1,"id":-1}
	_replace_parent(sibling,parent,previous)
	_nodes[sibling].parent=parent;_nodes[leaf].parent=parent
	_refit(parent)
func _remove_leaf(leaf: int)->void:
	if leaf==_root:_root=-1;_nodes[leaf].parent=-1;return
	var parent: int=_nodes[leaf].parent
	var grand: int=_nodes[parent].parent
	var sibling: int=_nodes[parent].right if int(_nodes[parent].left)==leaf else _nodes[parent].left
	_replace_parent(parent,sibling,grand);_nodes.erase(parent);_nodes[leaf].parent=-1
	if grand>=0:_refit(grand)
static func _public_row(row: Dictionary)->Dictionary:
	return {"id":row.id,"witness":row.witness.duplicate(),"revision":row.revision,"kind":row.kind,"bounds":row.bounds.duplicate(),"order":row.order,"sequence":row.sequence}
func query_flat_control(ticket: Dictionary,from: Vector3,to: Vector3,radius: float,exclude_id: int=-1,include_creatures: bool=true)->Dictionary:
	# Diagnostic retained-bounds control, deliberately linear. No received-world,
	# descriptors, model demand, transforms or precise triangles are read here.
	var result: Dictionary={"ready":false,"ids":[],"rows":[],"visited_nodes":0,"tested_leaves":0}
	if not _current(ticket) or _batch_depth>0 or not _finite3(from) or not _finite3(to) or not is_finite(radius) or radius<0:return result
	for row in _rows.values():
		result.tested_leaves+=1
		if int(row.id)==exclude_id or row.kind=="creature" and not include_creatures:continue
		var amount:=0.0 if row.kind=="pending" else radius
		var b: Dictionary=row.bounds
		if float(b.min_x)>maxf(from.x,to.x)+amount or float(b.max_x)<minf(from.x,to.x)-amount or float(b.min_y)>maxf(from.y,to.y)+amount or float(b.max_y)<minf(from.y,to.y)-amount:continue
		result.rows.append(_public_row(row))
	result.rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		return int(a.order)<int(b.order) if int(a.order)!=int(b.order) else int(a.sequence)<int(b.sequence))
	for row in result.rows:result.ids.append(int(row.id))
	result.ready=true;return result
func query(ticket: Dictionary,from: Vector3,to: Vector3,radius: float,exclude_id: int=-1,include_creatures: bool=true,vertical: Variant=null)->Dictionary:
	var result: Dictionary={"ready":false,"reason":"scope","ids":[],"rows":[],"visited_nodes":0,"tested_leaves":0}
	if not _current(ticket):return result
	if _batch_depth>0:result.reason="publishing";return result
	if not _finite3(from) or not _finite3(to) or not is_finite(radius) or radius<0:
		result.reason="invalid-query";return result
	if vertical!=null and (not vertical is Vector2 or not _finite2(vertical) or vertical.x>vertical.y):
		result.reason="invalid-vertical-range";return result
	# Query-local scalars preserve the original double folds and positive-AND
	# overlap comparisons. No derived data survives this synchronous query.
	var segment_min_x:=minf(from.x,to.x);var segment_min_y:=minf(from.y,to.y)
	var segment_max_x:=maxf(from.x,to.x);var segment_max_y:=maxf(from.y,to.y)
	var sweep_min_x:=segment_min_x-radius;var sweep_min_y:=segment_min_y-radius
	var sweep_max_x:=segment_max_x+radius;var sweep_max_y:=segment_max_y+radius
	var stack: Array[int]=[]
	if _root>=0:stack.append(_root)
	var found: Array=[]
	while not stack.is_empty():
		var at: int=stack.pop_back()
		var node: Dictionary=_nodes[at]
		result.visited_nodes+=1
		if not (node.min_x<=sweep_max_x and node.max_x>=sweep_min_x and node.min_y<=sweep_max_y and node.max_y>=sweep_min_y):continue
		if int(node.left)>=0:
			stack.append(int(node.left));stack.append(int(node.right));continue
		result.tested_leaves+=1
		var row: Dictionary=_rows[node.id]
		if int(row.id)==exclude_id or row.kind=="creature" and not include_creatures:continue
		if row.kind=="pending":
			var pending_bounds: Dictionary=row.bounds
			if not (pending_bounds.min_x<=segment_max_x and pending_bounds.max_x>=segment_min_x and pending_bounds.min_y<=segment_max_y and pending_bounds.max_y>=segment_min_y):continue
		if vertical!=null and row.kind in SHAPES and (float(row.bounds.max_z)<vertical.x or float(row.bounds.min_z)>vertical.y):continue
		found.append(_public_row(row))
	found.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		return int(a.order)<int(b.order) if int(a.order)!=int(b.order) else int(a.sequence)<int(b.sequence))
	for row in found:result.ids.append(int(row.id))
	result.rows=found;result.ready=true;result.reason=""
	_last_query={"visited_nodes":result.visited_nodes,"tested_leaves":result.tested_leaves,"matched_rows":found.size()}
	return result
func snapshot()->Dictionary:
	return {"active":_active,"epoch":_epoch,"scope":_scope.duplicate(),"entries":_rows.size(),"ledger_entries":_ledger.size(),"nodes":_nodes.size(),"height":int(_nodes[_root].height) if _root>=0 else 0,"last_query":_last_query.duplicate(),"last_bulk_ms":_last_bulk_ms}
func root_bounds()->Dictionary:
	if _root<0 or _batch_depth>0:return {}
	var b: Dictionary=_nodes[_root]
	return {"min_x":b.min_x,"min_y":b.min_y,"max_x":b.max_x,"max_y":b.max_y}
