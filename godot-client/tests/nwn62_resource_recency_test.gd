extends SceneTree
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var pool:=Pool.new();pool.maximum_materials=3
	for key in ["a","b","c"]:pool.retain("material",pool.materials,key,StandardMaterial3D.new(),3)
	var order=pool.resource_order.material
	check(order.size()==3 and order.first=="a" and order.last=="c","Initial LRU order follows insertion")
	for repeat in 1000:pool.touch("material","a")
	check(order.size()==3 and order.first=="b" and order.last=="a","Repeated hits keep one bounded recency link")
	pool.retain("material",pool.materials,"d",StandardMaterial3D.new(),3)
	check(not pool.materials.has("b") and pool.materials.has("a") and pool.materials.has("c") and pool.materials.has("d"),"Eviction removes the true oldest binding")
	check(order.size()==3 and order.first=="c" and order.last=="d" and int(pool.stats.material_evictions)==1,"Eviction updates links and count once")
	pool.touch("material","c");pool.retain("material",pool.materials,"e",StandardMaterial3D.new(),3)
	check(not pool.materials.has("a") and order.first=="d" and order.last=="e" and order.size()==3,"Middle and tail moves retain exact later eviction order")
	pool.clear()
	check(pool.materials.is_empty() and order.is_empty() and order.first==null and order.last==null,"World release clears all bindings and links")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual ResourcePool material LRU insertion, repeated hits, eviction and cleanup; untimed headless correctness only"}
	var file:=FileAccess.open("res://.cache/nwn62/checks/resource-recency-a.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
