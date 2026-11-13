extends RefCounted
# Authored server results must echo correlation issued by the actual controller
# through the real panel.open/submit path. This helper creates no request IDs,
# tokens, lifetimes, actor storage, server acceptance or fallback metadata.
const FIELDS=["version","owner","entry","request","generation","areaId","actorId","nativeLifetime","knownLifetime","operation","token"]
static func matches(command: Variant,operation: String,token: Variant=null) -> bool:
	if not command is Dictionary or command.get("kind")!="native-level-up" or command.get("operation")!=operation or token!=null and command.get("token")!=token:return false
	var scope: Variant=command.get("levelRequest")
	if not scope is Dictionary or scope.size()!=FIELDS.size() or not scope.has_all(FIELDS):return false
	for field in ["operation","generation","areaId","actorId"]:
		if scope[field]!=command.get(field):return false
	return scope.token==command.get("token",-1)
static func latest(desktop: Object,operation: String,token: Variant=null) -> Dictionary:
	var commands: Variant=desktop.get("commands") if is_instance_valid(desktop) else null
	if commands is Array:
		for index in range(commands.size()-1,-1,-1):
			var command: Variant=commands[index]
			if command is Dictionary and command.get("operation")==operation and (token==null or command.get("token")==token):
				if matches(command,operation,token):return command
				break
	push_error("Level-up fixture has no matching real correlated outgoing command.")
	return {}
static func echo(desktop: Object,response: Dictionary,token: Variant=null) -> Dictionary:
	if response.has("levelRequest"):
		push_error("Level-up fixture may not handcraft reply metadata.");return {}
	var command:=latest(desktop,str(response.get("operation","")),token)
	if command.is_empty():return {}
	var value:=response.duplicate(true)
	value.kind="native-action-result";value.action="native-level-up"
	# Real local transport JSON preserves values while turning Godot INT DTOs
	# into JSON numbers. The separately authored result retains its test shape.
	value.levelRequest=JSON.parse_string(JSON.stringify(command.levelRequest))
	return value
