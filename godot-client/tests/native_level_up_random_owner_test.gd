extends SceneTree
const RandomStream=preload("res://systems/native_data/native_client_random.gd")
const Owner=preload("res://systems/native_data/level_up_hit_die_owner.gd")
var checks:=0
var failures: Array=[]
var worker_answer: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
func snapshot(total: int=4) -> Dictionary:return {"ready":true,"source":{"current":0,"classes":[{"id":0,"level":total}],"owned":[],"selected":[]}}
func tables(die: int=8,threshold: int=3) -> Dictionary:return {"classes":{"orderedRows":[{"HitDie":str(die)}]},"ruleset":{"orderedRows":[{"Label":"MIN_LEVEL_FOR_MAX_HP","Value":str(threshold)}]}}
func reject_worker(stream) -> void:worker_answer={"take":stream.take(),"application":RandomStream.acquire(),"seed":stream.seed_once(19)}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.get("binarySha256")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.get("rows",[]).size()==192,"Existing unchanged original die/CRT oracle is identified")
	var scope: Array=[501,7,42,61];var ticket: Array=scope+[1,"summary"]
	for at in oracle.get("rows",[]).size():
		var row: Dictionary=oracle.rows[at];var input: Dictionary=row.case;var stream:=RandomStream.new();var owner:=Owner.new();var active:=tables(int(input.die),int(input.threshold));var copied:=snapshot(int(input.total));var original:=copied.duplicate(true);var flags:={"forceMaximum":bool(input.forceMaximum),"hideHitPointGain":false}
		check(stream.seed_once(int(input.seed)) and owner.begin(scope,stream),"Independent explicit-seed owner prepares original case "+str(at))
		var result:=owner.roll(ticket,copied,active,flags)
		check(not result.ready if row.undefinedDivision else result.ready and int(result.value)==int(row.value),"Original signed die/division/BYTE result "+str(at),result)
		check(stream.state==int(row.seedAfter) and stream.draws==int(row.randomCalls) and int(result.get("randomCalls",0))==int(row.randomCalls),"Exact original DWORD state/consumption including forced/undefined cases "+str(at),result)
		var count:=stream.draws;var repeat:=owner.roll(ticket,copied,active,flags)
		check(repeat==result and stream.draws==count and copied==original,"Duplicate Summary preparation reuses its result without redraw/received mutation "+str(at))
	var stream:=RandomStream.new();check(stream.seed_once(1) and not stream.seed_once(99),"A seeded stream cannot reseed itself")
	var owner:=Owner.new();check(owner.begin(scope,stream),"One draft binds the application stream without resetting it")
	var flags:={"forceMaximum":false,"hideHitPointGain":false};var active:=tables();var copied:=snapshot();var roll:=owner.roll(ticket,copied,active,flags);var first_seed:=stream.state
	check(roll.ready and roll.hitDie>=4 and roll.hitDie<=8 and stream.draws==1 and not roll.serverAcknowledged,"Normal die8 proposal has the original half-to-full range and is not an ACK")
	check(not owner.roll(scope+[0,"summary"],copied,active,flags).ready and not owner.roll([501,7,42,60,2,"summary"],copied,active,flags).ready and stream.draws==1,"Retired/foreign Summary callbacks cannot consume randomness")
	var changed:=flags.duplicate();changed.forceMaximum=true
	check(not owner.roll(ticket,copied,active,changed).ready and not owner.current(ticket,copied,active,changed) and stream.draws==1,"Changed received flags cannot reroll/overwrite a current Summary")
	check(not owner.roll(ticket,copied,tables(12),flags).ready and stream.draws==1,"Changed active die metadata cannot replace a prepared roll")
	check(not owner.roll(scope+[2,"summary"],copied,active,{"hideHitPointGain":false}).ready and stream.draws==1,"Missing received maximum flag stays unavailable without consuming a draw")
	var next:=owner.roll(scope+[2,"summary"],copied,active,changed)
	check(next.ready and next.hitDie==8 and stream.draws==2 and stream.state!=first_seed,"Genuine next Summary entry consumes a new value before forced maximum")
	var before_cancel:=stream.state;owner.retire()
	check(not owner.roll(ticket,copied,active,flags).ready and stream.state==before_cancel and stream.draws==2,"Cancel retires entry ownership without rewinding the shared sequence")
	check(owner.begin([501,7,42,62],stream) and owner.roll([501,7,42,62,1,"summary"],copied,active,flags).ready and stream.draws==3,"A new draft shares the advanced sequence rather than its own seed")
	var before_worker:=stream.state;var task:=WorkerThreadPool.add_task(reject_worker.bind(stream))
	while not WorkerThreadPool.is_task_completed(task):await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	check(not worker_answer.take.ready and worker_answer.application==null and not worker_answer.seed and stream.state==before_worker and stream.draws==3,"Actual worker cannot acquire, consume or reseed the main-thread application stream")
	var first=RandomStream.acquire();var second=RandomStream.acquire()
	check(is_same(first.data,second.data) and first.seed_kind=="godot_application_uptime_msec" and first.initialized and not second.seed_once(1),"Separate native handles share once-seeded app-lifetime primitive state")
	var count: int=first.draws;var value: Dictionary=first.take();var third=RandomStream.acquire()
	check(value.ready and second.state==value.seedAfter and third.state==value.seedAfter and third.draws==count+1,"Reacquiring controllers does not restore or reseed application state")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":oracle.rows.size(),"serverConnections":0,"gpu":false,"scope":"NEW native app-lifetime random state and per-Summary receipt; exact192 unchanged original arithmetic/state/call cases, one-shot/reentry/cancel/fresh draft/flags/rules and actual worker rejection. Explicit separate test seeds; no runtime hooks, game/server/pixel acceptance."};file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
