extends SceneTree
const Inspector=preload("res://systems/native_entity_inspector.gd")
class World extends Node3D:
	var generation:=4
	var area_id:=40
	var controlled_id:=7
	var closed:=false
	var retiring:=false
	var desired: Dictionary={}
	var instances: Dictionary={}
	var installed: Dictionary={}
	var hidden: Dictionary={}
	var failed_objects: Dictionary={}
	var batches: Array=[]
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func source(id: int,area: int) -> Dictionary:
	return {"id":id,"objectType":5,"areaId":area,"nativeLifetime":3,"replicated":{},"name":"Player %s"%id}
func run() -> void:
	var world:=World.new();root.add_child(world)
	var known:={7:source(7,40),8:source(8,40),9:source(9,41)}
	world.desired[8]={"object":known[8],"key":"known-model"}
	var scope:={"world":world,"generation":4,"connection":2,"known_objects":known}
	var inspector:=Inspector.new();root.add_child(inspector)
	inspector.setup(func():return scope,func(value):return value.name,"","")
	inspector.refresh_entities()
	check(inspector.ids==[7,8],"Client-known current-area player remains selectable before render admission")
	inspector.select_entity(0);var value:=inspector.selected_snapshot()
	check(not value.has("error") and value.admission=="not_in_render_desired" and not value.rendered,"Unknown model admission is distinguished from absent network delivery")
	check(not value.received_source.replicated.has("position"),"Unavailable received position stays absent rather than zero")
	var trace: Dictionary=value.visibility_trace.records[0]
	check(trace.known_received.available and trace.known_received.value and not trace.known_in_current_desired,"Cold trace identifies canonical delivery separately from desired-model registry")
	check(not trace.received.position.available and not trace.instance_present,"No visual instance or unavailable coordinates are invented")
	value.received_source.nativeLifetime=99
	check(known[7].nativeLifetime==3,"Inspection returns detached received data")
	known[7].nativeLifetime=4
	check(inspector.selected_snapshot().get("error","").contains("lifetime changed"),"Selected old reference cannot silently inspect same-ID replacement")
	inspector.refresh_entities();inspector.select_entity(0)
	check(inspector.selected_snapshot().received_source.nativeLifetime==4,"Explicit refresh admits replacement lifetime")
	known.erase(7)
	check(inspector.selected_snapshot().has("error"),"Canonical removal invalidates selection even if renderer still has stale data")
	scope.generation=5
	check(inspector.selected_snapshot().get("error","").contains("World changed"),"Area generation retirement invalidates old inspection")
	inspector.free();world.free();await process_frame
	print("NATIVE_KNOWN_ENTITY_INSPECTOR ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
