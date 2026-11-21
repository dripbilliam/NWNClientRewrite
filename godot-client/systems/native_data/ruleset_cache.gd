extends RefCounted
# CNWRules LoadRulesetInfo2ac0c0 -> GetRulesetIntEntry2a4130. A cache belongs
# to one resource owner/publication, never to a filename or a global world.
const SLOT="_native_ruleset_cache"
const Binary=preload("res://systems/native_data/binary_data.gd")
class Lease extends RefCounted:
	var generation:=0
class Entry extends RefCounted:
	var _source: Dictionary={}
	var _values: Dictionary={}
	var _duplicates: Array[String]=[]
	var failure: String=""
	var _lease: Lease
	var _generation:=-1
	var _scope: Array=[]
	var build_ms:=0.0
	func matches(tables: Dictionary) -> bool:
		return _lease!=null and _lease.generation==_generation and is_same(_source,tables.get("ruleset"))
	func integer(label: String,fallback: int) -> int:
		var core: GDScript=load("res://systems/native_data/ruleset_cache.gd")
		var key: Dictionary=core.hash_key(label)
		return int(_values.get(key.get("value",""),fallback)) if key.error.is_empty() else fallback
	func duplicates() -> Array[String]: return _duplicates.duplicate()
	func source_view() -> Dictionary: return _source
	func values_view() -> Dictionary: return _values
	func overlay(tables: Dictionary) -> Dictionary:
		var result: Dictionary=tables.duplicate(); result.ruleset=_source; result[SLOT]=self; return result
	func snapshot() -> Dictionary:
		return {"scope":_scope.duplicate(true),"generation":_generation,"entries":_values.size(),"build_ms":build_ms,"current":_lease!=null and _lease.generation==_generation}
class Owner extends RefCounted:
	var _lease:=Lease.new()
	var builds:=0
	func prepare(table: Dictionary,scope: Array=[]) -> Entry:
		var began:=Time.get_ticks_usec(); _lease.generation+=1; var entry:=Entry.new()
		var core: GDScript=load("res://systems/native_data/ruleset_cache.gd")
		entry._source=core.frozen_source(table)
		var compiled: Dictionary=core.compile_checked(entry._source)
		entry._values=compiled.values;entry._duplicates=compiled.duplicates;entry.failure=compiled.error
		entry._values.make_read_only()
		entry._lease=_lease; entry._generation=_lease.generation; entry._scope=scope.duplicate(true); entry.build_ms=(Time.get_ticks_usec()-began)/1000.0; builds+=1
		return entry
	func retire() -> void: _lease.generation+=1
static func current(tables: Dictionary) -> Entry:
	var candidate: Variant=tables.get(SLOT)
	return candidate if candidate is Entry and candidate.matches(tables) else null
static func field(row: Dictionary,name: String) -> Variant:
	# C2DA column lookup is insensitive; ruleset LABEL values are exact bytes.
	for key in row:
		if str(key).to_lower()==name.to_lower(): return row[key]
	return null
static func atoi(value: String) -> int:
	# Original atoi c81d54 calls its signed, base10 parser c8047c. It clamps
	# outside INT32 rather than accepting hex or wrapping. C-locale whitespace.
	var at:=0; var size:=value.length()
	while at<size and (value.unicode_at(at)==32 or value.unicode_at(at)>=9 and value.unicode_at(at)<=13): at+=1
	var negative:=false
	if at<size and value.unicode_at(at) in [43,45]: negative=value.unicode_at(at)==45; at+=1
	var result:=0; var last:=8 if negative else 7
	while at<size:
		var digit:=value.unicode_at(at)-48
		if digit<0 or digit>9: break
		if result>214748364 or result==214748364 and digit>last: return -2147483648 if negative else 2147483647
		result=result*10+digit; at+=1
	return -result if negative else result
static func hash_key(label: String) -> Dictionary:
	# JS TextDecoder('windows-1252') produces U+FFFD for the five undefined
	# bytes. Its reverse Map retains the last such byte, 0x9d.
	var high:=0xcbf29ce4;var low:=0x84222325
	for at in label.length():
		var code: int=label.unicode_at(at);var byte:=-1
		if code<128 or code>=160 and code<=255:byte=code
		elif code==0xfffd:byte=0x9d
		else:
			for slot in Binary.CP1252_HIGH.size():
				if slot in [1,13,15,16,29]:continue
				if int(Binary.CP1252_HIGH[slot])==code:byte=slot+128;break
		if byte<0:return {"value":"","error":"Ruleset label cannot be encoded as a native resource string"}
		# BigInt(i8(byte)) sign extends before XOR. Split the u64 into two
		# 32-bit halves so the FNV multiply cannot overflow Godot's signed int.
		if byte>=128:
			high^=0xffffffff;low^=(0xffffff00|byte)
		else:low^=byte
		var product: int=low*0x1b3
		high=(high*0x1b3+(product>>32)+(low<<8))&0xffffffff
		low=product&0xffffffff
	return {"value":str(high)+":"+str(low),"error":""}
static func compile_checked(table: Dictionary) -> Dictionary:
	var values: Dictionary={};var duplicates: Array[String]=[]
	for row in table.get("orderedRows",[]):
		var raw_label: Variant=field(row,"Label");var raw: Variant=field(row,"Value")
		if raw_label==null or str(raw_label) in ["","****"] or raw==null or str(raw) in ["","****"]:continue
		var key: Dictionary=hash_key(str(raw_label))
		if not key.error.is_empty():return {"values":{},"duplicates":duplicates,"error":str(key.error)}
		if values.has(key.value):duplicates.append(str(raw_label))
		values[key.value]=atoi(str(raw))
	return {"values":values,"duplicates":duplicates,"error":""}
static func compile(table: Dictionary) -> Dictionary:
	return compile_checked(table).values
static func duplicates(table: Dictionary) -> Array[String]:
	var compiled: Dictionary=compile_checked(table)
	var result: Array[String]=compiled.duplicates
	return result
static func from_source(tables: Dictionary,label: String,fallback: int) -> int:
	var key: Dictionary=hash_key(label)
	if not key.error.is_empty():return fallback
	var compiled: Dictionary=compile_checked(tables.get("ruleset",{}))
	return int(compiled.values.get(key.value,fallback)) if compiled.error.is_empty() else fallback
static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for child in value.values(): freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value: freeze(child)
		value.make_read_only()
static func frozen_source(table: Dictionary) -> Dictionary:
	var result: Dictionary=table.duplicate(true); freeze(result); return result
