extends SceneTree
const Art=preload("res://systems/native_ui_art.gd")
class Catalog extends RefCounted:
	func raster_location(name: String) -> Dictionary:return {} if name=="missing" else {"type":3}
class Assets extends Node:
	var failure:=""
	var serial:=0
	var pending: Array=[]
	var calls: Array=[]
	func request(name: String,_type: int,_decoder: String) -> int:
		failure=""
		if pending.size()>=1:failure="Native asset queue is full";return -1
		serial+=1;pending.append(serial);calls.append(name);return serial
	func close() -> void:pending.clear()
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var art:=Art.new();root.add_child(art);art.catalog=Catalog.new();art.assets=Assets.new();art.add_child(art.assets)
	var first:=TextureRect.new();root.add_child(first);var second:=TextureRect.new();root.add_child(second);var third:=TextureRect.new();root.add_child(third)
	art.bind(first,"busy");art.unbind(first);art.bind(first,"busy")
	check(art.assets.calls==["busy"] and art.bitmap_jobs.size()==1,"Revisiting an admitted bitmap joins its existing read after final listener retirement")
	art.bind(second,"skipped");art.bind(third,"skipped")
	check(art.assets.calls==["busy"] and art.deferred.size()==1 and art.waiting.skipped.size()==2,"One deferred resource coalesces its independent current targets")
	check(art.failed.is_empty(),"Only transient capacity pressure is deferred")
	art.bind(second,"replacement")
	check(art.waiting.skipped.size()==1 and art.deferred.size()==2,"Rebind prunes only its own obsolete listener")
	art.unbind(third)
	check(not art.deferred.has("skipped") and not art.waiting.has("skipped"),"The last retired listener drops that deferred read")
	art.bind(third,"dead");third.free()
	art.assets.pending.clear();art.prepared(1,{"error":"Authoritative decoder failure"})
	check(art.failed.has("busy") and not art.deferred.has("replacement") and art.assets.calls==["busy","replacement"],"Completion frees one slot and admits a current deferred resource")
	check(not art.waiting.has("dead") and not art.deferred.has("dead") and not art.assets.calls.has("dead"),"A freed deferred target is pruned without reading its bitmap")
	art.bind(first,"missing")
	check(art.failed.has("missing") and not art.deferred.has("missing"),"A real resource lookup miss remains explicit, with no retry")
	art.bind(first,"busy")
	check(art.assets.calls==["busy","replacement"],"An authoritative decoder failure is not retried")
	art.bind(first,"after-close")
	check(art.deferred.has("after-close"),"A still-current target may await real capacity")
	art.close()
	check(art.bindings.is_empty() and art.waiting.is_empty() and art.deferred.is_empty() and art.binding_resources.is_empty() and art.bitmap_jobs.is_empty(),"Close retires deferred data and all weak target identities synchronously")
	art.bind(first,"late-after-close")
	check(art.deferred.is_empty() and art.waiting.is_empty() and art.assets.calls==["busy","replacement"],"Late callbacks cannot resurrect artwork after close")
	art.free();first.free();second.free();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Authored transient-admission classification, coalescing, rebind/freed-target pruning, explicit missing/decode failure, close and late callback guards. Actual installed raster coverage is the companion Portrait queue test."},"  "));file.close();quit(0 if failures.is_empty() else 1)
