extends "res://tests/native_draw_cache_runtime_test.gd"
# Exercise actual cold/warm mesh artifact writes and retirement with only the
# shared process-owned cache driver maintaining idle services' leases.
func request(service) -> Dictionary:
	var answer: Dictionary=await super.request(service)
	await process_frame
	check(not service.is_processing(),"Real model service sleeps while its cache lease and completed artifact work remain valid")
	return answer
func settle() -> bool:
	var deadline:=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		var state:=Runtime.snapshot();var pending:=0
		for owner in state.owners:pending+=int(owner.pending_writes)
		if pending==0:return true
		# Deliberately do not call Runtime.poll here: the driver must drain writes.
		await process_frame
	return false
