extends RefCounted
# Isolated native POD collector. No SceneTree, renderer, clock, mesh visibility
# or production hook. Exact original pins are in NATIVE-TILE-FOG-COLLECTOR.md.
const MAX_CELLS:=131072
const MAX_PLANES:=64
var _nodes: Array=[]
var _root:=-1
var _cell:=0.0
var _key: Array=[]
static func f(value: float) -> float:return PackedFloat32Array([value])[0]
static func word(value: float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
static func scalar(value: int) -> float:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_u32(0,value);return bytes.decode_float(0)
static func number(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value)) and is_finite(f(float(value)))
static func uint(value: Variant,maximum: int=4294967295) -> bool:return number(value) and value>=0 and value<=maximum and value==floor(float(value))
static func point(value: Variant,size: int=3) -> bool:
	return value is Array and value.size()==size and value.all(func(v):return number(v))
static func dot(a: Array,b: Array) -> float:return f(f(f(float(a[0])*float(b[0]))+f(float(a[1])*float(b[1])))+f(float(a[2])*float(b[2])))
static func distance(plane: Array,p: Array) -> float:return f(dot(plane,p)+float(plane[3]))
static func rounded(value: Array) -> Array:return value.map(func(v):return f(float(v)))
static func normalize_native(v: Array) -> Array:
	var size:=dot(v,v)
	if size==1.0 or size>=f(.99999) and size<=f(1.00001):return v.duplicate()
	if size==0.0:return [1.0,0.0,0.0]
	var scale:=f(sqrt(f(1.0/size)))
	return [f(float(v[0])*scale),f(float(v[1])*scale),f(float(v[2])*scale)]
static func normal_of(a: Array,b: Array,c: Array) -> Array:
	var u: Array=[];var v: Array=[]
	for axis in 3:u.append(f(float(b[axis])-float(a[axis])));v.append(f(float(c[axis])-float(b[axis])))
	return normalize_native([f(f(u[1]*v[2])-f(u[2]*v[1])),f(f(u[2]*v[0])-f(u[0]*v[2])),f(f(u[0]*v[1])-f(u[1]*v[0]))])
static func rotate_native(q: Array,v: Array) -> Array:
	# Original Quaternion memory is WXYZ, with its real legacy shortcuts.
	var w: float=q[0];var x: float=q[1];var y: float=q[2];var z: float=q[3]
	if w==1.0 or v==[0.0,0.0,0.0] or x==0.0 and y==0.0 and z==0.0:return v.duplicate()
	var zy:=f(f(z*z)+f(y*y));var yw_zx:=f(f(y*w)+f(z*x));var zx_yw:=f(f(z*x)-f(y*w));var yy_xx:=f(f(y*y)+f(x*x))
	var yx_zw:=f(f(y*x)-f(z*w));var zw_yx:=f(f(z*w)+f(y*x));var zz_xx:=f(f(z*z)+f(x*x))
	var zy_xw:=f(f(z*y)+f(x*w));var zy_minus_xw:=f(f(z*y)-f(x*w))
	return [f(f(f(f(1.0-f(zy+zy))*v[0])+f(f(yx_zw+yx_zw)*v[1]))+f(f(yw_zx+yw_zx)*v[2])),f(f(f(f(1.0-f(zz_xx+zz_xx))*v[1])+f(f(zw_yx+zw_yx)*v[0]))+f(f(zy_minus_xw+zy_minus_xw)*v[2])),f(f(f(f(zy_xw+zy_xw)*v[1])+f(f(zx_yw+zx_yw)*v[0]))+f(f(1.0-f(yy_xx+yy_xx))*v[2]))]
static func camera_planes(camera: Dictionary) -> Dictionary:
	for key in ["position","quaternion_wxyz"]:
		if not point(camera.get(key),4 if key=="quaternion_wxyz" else 3):return {"available":false,"reason":"native-camera-transform-unavailable"}
	for key in ["angle","aspect","near","far"]:
		if not number(camera.get(key)):return {"available":false,"reason":"native-camera-projection-unavailable"}
	var angle:=f(camera.angle);var aspect:=f(camera.aspect);var near:=f(camera.near);var far:=f(camera.far)
	if aspect<=0 or near<=0 or far<=near:return {"available":false,"reason":"native-camera-projection-invalid"}
	var planes: Array=[[0.,0.,1.,near],[0.,0.,-1.,-far]]
	if angle>0:
		# Native tanf has separate CPU-selected SSE/FMA implementations. The
		# caller supplies its exact cached result for this same f32 angle; no
		# Godot/double tan is silently promoted to original instruction proof.
		if not uint(camera.get("half_tangent_word")) or camera.get("half_tangent_angle_word")!=word(angle):return {"available":false,"reason":"native-camera-tanf-word-unavailable"}
		var vertical:=scalar(int(camera.half_tangent_word));var horizontal:=f(vertical*aspect)
		if not is_finite(vertical) or vertical<=0 or not is_finite(horizontal):return {"available":false,"reason":"native-camera-tanf-word-invalid"}
		var origin: Array=[0.,0.,0.]
		for pair in [[[ -horizontal,vertical,-1.],[-horizontal,-vertical,-1.]],[[horizontal,-vertical,-1.],[horizontal,vertical,-1.]],[[horizontal,vertical,-1.],[-horizontal,vertical,-1.]],[[-horizontal,-vertical,-1.],[horizontal,-vertical,-1.]]]:
			var n:=normal_of(origin,pair[0],pair[1]);planes.append([n[0],n[1],n[2],0.])
	else:
		if not number(camera.get("orthographic_scale")) or camera.orthographic_scale<=0:return {"available":false,"reason":"native-camera-orthographic-scale-unavailable"}
		var scale:=f(camera.orthographic_scale)
		planes.append_array([[-1.,0.,0.,0.],[1.,0.,0.,-f(scale*aspect)],[0.,-1.,0.,0.],[0.,1.,0.,-scale]])
	var p:=rounded(camera.position);var q:=rounded(camera.quaternion_wxyz);var result: Array=[]
	for plane in planes:
		var n:=rotate_native(q,plane);result.append([n[0],n[1],n[2],f(-dot(n,p)+plane[3])])
	return {"available":true,"planes":result,"source":"Camera05a971..05aede/NormalOf22d960/Quaternion22ae90","tangent_supplied":angle>0}
static func renderer_delta_t(snapshot_words: Dictionary) -> Dictionary:
	if not uint(snapshot_words.get("hi")) or not uint(snapshot_words.get("lo")):return {"available":false,"reason":"native-primary-snapshot-words-unavailable"}
	var low:=int(snapshot_words.lo);var signed_low:=low-4294967296 if low>=2147483648 else low
	return {"available":true,"delta_t":f(f(float(signed_low))/1000000.0),"source":"Client50/6db9b7..6db9d5/signed-low32-CVTDQ2PS-DIVSS"}
func _node(plane: Array,leaf: int=0,low: Array=[],high: Array=[],vertices: Array=[]) -> int:
	var index:=_nodes.size();_nodes.append({"plane":plane,"leaf":leaf,"negative":-1,"positive":-1,"low":[0.,0.,0.] if low.is_empty() else low.duplicate(),"high":[0.,0.,0.] if high.is_empty() else high.duplicate(),"vertices":vertices,"tile":null});return index
func _grid(low: Array,high: Array,width: int,height: int) -> int:
	var mid_x:=f(floor(f(f(f(high[0]+low[0])*.5)/_cell))*_cell)
	var mid_y:=f(floor(f(f(f(high[1]+low[1])*.5)/_cell))*_cell)
	if width<2 and height<2:return _node([0.,0.,0.,0.],2,low,high)
	var axis:=1 if width<height else 0;var middle:=mid_y if axis==1 else mid_x
	var plane: Array=[0.,0.,0.,-middle];plane[axis]=1.
	var vertices: Array=[]
	if axis==1:vertices=[[low[0],middle,low[2]],[high[0],middle,low[2]],[high[0],middle,high[2]],[low[0],middle,high[2]]]
	else:vertices=[[middle,low[1],low[2]],[middle,high[1],low[2]],[middle,high[1],high[2]],[middle,low[1],high[2]]]
	var index:=_node(plane,0,low,high,vertices);var first_high:=high.duplicate();first_high[axis]=middle;var second_low:=low.duplicate();second_low[axis]=middle
	_nodes[index].negative=_grid(low,first_high,width if axis==1 else width/2,height/2 if axis==1 else height)
	_nodes[index].positive=_grid(second_low,high,width if axis==1 else width/2+width%2,height/2+height%2 if axis==1 else height)
	return index
func build(width: Variant,height: Variant,margin: Variant,cell: Variant) -> Dictionary:
	if not uint(width,65536) or width<1 or not uint(height,65536) or height<1 or not uint(margin,1024) or not number(cell) or cell<=0:return {"available":false,"reason":"native-bsp-build-input-unavailable"}
	var key: Array=[int(width),int(height),int(margin),word(float(cell))]
	if key==_key:return {"available":true,"cached":true,"nodes":_nodes.size()}
	var padded_x:=int(width)+2*int(margin);var padded_y:=int(height)+2*int(margin)
	if padded_x*padded_y>MAX_CELLS:return {"available":false,"reason":"native-bsp-cell-bound"}
	_nodes=[];_root=-1;_cell=f(float(cell));_key=key
	var minimum:=f(-f(float(margin)*_cell));var low: Array=[minimum,minimum,-30.]
	var high: Array=[f(float(padded_x-int(margin))*_cell),f(float(padded_y-int(margin))*_cell),f(float(maxi(padded_x,padded_y)+1)*10.)]
	for axis in 3:
		for positive in [false,true]:
			var plane: Array=[0.,0.,0.,0.];plane[axis]=1. if positive else -1.
			# Keep the source operation order: margin0's X/Y negative planes
			# produce +0, while simply copying the low bound would retain -0.
			plane[3]=-dot(plane,high) if positive else f(f(plane[2]*30.)-f(f(plane[1]*minimum)+f(plane[0]*minimum)))
			var vertices: Array=[]
			for bits in 8:
				if ((bits>>axis)&1)!=int(positive):continue
				vertices.append([high[0] if bits&1 else low[0],high[1] if bits&2 else low[1],high[2] if bits&4 else low[2]])
			var index:=_node(plane,0,low,high,vertices);_nodes[index].negative=_root;_nodes[index].positive=_node([0.,0.,0.,0.],1);_root=index
	var tail:=_root
	while int(_nodes[tail].negative)>=0:tail=int(_nodes[tail].negative)
	_nodes[tail].negative=_grid(low,high,padded_x,padded_y)
	return {"available":true,"cached":false,"nodes":_nodes.size(),"cells":padded_x*padded_y}
func _fit(p: Array,radius: float) -> int:
	var index:=_root
	while index>=0 and _nodes[index].leaf==0:
		var node: Dictionary=_nodes[index];var d:=distance(node.plane,p)
		if -radius<d:
			if d<radius:return index
			index=int(node.positive)
		else:index=int(node.negative)
	return index
func bind_tile(tile: Variant,position_native: Variant) -> Dictionary:
	if _root<0 or not (uint(tile) or tile is String and not tile.is_empty()) or not point(position_native):return {"available":false,"reason":"native-tile-placement-unavailable"}
	var index:=_fit(rounded(position_native),0.)
	if index<0:return {"available":false,"reason":"native-tile-node-unavailable"}
	var previous: Variant=_nodes[index].tile;_nodes[index].tile=tile
	return {"available":true,"node":index,"previous":previous}
func tile_at(position_native: Variant) -> Dictionary:
	if _root<0 or not point(position_native):return {"available":false}
	var index:=_fit(rounded(position_native),0.)
	return {"available":index>=0,"node":index,"tile":_nodes[index].tile if index>=0 else null}
func _callback(index: int,output: Dictionary,plane_count: int) -> void:
	output.node_indices.append(index);output.plane_counts.append(plane_count)
	if _nodes[index].tile!=null:output.tiles.append(_nodes[index].tile);output.tile_nodes.append(index)
func _ordered(index: int,camera: Array,output: Dictionary) -> void:
	if index<0:return
	_callback(index,output,0)
	var node: Dictionary=_nodes[index];var negative_first:=distance(node.plane,camera)<=0.
	# Original229cb0 visits FAR first, unlike the volume path below.
	_ordered(int(node.positive if negative_first else node.negative),camera,output)
	_ordered(int(node.negative if negative_first else node.positive),camera,output)
func _volume(index: int,camera: Array,planes: Array,output: Dictionary) -> void:
	if index<0:return
	_callback(index,output,planes.size());var node: Dictionary=_nodes[index]
	if node.leaf!=0:return
	var lists: Array=[[],[]];var rejected: Array=[false,false]
	for pindex in range(planes.size()-1,-1,-1):
		var plane: Array=planes[pindex];var mask:=0
		for vertex in node.vertices:
			mask|=2 if distance(plane,vertex)>=0. else 1
			if mask==3:break
		if mask==3:lists[0].append(plane);lists[1].append(plane)
		elif mask==1:
			var side:=0 if dot(plane,node.plane)<=0. else 1
			if not rejected[side]:lists[side].append(plane)
		elif mask==2:
			var side:=0 if dot(plane,node.plane)<=0. else 1;rejected[side]=true
			if rejected[1-side]:return
			lists[1-side].append(plane)
	var near_side:=0 if distance(node.plane,camera)<=0. else 1
	for side in [near_side,1-near_side]:
		if rejected[side]:continue
		var child:=int(node.negative if side==0 else node.positive)
		if lists[side].is_empty():_ordered(child,camera,output)
		else:_volume(child,camera,lists[side],output)
func collect(camera_native: Variant,planes: Variant) -> Dictionary:
	if _root<0 or not point(camera_native) or not planes is Array or planes.size()>MAX_PLANES or not planes.all(func(p):return point(p,4)):return {"available":false,"reason":"native-bsp-collection-input-unavailable"}
	var output:={"available":true,"node_indices":[],"plane_counts":[],"tiles":[],"tile_nodes":[]}
	_volume(_root,rounded(camera_native),planes.map(func(p):return rounded(p)),output)
	return output
func export_tree() -> Dictionary:
	return {"root":_root,"key":_key.duplicate(),"nodes":_nodes.duplicate(true)}
