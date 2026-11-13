extends SceneTree
const Work=preload("res://systems/native_data/character_picker_work.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func wait_for(worker) -> void:
	var end:=Time.get_ticks_msec()+10000
	while (worker.task>=0 or not worker.pending.is_empty()) and Time.get_ticks_msec()<end: await process_frame
	check(worker.task<0 and worker.pending.is_empty(),"Owned latest-only projection tasks terminate")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var rules:={"orderedRows":[{"LABEL":"Mixed","VALUE":"12"},{"Label":"Mixed","Value":"****"},{"Label":"Mixed","Value":"  -7tail"},{"Label":"mixed","Value":"5"},{"Label":"Hex","Value":"0x12"},{"Label":"Bad","Value":"words"},{"Label":"Wrap","Value":"4294967295"},{"Label":"Plus","Value":" +3"}]}
	var tables:={"ruleset":rules}; var indexed: Dictionary=tables.duplicate(); indexed._native_resolved_ruleset=Values.resolved_ruleset(tables)
	for label in ["Mixed","mixed","MIXED","Hex","Bad","Wrap","Plus","Absent"]:
		for fallback in [-5,0,3,200]: check(Values.cfg(tables,label,fallback)==Values.cfg(indexed,label,fallback),"Detached native cache preserves last/nonempty/exact-label/atoi/overflow/fallback: "+label)
	if args.has("oracle"):
		var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
		for row in oracle.rows:
			var entries: Array=[]
			for key in row.rules: entries.append({"Label":key,"Value":str(row.rules[key])})
			var original_tables:={"ruleset":{"orderedRows":entries}}; original_tables._native_resolved_ruleset=Values.resolved_ruleset(original_tables)
			check(Values.modifier(int(row.score),original_tables)==int(row.modifier),"Indexed ability projection matches unchanged original instruction oracle")
	var worker:=Work.new(); root.add_child(worker); var events: Array=[]; worker.completed.connect(func():events.append(worker.wanted.duplicate(true)))
	var source:={"skillSource":{"classes":[],"abilities":{},"ranks":[]}}
	check(worker.observe([1,1,"first"],source,{},0),"A received source schedules native display work")
	worker.observe([1,1,"second"],source,{},0); worker.observe([1,1,"third"],source,{},0)
	check(worker.task>=0 and worker.pending.identity[0]==[1,1,"third"] and worker.stats.coalesced==1,"One running and one latest pending selection bound rapid changes")
	source.skillSource.ranks.append(99); await wait_for(worker)
	check(events.size()==1 and events[0][0]==[1,1,"third"] and events[0][2].skillSource.ranks.is_empty(),"Only latest selection publishes and source mutation cannot alter captured input")
	check(worker.stats.stale==1 and worker.stats.submitted==2,"Superseded active work is retired rather than publishing stale details")
	var accepted: int=worker.stats.accepted; worker.observe([2,1,"third"],source,{},0); worker.retire(); await wait_for(worker)
	check(worker.result.is_empty() and worker.stats.accepted==accepted,"Disconnect retirement prevents a completed old-connection result")
	worker.observe([3,1,"third"],source,{},0); worker.observe([3,2,"third"],source,{},0); await wait_for(worker)
	check(worker.wanted[0]==[3,2,"third"] and events.back()[0]==[3,2,"third"],"Data-owner generation changes cannot reuse preceding server/override scope")
	var mutable:={"classes":{"orderedRows":[]},"ruleset":{"orderedRows":[{"Label":"Test","Value":"4"}]}}
	worker.observe([4,1,"third"],source,mutable,0); mutable.ruleset.orderedRows[0].Value="8"
	check(worker.active.tables.ruleset.orderedRows[0].Value=="4","Worker reads detached selected-table dictionaries")
	await wait_for(worker); var count: int=worker.stats.submitted
	check(not worker.observe([4,1,"third"],source,mutable,0) and worker.stats.submitted==count,"Unchanged identity/source/revision cannot repeat projection work")
	worker.observe([4,1,"third"],source,mutable,1)
	check(worker.active.tables.ruleset.orderedRows[0].Value=="8","A new publication revision refreshes even the same source table object")
	await wait_for(worker); worker.observe([4,1,"third"],null,mutable,1)
	check(worker.result.is_empty() and worker.pending.is_empty(),"Missing preview clears projections explicitly without fabricated statistics")
	worker.close(); check(worker.snapshot().closed and not worker.snapshot().running,"Close joins only its owned worker and clears retained input"); worker.free(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"gpuBenchmark":false},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
