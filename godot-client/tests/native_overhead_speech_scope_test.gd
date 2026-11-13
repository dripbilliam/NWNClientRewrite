extends SceneTree
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var current:=Scope.context(3,7,91);var packet:={"kind":"server-speech","channel":1,"objectId":42,"text":{"text":"Native speech"},"nativeTextEvent":{"version":1,"serial":10,"connection":3,"generation":7,"areaId":91,"source":{"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"knownLifetime":13}}}
	var raw: Dictionary=JSON.parse_string(JSON.stringify(packet));var before:=raw.duplicate(true);var received:={"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13,"replicationRemoved":false}
	var event:=Scope.event(raw,current);check(event.get("ready",false) and event.anchor,"Actual JSON numeric metadata remains an explicit native anchor witness")
	check(Scope.event(raw,{"ready":true}).get("pending",false),"Incomplete current-owner context remains pending without unsafe member access")
	check(Scope.received_source(event,received,current).get("ready",false),"Raw snapshot uses exact nativeLifetime plus clientKnownLifetime counterpart")
	var extra:=raw.duplicate(true);extra.nativeTextEvent.source.extra={"mutable":[1]};extra.nativeTextEvent.source.object=RefCounted.new();var projected:=Scope.event(extra,current)
	check(projected.source.size()==5 and not projected.source.has("extra") and not projected.source.has("object") and projected.source.id is int and projected.source.nativeLifetime is int,"Only five normalized known scalar fields enter the detached source view")
	projected.source.areaId=12;extra.nativeTextEvent.source.extra.mutable[0]=99
	check(extra.nativeTextEvent.source.areaId==91 and not projected.source.has("extra") and raw==before,"Mutable extra fields and projected source updates cannot alias original event metadata")
	var removed:=received.duplicate();removed.clientKnownLifetime=14
	check(not Scope.received_source(event,removed,current).get("ready",false),"A retained native proxy redisclosed with the same ID/nativeLifetime cannot steal old speech")
	removed=received.duplicate();removed.nativeLifetime=9;check(not Scope.received_source(event,removed,current).get("ready",false),"A native identity replacement cannot steal old speech")
	check(Scope.received_source(event,{},current).get("pending",false),"An event before native snapshot publication can wait without fabricating an actor")
	check(not Scope.event(raw,Scope.context(4,7,91)).get("ready",false),"Old connection metadata cannot attach after reconnect")
	check(not Scope.event(raw,Scope.context(3,8,91)).get("ready",false),"Old area generation cannot attach during same-area reentry")
	check(not Scope.event(raw,Scope.context(3,7,92)).get("ready",false),"Other-area events cannot attach in the current world")
	var null_source:=raw.duplicate(true);null_source.nativeTextEvent.source=null
	var unanchored:=Scope.event(null_source,current);check(unanchored.get("ready",false) and not unanchored.anchor and null_source.text==raw.text,"System/remote/null-source payload stays intact without an invented anchor")
	var unknown:=raw.duplicate(true);unknown.nativeTextEvent.areaId=null;check(Scope.event(unknown,current).get("pending",false),"Unknown event area stays explicit instead of becoming area0/current")
	unknown=raw.duplicate(true);unknown.nativeTextEvent.source.areaId=null;unknown.nativeTextEvent.source.objectType=null
	check(Scope.received_source(Scope.event(unknown,current),received,current).get("ready",false),"Unknown source fields can be resolved only by the exact received lifetime witness")
	for invalid in [null,true,"8",1.5,-1,0,INF,NAN]:
		var malformed:=raw.duplicate(true);malformed.nativeTextEvent.source.nativeLifetime=invalid
		check(not Scope.event(malformed,current).get("ready",false),"Malformed or nonpositive lifetime never becomes a ready source")
	var gone:=received.duplicate();gone.replicationRemoved=true;check(not Scope.received_source(event,gone,current).get("ready",false),"Removed speaker cannot retain overhead text")
	check(raw==before,"Presentation validation does not alter original message/TLK payload or metadata")
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"productionImported":false,"scope":"Authored/JSON native text metadata and raw speaker lifetime boundary only; no channel, duration, rendering, original server or pixel acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
