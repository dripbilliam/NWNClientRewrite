extends RefCounted
const DEFAULT_PORT:=8765
static func parse(arguments: Variant,environment: Dictionary={}) -> Dictionary:
	var values:={"entity-api-rest":"false","entity-api-rest-port":str(DEFAULT_PORT),"entity-api-rest-discovery":"user://entity-api-rest-"+str(OS.get_process_id())+".json"}
	for pair in [["entity-api-rest","NWN_ENTITY_API_REST"],["entity-api-rest-port","NWN_ENTITY_API_REST_PORT"],["entity-api-rest-discovery","NWN_ENTITY_API_REST_DISCOVERY"]]:
		if environment.has(pair[1]): values[pair[0]]=str(environment[pair[1]])
	var seen: Dictionary={}
	for argument in arguments:
		var text:=str(argument)
		if not text.begins_with("--entity-api-rest"): continue
		var pair:=text.trim_prefix("--").split("=",true,1)
		if pair.size()!=2 or pair[0] not in ["entity-api-rest","entity-api-rest-port","entity-api-rest-discovery"] or seen.has(pair[0]): return {"enabled":false,"error":"invalid_rest_option"}
		seen[pair[0]]=true
		values[pair[0]]=pair[1]
	if values["entity-api-rest"] not in ["true","false"]: return {"enabled":false,"error":"invalid_rest_option"}
	var port: String=values["entity-api-rest-port"]
	if port.is_empty() or not port.is_valid_int() or str(int(port))!=port or int(port)<0 or int(port)>65535: return {"enabled":false,"error":"invalid_rest_port"}
	var path: String=values["entity-api-rest-discovery"]
	if path.is_empty() or path.contains("\n") or path.contains("\r") or (not path.begins_with("user://") and not path.is_absolute_path()): return {"enabled":false,"error":"invalid_rest_discovery_path"}
	return {"enabled":values["entity-api-rest"]=="true","port":int(port),"discovery_path":path}
