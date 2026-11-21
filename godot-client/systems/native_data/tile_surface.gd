extends RefCounted
# Original ASCII WOK collision geometry, kept in native NWN axes. Height queries
# preserve physical face order and native f32 plane arithmetic. This is not the
# complete adjacency/AABB/line-clipping implementation; no JS-prepared input.
const LIMIT:=2000000
const Binary=preload("res://systems/native_data/binary_data.gd")
var failure:=""
static func f(value: float) -> float: return Vector3(value,0,0).x
func reject(reason: String) -> Dictionary:
	failure=reason; return {}
func parse_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.size()>64*1024*1024 or bytes.has(0): return reject("Binary or oversized WOK is not supported by the ASCII decoder")
	return parse(Binary.new(bytes).text(0,bytes.size()))
func numbers(tokens: PackedStringArray,count: int) -> Array:
	if tokens.size()<count: failure="Truncated original WOK row"; return []
	var result: Array=[]
	for index in count:
		var text:=tokens[index]
		if text.to_lower().begins_with("0x") and text.is_valid_hex_number(true): result.append(f(float(text.hex_to_int()))); continue
		if not text.is_valid_float() or not is_finite(text.to_float()): failure="Invalid original WOK number"; return []
		result.append(f(text.to_float()))
	return result
static func normalize(value: Array) -> Array:
	var square:=f(f(f(value[0]*value[0])+f(value[1]*value[1]))+f(value[2]*value[2]))
	if square>=f(0.99999) and square<=f(1.00001): return value
	if square==0: return [1.0,0.0,0.0]
	var inverse:=f(sqrt(f(1.0/square)))
	return [f(value[0]*inverse),f(value[1]*inverse),f(value[2]*inverse)]
static func normal(a: Array,b: Array,c: Array) -> Array:
	var u:=[f(b[0]-a[0]),f(b[1]-a[1]),f(b[2]-a[2])]; var v:=[f(c[0]-b[0]),f(c[1]-b[1]),f(c[2]-b[2])]
	return normalize([f(f(u[1]*v[2])-f(u[2]*v[1])),f(f(u[2]*v[0])-f(u[0]*v[2])),f(f(u[0]*v[1])-f(u[1]*v[0]))])
static func snap(value: float) -> float:
	value=f(value); var scaled:=f(f(value*512)+f(0.5)); var integer:=int(scaled) if scaled>=-2147483648.0 and scaled<2147483648.0 else -2147483648
	return f(integer>>9) if integer%512==0 else value
static func twice(value: float) -> float: return f(value+value)
static func rotate(q: Array,p: Array) -> Array:
	var w: float=q[0]; var x: float=q[1]; var y: float=q[2]; var z: float=q[3]
	var vx: float=p[0]; var vy: float=p[1]; var vz: float=p[2]
	if w==1 or (vx==0 and vy==0 and vz==0) or (x==0 and y==0 and z==0): return p.duplicate()
	var xx:=f(x*x); var yy:=f(y*y); var zz:=f(z*z); var xy:=f(x*y); var zx:=f(z*x); var zy:=f(z*y); var xw:=f(x*w); var yw:=f(y*w); var zw:=f(z*w)
	return [f(f(f(f(1-twice(f(zz+yy)))*vx)+f(twice(f(xy-zw))*vy))+f(twice(f(yw+zx))*vz)),f(f(f(f(1-twice(f(zz+xx)))*vy)+f(twice(f(xy+zw))*vx))+f(twice(f(zy-xw))*vz)),f(f(f(twice(f(zy+xw))*vy)+f(twice(f(zx-yw))*vx))+f(f(1-twice(f(yy+xx)))*vz))]
func parse(text: String) -> Dictionary:
	failure=""
	if text.length()>64*1024*1024: return reject("Oversized original WOK is unsupported")
	var whitespace:=RegEx.new(); whitespace.compile("\\s+")
	var active:=false; var found:=false; var offset: Array=[0.0,0.0,0.0]; var q: Array=[1.0,0.0,0.0,0.0]
	var vertices: Array=[]; var faces: Array=[]; var materials: Array=[]; var vertex_map: Array=[]; var known: Dictionary={}; var aabb_rows: Array=[]; var node_rotation:=false
	var lines:=text.replace("\r","").split("\n"); var cursor:=0
	while cursor<lines.size():
		var line:=str(lines[cursor]).strip_edges(); cursor+=1
		if line.is_empty() or line.begins_with("#"): continue
		var tokens: PackedStringArray=whitespace.sub(line," ",true).split(" ",false); var command:=tokens[0]
		if command=="node":
			active=tokens.size()>=2 and tokens[1]=="aabb"
			if active:
				if found: return reject("Multiple original tile aabb collision nodes are unsupported")
				found=true
			continue
		if command=="endnode": active=false; continue
		if not active: continue
		if command=="position":
			var values:=numbers(tokens.slice(1),3)
			if not failure.is_empty(): return {}
			offset=[f(values[0]+5),f(values[1]+5),values[2]]
		elif command=="orientation":
			var values:=numbers(tokens.slice(1),4)
			if not failure.is_empty(): return {}
			if values[3]==0 or (values[0]==0 and values[1]==0 and values[2]==0): q=[1.0,0.0,0.0,0.0]
			else:
				if absf(float(values[3]))>=1000000: return reject("Original WOK trigonometric input exceeds supported range")
				var axis:=normalize(values.slice(0,3)); var half:=f(values[3]*f(0.5)); var sine:=f(sin(half))
				q=[f(cos(half)),f(axis[0]*sine),f(axis[1]*sine),f(axis[2]*sine)]; node_rotation=true
		elif command=="aabb":
			if not aabb_rows.is_empty(): return reject("Repeated original WOK AABB tree")
			var pending:=1; var fields:=tokens.slice(1)
			while pending>0:
				if fields.size()!=7: return reject("Invalid original WOK AABB row")
				var values:=numbers(fields,7)
				if not failure.is_empty(): return {}
				if values[6]!=floor(float(values[6])) or values[6]<-1: return reject("Invalid original WOK AABB face")
				aabb_rows.append(values); pending+=1 if values[6]==-1 else -1
				if aabb_rows.size()>LIMIT: return reject("Original WOK AABB allocation exceeds bound")
				if pending>0:
					if cursor>=lines.size(): return reject("Truncated original WOK AABB tree")
					fields=whitespace.sub(str(lines[cursor]).strip_edges()," ",true).split(" ",false); cursor+=1
		elif command in ["verts","vertices","faces"]:
			if tokens.size()!=2: return reject("Binary original WOK row sections are unsupported")
			if not tokens[1].is_valid_int() or int(tokens[1])<0 or int(tokens[1])>LIMIT: return reject("Invalid original WOK array count")
			if ((not faces.is_empty()) if command=="faces" else (not vertex_map.is_empty())): return reject("Repeated original WOK arrays")
			for row_index in int(tokens[1]):
				if cursor>=lines.size(): return reject("Truncated original WOK array")
				var fields: PackedStringArray=whitespace.sub(str(lines[cursor]).strip_edges()," ",true).split(" ",false); cursor+=1
				var values:=numbers(fields,8 if command=="faces" else 3)
				if not failure.is_empty(): return {}
				if command!="faces":
					var vertex:=rotate(q,values); vertex=[snap(f(vertex[0]+offset[0])),snap(f(vertex[1]+offset[1])),snap(f(vertex[2]+offset[2]))]
					var key:=PackedFloat32Array(vertex).to_byte_array().hex_encode()
					if not known.has(key): known[key]=vertices.size(); vertices.append(vertex)
					vertex_map.append(int(known[key]))
				else:
					for value in values:
						if value!=floor(float(value)): return reject("Noninteger original WOK face")
					for corner in 3:
						if values[corner]<0 or values[corner]>=vertex_map.size(): return reject("Original WOK face index is outside vertices")
					faces.append([vertex_map[int(values[0])],vertex_map[int(values[1])],vertex_map[int(values[2])]]); materials.append(int(values[7]))
	if not found: return reject("Original WOK has no aabb collision node")
	for row in aabb_rows:
		if int(row[6])>=faces.size(): return reject("Original WOK AABB face is outside triangles")
	var normals: Array=[]; var constants: Array=[]
	var low: Array=vertices[0].duplicate() if not vertices.is_empty() else [0.0,0.0,0.0]; var high: Array=low.duplicate()
	for vertex in vertices:
		for axis in 3: low[axis]=minf(low[axis],vertex[axis]); high[axis]=maxf(high[axis],vertex[axis])
	for face in faces:
		var n:=normal(vertices[face[0]],vertices[face[1]],vertices[face[2]]); var a: Array=vertices[face[0]]
		normals.append(n); constants.append(f(-f(f(f(a[1]*n[1])+f(a[0]*n[0]))+f(a[2]*n[2]))))
	return {"vertices":vertices,"faces":faces,"materials":materials,"normals":normals,"constants":constants,"bounds_min":low,"bounds_max":high,"aabb_source_rows":aabb_rows,"node_rotation":node_rotation,"rotation_math":"Godot sin/cos rounded to f32; original CRT bit parity not established","scope":"Original ASCII WOK data for native height; adjacency, AABB acceleration and line collision pending"}
static func walkable(table: Dictionary,material: int) -> bool:
	var rows: Array=table.get("orderedRows",[]); var value: Variant=rows[material].get("Walk",table.get("defaultValue","0")) if material>=0 and material<rows.size() else table.get("defaultValue","0")
	var text:=str(value); return int(float(text))!=0 if text.is_valid_float() else false
static func edge(a: Array,b: Array,x: float,y: float) -> float: return f(f(f(y-a[1])*f(b[0]-a[0]))+f(f(a[1]-b[1])*f(x-a[0])))
static func height(mesh: Dictionary,table: Dictionary,point: Array) -> float:
	var x:=f(point[0]); var y:=f(point[1])
	for allowed in [true,false]:
		for index in mesh.faces.size():
			if walkable(table,int(mesh.materials[index]))!=allowed: continue
			var face: Array=mesh.faces[index]; var a: Array=mesh.vertices[face[0]]; var b: Array=mesh.vertices[face[1]]; var c: Array=mesh.vertices[face[2]]
			if edge(a,b,x,y)>=0 and edge(b,c,x,y)>=0 and edge(c,a,x,y)>=0:
				var n: Array=mesh.normals[index]
				return 0.0 if n[2]==0 else f(-f(f(f(n[1]*y)+f(f(n[0]*x)+f(mesh.constants[index]))))/n[2])
	return 0.0
static func canonical(point: Array,orientation: int) -> Array:
	var x:=f(point[0]); var y:=f(point[1])
	if orientation==1: return [y,f(10-x)]
	if orientation==2: return [f(10-x),f(10-y)]
	if orientation==3: return [f(10-y),x]
	return [x,y]
