extends RefCounted
# A bounded numeric-only packet. The worker never reads a Node, viewport,
# rendering API, file, network, shared mutable profiler state or scene resource.
var result: Dictionary={}
static func calculate(rows: Array) -> Dictionary:
	var fields: Dictionary={}; var worst: Dictionary={}
	for row in rows:
		if float(row.wall_ms)>float(worst.get("wall_ms",-1)): worst=row
		for name in row:
			if not fields.has(name): fields[name]=[]
			fields[name].append(float(row[name]))
	var output: Dictionary={}
	for name in fields:
		var values: Array=fields[name]; var present:=values.size(); var total:=0.0
		for value in values: total+=value
		while values.size()<rows.size(): values.append(0.0)
		values.sort()
		output[name]={"mean":total/values.size(),"when_present_mean":total/present,"p95":values[mini(values.size()-1,ceili(values.size()*0.95)-1)],"max":values[-1],"samples":values.size(),"active_samples":present}
	return {"metrics":output,"worst_frame":worst.duplicate(),"frames":rows.size()}
func run(owned_rows: Array,generation: int) -> void:
	var began:=Time.get_ticks_usec()
	result=calculate(owned_rows)
	result.generation=generation; result.thread=OS.get_thread_caller_id()
	# Release the copied window here, including rows evicted while we worked.
	# Completion polling later frees only an empty bound argument on main.
	owned_rows.clear()
	result.worker_ms=(Time.get_ticks_usec()-began)/1000.0
