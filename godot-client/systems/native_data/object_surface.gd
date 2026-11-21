extends RefCounted
# Collision-only original ASCII PWK/DWK. Physical transforms carry between
# trimeshes as in the original readers; decorative empty resources are valid.
const Tile=preload("res://systems/native_data/tile_surface.gd")
var failure:=""
func reject(reason: String) -> Dictionary: failure=reason; return {}
func parse(bytes: PackedByteArray,door: bool=false) -> Dictionary:
	if bytes.size()>64*1024*1024 or bytes.has(0): return reject("Binary/oversized object walkmesh is unsupported")
	var lines:=bytes.get_string_from_ascii().replace("\r","").split("\n"); var whitespace:=RegEx.new(); whitespace.compile("\\s+")
	var states: Array=[{"vertices":[],"faces":[]},{"vertices":[],"faces":[]},{"vertices":[],"faces":[]}]; var active:=-1
	var offset:=Vector3.ZERO; var q: Array=[1.0,0.0,0.0,0.0]; var cursor:=0
	while cursor<lines.size():
		var tokens:=whitespace.sub(str(lines[cursor]).strip_edges()," ",true).split(" ",false); cursor+=1
		if tokens.is_empty() or tokens[0].begins_with("#"): continue
		if tokens[0]=="node":
			active=-1
			if tokens.size()>=3 and tokens[1]=="trimesh":
				if not door: active=0
				else:
					var name:=str(tokens[2]).substr(2)
					for index in 3:
						if name.begins_with("_DWK_wg_"+["closed","open1","open2"][index]): active=index
			continue
		if tokens[0]=="endnode": active=-1; continue
		if active<0: continue
		if tokens[0]=="position":
			if tokens.size()<4: return reject("Truncated walkmesh position")
			offset=Vector3(float(tokens[1]),float(tokens[2]),float(tokens[3]))
		elif tokens[0]=="orientation":
			if tokens.size()<5: return reject("Truncated walkmesh orientation")
			var axis:=Vector3(float(tokens[1]),float(tokens[2]),float(tokens[3])); var angle:=float(tokens[4]); var half:=Tile.f(angle*Tile.f(0.5)); var unit:=axis.normalized()*Tile.f(sin(half))
			q=[Tile.f(cos(half)),unit.x,unit.y,unit.z] if axis.length_squared()>0 else [1.0,0.0,0.0,0.0]
		elif tokens[0] in ["verts","vertices","faces"]:
			if tokens.size()!=2 or not tokens[1].is_valid_int() or int(tokens[1])<0 or int(tokens[1])>2000000: return reject("Invalid object walkmesh section count")
			var faces:=tokens[0]=="faces"
			if not states[active]["faces" if faces else "vertices"].is_empty(): return reject("Repeated walkmesh section")
			for row in int(tokens[1]):
				if cursor>=lines.size(): return reject("Truncated object walkmesh")
				var fields:=whitespace.sub(str(lines[cursor]).strip_edges()," ",true).split(" ",false); cursor+=1
				if fields.size()<(8 if faces else 3): return reject("Truncated object walkmesh row")
				for field in fields:
					if not str(field).is_valid_float() or not is_finite(float(field)): return reject("Invalid object walkmesh number")
				if faces:
					var face: Array=[]
					for corner in 3:
						if float(fields[corner])!=floor(float(fields[corner])) or int(fields[corner])<0 or int(fields[corner])>=states[active].vertices.size(): return reject("Invalid object walkmesh face")
						face.append(int(fields[corner]))
					states[active].faces.append(face)
				else:
					var v:=Tile.rotate(q,[Tile.f(float(fields[0])),Tile.f(float(fields[1])),Tile.f(float(fields[2]))]); states[active].vertices.append(Vector3(v[0],v[1],v[2])+offset)
	return {"states":states,"door":door}
