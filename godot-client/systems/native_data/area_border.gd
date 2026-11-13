extends RefCounted
# NEW/unimported original1407dea10 border plan. No I/O, world, gameplay grid,
# invented filler, or geometry outside the original Edge2DA's selected model.
const F=preload("res://systems/native_render/particle_math.gd")
const Ints=preload("res://systems/native_data/ruleset_cache.gd")
const CORNERS=["TopRight","BottomRight","BottomLeft","TopLeft"]
const EDGES=["Top","Right","Bottom","Left"]
static func lower(value: String) -> String:
	var result:=""
	for at in value.length():
		var code:=value.unicode_at(at);result+=String.chr(code+32 if code>=65 and code<=90 else code)
	return result
static func i32(value: int) -> int:return ((value+2147483648)&4294967295)-2147483648
static func resource_name(set_name: String) -> String:return lower((set_name+"_Edge").left(16))
static func native_cell(table: Dictionary,index: int,column: String) -> String:
	var rows: Array=table.get("orderedRows",[]);var columns: Array=table.get("columns",[]);var at:=-1
	for key in columns.size():
		if lower(str(columns[key]))==lower(column):at=key;break
	var result: String=str(table.get("defaultValue",""))
	if index>=0 and index<rows.size() and (columns.is_empty() or at>=0):
		var physical: Array=table.get("orderedCells",[])
		if at>=0 and index<physical.size() and at<physical[index].size():result=str(physical[index][at])
		else:
			for key in rows[index]:
				if lower(str(key))==lower(column):result=str(rows[index][key]);break
	return "" if result=="****" else result
static func type_at(set_data: Dictionary,tile: Dictionary,side: int,corner: bool) -> String:
	var id: int=int(tile.get("id",tile.get("tile_id",-1)))
	var row: Dictionary=set_data.tiles[id].get("fields",set_data.tiles[id])
	return str(row.get((CORNERS if corner else EDGES)[(side+int(tile.orientation))&3],""))
static func choose(table: Dictionary,a: String,b: String,edge: String,direct: int) -> Dictionary:
	for index in table.get("orderedRows",[]).size():
		if lower(native_cell(table,index,"Edge"))!=lower(edge):continue
		var one:=lower(native_cell(table,index,"Corner1"));var two:=lower(native_cell(table,index,"Corner2"))
		var orientation: int=direct if one==lower(a) and two==lower(b) else (direct+2)&3 if one==lower(b) and two==lower(a) else -1
		if orientation<0:continue
		var height:=native_cell(table,index,"Height")
		# Original ignores GetINT BOOL but malformed hex leaves prior storage.
		# Keep that unresolved; decimal empty/missing writes0 or table-default atoi.
		var value:=0
		if height.length()>2 and height.left(2).to_lower()=="0x":
			var digits:="";var cursor:=2
			while cursor<height.length() and height[cursor].to_lower() in "0123456789abcdef":digits+=height[cursor];cursor+=1
			if digits.is_empty() or digits.length()>8:return {"ready":false,"reason":"Unresolved original Edge2DA Height conversion."}
			value=i32(digits.hex_to_int())
		else:value=Ints.atoi(height)
		var raw:=native_cell(table,index,"Model")
		return {"ready":true,"row":index,"orientation":orientation,"rawModel":raw,"model":lower(raw.left(16)),"height":value}
	return {"ready":true,"row":-1,"orientation":null,"rawModel":"","model":"","height":0}
static func plan(area: Dictionary,set_data: Dictionary,table: Variant,gate: Dictionary) -> Dictionary:
	if not gate.get("enabled") is bool or not gate.get("disabled") is bool:return {"ready":false,"reason":"Native border setting/area gate is unavailable."}
	if not gate.enabled or gate.disabled:return {"ready":true,"enabled":false,"attempts":[],"placements":[]}
	# null means a completed native Load2DA failure/known absence, never pending.
	if table==null:return {"ready":true,"enabled":true,"loaded":false,"attempts":[],"placements":[]}
	if not table is Dictionary or not table.get("orderedRows") is Array:return {"ready":false,"reason":"Native Edge2DA is not prepared."}
	var width: int=int(area.get("width",0));var height: int=int(area.get("height",0));var tiles: Array=area.get("tiles",[])
	if width<1 or height<1 or width*height!=tiles.size() or width*height>65536 or not set_data.get("tiles") is Array or not set_data.has("transition"):return {"ready":false,"reason":"Original border grid/SET is unavailable."}
	for tile in tiles:
		var id: int=int(tile.get("id",tile.get("tile_id",-1)))
		if id<0 or id>=set_data.tiles.size() or not tile.has("orientation") or not tile.has("height"):return {"ready":false,"reason":"Original border source tile is unavailable."}
	var cells: Array=[]
	for y in range(-5,height+5):
		for x in range(-5,0):cells.append(["left",x,y,clampi(y,0,height-1)*width,3,2,3,0])
	for y in range(-5,height+5):
		for x in range(width,width+5):cells.append(["right",x,y,clampi(y,0,height-1)*width+width-1,0,1,1,0])
	for y in range(-5,0):
		for x in width:cells.append(["bottom",x,y,x,2,1,2,1])
	for y in range(height,height+5):
		for x in width:cells.append(["top",x,y,(height-1)*width+x,3,0,0,1])
	var attempts: Array=[];var placements: Array=[]
	for cell in cells:
		var tile: Dictionary=tiles[int(cell[3])];var y: int=cell[2]
		var a:=type_at(set_data,tile,cell[4],true);var b:=type_at(set_data,tile,cell[5],true);var edge:=type_at(set_data,tile,cell[6],false)
		if cell[0] in ["left","right"]:
			if y<0:
				if cell[0]=="left":a=""
				else:a=type_at(set_data,tile,1,true);b=""
				edge=""
			elif y>=height:
				if cell[0]=="left":b=""
				else:a="";b=type_at(set_data,tile,0,true)
				edge=""
		var chosen:=choose(table,a,b,edge,cell[7])
		if not chosen.ready:return chosen
		var native_position: Array=[F.f(F.f(F.f(float(cell[1]))*F.f(10.0))+F.f(5.0)),F.f(F.f(F.f(float(y))*F.f(10.0))+F.f(5.0)),F.f(F.f(float(set_data.transition))*F.f(float(i32(int(chosen.height)+int(tile.height)))))]
		var result: Dictionary=chosen.duplicate();result.merge({"side":cell[0],"x":cell[1],"y":y,"sourceIndex":cell[3],"nativePosition":native_position,"position":Vector3(native_position[0],native_position[2],-native_position[1]),"nativeSpawnFlags":1})
		attempts.append(result)
		if not str(chosen.rawModel).is_empty():placements.append(result)
	return {"ready":true,"enabled":true,"loaded":true,"attempts":attempts,"placements":placements}
