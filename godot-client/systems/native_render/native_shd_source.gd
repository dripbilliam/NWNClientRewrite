extends RefCounted
# Reads the mounted resource layers used by the old resolver. GLSL returned
# here is evidence/input only: Godot spatial shaders cannot compile Three's
# onBeforeCompile GLSL stage directly.
const SHD:=2069
const MAX_DEPTH:=16
const MAX_CHARS:=1024*1024

static func declared_symbols(source: String) -> Dictionary:
	var symbols: Dictionary={}
	for pattern in ["(?m)^\\s*#define\\s+([A-Za-z_]\\w*)", "\\b(?:uniform|varying|attribute|const)\\s+(?:(?:lowp|mediump|highp)\\s+)?(?:float|int|bool|[ib]?vec[234]|mat[234]|sampler\\w+)\\s+(?:(?:lowp|mediump|highp)\\s+)?([A-Za-z_]\\w*)", "\\b(?:void|float|int|bool|[ib]?vec[234]|mat[234])\\s+([A-Za-z_]\\w*)\\s*\\("]:
		var expression:=RegEx.new()
		if expression.compile(pattern)!=OK:continue
		for row in expression.search_all(source):symbols[row.get_string(1)]=true
	return symbols

static func fnv_cache_key(source: String) -> String:
	# Match Math.imul FNV-1a over JavaScript charCodeAt UTF-16 units.
	var hash: int=2166136261
	for index in source.length():
		var point: int=source.unicode_at(index)
		if point<=0xffff:hash=((hash^point)*16777619)&0xffffffff
		else:
			point-=0x10000
			hash=((hash^(0xd800+(point>>10)))*16777619)&0xffffffff
			hash=((hash^(0xdc00+(point&0x3ff)))*16777619)&0xffffffff
	return "%x"%hash

static func _expand(catalog,name: String,stack: Array,sources: Dictionary,order: Array) -> Dictionary:
	if stack.has(name) or stack.size()>MAX_DEPTH:
		return {"error":"Native shader include cycle: "+name}
	var source: String
	if sources.has(name):source=sources[name]
	else:
		var bytes: PackedByteArray=catalog.get_resource(name,SHD)
		if bytes.is_empty():return {"error":"Native shader resource unavailable: "+name}
		source=bytes.get_string_from_utf8()
		if source.length()>MAX_CHARS:return {"error":"Native shader is too large: "+name}
		sources[name]=source;order.append(name)
	var expression:=RegEx.new()
	if expression.compile("(?m)^\\s*#include\\s+\"([\\w]+)\"\\s*$")!=OK:
		return {"error":"Native shader include matcher failed"}
	var at:=0
	var expanded:=""
	for match_row in expression.search_all(source):
		expanded+=source.substr(at,match_row.get_start()-at)
		var child: Dictionary=_expand(catalog,match_row.get_string(1),stack+[name],sources,order)
		if child.has("error"):return child
		expanded+=str(child.value)
		at=match_row.get_end()
	expanded+=source.substr(at)
	return {"value":expanded}

static func load(catalog,name: String,required: Array) -> Dictionary:
	if catalog==null or not catalog.has_method("get_resource"):
		return {"error":"Native shader catalog is unavailable"}
	var sources: Dictionary={}
	var order: Array=[]
	var expanded: Dictionary=_expand(catalog,name,[],sources,order)
	if expanded.has("error"):return expanded
	var source: String=expanded.value
	for symbol in required:
		var declaration:=RegEx.new()
		if declaration.compile("\\b"+str(symbol)+"\\b")!=OK or declaration.search(source)==null:
			return {"error":"Native shader declaration unavailable: "+str(symbol)}
	var hash:=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(source.to_utf8_buffer())
	return {"source":source,"resources":order,"sha256":hash.finish().hex_encode()}
