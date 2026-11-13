extends RefCounted
# CNWCCreatureStats constructor110/114 + ordered DM visibility cache writes.
# These are two native LOCAL renderer/GUI fields, never invented server stats.
# The canonical lifetime owner calls construct/retire; no world or Node store.
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
const Reveal=preload("res://systems/native_render/native_scene_visibility.gd")
var _connection: Variant=null
var _guard: Callable
var _closed:=true
var _records: Dictionary={}
var _controlled: Variant=null
var _controlled_lifetime: Array=[]
var _permission: Variant=null
var _serial:=-1
var _revision:=0
var _issues: Array=[]
var stats:={"constructed":0,"retired":0,"permission_events":0,"ai_writes":0,"unavailable":0}
func _issue(reason: String) -> Dictionary:
	stats.unavailable+=1
	if _issues.size()<32:_issues.append(reason)
	return {"available":false,"reason":reason}
func configure(connection: Variant,guard: Callable) -> Dictionary:
	if not _closed or (not connection is String and not connection is int) or connection is String and connection.is_empty() or not guard.is_valid():return _issue("native-local-visibility-connection-unavailable")
	_connection=connection;_guard=guard;_closed=false;return {"available":true}
func _current() -> bool:
	return not _closed and _guard.is_valid() and _guard.call(_connection)==true and not _closed
static func valid_token(value: Variant) -> bool:
	if not value is Array or value.size()!=2:return false
	return not Reveal.scope_value({"connection_epoch":1,"area_generation":1,"area_id":1,"controlled_id":1,"controlled_lifetime":value}).is_empty()
static func uint(value: Variant,maximum: int=4294967295) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and value==floor(float(value))
func _record(id: int,token: Array) -> Dictionary:
	if not _current() or not _records.has(id) or _records[id].lifetime!=token:return {}
	return _records[id]
func accepted_lifecycle(event: Dictionary) -> Dictionary:
	# Caller is the synchronously admitted accepted-lifecycle v2 boundary,
	# not an ordinary snapshot/DTO, renderer adoption or inferred first sight.
	if not _current() or event.get("version")!=2 or not uint(event.get("objectId")) or event.get("objectType")!=5:return _issue("native-creature-constructor-boundary-unavailable")
	var id:=int(event.objectId);var token: Variant=event.get("physicalToken");var epoch: Variant=event.get("lifecycleEpoch")
	if event.get("operation")=="create" and event.get("ownership")=="retained" and token is String and _records.has(id) and _records[id].physical==token and _records[id].epoch==epoch:return {"available":true,"constructed":false,"retained":true}
	if event.get("operation")!="create" or event.get("ownership")!="new" or event.get("constructionCertified")!=true or event.get("aiRegistrationCertified")!=true or event.get("constructionHistoryComplete")!=true or not token is String or token.is_empty() or not uint(epoch):
		# Ambiguous ownership cannot transfer a cache to a different entity.
		if _records.has(id):_records.erase(id);stats.retired+=1;_revision+=1
		return _issue("native-local-constructor-history-unavailable")
	if _records.has(id):
		if _records[id].physical==token and _records[id].epoch==epoch:return {"available":true,"constructed":false}
		_records.erase(id);stats.retired+=1
	_records[id]={"physical":token,"epoch":int(epoch),"lifetime":[],"creature110":0,"creature114":0,"needs_ai":_permission==true and _controlled==id}
	stats.constructed+=1;_revision+=1;return {"available":true,"constructed":true,"source":"CNWCCreatureStats7ea230/clearQword110"}
func bind(source: Dictionary) -> Dictionary:
	if not _current() or not uint(source.get("id")) or source.get("objectType")!=5:return _issue("native-creature-source-unavailable")
	var token:=Lifetime.token(source);var id:=int(source.id);var owner: Variant=source.get("nativeClockOwner")
	if not valid_token(token) or not owner is Dictionary or owner.get("version")!=1 or owner.get("source")!="native-client-clock-owner-v1" or owner.get("connection")!=_connection or owner.get("physicalCurrent")!=true or not _records.has(id):return _issue("native-creature-physical-owner-unavailable")
	var record: Dictionary=_records[id]
	if record.physical!=owner.get("physicalToken") or record.epoch!=owner.get("epoch"):return _issue("native-creature-physical-owner-mismatch")
	if record.lifetime!=token:record.lifetime=token;_revision+=1
	return {"available":true,"source":"certified-physical-owner-bound-to-current-received-lifetime"}
func retire(id: int,token: Array) -> bool:
	if _record(id,token).is_empty():return false
	_records.erase(id);stats.retired+=1;_revision+=1
	if _controlled==id and _controlled_lifetime==token:_controlled=null;_controlled_lifetime=[]
	return true
func controlled_changed(id: Variant,token: Array=[]) -> Dictionary:
	if not _current() or id!=null and (not uint(id) or not valid_token(token)):return _issue("native-controlled-visibility-owner-unavailable")
	if id==_controlled and token==_controlled_lifetime:return {"available":true,"changed":false}
	_controlled=id;_controlled_lifetime=token.duplicate(true) if id!=null else [];_revision+=1
	var record:=_record(int(id),token) if id!=null else {}
	if not record.is_empty() and _permission==true:record.needs_ai=true
	return {"available":true,"changed":true}
func receive(frame: Dictionary) -> Dictionary:
	if not _current() or frame.get("kind")!="raw-creature-visibility-permission" or frame.get("connection")!=_connection or not uint(frame.get("serial"),9223372036854775807) or frame.serial<=_serial or not frame.get("permission") is bool or not frame.get("field114") is bool:return _issue("fresh-native-permission-event-unavailable")
	var id: Variant=frame.get("actorId");var token: Variant=frame.get("lifetime")
	if id!=null and (not uint(id) or not valid_token(token)) or id==null and token!=null:return _issue("native-permission-recipient-reference-unavailable")
	var record: Dictionary={};var owner: Variant=frame.get("recipientOwner")
	if id!=null and owner is Dictionary and owner.get("version")==1 and owner.get("source")=="native-client-clock-owner-v1" and owner.get("connection")==_connection and owner.get("physicalCurrent")==true and _records.has(int(id)):
		var candidate: Dictionary=_records[int(id)]
		if candidate.physical==owner.get("physicalToken") and candidate.epoch==owner.get("epoch"):record=candidate
	_permission=frame.permission;_serial=int(frame.serial);stats.permission_events+=1;_revision+=1
	var controlled:=_record(int(_controlled),_controlled_lifetime) if _controlled!=null else {}
	if not controlled.is_empty():controlled.needs_ai=frame.permission
	if not record.is_empty():
		record.creature114=int(frame.field114)
		if not frame.permission:record.creature110=0
		record.needs_ai=frame.permission and id==_controlled and record.lifetime==_controlled_lifetime
	if id!=null and record.is_empty():_issue("native-permission-recipient-physical-owner-unavailable")
	return {"available":true,"accepted":true,"actor":id,"recipient_available":id==null or not record.is_empty(),"source":"receivedDM797ae0/subtype31-22"}
func receive_connection_permission(permission: bool) -> Dictionary:
	# Original connection subtype16 supplies permission only, not stats114.
	if not _current():return _issue("native-connection-permission-scope-unavailable")
	_permission=permission;_revision+=1
	var record:=_record(int(_controlled),_controlled_lifetime) if _controlled!=null else {}
	if not record.is_empty() and permission:record.needs_ai=true
	return {"available":true,"source":"receivedConnection16"}
func initialize_connection_permission(value: Dictionary) -> Dictionary:
	# This exact record is created at NetworkGameSession.connect(16), before
	# any server event. It is a native constructor/session initialization fact,
	# not a replay of the sticky subtype31/22 received stats114 writer.
	var permission: Variant=value.get("permission")
	# JSON.parse_string delivers all numbers as float. Array.has is type-strict;
	# valid native0/1 carrier words must not fail a literal-int membership test.
	if value.get("source")!="native_connection_start_16" or value.get("field114")!=null or value.get("parameter")!=null or not (permission is bool or uint(permission,1)):return _issue("native-connection16-initializer-unavailable")
	if _permission!=null:return {"available":true,"applied":false}
	return receive_connection_permission(bool(value.permission))
func ai(id: int,token: Array,context: Dictionary) -> Dictionary:
	var record:=_record(id,token)
	if record.is_empty():return _issue("native-creature-ai-lifetime-unavailable")
	if _permission==null:return _issue("native-ai-dm-permission-unavailable")
	if _permission==false or id!=_controlled or token!=_controlled_lifetime or record.creature110!=0:
		record.needs_ai=false;return {"available":true,"changed":false}
	# Exact getter6ac1b0 gates the positive DM path. Its semantic label remains
	# unknown; do not substitute account, roster, render mode or a guessed zero.
	if not uint(context.get("controlled_getter6ac1b0"),65535):return _issue("native-dm-ai-getter-unavailable")
	if context.controlled_getter6ac1b0!=0:record.needs_ai=false;return {"available":true,"changed":false}
	if not context.get("gui_present") is bool:return _issue("native-dm-gui-owner-unavailable")
	if context.gui_present and not uint(context.get("gui674")):return _issue("native-dm-gui674-unavailable")
	record.creature110=1
	if context.gui_present:record.creature114=int(context.gui674)
	record.needs_ai=false;_revision+=1;stats.ai_writes+=1
	return {"available":true,"changed":true,"statusA8":3,"request_target":record.creature114!=0,"source":"CNWCCreatureAI7fbd10"}
func fields(id: int,token: Array) -> Dictionary:
	var record:=_record(id,token)
	if record.is_empty():return _issue("native-local-visibility-fields-unavailable")
	if _controlled==id and _controlled_lifetime==token and _permission==null:return _issue("native-controlled-dm-permission-unavailable")
	if record.needs_ai:return _issue("native-controlled-dm-ai-not-reconciled")
	return {"available":true,"creature110":record.creature110,"creature114":record.creature114,"source":"native-local-constructor-and-ordered-DM-events"}
func snapshot() -> Dictionary:
	return {"closed":_closed,"connection":_connection,"controlled":_controlled,"controlled_lifetime":_controlled_lifetime.duplicate(true),"permission":_permission,"serial":_serial,"count":_records.size(),"revision":_revision,"stats":stats.duplicate(),"issues":_issues.duplicate()}
func close() -> void:
	_closed=true;_connection=null;_guard=Callable();_records.clear();_controlled=null;_controlled_lifetime=[];_permission=null;_serial=-1;_revision+=1
