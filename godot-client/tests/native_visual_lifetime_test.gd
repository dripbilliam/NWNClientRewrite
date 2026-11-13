extends SceneTree
const Effects=preload("res://systems/native_render/effect_world.gd")
var checks:=0
var failures: Array=[]
class World extends Node3D:
	var desired: Dictionary={}
	var installed: Dictionary={}
	var instances: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var world:=World.new(); root.add_child(world)
	var actor:=Node3D.new(); world.add_child(actor); world.desired[1]={"object":{"nativeLifetime":10},"key":"new-appearance"}; world.instances[1]=actor; world.installed[1]="old-appearance"
	var effects:=Effects.new(); root.add_child(effects); effects.set_process(false); effects.world=world; effects.client=effects
	for name in ["visualeffects","progfx","appearance"]: effects.tables[name]={"orderedRows":[]}
	check(effects.tables_ready(),"All required effect dependencies enable delivery")
	for name in ["ruleset","racialtypes","classes"]: effects.tables[name]={"orderedRows":[]}
	check(effects.tables_ready(),"Unrelated shared rules tables cannot stall already-ready visual delivery")
	effects.tables.erase("progfx")
	check(not effects.tables_ready(),"Extra tables cannot conceal a missing effect dependency")
	effects.reserve(1,10,{"visualId":1,"sourceId":0x7f000000},false)
	var entry: Dictionary=effects.entries[1]
	check(effects._bound(entry) and effects.host(1)==actor,"Existing effects retain the source while its new appearance streams")
	check(effects.descriptor(1).is_empty(),"New effect definitions wait for the actual current appearance")
	world.instances.erase(1)
	check(effects._bound(entry) and effects.host(1)==null,"Temporary render absence preserves canonical effect lifetime")
	world.desired[1].object.nativeLifetime=11
	check(not effects._bound(entry),"Recycled IDs cannot retain an old source effect")
	world.desired.erase(1)
	check(not effects._bound(entry),"Canonical removal retires effects even before model admission")
	effects._forget(1,"retired"); check(effects.records.is_empty() and effects.entries.is_empty(),"Retirement releases pending definitions and physical entries together")
	effects.receive_raw({"serial":1,"events":[{"id":1,"lifetime":10,"kind":"loop","changes":[]}]}); effects.receive_raw({"serial":1,"events":[{"id":1,"lifetime":10,"kind":"loop","changes":[]}]})
	check(effects.queue.size()==1 and effects.delivery.stale==1,"Duplicate raw frames cannot duplicate the effect list")
	effects.close(); check(effects.queue.is_empty() and effects.records.is_empty(),"Close drops deferred raw work and effect data")
	effects.free(); world.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Authored native effect model/canonical lifetime boundaries; real server expiry and rendering verified separately"},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
