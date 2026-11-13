extends SceneTree
const Fields=preload("res://systems/native_render/native_creature_visibility_fields.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	for word in [0.0,1.0,false,true]:
		var value: Dictionary=JSON.parse_string(JSON.stringify({"source":"native_connection_start_16","permission":word,"field114":null,"parameter":null}))
		var fields:=Fields.new();fields.configure(1,func(connection):return connection==1)
		check(fields.initialize_connection_permission(value).available and fields.snapshot().permission==bool(word),"Exact JSON numeric/bool connection16 initializer "+str(word))
		check(value.permission==word,"Native permission carrier remains detached and unmodified")
		var opposite: Dictionary=JSON.parse_string(JSON.stringify({"source":"native_connection_start_16","permission":not bool(word),"field114":null,"parameter":null}))
		check(fields.initialize_connection_permission(opposite).available and fields.snapshot().permission==bool(word),"Connection16 initialization is applied only once "+str(word))
		fields.close()
	for bad in [null,-1.0,0.5,2.0,"0",NAN,INF]:
		var fields:=Fields.new();fields.configure(1,func(connection):return connection==1)
		check(not fields.initialize_connection_permission({"source":"native_connection_start_16","permission":bad,"field114":null,"parameter":null}).available and fields.snapshot().permission==null,"Malformed initializer word remains explicitly unavailable "+str(bad))
		fields.close()
	var ordered:=Fields.new();ordered.configure(1,func(connection):return connection==1)
	var fresh: Dictionary=JSON.parse_string(JSON.stringify({"kind":"raw-creature-visibility-permission","connection":1,"serial":1,"permission":true,"field114":false,"actorId":null,"lifetime":null,"recipientOwner":null}))
	check(ordered.receive(fresh).available and ordered.snapshot().permission==true,"Fresh pre-area subtype31 permission is connection-global")
	check(ordered.initialize_connection_permission({"source":"native_connection_start_16","permission":0.0,"field114":null,"parameter":null}).available and ordered.snapshot().permission==true,"Late connection16 carrier cannot overwrite an already received fresh permission")
	check(not ordered.initialize_connection_permission({"source":"native_connection_start_16","permission":0.0,"field114":false,"parameter":null}).available and ordered.snapshot().permission==true,"Sticky stats114 writer cannot masquerade as connection initialization")
	ordered.close()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Godot JSON numeric carrier initialization, exact bool/finite0-or1 validation and mutation isolation. No server or renderer acceptance."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_VISIBILITY_JSON_FIELDS ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
