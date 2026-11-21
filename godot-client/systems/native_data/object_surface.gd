extends RefCounted
# Collision-only original ASCII PWK/DWK. Physical transforms carry between
# trimeshes as in the original readers; decorative empty resources are valid.
const Tile=preload("res://systems/native_data/tile_surface.gd")
const NativeMath=preload("res://systems/native_data/native_math.gd")
var failure:=""
func reject(reason: String) -> Dictionary: failure=reason; return {}
static func source_number(token: String) -> float:
	var text:=token.strip_edges()
	if text.is_empty():return 0.0
	if text.length()>=2 and text[0]=="0" and text[1].to_lower() in ["x","b","o"]:
		if text.length()==2:return NAN
		var radix: int={"x":16,"b":2,"o":8}[text[1].to_lower()]
		var number:=0.0
		for at in range(2,text.length()):
			var code:=text.unicode_at(at);var digit:=-1
			if code>=48 and code<=57:digit=code-48
			elif code>=65 and code<=70:digit=code-65+10
			elif code>=97 and code<=102:digit=code-97+10
			if digit<0 or digit>=radix:return NAN
			number=number*radix+digit
		return number
	return float(text) if text.is_valid_float() else NAN
func values(tokens: PackedStringArray,count: int,label: String,integer: bool=false) -> Variant:
	if tokens.size()<count:return {"error":"Invalid native object mesh "+label}
	var result: Array=[]
	for index in count:
		var text:=str(tokens[index])
		var number:=source_number(text)
		if not is_finite(number) or not is_finite(Tile.f(number)):return {"error":"Invalid native object mesh "+label}
		if integer and number!=floorf(number):return {"error":"Invalid native object mesh "+label}
		if integer:
			# JS `v|0` retains the low signed 32 bits after Number.isInteger.
			var word:=int(fmod(number,4294967296.0))
			if word<0:word+=4294967296
			result.append(word-4294967296 if word>=2147483648 else word)
		else:result.append(Tile.f(number))
	return result
func parse(bytes: PackedByteArray,door: bool=false) -> Dictionary:
	if bytes.has(0): return reject("Native binary object mesh sections are not implemented")
	var lines:=bytes.get_string_from_ascii().replace("\r","").split("\n"); var whitespace:=RegEx.new(); whitespace.compile("\\s+")
	var states: Array=[{"vertices":[],"faces":[],"materials":[]},{"vertices":[],"faces":[],"materials":[]},{"vertices":[],"faces":[],"materials":[]}]; var active:=-1
	var tags: Array=[{}, {}, {}]
	var offset:=Vector3.ZERO; var q: Array=[1.0,0.0,0.0,0.0]; var cursor:=0
	while cursor<lines.size():
		var trimmed:=str(lines[cursor]).strip_edges(true,false)
		if trimmed.length()>254:return reject("Native object mesh long-line parsing is not implemented")
		var tokens:=whitespace.sub(trimmed.strip_edges()," ",true).split(" ",false); cursor+=1
		if tokens.is_empty() or tokens[0].begins_with("#"): continue
		if tokens[0]=="node":
			active=-1
			if tokens.size()>=3 and tokens[1]=="trimesh":
				if not door and trimmed.begins_with("node trimesh "): active=0
				elif door:
					var name:=str(tokens[2]).substr(2)
					for index in 3:
						if name.begins_with("_DWK_wg_"+["closed","open1","open2"][index]): active=index
			continue
		if tokens[0]=="endnode": active=-1; continue
		if active<0: continue
		if tokens[0]=="position":
			var position: Variant=values(tokens.slice(1),3,"position")
			if position is Dictionary:return reject(str(position.error))
			offset=Vector3(position[0],position[1],position[2])
		elif tokens[0]=="orientation":
			var orientation: Variant=values(tokens.slice(1),4,"orientation")
			if orientation is Dictionary:return reject(str(orientation.error))
			var axis: Array=[orientation[0],orientation[1],orientation[2]]
			var angle:=float(orientation[3]); var half:=Tile.f(angle*Tile.f(0.5)); var sine:=NativeMath.native_sinf(half); var cosine:=NativeMath.native_cosf(half)
			if not is_finite(sine) or not is_finite(cosine):return reject("Original object walkmesh orientation is unavailable")
			if axis[0]==0 and axis[1]==0 and axis[2]==0: q=[1.0,0.0,0.0,0.0]
			else:
				var unit:=Tile.normalize(axis)
				q=[cosine,Tile.f(unit[0]*sine),Tile.f(unit[1]*sine),Tile.f(unit[2]*sine)]
		elif tokens[0] in ["verts","vertices","faces"]:
			var count_value:=source_number(tokens[1]) if tokens.size()>1 else NAN
			if not is_finite(count_value) or count_value!=floor(count_value) or count_value<0 or count_value>2000000:return reject("Invalid native object mesh row count")
			if tokens.size()>2:return reject("Native binary object mesh row sections are not implemented")
			var faces:=tokens[0]=="faces"
			var tag: String="faces" if faces else "vertices"
			if tags[active].has(tag):return reject("Repeated native object mesh "+tag+" section is not implemented")
			tags[active][tag]=true
			for row in int(count_value):
				if cursor>=lines.size(): return reject("Truncated native object mesh rows")
				var fields:=whitespace.sub(str(lines[cursor]).strip_edges()," ",true).split(" ",false); cursor+=1
				var parsed: Variant=values(fields,8 if faces else 3,"face" if faces else "vertex",faces)
				if parsed is Dictionary:return reject(str(parsed.error))
				if faces:
					states[active].faces.append(parsed.slice(0,3))
					states[active].materials.append(parsed[7])
				else:
					var v:=Tile.rotate(q,parsed)
					states[active].vertices.append(Vector3(Tile.f(offset.x+v[0]),Tile.f(offset.y+v[1]),Tile.f(offset.z+v[2])))
	for state in states:
		for face in state.faces:
			for index in face:
				if index<0 or index>=state.vertices.size():return reject("Native object mesh negative or invalid indices are not implemented")
	return {"states":states,"door":door}
