extends "res://tests/native_perf140_particle_census_test.gd"
const ColdGroup=preload("res://systems/native_render/particle_stream_group.gd")
class Metadata extends Node3D:
	var origin_resource:="fixture_particle_model"
	var physical_part:=23
	var source_path:=NodePath("..")
func reentrant_cold_case() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var node:=Node3D.new();scene.add_child(node)
	var seed_owner:=make_owner(false,"fountain",32|128|16,false,false)
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed_owner.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":scene.get_instance_id()},{}).has("error"),"Reentrant cold fixture configures")
	seed_owner.providers.clear()
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var bridge:=ColdGroup.new();bridge.native=presentation
	var observed:={"rejected":false}
	var services:={"random":func():return 1,"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass}
	check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":services,"culling":false,"clock":func():
		observed.rejected=bridge.cold_particle_census().has("error")
		return {"clip":"","time":0.0}
	}).has("error"),"Reentrant cold fixture registers")
	check(not presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(17000000,false)}).has("error") and observed.rejected,"Native cold census rejects a running frame without disrupting its clock")
	bridge.running=true;check(bridge.cold_particle_census().has("error"),"GD cold wrapper rejects its own running frame")
	bridge.running=false;presentation.call("dispatch",5,{});services.clear();bridge.native=null;bridge.free();presentation=null;owner=null;scene.free()
func _init() -> void:
	experiment_mode="direct_animating"
	experiment_scope="Explicit cold scalar census and weak metadata join, with mutation isolation/no state or RNG advancement, plus existing profile partitions/all-off-on native oracle. No automatic export, per-frame census scan, graphical or FPS acceptance."
func finish_experiment(groups: Array) -> void:
	super.finish_experiment(groups)
	reentrant_cold_case()
	for group: Dictionary in groups:
		var before: Array=[]
		for owner: RefCounted in group.owners:before.append(owner.call("dispatch",2,{},{}))
		var draws: int=group.rng.draws
		var bridge:=ColdGroup.new();bridge.native=group.presentation
		for node: Node3D in group.nodes:
			node.set_script(Metadata)
			bridge.members[node.get_instance_id()]={"emitter":weakref(node)}
		var dump: Dictionary=bridge.cold_particle_census()
		check(not dump.has("error") and dump.emitters.size()==5,"Cold export contains every native and fallback member")
		var native_count:=0
		for row: Dictionary in dump.emitters:
			check(row.metadata_available and row.origin_resource=="fixture_particle_model" and row.physical_part==23 and row.source_path==".." and row.node_path!=null,"Cold metadata uses existing weak members")
			if not row.native:
				check(not row.has("active") and not row.has("birth_rate"),"Fallback does not invent native emitter state")
				continue
			native_count+=1
			check(row.source_id==group.source.get_instance_id() and row.pose_id==row.id,"Cold lifetime identities match the registered owner")
			check(row.kind in [0,1,2] and row.active>=0 and row.free>=0 and row.clip_count>=0 and row.all_channel_count>=0,"Cold native classification is bounded")
			check(row.selected_cached_count<=row.selected_constant_count and row.selected_constant_count<=row.selected_channel_count,"Cold channel categories are consistent")
			row.birth_rate=99999.0
		check(native_count==4,"Cold export separates owned and fallback records")
		var again: Dictionary=bridge.cold_particle_census()
		check(again.emitters.all(func(row):return not row.native or row.birth_rate!=99999.0),"Mutating exported rows cannot change native emitter fields")
		bridge.members.erase(group.nodes[0].get_instance_id())
		var missing: Dictionary=bridge.cold_particle_census()
		check(not missing.emitters[0].metadata_available and missing.emitters[0].origin_resource==null,"Unavailable weak metadata stays explicit")
		check(group.rng.draws==draws,"Cold export never advances shared RNG")
		for index in group.owners.size():check(same(before[index],group.owners[index].call("dispatch",2,{},{})).is_empty(),"Cold export does not mutate native simulation state")
		bridge.native=null;bridge.free()
