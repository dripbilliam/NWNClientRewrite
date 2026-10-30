extends SceneTree
const Repeat=preload("res://systems/native_data/gui_repeat.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var clock:=Repeat.new()
	check(not clock.tick(1000000),"Inactive original GUI timer never delivers a callback")
	clock.begin(); check(not clock.tick(500000),"Original arrow delay uses a strict500000-microsecond threshold")
	check(clock.tick(1) and not clock.first,"First arrow repeat occurs only after the delay expires")
	check(not clock.tick(50000) and clock.tick(1),"Later arrow repeats use the strict50000-microsecond period")
	check(clock.tick(2000000) and clock.elapsed==0,"A long frame emits one callback and discards accumulated excess instead of a repeat burst")
	check(not clock.tick(0),"A stalled frame cannot leave replay callbacks queued")
	check(not clock.tick(1000000,false) and clock.tick(0,true),"Pressed-animation eligibility suppresses repeat while retaining elapsed time for re-entry")
	clock.stop(); check(not clock.active and clock.elapsed==0 and not clock.tick(1000000),"Release or retirement clears the repeat timer")
	clock.begin_rail(); check(clock.tick(0) and clock.first,"Original rail press primes its clock so the first GUI timer tick pages before the initial hold delay")
	check(not clock.tick(333333) and clock.tick(1),"Original rail paging has its separate333333-microsecond initial hold delay")
	check(not clock.tick(100000) and clock.tick(1),"Original rail paging repeats every100000 microseconds with a strict threshold")
	clock.begin(); check(clock.first and clock.elapsed==0 and not clock.tick(100000),"A new press starts a new initial delay rather than inheriting the previous hold")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Static original GUI timer thresholds, eligibility and per-tick callback semantics. Graphical input and original-client execution acceptance are separate."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
