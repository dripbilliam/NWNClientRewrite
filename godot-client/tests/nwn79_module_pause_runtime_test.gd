extends SceneTree

const Services=preload("res://systems/native_data/client_clock_services.gd")
const Decoder=preload("res://systems/native_data/native_network_module_pause.gd")
const WorldClock=preload("res://systems/native_data/world_timer.gd")

class Counter extends RefCounted:
	var value:=0
	var reads:=0
	func read()->Dictionary:
		var answer:=WorldClock.words_from_int(value)
		value+=1000
		reads+=1
		return answer

class Lower extends RefCounted:
	var calls: Array=[]
	func object(_id: int)->Variant:return null
	func as_object(value: Variant)->Variant:return value
	func scene(_value: Variant)->Variant:return null
	func scene_virtual(_value: Variant,_offset: int)->Variant:return {"ready":true}
	func reset_object(_value: Variant,_day: int,_time: int)->Dictionary:return {"ready":true}
	func text(id: int)->void:calls.append(["pauseText",id])
	func audio(on: bool)->void:calls.append(["audio",on])
	func lifecycle(_value: Dictionary)->Dictionary:return {"ready":true,"action":"unknown"}
	func callbacks()->Dictionary:
		return {"object":object,"asObject":as_object,"scene":scene,"sceneVirtual":scene_virtual,"resetObjectTimes":reset_object,"pauseText":text,"audio":audio,"acceptedLifecycle":lifecycle}

var failures: Array=[]
var checks:=0

func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)

func original_message(fixture: Dictionary,mask: int,value: int)->Dictionary:
	for row in fixture.cases:
		if not str(row.origin).begins_with("original native receiver"):continue
		if int(row.expected.mask)==mask and int(row.expected.value)==value:
			return Decoder.decode_packet(str(row.packet).hex_decode())
	return {"error":"Missing original receiver case."}

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_module_pause_fixture.json"))
	if not fixture is Dictionary or int(fixture.get("nativeReceiver",0))!=96:
		printerr("NWN79 module-pause runtime fixture unavailable")
		quit(1)
		return
	var pause: Dictionary=original_message(fixture,1,1)
	var unpause: Dictionary=original_message(fixture,1,0)
	check(not pause.has("error") and not unpause.has("error"),"original-receiver-pause-packets-decode")
	var service:=Services.new()
	var counter:=Counter.new()
	var lower:=Lower.new()
	var facts:={"processConstructionKnown":true,"gui":{"known":true,"value":null},"profileMode":0,"controlledId":0x80000005}
	check(service.construct_process(counter.read,facts,lower.callbacks()).ready,"construct-real-three-timers")
	check(service.attach_connection(7).ready and service.set_scope([7,3,20]).ready,"attach-and-scope")
	check(not service.receive_server_pause(pause,7,20,3).ready,"no-packet-before-frame-prefix")
	check(service.begin_frame(1).ready,"prefix-three-timers")
	var applied: Dictionary=service.receive_server_pause(pause,7,20,3)
	check(applied.ready and service.state_view().pause.flags==1 and applied.deliveryOrder==1,"original-pause-applies-clock-flags")
	var reads_before:=counter.reads
	var calls_before:=lower.calls.size()
	var repeated: Dictionary=service.receive_server_pause(pause,7,20,3)
	check(repeated.ready and repeated.duplicatePacket and repeated.changed==false and repeated.deliveryOrder==2,"duplicate-packet-delivered-but-clock-noop")
	check(counter.reads==reads_before and lower.calls.size()==calls_before,"duplicate-does-no-more-work")
	check(not service.receive_server_pause(unpause,8,20,3).ready and not service.receive_server_pause(unpause,7,21,3).ready and not service.receive_server_pause(unpause,7,20,2).ready,"stale-connection-area-generation-rejected")
	check(service.state_view().pause.flags==1,"stale-packets-preserve-flags")
	var released: Dictionary=service.receive_server_pause(unpause,7,20,3)
	check(released.ready and service.state_view().pause.flags==0 and released.deliveryOrder==3,"original-unpause-releases-clock-flags")
	check(lower.calls.has(["audio",true]) and lower.calls.has(["audio",false]),"audio-callbacks-on-pause-transitions")
	check(service.finish_ai(1,{"module":false,"area":false,"completePass":false}).ready,"finish-frame")
	var changed: Dictionary=service.set_scope([7,4,21],[],{"continuousHistory":true})
	check(changed.ready,"area-generation-advance")
	check(service.begin_frame(2).ready,"next-area-frame-prefix")
	check(not service.receive_server_pause(pause,7,20,3).ready,"old-area-packet-rejected-after-transfer")
	var new_area: Dictionary=service.receive_server_pause(pause,7,21,4)
	check(new_area.ready and not new_area.duplicatePacket and new_area.deliveryOrder==4,"new-area-packet-accepted-in-order")
	check(service.finish_ai(2,{"module":false,"area":false,"completePass":false}).ready,"finish-new-area-frame")
	check(service.cleanup_connection().ready and service.state_view().pause.flags==0,"cleanup-unpauses-before-detach")
	check(service.attach_connection(8).ready and service.set_scope([8,1,30]).ready,"reconnect-with-process-timers")
	check(service.begin_frame(3).ready,"reconnect-frame-prefix")
	check(not service.receive_server_pause(pause,7,21,4).ready,"prior-connection-packet-rejected")
	var reconnect: Dictionary=service.receive_server_pause(pause,8,30,1)
	check(reconnect.ready and reconnect.deliveryOrder==1 and not reconnect.duplicatePacket,"reconnect-restarts-packet-order")
	check(service.cleanup_connection().ready and service.destroy_process().ready,"ordered-final-cleanup")
	if failures.is_empty():print("NWN79 module-pause runtime PASS checks=",checks," original_receiver_packets=2")
	else:printerr("NWN79 module-pause runtime FAIL ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
