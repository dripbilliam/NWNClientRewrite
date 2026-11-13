extends SceneTree
# SOURCE ONLY until Root grants a headless lane. No assets/server/GPU/native DLL.
const Ordinary=preload("res://systems/native_render/placeable_lights.gd")
const Candidate=preload("res://tools/perf140/particles/placeable_light_plan_cache_candidate.gd")
class TestWorld extends Node3D:
	signal instance_ready(id,source,instance)
	signal instance_removed(id)
	var area_id:=99
	var instances: Dictionary={}
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func light_object(id: int=2) -> Dictionary:
	return {"id":id,"areaId":99,"objectType":9,"replicated":{"lightOn":true,"position":[4,5,6],"orientation":[0,1,0],"appearance":0}}
func run() -> void:
	var world:=TestWorld.new();root.add_child(world)
	var ordinary:=Ordinary.new();var candidate:=Candidate.new()
	ordinary.world=world;candidate.world=world
	# Do not add either manager to the tree: their original _process would
	# install real models. This fixture tests only pure plans/unchanged dirty.
	var definition: Dictionary={"orderedRows":[{"LightColor":"0","LightOffsetX":"1","LightOffsetY":"2","LightOffsetZ":"3"}]}
	var colours: Dictionary={"orderedRows":[{"RED":"1","GREEN":"0.5","BLUE":"0.25"}]}
	for owner in [ordinary,candidate]:
		owner.tables={"placeables":definition,"lightcolor":colours}
		owner.receive_area([{"id":1,"appearance":0,"position":[1,2,3]}])
		owner.receive([light_object()])
	check(candidate.plans()==ordinary.plans(),"First pure plans are exact")
	var misses: int=candidate.plan_cache_stats.misses
	check(candidate.plans()==ordinary.plans() and candidate.plan_cache_stats.hits==1,"Second exact plan reuses pure output")
	for owner in [ordinary,candidate]:owner.dirty=false;owner.receive([{"id":5,"areaId":99,"objectType":5}])
	check(ordinary.dirty and candidate.dirty,"Unrelated receive preserves original dirty/wake")
	check(candidate.plans()==ordinary.plans() and candidate.plan_cache_stats.misses==misses,"Unrelated actor update reuses plan without skipping apply boundary")
	# Shared alias mutation is caught at the next original plans boundary.
	candidate.objects[2].replicated.position[0]=12;ordinary.objects[2].replicated.position[0]=12
	check(candidate.plans()==ordinary.plans() and candidate.plan_cache_stats.misses==misses+1,"In-place position mutation invalidates")
	for owner in [ordinary,candidate]:owner.receive([{"id":2,"areaId":99,"objectType":9,"replicated":{"lightOn":false}}])
	check(candidate.plans()==ordinary.plans() and not candidate.plans().has(2),"Light off removes dynamic override")
	for owner in [ordinary,candidate]:owner.receive([light_object()]);owner.receive([], [2])
	check(candidate.plans()==ordinary.plans(),"Explicit removal retains area list semantics")
	for owner in [ordinary,candidate]:owner.receive_area([{"id":1,"appearance":0,"position":[7,8,9]}])
	check(candidate.plans()==ordinary.plans(),"Area list change invalidates")
	for owner in [ordinary,candidate]:owner.receive_area([{"id":1,"appearance":0,"position":[0.0,8,9]}])
	check(var_to_bytes(candidate.plans())==var_to_bytes(ordinary.plans()),"Positive-zero authored position bytes match")
	var zero_misses: int=candidate.plan_cache_stats.misses
	# receive_area itself has Variant-equality admission. Mutate the manager's
	# stored value here to test a real different pure-plan input, independently
	# of whether that original admission accepts a signed-zero-only republish.
	for owner in [ordinary,candidate]:owner.area_records[1].position[0]=-0.0
	check(var_to_bytes(candidate.plans())==var_to_bytes(ordinary.plans()) and candidate.plan_cache_stats.misses==zero_misses+1,"Signed-zero numeric equality cannot hide a plan change")
	for owner in [ordinary,candidate]:
		owner.tables.placeables={"orderedRows":[{"LightColor":"0"},{"LightColor":"0","LightOffsetX":"9"}]}
		owner.receive_area([{"id":1,"appearance":9007199254740993,"position":[7,8,9]}])
	check(var_to_bytes(candidate.plans())==var_to_bytes(ordinary.plans()) and candidate.plans()[1].appearance==1,"Int64 appearance masking keeps its low bits")
	var integer_misses: int=candidate.plan_cache_stats.misses
	for owner in [ordinary,candidate]:owner.area_records[1].appearance=9007199254740992.0
	check(var_to_bytes(candidate.plans())==var_to_bytes(ordinary.plans()) and candidate.plan_cache_stats.misses==integer_misses+1 and candidate.plans()[1].appearance==0,"Rounded float appearance cannot alias int64 witness")
	var prior_extra_fallback: int=candidate.plan_cache_stats.fallbacks
	for owner in [ordinary,candidate]:owner.receive_area([{"id":1,"appearance":0,"position":[7,8,9,77]}])
	check(candidate.plans()==ordinary.plans() and candidate.plans()[1].position.size()==4 and candidate.plan_cache_stats.fallbacks>prior_extra_fallback,"Extra authored position fields retain original complete Array")
	for owner in [ordinary,candidate]:owner.receive_area([{"id":1,"appearance":0,"position":[7,8,9]}])
	for owner in [ordinary,candidate]:owner.receive([],[],true)
	check(candidate.plans()==ordinary.plans(),"Full object reset preserves authored area lights")
	# Canonical table completion invalidates even when source identity is reused.
	for owner in [ordinary,candidate]:owner.requests[11]="lightcolor";owner.prepared(11,{"error":"","value":{"orderedRows":[{"RED":"0.2","GREEN":"0.3","BLUE":"0.4"}]}})
	check(candidate.plans()==ordinary.plans(),"Canonical table publication invalidates")
	var prior_fallback: int=candidate.plan_cache_stats.fallbacks
	for owner in [ordinary,candidate]:owner.receive([{"id":3,"areaId":99,"objectType":9,"replicated":{"lightOn":true}}])
	check(candidate.plans()==ordinary.plans() and candidate.plan_cache_stats.fallbacks==prior_fallback+1,"Unavailable position uses original live fallback")
	# Source-only token checks do not call the original nonfinite conversion.
	check(not Candidate._number_input(INF) and not Candidate._number_input(-INF) and not Candidate._number_input(NAN),"Nonfinite numeric inputs never enroll")
	var cold: Dictionary=candidate.snapshot()
	check(cold.plan_cache.enabled and cold.plan_cache.mode=="narrow-typed-plan-witness-v1" and cold.plan_cache.stats.hits>0,"Existing cold snapshot identifies actual candidate and cumulative reuse")
	var live_hits: int=candidate.plan_cache_stats.hits
	cold.plan_cache.stats.hits=-999
	check(candidate.plan_cache_stats.hits==live_hits,"Cold counters are detached from candidate state")
	for owner in [ordinary,candidate]:owner.close();owner.free()
	world.free()
	print("NATIVE_PERF140_PARTICLE_LIGHT_PLANS ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
