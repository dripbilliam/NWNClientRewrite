extends SceneTree
const Scope=preload("res://systems/native_data/level_up_reply_scope.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var scope:={"generation":2,"areaId":7,"actorId":42,"nativeLifetime":123,"knownLifetime":456}
	var owner:=Scope.new();check(owner.open(scope,1),"Known scope opens local request entry")
	var issued:=owner.issue("begin",-1);var one: Dictionary=issued.value
	check(issued.ready and owner.pending_count()==1 and not owner.issue("begin",-1).ready,"Duplicate outstanding begin is not sent twice")
	var wire: Variant=JSON.parse_string(JSON.stringify(one))
	var printable:=one.duplicate();printable.owner="local request";check(not Scope.metadata(printable).is_empty(),"Opaque printable ASCII owner matches the Host contract")
	check(typeof(wire.request)==TYPE_FLOAT and owner.consume(wire,scope,1,"begin"),"Exact JSON number echo consumes its one native request")
	check(not owner.consume(one,scope,1,"begin"),"Duplicate reply is not consumed again")
	check(owner.open(scope,2),"Next UI entry opens")
	var two: Dictionary=owner.issue("begin",-1).value
	check(two.request>one.request and not owner.consume(one,scope,2,"begin") and owner.pending_count()==1,"Old same-actor begin cannot replace a new request")
	check(owner.current(scope,2) and not owner.current(scope,1),"Command admission checks the same current view as reply consumption")
	var detached:=two.duplicate();detached.owner="other";check(not owner.consume(detached,scope,2,"begin"),"Foreign controller cannot claim the request")
	check(owner.consume(two,scope,2,"begin"),"Current request survives stale or foreign echoes")
	var submit: Dictionary=owner.issue("submit",12).value
	var changed:=scope.duplicate()
	for key in Scope.CONTEXT:
		changed=scope.duplicate();changed[key]+=1
		check(not owner.current(changed,2),"Stale entity or scope cannot issue a new command "+str(key))
		check(not owner.consume(submit,changed,2,"submit"),"Changed connection/area/actor/lifetime cannot consume "+str(key))
	check(not owner.consume(submit,scope,3,"submit") and not owner.consume(submit,scope,2,"cancel"),"Changed view or operation cannot consume submit")
	var stale:=submit.duplicate();stale.token=11;check(not owner.consume(stale,scope,2,"submit"),"Old transaction token cannot consume submit")
	check(owner.consume(submit,scope,2,"submit"),"Current failure or success may resolve the same exact request once")
	var cancel: Dictionary=owner.issue("cancel",12).value;owner.retire()
	check(not owner.consume(cancel,scope,2,"cancel") and owner.pending_count()==0,"Presentation retirement discards its pending local replies")
	check(owner.open(scope,3),"Reconnect/reopen may establish another entry")
	var fresh: Dictionary=owner.issue("begin",-1).value
	check(fresh.request>cancel.request and not owner.consume(cancel,scope,3,"cancel"),"Retirement never recycles request identity")
	var bad: Array=[null,[],{},"value"]
	for key in Scope.FIELDS:
		var missing:=fresh.duplicate();missing.erase(key);bad.append(missing)
	for pair in [["version",2],["owner",""],["owner","a\nb"],["owner","x".repeat(129)],["entry",-1],["request",0],["request",1.5],["generation",null],["areaId",4294967296],["actorId","42"],["nativeLifetime",0],["knownLifetime",false],["operation","heal"],["token",0]]:
		var malformed:=fresh.duplicate();malformed[pair[0]]=pair[1];bad.append(malformed)
	var extra:=fresh.duplicate();extra.secret="not returned";bad.append(extra)
	for value in bad:check(Scope.metadata(value).is_empty() and not owner.consume(value,scope,3,"begin"),"Malformed/missing/extra metadata is rejected without consuming current request")
	fresh.owner="mutated returned value"
	check(owner.pending_count()==1,"Returned metadata is detached from outstanding state")
	owner.retire()
	check(not owner.open({"generation":2,"areaId":7,"actorId":42},4),"Unavailable lifetimes never become zero or invented")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"productionIntegrated":false,"serverConnections":0,"gpu":false,"scope":"Pure local request/view metadata owner; actual JSON number roundtrip, duplicate/stale/reconnect/lifetime/operation/token guards and detached data. No controller/Host/server integration yet."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
