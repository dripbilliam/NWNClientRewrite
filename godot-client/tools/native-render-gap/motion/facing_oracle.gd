extends SceneTree
const Base=preload("res://frozen_network_motion.gd")
const Candidate=preload("res://systems/network_motion.gd")
var checks:=0
var failed:=false
func check(value: bool,label: String)->void:
	checks+=1
	if not value and not failed:failed=true;push_error(label)
func compare(old: Vector3,target: Vector3,animation: int,dt: int,options: Dictionary,index: int)->void:
	var expected: Dictionary=Base.facing_step(old,target,animation,dt,options)
	var actual: Dictionary=Candidate.facing_step(old,target,animation,dt,options)
	check(var_to_bytes(expected)==var_to_bytes(actual),"Facing bit mismatch case "+str(index)+": "+str([old,target,animation,dt,options,expected,actual]))
func _initialize()->void:
	check(ClassDB.class_exists("NwnMotionNumeric"),"Numeric helper unavailable")
	check(Candidate.use_native_facing,"Candidate route not selected")
	var rng:=RandomNumberGenerator.new();rng.seed=70811331
	var animations: Array[int]=[0,1,2,3,4,53,54,80,81,82,83,65535]
	var vectors: Array[Vector3]=[Vector3.ZERO,Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,1,0),Vector3(0,-1,0),Vector3(-0.0,0.0,-0.0),Vector3(0.99,0.14106736,0),Vector3(0.707,0.707,0),Vector3(0,0,1),Vector3(0.00000001,0,0)]
	var index:=0
	for old in vectors:
		for target in vectors:
			for animation in animations:
				for dt in [0,1,7,16,33,100,1000]:
					compare(old,target,animation,dt,{"restored":index%2,"modelType":index%3,"model":index%5!=0},index);index+=1
	for iteration in 20000:
		var old:=Vector3(rng.randf_range(-2,2),rng.randf_range(-2,2),rng.randf_range(-1,1))
		if iteration%3==0:old=Base.normalized32(old)
		var target:=Vector3(rng.randf_range(-4,4),rng.randf_range(-4,4),rng.randf_range(-1,1))
		var options: Dictionary={} if iteration%5==0 else {"restored":iteration%2,"modelType":iteration%3,"model":iteration%7!=0}
		compare(old,target,animations[iteration%animations.size()],rng.randi_range(0,100),options,index);index+=1
	# Unsupported calls must execute the exact retained script body.
	for options in [{"restored":1.0},{"modelType":1.0},{"model":1},{"model":"yes"}]:
		compare(Vector3(1,0,0),Vector3(0,1,0),53,16,options,index);index+=1
	for dt in [-1,60001,1000000]:
		compare(Vector3(1,0,0),Vector3(0,1,0),4,dt,{},index);index+=1
	var stats: Dictionary=ClassDB.class_call_static("NwnMotionNumeric","inspect")
	check(int(stats.supported)>28000 and int(stats.calls)==index,"Actual numeric use/case count differs")
	print(JSON.stringify({"success":not failed,"checks":checks,"cases":index,"native":stats,"scope":"Bit-exact differential oracle against actual frozen NetworkMotion.facing_step, plus original fallback conversion domains; no FPS claim"}))
	quit(1 if failed else 0)
