extends SceneTree
const Runtime=preload("res://systems/visual_runtime.gd")
const Phases=preload("res://systems/visual_phases.gd")
class Manager extends Node3D:
	var target: Node3D
	var runtime
	var commands: Array=[]
	var diagnostics: Array=[]
	var mutate_counter:=false
	func host(id: int,_token: int=0) -> Node3D:return target if id==7 else null
	func diagnose(code: String,detail: String,_effect: int) -> void:diagnostics.append([code,detail])
	func alpha_commands(effect: int,id: int,token: int,value: Array) -> Dictionary:
		commands.append({"effect":effect,"id":id,"token":token,"commands":value.duplicate(true)})
		if mutate_counter:runtime.state.programRemainingCc=123
		return {"available":true}
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func program(period: int=0) -> Dictionary:
	return {"type":{"found":true,"value":5},"integer":{"param5":{"found":true,"value":period}},"float":{"param1":{"found":true,"value":0.5},"param2":{"found":true,"value":-1.0}}}
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var manager:=Manager.new();root.add_child(manager);manager.target=Node3D.new();manager.add_child(manager.target)
	var runtime:=Runtime.new();manager.add_child(runtime);manager.runtime=runtime
	var state:=Phases.constructor_state();state.target54=7;state.programsD0=[10,65535,65535];state.programPhaseFa=1;state.updateProgramD8=1
	check(state.alphaPhaseFb==0,"Alpha byte has original constructor value")
	check(runtime.configure(manager,1,{"state":state,"hosts":{"7":{"type":5}},"programs":{"10":program()},"visual":{"integer":{},"float":{},"string":{}}}),"Runtime accepts prepared program from existing definition")
	runtime._load_program(runtime.state,10)
	check(runtime.state.field104==0.5 and manager.commands.is_empty(),"Load stores minimum and does not publish")
	runtime._start_program(runtime.state,10)
	check(runtime.state.field100==0.5,"Start uses active data-defined minimum")
	check(manager.commands.size()==1 and manager.commands[0].id==7 and manager.commands[0].effect==1,"Renderer target and physical effect routed")
	check(manager.commands[0].commands.size()==1 and manager.commands[0].commands[0].kind=="set_alpha","Negative vector parameter preserves channel")
	runtime.state.programRemainingCc=42;runtime._update_program(runtime.state,10,16)
	check(runtime.state.programRemainingCc==42,"Constant alpha does not advance native program counter")
	runtime.definition.programs["10"]=program(500);runtime.state.programRemainingCc=100;manager.mutate_counter=true
	runtime._update_program(runtime.state,10,16);manager.mutate_counter=false
	check(runtime.state.programRemainingCc==139,"Post-publication delta uses counter mutated by callback")
	check(runtime.state.alphaPhaseFb==0 and is_equal_approx(runtime.state.field100,0.8),"Temporal state and renderer alpha share original clock calculation")
	runtime._stop_program(runtime.state,10)
	check(manager.commands.back().commands[0].alpha_word==1065353216,"Stop restores native alpha one")
	var count:=manager.commands.size();manager.target=null;runtime._update_program(runtime.state,10,20)
	check(manager.commands.size()==count,"Unavailable target publishes no invented actor state")
	check(manager.diagnostics.is_empty(),"Supported Type5 boundaries have no unsupported diagnosis")
	runtime.close();await process_frame;manager.free()
	print("NATIVE_VISUAL_ALPHA_RUNTIME ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
