extends RefCounted
# Direct table projections from spell_metadata.js. The active physical 2DA row,
# first matching column and table default remain the source of every field.
const U32=0xffffffff
static func table_from(source: Dictionary) -> Dictionary:
	return source.get("spells",{}) if source.has("spells") else source
static func _rows(table: Dictionary) -> Array:
	if table.get("orderedRows") is Array:return table.orderedRows
	return table.get("rows",{}).values() if table.get("rows",{}) is Dictionary else []
static func native_string_entry(table: Dictionary,index: int,column: String) -> Dictionary:
	var columns:Array=table.get("columns",[])
	var column_index:=-1
	for position in columns.size():
		if str(columns[position]).to_lower()==column.to_lower(): column_index=position; break
	var rows:Array=_rows(table)
	var valid:bool=column_index>=0 and index>=0 and index<rows.size() and rows[index] is Dictionary
	var cell:Variant=table.get("defaultValue",null)
	if valid:
		var cells:Array=table.get("orderedCells",[])
		cell=cells[index][column_index] if index<cells.size() and column_index<cells[index].size() else rows[index].get(columns[column_index])
	var value:String="" if cell==null or str(cell) in ["","****"] else str(cell)
	return {"found":valid and not value.is_empty(),"value":value}
static func spell_string_entry(table: Dictionary,index: int,column: String) -> String:
	return str(native_string_entry(table,index,column).value)
static func _integer(table: Dictionary,index: int,column: String) -> Dictionary:
	# combat_stats.js::intEntry reads the first case-insensitive row field.
	# Keep this independent of VisualDefinition so scene readers can use the
	# same string-entry projection without a preload cycle.
	var rows:Array=_rows(table)
	var row:Dictionary={}
	if table.get("orderedRows") is Array:
		if index>=0 and index<rows.size() and rows[index] is Dictionary:row=rows[index]
	else:
		var labeled:Variant=table.get("rows",{}).get(index) if table.get("rows",{}) is Dictionary else null
		if labeled is Dictionary:row=labeled
	var cell:Variant=null
	var found:=false
	for key in row:
		if str(key).to_lower()==column.to_lower():cell=row[key];found=true;break
	var value:int=0
	if not found:
		var default_match:=RegEx.create_from_string("^\\s*([+-]?\\d+)").search(str(table.get("defaultValue",null)) if table.get("defaultValue",null)!=null else "")
		if default_match!=null:value=int(default_match.get_string(1))
		return {"found":false,"value":signed32(value)}
	if cell=="" or cell=="****":return {"found":false,"value":0}
	var source:String=str(cell) if cell!=null else ""
	var hex_match:=RegEx.create_from_string("^0[xX][0-9a-fA-F]+").search(source)
	if hex_match!=null:value=hex_match.get_string().hex_to_int()
	else:
		var decimal_match:=RegEx.create_from_string("^\\s*([+-]?\\d+)").search(source)
		if decimal_match!=null:value=int(decimal_match.get_string(1))
	return {"found":true,"value":signed32(value)}
static func signed32(value: int) -> int:
	var bits:int=value&U32
	return bits-0x100000000 if bits>=0x80000000 else bits
static func _float(table: Dictionary,index: int,column: String) -> Dictionary:
	var columns:Array=table.get("columns",[])
	var column_index:=-1
	for position in columns.size():
		if str(columns[position]).to_lower()==column.to_lower(): column_index=position; break
	var rows:Array=_rows(table)
	var valid:bool=column_index>=0 and index>=0 and index<rows.size() and rows[index] is Dictionary
	var cell:Variant=table.get("defaultValue",null)
	if valid:
		var cells:Array=table.get("orderedCells",[])
		cell=cells[index][column_index] if index<cells.size() and column_index<cells[index].size() else rows[index].get(columns[column_index])
	if valid and (cell==null or str(cell) in ["","****"]): return {"found":false,"value":0.0}
	var pattern:=RegEx.new(); pattern.compile("^\\s*[+-]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][+-]?\\d+)?")
	var parsed:=pattern.search(str(cell) if cell!=null else "")
	var value:=PackedFloat32Array([parsed.get_string().to_float() if parsed!=null else 0.0])[0]
	return {"found":valid,"value":value}
static func _lower(text: String) -> String:
	var nul:int=text.find(String.chr(0))
	return (text.left(nul) if nul>=0 else text).to_lower()
static func conjure_animation_type(text: String) -> int:
	return int({"hand":1,"head":2}.get(_lower(text),0))
static func cast_animation_type(text: String) -> int:
	return int({"out":1,"self":2,"up":3,"area":4,"point":6,"touch":6,"attack":7,"creature":8}.get(_lower(text),0))
static func projectile_path_type(text: String) -> int:
	return int({"homing":1,"ballistic":2,"highballistic":3,"accelerating":5,"spiral":6,"linked":7,"bounce":8,"burst":9,"test":50}.get(_lower(text),0))
static func saving_throw_spell(source: Dictionary,id: int) -> Variant:
	id=signed32(id)
	var table:Dictionary=table_from(source)
	var rows:Array=_rows(table)
	if id<0 or id>=rows.size(): return null
	var classification:int=int(_integer(table,id,"UserType").value)&255
	var school_text: String=""
	var row:Dictionary=rows[id]
	for key in row:
		if str(key).to_lower()=="school": school_text=str(row[key]) if row[key]!=null else ""; break
	var school:int=int({"A":1,"C":2,"D":3,"E":4,"V":5,"I":6,"N":7,"T":8}.get(school_text.left(1),0))
	return {"classification":classification,"school":school} if school!=0 else {"classification":classification,"schoolUnavailable":true}
static func saving_throw_school(spell: Dictionary,id: int) -> Dictionary:
	return {"value":int(spell.school)} if spell.has("school") else {"error":"Native spell %d school reads uninitialized loader storage"%id}
static func talent_spell(source: Dictionary,id: int) -> Variant:
	id=signed32(id)
	var table:Dictionary=table_from(source)
	if id<0 or id>=_rows(table).size(): return null
	var innate:Dictionary=_integer(table,id,"Innate")
	var master:Dictionary=_integer(table,id,"Master")
	var children:Array=[]
	for index in range(1,9):
		var child:Dictionary=_integer(table,id,"SubRadSpell"+str(index))
		if bool(child.found): children.append(int(child.value))
	var max_cr:int=(int(innate.value)*2-1)&U32
	if max_cr>=0x80000000: max_cr-=0x100000000
	return {"id":id,"category":int(_integer(table,id,"Category").value),"maxCR":max_cr,"innate":int(innate.value)&255 if bool(innate.found) else 255,"master":int(master.value) if bool(master.found) else id,"children":children}
static func casting_spell(source: Dictionary,id: int) -> Variant:
	id=signed32(id)
	var table:Dictionary=table_from(source)
	if id<0 or id>=_rows(table).size(): return null
	var string:=func(column):return spell_string_entry(table,id,column)
	var number:=func(column):return int(_integer(table,id,column).value)
	var master:Dictionary=_integer(table,id,"Master")
	var innate:Dictionary=_integer(table,id,"Innate")
	var counter1:Dictionary=_integer(table,id,"Counter1")
	var counter2:Dictionary=_integer(table,id,"Counter2")
	var shape:String=str(string.call("TargetShape")).to_lower()
	return {"id":id,"components":string.call("VS"),"range":str(string.call("Range")).left(1),"impactScript":string.call("ImpactScript"),
		"targetShape":int({"sphere":1,"rectangle":2,"cone":3,"hsphere":4}.get(shape,0)),"targetSizeX":float(_float(table,id,"TargetSizeX").value),"targetSizeY":float(_float(table,id,"TargetSizeY").value),"targetFlags":number.call("TargetFlags"),
		"master":int(master.value) if bool(master.found) else id,"innate":int(innate.value)&255 if bool(innate.found) else 255,"metamagic":int(number.call("MetaMagic"))&255,
		"counter1":int(counter1.value) if bool(counter1.found) else -1,"counter2":int(counter2.value) if bool(counter2.found) else -1,
		"targetType":int(number.call("TargetType"))&65535,"conjureTime":int(number.call("ConjTime"))&U32,"conjureAnimation":conjure_animation_type(string.call("ConjAnim")),
		"castTime":int(number.call("CastTime"))&U32,"castAnimation":cast_animation_type(string.call("CastAnim")),"useProjectile":int(number.call("Proj")),
		"projectilePath":projectile_path_type(string.call("ProjType")),"userType":int(number.call("UserType"))&255,"spontaneouslyCast":int(number.call("SpontaneouslyCast")),
		"useConcentration":int(number.call("UseConcentration")),"hasProjectile":int(number.call("HasProjectile"))}
