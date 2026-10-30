extends SceneTree
const Keys=preload("res://systems/native_data/packed_animation_keys.gd")
var checks:=0
var failures: Array=[]
var mutex:=Mutex.new()
var worker_results: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func direct(data: Dictionary) -> bool:
	return ClassDB.class_call_static(&"NwnParticleKernel",&"animation_keys_valid",data.values,int(data.times),int(data.first),int(data.rows),int(data.components)*(3 if data.bezier else 1))
func worker(cases: Array) -> void:
	var passed:=true
	for repeat in 20:
		for data in cases:
			if direct(data)!=Keys.valid_gd(data): passed=false
	mutex.lock(); worker_results.append({"passed":passed,"thread":OS.get_thread_caller_id()}); mutex.unlock()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	check(Keys.native_available,"Compiled array validator is available before loader workers start")
	var cases: Array=[]; var random:=RandomNumberGenerator.new(); random.seed=923871
	for index in 120:
		var rows:=random.randi_range(1,30); var components:=random.randi_range(1,4); var bezier:=random.randi_range(0,1)==1
		var stride:=components*(3 if bezier else 1); var first:=rows+8; var values:=PackedFloat32Array(); values.resize(first+rows*stride+8)
		for offset in values.size(): values[offset]=random.randf_range(-100,100)
		for row in rows: values[row]=row*0.25
		var data:={"values":values,"times":0,"first":first,"rows":rows,"components":components,"bezier":bezier}; cases.append(data)
		var mutation:=data.duplicate(true)
		match index%6:
			0: mutation.values[0]=-1
			1: mutation.values[first]=INF
			2: mutation.values[first+rows*stride-1]=NAN
			3: mutation.values[rows-1]=-0.5
			4: mutation.first=values.size()
			5: mutation.values[-1]=NAN # Unused source bytes do not invalidate used keys.
		cases.append(mutation)
	for data in cases: check(direct(data)==Keys.valid_gd(data),"Native/reference finite/time/range agreement for authored case "+str(checks))
	var basic: Dictionary=cases[0]
	for field in ["times","first","rows","components"]:
		for value in [-1,1<<62]:
			var bad:=basic.duplicate(); bad[field]=value
			check(not direct(bad) and not Keys.valid_gd(bad),"Invalid/overflowing descriptor rejected: "+field+"="+str(value))
	var empty:=basic.duplicate(); empty.rows=0
	check(direct(empty) and Keys.valid_gd(empty),"Empty valid range needs no data read")
	var began:=Time.get_ticks_usec()
	for repeat in 8:
		for data in cases: direct(data)
	var compiled_ms:=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec()
	for repeat in 8:
		for data in cases: Keys.valid_gd(data)
	var gd_ms:=(Time.get_ticks_usec()-began)/1000.0
	var tasks: Array=[]
	for index in 4: tasks.append(WorkerThreadPool.add_task(worker.bind(cases)))
	while tasks.any(func(task):return not WorkerThreadPool.is_task_completed(task)): await process_frame
	for task in tasks: WorkerThreadPool.wait_for_task_completion(task)
	check(worker_results.size()==4 and worker_results.all(func(row):return row.passed and row.thread!=OS.get_main_thread_id()),"Concurrent loader workers validate shared immutable arrays without shared key/state mutation")
	check(cases[0].values[0]==0 and not is_nan(cases[0].values[-1]),"Validation and corruption cases do not mutate shared source arrays")
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"compiled_ms":compiled_ms,"gd_ms":gd_ms,"workers":worker_results,"publicConnections":0,"scope":"Native ABI, authored validation/corruption/range and concurrent read-only arithmetic versus GD reference; descriptive microbenchmark, not world/FPS acceptance"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
