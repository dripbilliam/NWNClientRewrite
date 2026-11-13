extends RefCounted
const Json=preload("res://systems/client_api/rest_json.gd")
const EntityProvider=preload("res://systems/client_api/entities.gd")
const REF_FIELDS:=["api_instance","scope_id","connection","area_generation","area_id","object_id","lifetime"]
const MAX_LIMIT:=100
var _entities: RefCounted
func _init(entities: RefCounted) -> void: _entities=entities
static func error(status: int,code: String) -> Dictionary:
	return {"status":status,"body":{"api_version":1,"error":{"code":code}}}
static func integer(text: String,allow_negative: bool=false) -> Variant:
	if text.is_empty() or text.length()>20 or not text.is_valid_int() or str(int(text))!=text or (not allow_negative and text.begins_with("-")): return null
	return int(text)
static func reference_token(reference: Dictionary) -> String:
	var parts:=PackedStringArray(["r1"])
	for field in REF_FIELDS: parts.append(str(reference[field]))
	return ".".join(parts)
static func parse_reference(token: String) -> Variant:
	var parts:=token.split(".",true)
	if parts.size()!=8 or parts[0]!="r1": return null
	var result: Dictionary={}
	for index in REF_FIELDS.size():
		var value: Variant=integer(parts[index+1],index==0)
		if value==null: return null
		result[REF_FIELDS[index]]=value
	if not EntityProvider.valid_id(result.object_id) or not EntityProvider.valid_id(result.area_id) or result.scope_id<1 or result.lifetime<1: return null
	return result
func _ok(body: Dictionary) -> Dictionary:
	body.api_version=1
	var encoded:=Json.encode(body)
	if not encoded.ok: return error(422,"representation_limit")
	if not encoded.unavailable_paths.is_empty(): encoded.value.representation_unavailable_paths=encoded.unavailable_paths
	return {"status":200,"body":encoded.value}
func dispatch(target: String) -> Dictionary:
	if target.length()>2048: return error(414,"target_too_long")
	if not target.begins_with("/") or target.contains("#") or target.contains("%") or target.contains("+") or target.contains("\\"): return error(400,"invalid_target")
	var pieces:=target.split("?",true,1); var path:=pieces[0]; var query: Dictionary={}
	if pieces.size()==2:
		if pieces[1].is_empty(): return error(400,"invalid_query")
		for pair_text in pieces[1].split("&",true):
			var pair:=pair_text.split("=",true,1)
			if pair.size()!=2 or pair[0].is_empty() or pair[1].is_empty() or query.has(pair[0]): return error(400,"invalid_query")
			query[pair[0]]=pair[1]
	var list_route:=path=="/api/v1/entities"
	var allowed: Array=["object_type","area_id","current_area","limit","cursor"] if list_route else (["presentation"] if path in ["/api/v1/controlled","/api/v1/player-character"] or path.begins_with("/api/v1/entities/") or path.begins_with("/api/v1/references/") else [])
	for key in query:
		if not allowed.has(key): return error(400,"unknown_query_parameter")
	var presentation:=false
	if query.has("presentation"):
		if query.presentation not in ["true","false"]: return error(400,"invalid_boolean")
		presentation=query.presentation=="true"
	if path=="/api/v1": return _ok({"service":"nwn-client-entities","read_only":true,"routes":["scope","entities","entities/{id}","references/{reference}","controlled","player-character"]})
	if path=="/api/v1/scope": return _ok({"scope":_entities.get_scope()})
	if list_route: return _list(query)
	var copy_budget:={"max_nodes":8192,"max_text_chars":65536,"max_depth":48}
	if path in ["/api/v1/controlled","/api/v1/player-character"]:
		var result: Dictionary=_entities.get_controlled(presentation,copy_budget) if path.ends_with("/controlled") else _entities.get_player_character(presentation,copy_budget)
		if copy_budget.get("exceeded",false): return error(422,"representation_limit")
		if result.get("reference") is Dictionary: result.reference_token=reference_token(result.reference)
		return _ok({"result":result})
	var entity: Variant=null
	if path.begins_with("/api/v1/entities/"):
		var id: Variant=integer(path.trim_prefix("/api/v1/entities/"))
		if id==null or not EntityProvider.valid_id(id): return error(400,"invalid_object_id")
		entity=_entities.get_by_id(id,presentation,copy_budget)
		if copy_budget.get("exceeded",false): return error(422,"representation_limit")
		if entity==null: return error(404,"entity_not_known")
	elif path.begins_with("/api/v1/references/"):
		var reference: Variant=parse_reference(path.trim_prefix("/api/v1/references/"))
		if reference==null: return error(400,"invalid_reference")
		entity=_entities.resolve(reference,presentation,copy_budget)
		if copy_budget.get("exceeded",false): return error(422,"representation_limit")
		if entity==null: return error(410,"stale_reference")
	else: return error(404,"route_not_found")
	return _ok({"reference":reference_token(entity.reference),"entity":entity})
func _list(query: Dictionary) -> Dictionary:
	var filters: Dictionary={"current_area":false}
	for field in ["object_type","area_id"]:
		if not query.has(field): continue
		var value: Variant=integer(query[field])
		if value==null or (field=="object_type" and value>255) or (field=="area_id" and not EntityProvider.valid_id(value)): return error(400,"invalid_filter")
		filters[field]=value
	if query.has("current_area"):
		if query.current_area not in ["true","false"]: return error(400,"invalid_boolean")
		filters.current_area=query.current_area=="true"
	var limit:=50
	if query.has("limit"):
		var requested: Variant=integer(query.limit)
		if requested==null or requested<1 or requested>MAX_LIMIT: return error(400,"invalid_limit")
		limit=requested
	var scope: Dictionary=_entities.get_scope()
	var filter_key:=JSON.stringify([filters.get("object_type"),filters.get("area_id"),filters.current_area]).sha256_text()
	var after:=-1
	if query.has("cursor"):
		var cursor: PackedStringArray=query.cursor.split(".",true)
		if cursor.size()!=5 or cursor[0]!="c1" or integer(cursor[1],true)==null or integer(cursor[2])==null or integer(cursor[3])==null or cursor[4]!=filter_key: return error(400,"invalid_cursor")
		if int(cursor[1])!=_entities.get_instance_id() or int(cursor[2])!=int(scope.scope_id): return error(410,"stale_cursor")
		after=int(cursor[3])
		if not EntityProvider.valid_id(after): return error(400,"invalid_cursor")
	var page: Dictionary=_entities.page_references(filters,after,limit)
	var items: Array=[]
	for reference in page.items: items.append({"object_id":reference.object_id,"reference":reference_token(reference)})
	var next_cursor: Variant=null
	if page.has_more and not items.is_empty(): next_cursor="c1.%s.%s.%s.%s"%[_entities.get_instance_id(),scope.scope_id,items[-1].object_id,filter_key]
	return _ok({"scope":scope,"items":items,"page":{"limit":limit,"returned":items.size(),"has_more":page.has_more,"next_cursor":next_cursor}})
