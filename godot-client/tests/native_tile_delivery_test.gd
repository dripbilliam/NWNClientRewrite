extends SceneTree
const Delivery=preload("res://systems/native_render/tile_visibility_delivery.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func frame(serial: int,generation: int=2) -> Dictionary:
	return {"kind":"raw-tile-visibility","connection":9,"generation":generation,"areaId":22,"actorId":17,"lifetime":[["nativeLifetime",true,3],["disclosureLifetime",false,null]],"serial":serial,"change":{"mode":[true,false],"points":[{"x":1,"y":2}]}}
func _initialize() -> void:
	var delivery:=Delivery.new();delivery.reset(9)
	var original:=frame(1)
	check(delivery.push(original),"Fresh scoped event queues before world admission")
	original.change.points[0].x=99
	check(delivery.pending[0].frame.change.points[0].x==1,"Queued delivery is detached from producer mutation")
	check(not delivery.push(frame(1)),"Duplicate transport serial cannot replay native setters")
	check(delivery.push(frame(2)),"Repeated reset with new serial is preserved")
	delivery.drain(func(_value):return {"status":"wait"})
	check(delivery.pending.map(func(row):return row.frame.serial)==[1,2],"Waiting before area availability preserves reset order")
	var observed: Array=[]
	delivery.drain(func(value):observed.append(value.serial);return {"status":"accepted"})
	check(observed==[1,2] and delivery.pending.is_empty(),"State boundary delivers ordered events exactly once")
	delivery.push(frame(3));delivery.push(frame(4,3))
	delivery.drain(func(value):return {"status":"retired" if value.generation==2 else "wait"})
	check(delivery.pending.size()==1 and delivery.pending[0].frame.generation==3,"Transition retires stale area and preserves future-area delivery")
	delivery.drain(func(_value):delivery.push(frame(5,3));return {"status":"wait"})
	check(delivery.pending.map(func(row):return row.frame.serial)==[4,5],"Synchronous callback enqueue retains original ordering")
	delivery.reset(10)
	check(delivery.pending.is_empty() and not delivery.push(frame(6)),"Reconnect discards retired connection and rejects old wire frames")
	var missing:=frame(7);missing.connection=10;missing.lifetime[0]=["nativeLifetime",false,null]
	check(not delivery.push(missing),"Unavailable native identity cannot be fabricated for scope admission")
	delivery.close();check(not delivery.push(frame(8)) and delivery.pending.is_empty(),"Closed delivery owner cannot resurrect queued state")
	print("NATIVE_TILE_DELIVERY ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
