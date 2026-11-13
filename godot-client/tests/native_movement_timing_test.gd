extends SceneTree
const Trace=preload("res://systems/native_data/movement_timing.gd")
const Keyboard=preload("res://systems/native_keyboard.gd")
var checks:=0
var calls: Array=[]
func expect(value: bool,reason: String) -> void:
	checks+=1
	if not value:push_error(reason);quit(1)
func predict(id: int,flags: int,heading: int) -> Dictionary:calls.append(["preview",id,flags,heading]);return {}
func end_prediction(id: int) -> void:calls.append(["stop",id])
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var keyboard:=Keyboard.new();root.add_child(keyboard);keyboard.set_process(false)
	var source: Dictionary={"lifetime":8,"position":Vector3(1,2,3),"render":Vector3(1.1,2,3),"orientation":Vector3(1,0,0),"animation":3}
	var current: Dictionary={"id":55,"identity":"1/2/55/8","state":source,"position":Vector3(1,2,3)}
	var before:=source.duplicate(true);var snapshot:=Trace.sample(current,keyboard,1,2,99)
	expect(snapshot.actorId==55 and snapshot.lifetime==8,"capture identity")
	expect(snapshot.state.received_position==[1.0,2.0,3.0],"received state distinguished")
	expect(snapshot.state.render==[source.render.x,source.render.y,source.render.z],"presentation state distinguished")
	expect(not snapshot.state.has("runRate"),"missing data stays missing")
	snapshot.state.position[0]=100;expect(source==before,"detached capture cannot mutate state")
	var request: Dictionary={"actorId":55,"lifetime":8,"requestId":1,"operation":"drive","flags":3,"heading":900,"transmit":true,"position":[500,500]}
	expect(Trace.replay(request,current,keyboard,predict,end_prediction).accepted,"drive replay accepted")
	expect(calls==[["preview",55,3,900]],"ordinary prediction called without pose overwrite")
	expect(source==before,"received/presentation input never overwritten by trace")
	expect(keyboard.moving and keyboard.request_serial==1,"ack owner established")
	expect(not Trace.replay(request,current,keyboard,predict,end_prediction).accepted,"duplicate request rejected")
	request.requestId=2;request.lifetime=9;expect(not Trace.replay(request,current,keyboard,predict,end_prediction).accepted,"retired lifetime rejected")
	request.lifetime=8;request.actorId=56;expect(not Trace.replay(request,current,keyboard,predict,end_prediction).accepted,"different actor rejected")
	request.actorId=55;request.transmit=false;expect(Trace.replay(request,current,keyboard,predict,end_prediction).accepted,"local preview tick accepted")
	expect(calls[-1]==["preview",55,3,-1],"nontransmitted refresh preserves heading")
	request.requestId=3;request.operation="turn";request.movementTrace={"keyboard":{"flags":16}}
	expect(Trace.replay(request,current,keyboard,predict,end_prediction).accepted,"turn decision accepted")
	expect(calls[-1]==["preview",55,16,-1],"turn through ordinary planner")
	request.requestId=4;request.movementTrace={};expect(not Trace.replay(request,current,keyboard,predict,end_prediction).accepted,"missing turn data rejected")
	request.operation="stop";expect(Trace.replay(request,current,keyboard,predict,end_prediction).accepted,"stop replay accepted")
	expect(calls[-1]==["stop",55] and not keyboard.moving,"ordinary stop without transmission")
	expect(not Trace.replay(request,{},keyboard,predict,end_prediction).accepted,"transition/unadmitted input rejected")
	keyboard.free();print(JSON.stringify({"success":true,"checks":checks,"server_connections":0}));quit(0)
