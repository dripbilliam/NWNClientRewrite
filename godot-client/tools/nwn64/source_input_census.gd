extends RefCounted
# Cold, read-only census of the current shared CPU particle presentation.
# Native dispatch 17 supplies rows in the presenter's actual registration order.

static func summarize(rows: Array, registered: int) -> Dictionary:
	var errors: Array[String]=[]
	var sources: Dictionary={}
	var prepared_sources: Dictionary={}
	var kinds: Dictionary={}
	var flags: Dictionary={}
	var owned:=0
	var prepared:=0
	var source_reads:=0
	var same_pose_source:=0
	var adjacent_source_repeats:=0
	var previous_source: Variant=null
	var id_seen: Dictionary={}
	for value in rows:
		if not value is Dictionary:
			errors.append("non-dictionary-row")
			continue
		var row: Dictionary=value
		if not row.has("id") or id_seen.has(row.id):
			errors.append("absent-or-duplicate-id")
			continue
		id_seen[row.id]=true
		if not bool(row.get("has_owner",false)):
			previous_source=null
			continue
		owned+=1
		if not row.has("source_id") or not row.has("pose_id"):
			errors.append("missing-pose-identity")
			continue
		var source_id: int=int(row.source_id)
		var pose_id: int=int(row.pose_id)
		if source_id<=0 or pose_id<=0:errors.append("invalid-pose-identity")
		sources[source_id]=int(sources.get(source_id,0))+1
		var kind: int=int(row.get("kind",-1))
		var emitter_flags: int=int(row.get("emitter_flags",-1))
		kinds[kind]=int(kinds.get(kind,0))+1
		flags[emitter_flags]=int(flags.get(emitter_flags,0))+1
		if bool(row.get("prepared",false)):
			prepared+=1
			if source_id==pose_id:same_pose_source+=1
			else:
				source_reads+=1
				prepared_sources[source_id]=int(prepared_sources.get(source_id,0))+1
				if previous_source==source_id:adjacent_source_repeats+=1
			previous_source=source_id
		else:previous_source=null
	if rows.size()!=registered:errors.append("registered-row-count-mismatch")
	var repeated_owners:=0
	for count in sources.values():
		if int(count)>1:repeated_owners+=int(count)
	var repeat_reads:=0
	for count in prepared_sources.values():
		if int(count)>1:repeat_reads+=int(count)-1
	return {"success":errors.is_empty(),"errors":errors,"registered":registered,"owned":owned,"prepared":prepared,"unique_sources":sources.size(),"repeated_source_owners":repeated_owners,"separate_source_pose_reads":source_reads,"same_pose_source":same_pose_source,"prepared_unique_source_ids":prepared_sources.size(),"potential_duplicate_source_reads":repeat_reads,"adjacent_source_repeats":adjacent_source_repeats,"kind_counts":kinds,"emitter_flags_counts":flags,"scope":"Cold last-frame identity census. Duplicate reads are an upper bound only; callbacks, node mutation and retirement may require every live read. The native survey recomputes hypothetical admission values but does not advance simulation or clocks."}

static func collect(world: Node) -> Dictionary:
	if not is_instance_valid(world):return {"success":false,"errors":["world-unavailable"]}
	var group: Variant=world.get("particle_stream_group")
	if not is_instance_valid(group) or not is_instance_valid(group.native):return {"success":false,"errors":["shared-presentation-unavailable"]}
	var survey: Variant=group.native.call("dispatch",17,{})
	if not survey is Dictionary or survey.has("error") or not survey.get("rows",null) is Array:return {"success":false,"errors":["native-survey-unavailable"]}
	var result:=summarize(survey.rows,int(survey.get("registered",-1)))
	result.area_id=int(world.get("area_id"))
	result.generation=int(world.get("generation"))
	result.shared_members=group.members.size()
	result.fast_members=int(group.fast_members)
	if result.registered!=result.shared_members:
		result.success=false
		result.errors.append("shared-native-member-count-mismatch")
	return result
