extends SceneTree
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path):quit(2);return
	var received: Dictionary=JSON.parse_string('{"id":17,"nativeLifetime":3,"clientKnownLifetime":8}')
	check(Lifetime.token(received)==[["nativeLifetime",true,3],["disclosureLifetime",true,8]],"Actual JSON snapshot uses canonical clientKnownLifetime carrier")
	var legacy:={"nativeLifetime":3,"disclosureLifetime":8}
	check(Lifetime.token(legacy)==Lifetime.token(received),"Older detached DTO remains token-compatible")
	check(not Lifetime.changed(legacy,received),"Equivalent carrier spelling does not rebuild a model")
	var next: Dictionary=JSON.parse_string('{"nativeLifetime":3,"clientKnownLifetime":9}')
	check(Lifetime.changed(received,next),"Known-run retirement fences a retained native physical object")
	check(not Lifetime.changed(received,received.duplicate(true)),"Unchanged known-run does not spuriously retire")
	var both:={"nativeLifetime":3,"clientKnownLifetime":8,"disclosureLifetime":4}
	check(Lifetime.token(both)==Lifetime.token(received),"Canonical transport supersedes stale legacy alias")
	for unavailable in [null,-1,1.25,"8",false,NAN,INF]:
		var source:={"nativeLifetime":3,"clientKnownLifetime":unavailable,"disclosureLifetime":4}
		check(Lifetime.token(source)[1]==["disclosureLifetime",false,null],"Unavailable canonical identity cannot revive old alias")
	var absent: Dictionary=JSON.parse_string('{"nativeLifetime":3}')
	check(Lifetime.token(absent)[1]==["disclosureLifetime",false,null],"Missing identity is explicit, never zero")
	check(Lifetime.changed(absent,received),"Acquiring a known-run identity invalidates unscoped presentation")
	var tokens:=Lifetime.token(received);tokens[1][2]=99
	check(Lifetime.token(received)[1][2]==8,"Detached tokens cannot mutate received source")
	var out:=FileAccess.open(path,FileAccess.WRITE);out.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures}));out.close();quit(0 if failures.is_empty() else 1)
