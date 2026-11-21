extends RefCounted

# The old NetworkScene used parseDoorWalkmesh from walkmesh.js only to build
# the closed DWK pick bounds. Keep its permissive exporter/node rules separate
# from the native collision decoder used for physical door geometry.
var failure:=""

static func _number(value: String)->Variant:
	if value.to_lower().begins_with("0x") and value.is_valid_hex_number(true):return float(value.hex_to_int())
	if not value.is_valid_float():return null
	var result:=value.to_float()
	return result if is_finite(result) else null

static func _numbers(tokens: PackedStringArray,start: int,count: int)->Array:
	if tokens.size()<start+count:return []
	var values: Array=[]
	for index in count:
		var value: Variant=_number(str(tokens[start+index]))
		if value==null:return []
		values.append(value)
	return values

static func _rotate_axis(value: Array,orientation: Array)->Array:
	var length:=sqrt(float(orientation[0])*float(orientation[0])+float(orientation[1])*float(orientation[1])+float(orientation[2])*float(orientation[2]))
	var angle:=float(orientation[3])
	if length<1e-8 or absf(angle)<1e-8:return value
	var axis: Array=[float(orientation[0])/length,float(orientation[1])/length,float(orientation[2])/length]
	var cosine:=cos(angle);var sine:=sin(angle)
	var dot_value:=float(axis[0])*float(value[0])+float(axis[1])*float(value[1])+float(axis[2])*float(value[2])
	var cross: Array=[float(axis[1])*float(value[2])-float(axis[2])*float(value[1]),float(axis[2])*float(value[0])-float(axis[0])*float(value[2]),float(axis[0])*float(value[1])-float(axis[1])*float(value[0])]
	var rotated: Array=[]
	for index in 3:rotated.append(float(value[index])*cosine+float(cross[index])*sine+float(axis[index])*dot_value*(1.0-cosine))
	return rotated

func reject(reason: String)->Dictionary:
	failure=reason;return {}

func parse(bytes: PackedByteArray)->Dictionary:
	failure=""
	var text:=bytes.get_string_from_ascii()
	var header:=RegEx.new()
	header.compile("(?im)(?:^|\\n)\\s*(?:#MAXWALKMESH\\s+ASCII|#MAXDOOR\\s+ASCII|#NWMAX\\s+(?:WALKMESH|PWKMESH|DWKMESH)\\s+ASCII)\\b")
	var legacy:=RegEx.new();legacy.compile("(?im)(?:^|\\n)\\s*#MAXMODEL\\s+ASCII\\b")
	if header.search(text)==null and legacy.search(text)==null:return reject("Unsupported NWN walkmesh format.")
	var lines:=text.replace("\r","").split("\n")
	var whitespace:=RegEx.new();whitespace.compile("\\s+")
	var door_name:=RegEx.new();door_name.compile("(?i)_DWK_wg_(closed|open1|open2)$")
	var vertices: Array=[]
	var pick_points: Array=[]
	var recognized:=false
	var node_state:=-1
	var node_position: Array=[0.0,0.0,0.0]
	var node_orientation: Array=[0.0,0.0,1.0,0.0]
	var node_vertex_start:=0
	var cursor:=0
	while cursor<lines.size():
		var line:=str(lines[cursor]).strip_edges();cursor+=1
		if line.is_empty() or line.begins_with("#"):continue
		var tokens:=whitespace.sub(line," ",true).split(" ",false)
		if tokens.is_empty():continue
		match str(tokens[0]).to_lower():
			"node":
				node_state=-1
				node_position=[0.0,0.0,0.0];node_orientation=[0.0,0.0,1.0,0.0]
				node_vertex_start=vertices.size()
				# parseWalkmesh carries the authored node name for every node type.
				# parseDoorWalkmesh separately recognizes only exact trimesh lines
				# when deciding whether a DWK state exists at all.
				if tokens.size()>=3:
					var found:=door_name.search(str(tokens[2]))
					if found!=null:
						node_state=["closed","open1","open2"].find(found.get_string(1).to_lower())
						if tokens.size()==3 and str(tokens[1]).to_lower()=="trimesh":recognized=true
			"position","orientation":
				var count:=3 if str(tokens[0]).to_lower()=="position" else 4
				var values:=_numbers(tokens,1,count)
				if values.size()!=count:return reject("Invalid WOK transform at line "+str(cursor)+".")
				if count==3:node_position=values
				else:node_orientation=values
			"verts","faces":
				if tokens.size()<2:return reject("Invalid WOK "+str(tokens[0]).to_lower()+" count at line "+str(cursor)+".")
				var requested: Variant=_number(str(tokens[1]))
				if requested==null or float(requested)!=floorf(float(requested)) or float(requested)<0 or float(requested)>2000000:return reject("Invalid WOK "+str(tokens[0]).to_lower()+" count at line "+str(cursor)+".")
				var is_face:=str(tokens[0]).to_lower()=="faces"
				for row in int(requested):
					var row_line: String=""
					while cursor<lines.size():
						row_line=str(lines[cursor]).strip_edges();cursor+=1
						if not row_line.is_empty() and not row_line.begins_with("#"):break
					if row_line.is_empty():return reject("Truncated WOK "+str(tokens[0]).to_lower()+" section.")
					var fields:=whitespace.sub(row_line," ",true).split(" ",false)
					var values:=_numbers(fields,0,3)
					if values.size()<3 or is_face and fields.size()<8:return reject("Invalid WOK "+("face" if is_face else "vertex")+" at line "+str(cursor)+".")
					if not is_face:
						var rotated:=_rotate_axis(values,node_orientation)
						vertices.append([float(rotated[0])+float(node_position[0]),float(rotated[2])+float(node_position[2]),-float(rotated[1])-float(node_position[1])])
						continue
					for index in 3:
						if float(values[index])!=floorf(float(values[index])):return reject("Invalid WOK face at line "+str(cursor)+".")
						var vertex_index:=node_vertex_start+int(values[index])
						if int(values[index])<0 or vertex_index>=vertices.size():return reject("WOK face index outside the vertex array at line "+str(cursor)+".")
					var material: Variant=_number(str(fields[7]))
					if material==null or float(material)!=floorf(float(material)):continue
					if node_state==0:
						for index in 3:pick_points.append(vertices[node_vertex_start+int(values[index])])
	if not recognized:return reject("DWK has no recognized door collision states.")
	return {"pick_points":pick_points}
