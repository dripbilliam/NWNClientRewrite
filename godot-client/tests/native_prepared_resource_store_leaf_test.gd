extends "res://tests/native_prepared_resource_store_test.gd"
# Focus the one-leaf reader-parent optimization; the unchanged 72-check store
# suite and three-process reader/evictor suite remain separate acceptance gates.
func run() -> void:
	var store=fresh("reader-leaves",200)
	check(put(store,A,60),"Authored resource publishes for leaf checks")
	var artifact: String=store.lookup(A)
	var parent: String=store.directory.path_join("readers").path_join(artifact.get_file().trim_suffix(".res"))
	var one: Dictionary=store.acquire_read(A)
	check(not one.is_empty() and store.snapshot().reader_leaf_mkdir_created==1,"First lease creates exactly its owned reader leaf")
	var two: Dictionary=store.acquire_read(A)
	check(not two.is_empty() and one.nonce!=two.nonce and store.snapshot().reader_leaf_mkdir_existing==1,"Concurrent reader shares the verified existing parent with its own nonce")
	check(store.snapshot().active_reads==2 and store.snapshot().reader_leaf_mkdir_attempts==2,"One leaf attempt per real acquired lease is counted")
	store.release_read(one)
	check(DirAccess.dir_exists_absolute(parent) and store.snapshot().active_reads==1,"First release cannot remove another reader's nonempty parent")
	check(not store.invalidate(A) and store.failure=="read-pinned","Remaining nonce still fences invalidation")
	store.release_read(two)
	check(not DirAccess.dir_exists_absolute(parent) and store.snapshot().active_reads==0,"Final exact release removes only the empty reader leaf")
	write_file(parent,"fixture-file-collision".to_utf8_buffer())
	var blocked: Dictionary=store.acquire_read(A)
	check(blocked.is_empty() and store.snapshot().reader_leaf_mkdir_failed==1,"Existing ordinary file is not admitted as a reader directory")
	check(FileAccess.get_file_as_string(parent)=="fixture-file-collision" and store.lookup(A)==artifact,"Failed leaf creation preserves the foreign file and original derivative")
	DirAccess.remove_absolute(parent) # Exact fixture-created file only.
	var readers: String=store.directory.path_join("readers")
	check(DirAccess.remove_absolute(readers)==OK,"Authored empty configured reader category can be removed for fallback test")
	blocked=store.acquire_read(A)
	check(blocked.is_empty() and not DirAccess.dir_exists_absolute(readers),"Unavailable configured ancestor returns a miss instead of rebuilding an absolute path chain")
	check(DirAccess.make_dir_absolute(readers)==OK,"Fixture restores only its exact owned reader category")
	one=store.acquire_read(A)
	check(not one.is_empty() and store.snapshot().reader_leaf_mkdir_created==2,"Normal acquisition resumes after category restoration")
	store.release_read(one)
	check(store.close(),"Leaf fixture closes without live lease or staged data")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"One-leaf directory creation only; real nonce JSON reader pins, concurrent reads, regular-file collision and unavailable ancestor fallback. No renderer/server/FPS claim."}
	write_file(str(args.report),JSON.stringify(result,"\t").to_utf8_buffer());print("PREPARED_RESOURCE_READER_LEAF ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
