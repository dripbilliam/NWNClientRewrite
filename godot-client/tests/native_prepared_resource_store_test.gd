extends SceneTree
const Store=preload("res://systems/native_data/prepared_resource_store.gd")
const A="1111111111111111111111111111111111111111111111111111111111111111"
const B="2222222222222222222222222222222222222222222222222222222222222222"
const C="3333333333333333333333333333333333333333333333333333333333333333"
var checks:=0
var failures: Array=[]
var args: Dictionary={}
var metrics: Array=[]
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
	return value
func write_file(path: String,bytes: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.flush();file.close()
func envelope(size: int) -> PackedByteArray:
	var bytes:=PackedByteArray();bytes.resize(size);bytes.fill(7)
	for index in 4:bytes[index]="RSRC".to_ascii_buffer()[index]
	return bytes
func staged(store,key: String,size: int) -> Dictionary:
	var ticket: Dictionary=store.begin_write(key)
	if not ticket.is_empty():write_file(ticket.path,envelope(size))
	return ticket
func put(store,key: String,size: int) -> bool:
	var ticket:=staged(store,key,size);return not ticket.is_empty() and store.commit_write(ticket)
func fresh(name: String,budget: int=Store.DEFAULT_BUDGET):
	var store=Store.new();check(store.configure(str(args.root).path_join(name),budget),"Configure owned "+name);return store
func core() -> void:
	var root: String=str(args.root).path_join("core");DirAccess.make_dir_recursive_absolute(root)
	var foreign:=root.path_join("original.keep");write_file(foreign,"original-data".to_utf8_buffer())
	var store=fresh("core")
	check(store.snapshot().budget_bytes==25*1024*1024*1024 and store.snapshot().committed_bytes==0,"Default25GiB is an accounting limit, not an allocation")
	check(store.begin_write("../bad").is_empty() and store.begin_write(A.to_upper().replace("1","A")).is_empty(),"Invalid/noncanonical keys are rejected")
	var ticket:=staged(store,A,60);var copy:=ticket.duplicate();copy.path=foreign
	check(not store.commit_write(copy) and store.failure=="invalid-ticket","Mutated ticket cannot publish an original file")
	store.cancel_write(copy)
	check(FileAccess.get_file_as_string(foreign)=="original-data","Mutated cancellation preserves original files")
	check(not store.close() and store.failure=="active-writes","Close does not delete an asynchronously owned staged ticket")
	check(store.commit_write(ticket),"Valid resource envelope publishes")
	var path: String=store.lookup(A)
	check(not path.is_empty() and path.ends_with(".res") and not FileAccess.file_exists(ticket.path),"Published artifact has immutable nonce path; staging is retired")
	check(not store.commit_write(ticket) and store.failure=="invalid-ticket","Published write ticket cannot be replayed")
	var duplicate:=staged(store,A,64)
	check(store.commit_write(duplicate) and store.lookup(A)==path and store.snapshot().committed_bytes==60,"Concurrent same-key publication deduplicates actual disk accounting")
	var before: Dictionary=store.snapshot()
	for index in 30:check(store.lookup(A)==path,"Hot lookup retains current artifact")
	var after: Dictionary=store.snapshot()
	check(after.ancestor_checks==before.ancestor_checks and after.index_reads==before.index_reads,"Hot hits do not walk root ancestry or reparse indexes")
	check(after.file_opens-before.file_opens==30,"Each hot hit reads one bounded envelope/length, not the complete resource")
	metrics.append({"case":"30-hot-path-hints","calls":30,"lookup_us":after.lookup_us-before.lookup_us,"artifact_file_opens":after.file_opens-before.file_opens,"ancestor_checks":after.ancestor_checks-before.ancestor_checks,"index_reads":after.index_reads-before.index_reads,"metadata_bytes_read":after.metadata_bytes_read-before.metadata_bytes_read})
	var view: Dictionary=store.snapshot();view.budget_bytes=4
	check(store.snapshot().budget_bytes==Store.DEFAULT_BUDGET,"Returned snapshot is detached")
	var reader: Dictionary=store.acquire_read(A)
	check(not reader.is_empty() and not store.close() and store.failure=="active-reads","Read lease prevents close until asynchronous consumer releases")
	check(not store.invalidate(A) and store.failure=="read-pinned","Invalidation respects a live read lease")
	var invalid_reader:=reader.duplicate();invalid_reader.path=foreign;store.release_read(invalid_reader)
	check(store.snapshot().active_reads==1,"Mutated read lease cannot retire another read")
	store.release_read(reader)
	check(store.invalidate(A) and store.lookup(A).is_empty() and not FileAccess.file_exists(path),"Released artifact can be invalidated and rebuilt")
	check(FileAccess.get_file_as_string(foreign)=="original-data","Original sibling survives publication, deduplication and invalidation")
	check(store.close(),"Idle store closes cleanly")
func budgets() -> void:
	var one=fresh("budget",100);var two=Store.new()
	check(two.configure(str(args.root).path_join("budget"),100),"Second store shares the existing owned namespace")
	check(put(one,A,60),"First bounded artifact saves")
	var read: Dictionary=two.acquire_read(A)
	check(not read.is_empty(),"Second owner acquires an indexed read lease")
	var pending:=staged(one,B,60)
	check(not one.commit_write(pending) and one.failure=="budget-pinned","Pinned artifact cannot be evicted to exceed the budget")
	check(one.snapshot().committed_bytes==60 and FileAccess.file_exists(pending.path),"Rejected publication retains its staged ticket for deliberate retry")
	two.release_read(read)
	check(one.commit_write(pending) and one.lookup(A).is_empty() and not one.lookup(B).is_empty(),"Retry evicts only the now-unpinned owned least-recent artifact")
	check(one.snapshot().committed_bytes==60 and one.snapshot().evictions==1,"Eviction accounts actual committed bytes")
	var contended:=staged(one,C,40)
	check(two._try_publish_lock(),"Authored second owner holds the actual nonblocking publication lock")
	var began:=Time.get_ticks_usec();var accepted: bool=one.commit_write(contended);var elapsed:=Time.get_ticks_usec()-began
	check(not accepted and one.failure=="busy" and elapsed<1000000 and FileAccess.file_exists(contended.path),"Contended commit returns promptly and preserves its exact staged ticket")
	two._unlock_publish()
	check(one.commit_write(contended) and one.snapshot().committed_bytes==100,"The same staged ticket commits after contention clears")
	var oversized:=staged(one,C,101)
	check(not one.commit_write(oversized) and one.failure=="invalid-resource-envelope-or-size","Artifact larger than the configured budget is rejected")
	one.cancel_write(oversized)
	var invalid:=staged(one,C,60);write_file(invalid.path,"bad envelope".to_utf8_buffer())
	check(not one.commit_write(invalid) and one.failure=="invalid-resource-envelope-or-size","Non-resource envelope cannot enter the cache")
	one.cancel_write(invalid)
	check(one.close() and two.close(),"Both bounded owners close")
func recovery() -> void:
	var store=fresh("recovery",200)
	check(put(store,A,60),"Recovery source artifact saves")
	var path: String=store.lookup(A);var prefix:=A.left(2)
	var state_path: String=store.directory.path_join("state.json")
	check(DirAccess.rename_absolute(state_path,state_path+".bak")==OK,"Authored crash boundary retains the previous accounting backup")
	var recovered=Store.new()
	check(recovered.configure(str(args.root).path_join("recovery"),200),"Interrupted accounting publication recovers under the owned lock")
	check(recovered.lookup(A)==path and recovered.snapshot().committed_bytes==60 and recovered.snapshot().recovered==1,"Recovery reconstructs actual indexed artifacts without losing the file")
	var foreign: String=store.directory.path_join("foreign.keep");write_file(foreign,"unrelated".to_utf8_buffer())
	var lock_path: String=store.directory.path_join("publish.lock");DirAccess.make_dir_absolute(lock_path)
	var owner:={"format":Store.FORMAT,"root_id":store.directory.sha256_text(),"pid":99999999,"nonce":"dead"}
	write_file(lock_path.path_join("owner.json"),JSON.stringify(owner).to_utf8_buffer())
	var pending:=staged(recovered,B,60)
	check(not recovered.commit_write(pending) and recovered.failure=="busy","Foreign or apparently dead PID markers conservatively block publication")
	# Fixture-owned marker cleanup models an explicit external ownership audit.
	DirAccess.remove_absolute(lock_path.path_join("owner.json"));DirAccess.remove_absolute(lock_path)
	check(recovered.commit_write(pending),"The original ticket retries after explicitly owned stale-lock cleanup")
	check(FileAccess.get_file_as_string(foreign)=="unrelated","Recovery preserves unrelated files in the owned namespace")
	check(store.close() and recovered.close(),"Recovered owners close without live leases")
func role() -> void:
	var store=Store.new();var success: bool=store.configure(str(args.root),100);var ticket: Dictionary={};var reason:=""
	if args.role=="holder" and success:
		success=put(store,A,60);ticket=store.acquire_read(A);success=success and not ticket.is_empty()
		write_file(str(args.ready),JSON.stringify({"success":success,"pid":OS.get_process_id()}).to_utf8_buffer())
		var deadline:=Time.get_ticks_msec()+10000
		while not FileAccess.file_exists(str(args.release)) and Time.get_ticks_msec()<deadline:await process_frame
		store.release_read(ticket)
	elif args.role=="writer" and success:
		ticket=staged(store,B,60);success=store.commit_write(ticket)
		if not success:reason=store.failure;store.cancel_write(ticket)
	var result:={"success":success,"failure":reason if not reason.is_empty() else store.failure,"snapshot":store.snapshot(),"pid":OS.get_process_id(),"path_a":store.lookup(A),"path_b":store.lookup(B)}
	store.close();write_file(str(args.report),JSON.stringify(result).to_utf8_buffer());quit(0)
func _initialize() -> void:
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--") and "=" in value:var parts:=value.substr(2).split("=",true,1);args[parts[0]]=parts[1]
	call_deferred("run")
func run() -> void:
	if args.has("role"):await role();return
	core();budgets();recovery()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Prepared resource disk ownership, tickets, sharded index, budget, deduplication, read leases and crash accounting; controlled envelope fixtures, not a codec, renderer or FPS test"}
	write_file(str(args.report),JSON.stringify(result,"\t").to_utf8_buffer());print("PREPARED_RESOURCE_STORE ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
