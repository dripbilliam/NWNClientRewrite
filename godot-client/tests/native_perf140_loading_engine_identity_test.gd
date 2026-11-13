extends SceneTree
const Identity=preload("res://systems/native_data/scoped_processor_identity.gd")
const Prework=preload("res://systems/native_data/prework_store.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func arg(prefix: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""
func graph_for(kind: String) -> Dictionary:
	return {"ready":true,"kind":kind,"files":[{"path":"systems/a.gd","sha256":"a".repeat(64)}],"libraries":[],"argument_prefixes":[],"environment":[],"native_classes":[]}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var failure_mode:=arg("--mode=")=="failure"; var kinds:=["static-model","actor-model","gui-icon-v1","finished-icon-v1","rejection:static-model","rejection:actor-model","rejection:gui-icon-v1"]
	var description:={"format":Identity.FORMAT,"generator":"b".repeat(64)}; var reader:=func(_path):return "a".repeat(64)
	var context:={"engine":{"same":"metadata"},"engine_sha256":"c".repeat(64),"arguments":[],"environment":[],"classes":[],"schema":Identity.FORMAT,"renderer":["method","driver","display"]}
	for kind in kinds:
		var original:=Identity.verify(kind,description,graph_for(kind),reader,context)
		check(Identity.valid_digest(original.identity),"complete actual-engine proof admits "+kind)
		var other:=context.duplicate(true); other.engine_sha256="d".repeat(64)
		check(Identity.verify(kind,description,graph_for(kind),reader,other).identity!=original.identity,"different actual engine bytes change identity despite identical version metadata: "+kind)
		for invalid in [null,"","C".repeat(64),"manual-build-tag",17]:
			var bad:=context.duplicate(true); bad.engine_sha256=invalid
			check(Identity.verify(kind,description,graph_for(kind),reader,bad).identity.is_empty(),"missing/malformed engine fingerprint cannot manufacture optional identity: "+kind)
		var missing:=context.duplicate(true); missing.erase("engine_sha256")
		check(Identity.verify(kind,description,graph_for(kind),reader,missing).identity.is_empty(),"absent actual engine proof disables "+kind)
	if failure_mode:
		# Owned isolated process only: model an unsupported/failed initialized
		# fingerprint without modifying the engine executable or live sources.
		Identity.engine_initialized=true; Identity.engine_sha256=""; Identity.engine_error="fixture-unavailable"
		for kind in kinds:
			check(Identity.runtime_context(graph_for(kind)).is_empty(),"failed executable fingerprint refuses runtime context: "+kind)
			check(Identity.resolve(kind).is_empty(),"failed executable fingerprint refuses actual source namespace: "+kind)
		check(Prework.request_key("test",2002,"static-model",{},"a".repeat(64),[]).is_empty(),"failed engine proof cannot create a model derivative key")
		check(Prework.icon_request_key("a".repeat(64),[]).is_empty(),"failed engine proof cannot create a finished pixel key")
		check(Prework.rejection_request_key("a".repeat(64),"static-model").is_empty(),"failed engine proof cannot create a rejection key")
		check(int(Identity.engine_status().reads)==0,"failed initialized proof is not retried by each worker/kind")
	else:
		check(not bool(Identity.engine_status().initialized),"process fingerprint has not been eagerly read by source imports")
		var threads: Array=[]
		for index in 8:
			var thread:=Thread.new(); check(thread.start(func():return Identity.runtime_context(graph_for("static-model")))==OK,"concurrent identity worker starts"); threads.append(thread)
		for thread in threads:
			var actual: Dictionary=thread.wait_to_finish()
			check(actual.get("engine_sha256")==arg("--expected-engine-sha="),"all concurrent worker contexts carry actual pinned executable bytes")
		for kind in kinds:
			check(Identity.runtime_context(graph_for(kind)).get("engine_sha256")==arg("--expected-engine-sha="),"every artifact kind shares exact executable proof")
			check(Identity.valid_digest(Identity.resolve(kind)),"actual final source descriptor plus executable admits "+kind)
		var snapshot:=Identity.engine_status(); check(snapshot.reads==1 and snapshot.initialized and snapshot.error.is_empty(),"one synchronized executable SHA read serves every process worker/service/kind")
		snapshot.sha256="mutated"; check(Identity.engine_status().sha256==arg("--expected-engine-sha="),"diagnostic engine proof is detached")
		for index in 20: Identity.engine_identity()
		check(Identity.engine_status().reads==1,"repeated callers do not rehash executable bytes")
	var proof:={"success":failures.is_empty(),"mode":arg("--mode="),"checks":checks,"failures":failures,"identity_status":Identity.status(),"scope":"Actual executable identity, synchronized once-per-process memo, concurrent callers, per-kind separation and failure-closed factories. No GPU/server/speed claim."}
	var file:=FileAccess.open(arg("--report="),FileAccess.WRITE); file.store_string(JSON.stringify(proof)); file.close(); print(JSON.stringify({"success":proof.success,"checks":checks,"mode":proof.mode,"failures":failures})); quit(0 if proof.success else 1)
