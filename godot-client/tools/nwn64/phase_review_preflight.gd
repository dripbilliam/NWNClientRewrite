extends "res://tools/nwn65/census_preflight.gd"
# Combined cheap parser/getter preflight. No original world or GPU/FPS run.
const Phase=preload("res://tools/nwn64/phase_review_census.gd")
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
class SampleNative extends RefCounted:
	var calls:=0
	var packet: Dictionary={"enabled":true,"coarse_phases":true,"stride":120,"min_members":0,"phase_success_samples":1,"errors":0,"excluded_detailed_samples":0,"records":[{"success":true,"phase_complete":true}]}
	func dispatch(operation: int,_input: Dictionary)->Dictionary:
		calls+=1
		return packet.duplicate(true) if operation==16 else {"error":"unexpected operation"}
class PhaseGroup extends Node:
	var members: Dictionary={1:{},2:{}}
	var fast_members:=2
	var native_surface_output:=true
	var native: RefCounted
class PhaseWorld extends Node:
	var area_id:=91
	var generation:=7
	var particle_stream_group: Node
func phase_contracts()->void:
	var world:=PhaseWorld.new();var group:=PhaseGroup.new();world.add_child(group);world.particle_stream_group=group
	var native:=SampleNative.new();group.native=native
	var before: Dictionary=native.packet.duplicate(true);var result: Dictionary=Phase.collect(world)
	check(result.success and result.members==2 and result.fast_members==2 and result.area_id==91,"Phase helper reads only final source/sampler census")
	check(native.calls==1 and native.packet==before,"Phase helper dispatches16 exactly once without altering sampler input")
	check(primitive(result),"Phase report contains primitive values only")
	native.packet.excluded_detailed_samples=1
	check(not Phase.collect(world).success,"Detailed native samples cannot be labelled normal")
	native.packet.excluded_detailed_samples=0;native.packet.min_members=1800
	check(not Phase.collect(world).success,"Wrong member threshold rejects diagnostic coverage")
	check(not Phase.collect(null).success,"Unavailable phase world is explicit")
	var weak:=weakref(native);group.native=null;native=null;world.free()
	check(weak.get_ref()==null,"Phase report retains no native or scene owner")
func run()->void:
	phase_contracts()
	super.run()
