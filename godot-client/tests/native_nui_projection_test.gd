extends SceneTree
const State=preload("res://systems/native_data/nui_state.gd")
const Projector=preload("res://systems/native_data/nui_projector.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var state:=State.new(); var projector:=Projector.new()
	check(not State.equal(2,State.UNDEFINED) and not State.equal(State.UNDEFINED,false),"Missing bindings compare safely with numeric and boolean choices")
	check(State.equal(2,2.0) and not State.equal(1,true),"Wire numeric values match their controls without boolean coercion")
	state.receive({"kind":"nui-create","token":1,"nativeSerial":27,"format":0,"resref":"auth_jui"})
	check(not state.windows[1].ready and int(state.windows[1].serial)==27,"Resource-backed window waits for native JUI while preserving the wire serial")
	var initial:=["first","second"]; state.receive({"kind":"nui-binds","updates":[{"token":1,"bind":"names","value":initial}]}); initial[0]="changed outside"
	check(state.windows[1].bindings.names[0]=="first","Incoming binding arrays are copied rather than aliased")
	var layout:={"title":"Authored native projection","geometry":{"x":20,"y":30,"w":400,"h":300},"root":{"type":"col","children":[{"type":"combo","id":"choice","value":{"bind":"missing"},"elements":[["First",10],["Second",20]]},{"type":"list","id":"large","row_count":1000000,"row_template":[[{"type":"check","id":"cell","value":{"bind":"checks"}},100,false]]}]}}
	state.windows[1].layout=layout; state.windows[1].ready=true
	var record:={"id":4,"controls":{},"ranges":{},"acks":{}}; var result:=projector.project(state.windows[1],record)
	check(not result.is_empty() and projector.failure.is_empty(),"Missing choice values and dictionary geometry project without type errors")
	check(int(result.nodes[1].values.selected)==-1,"Unreceived choice is unselected rather than invented")
	check(result.nodes.size()==35 and int(result.nodes[2].values.row_count)==1000000,"Million-row list creates only its bounded visible controls")
	check(result.frame.geometry==layout.geometry and not is_same(record.geometry_source,layout.geometry),"Geometry source retains an independent copy for local drag ownership")
	var original_ids: Array=record.controls.keys(); result=projector.project(state.windows[1],record)
	check(record.controls.keys()==original_ids,"Binding-only projection retains native control identities")
	record.ranges["root/1"]={"start":150,"count":8}; result=projector.project(state.windows[1],record)
	check(result.nodes.size()==11 and int(result.nodes[3].index)==150,"Virtual range changes create the requested distant server rows")
	state.local_bind(1,"geometry",{"x":99}); check(state.windows[1].bindings.geometry.x==99,"Native binding updates remain connection-owned")
	state.receive({"kind":"nui-create","token":1,"nativeSerial":28,"format":1,"layout":{"root":{"type":"label","value":"replacement"}}})
	check(int(state.windows[1].serial)==28 and state.windows[1].bindings.is_empty(),"Reused server token replaces the old window and its bindings")
	state.receive({"kind":"nui-destroy","token":1}); check(state.windows.is_empty(),"Server destroy releases the native window state")
	var invalid:={"token":2,"serial":29,"version":9,"ready":true,"layout":{"root":{"type":"unsupported"}},"bindings":{},"layouts":{}}
	check(projector.project(invalid,{"id":5,"controls":{},"ranges":{},"acks":{}}).is_empty() and not projector.failure.is_empty(),"Unsupported NUI layouts fail explicitly")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Native regressions for observed missing-value/copying failures, JUI ownership and bounded virtualization"}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
