extends RefCounted
# Entry-only continuation. The world is new and unpublished: there are no
# admitted animation, attachment or particle clocks to pause. Live full/delta
# boundaries continue to use the established synchronous receiver.
var owner
var objects: Array=[]
var controlled:=-1
var metadata: Dictionary={}
var current: Dictionary={}
var phase:="idle"
var index:=0
var keys: Array=[]
var previous_mode:=Node.PROCESS_MODE_INHERIT
var active:=false
var cancelled:=false
var scope_open:=false
var base_boundary_open:=false
var began_at:=0
var units:=0
var maximum_unit_us:=0
var overruns: Dictionary={}

func begin(world,rows: Array,controlled_id: int,prepared: Dictionary={}) -> bool:
	if active or not is_instance_valid(world) or world.closed or world.retiring or not world.desired.is_empty() or not world.instances.is_empty() or not world.hidden.is_empty() or not world.motion.objects.is_empty():return false
	owner=world;objects=rows;controlled=controlled_id;metadata=prepared
	previous_mode=world.process_mode;world.process_mode=Node.PROCESS_MODE_DISABLED
	active=true;began_at=Time.get_ticks_usec();phase="begin"
	world.received_snapshot_scope_begin(rows,controlled_id);scope_open=true
	return true

func _next(value: String,values: Array=[]) -> void:
	phase=value;index=0;keys=values

func _unit() -> void:
	match phase:
		"begin":
			owner._boundary_received_metadata={}
			if not metadata.is_empty():owner.received_metadata_stats.prepared_boundaries+=1;owner.received_metadata_stats.prepared_rows+=objects.size()
			owner.base_scenery_begin_boundary(true)
			base_boundary_open=true
			if owner.continuous_base_stream:owner.base_stream_schedule.clear()
			if is_instance_valid(owner.placeable_lights):owner.placeable_lights.receive([],[],true)
			owner.controlled_id=controlled
			owner.base_scenery_omitted={};owner.base_scenery_unaddressable_omitted=false
			_next("lights")
		"lights":
			if index>=objects.size():_next("rows");return
			if is_instance_valid(owner.placeable_lights):
				var object: Dictionary=objects[index]
				var light_id:=int(object.get("id",-1))
				# The full reset left this new world's light map empty. A row
				# that cannot create a light and has no earlier light to erase
				# needs no receive call. Keep duplicate-ID last-wins removal.
				if int(object.get("objectType",0))==9 or owner.placeable_lights.objects.has(light_id):owner.placeable_lights.receive([object])
			index+=1
		"rows":
			if index>=objects.size():_next("population",current.keys());return
			var object: Dictionary=objects[index]
			var prepared: Dictionary=metadata.rows[index] if not metadata.is_empty() else {}
			index+=1
			if not prepared.is_empty():owner._boundary_received_metadata[int(object.get("id",-1))]={"source":object,"value":prepared}
			owner.base_scenery_forget_omitted(int(object.get("id",-1)))
			# begin() requires an empty instance map. Static-draw invalidation
			# only withdraws an installed instance, so there is none to visit.
			if int(object.get("areaId",-1))!=owner.area_id or object.get("replicationRemoved",false) or int(object.get("objectType",0)) not in [5,6,9,10]:owner.note_omitted_base_scenery(object);return
			if (prepared.pose if not prepared.is_empty() else owner.object_pose(object)).is_empty():owner.note_omitted_base_scenery(object);return
			# Admission required an empty world, so retire_replaced_lifetime is
			# provably a no-op here; no existing model is exposed midway.
			var id:=int(object.id)
			current[id]={"object":object,"key":prepared.key if not prepared.is_empty() else owner.signature(object)}
			owner.base_scenery_stamp_slot(id,current[id]);owner.base_stream_note_desired(id,current[id])
			if int(object.objectType)==5 and not owner.motion.objects.has(id):
				var state: Dictionary=object.get("replicated",{})
				owner.motion.observe(id,state,true,state)
			owner.observe_facing_target(object)
		"population":
			# The per-row check only sets this flag. Finish the final
			# publication below once it is true; more comparisons cannot
			# change that result.
			if owner.base_scenery_population_changed:index=keys.size()
			if index<keys.size():owner.base_scenery_note_population_change({},current[keys[index]]);index+=1;return
			if not owner.base_scenery_omitted.is_empty() or owner.base_scenery_unaddressable_omitted:owner.base_scenery_population_changed=true
			owner.desired=current;owner.base_scenery_population_known=true;owner.base_live_revision+=1
			_next("drive")
		"drive":
			if is_instance_valid(owner.drive_collision):
				if owner.drive_collision.has_method("begin_received_full"):
					owner.drive_collision.begin_received_full();_next("drive_rows");return
				elif owner.drive_collision.has_method("sync_full"):owner.drive_collision.sync_full()
				else:owner.drive_collision.warm_dirty=true
			_next("progress_begin")
		"drive_rows":
			if owner.drive_collision.received_full_step():_next("progress_begin")
		"progress_begin":
			for field in owner.BASE_SCENERY_PROGRESS_FIELDS:owner.base_scenery_progress_counts[field]=0
			owner.base_scenery_progress_counts.unresolved_reasons={}
			_next("progress_rows",current.keys())
		"progress_rows":
			if index>=keys.size():_next("progress_omitted",owner.base_scenery_omitted.keys());return
			var id: int=keys[index];index+=1
			var wanted: Dictionary=current[id]
			owner.base_scenery_stamp_slot(id,wanted)
			owner.base_scenery_adjust(int(wanted.base_progress_flags),str(wanted.base_progress_reason),1)
		"progress_omitted":
			if index<keys.size():owner.base_scenery_adjust(1|64|128,str(owner.base_scenery_omitted[keys[index]]),1);index+=1;return
			owner.base_scenery_rebuild_pending=false;owner.stats.base_scenery_scans=int(owner.stats.get("base_scenery_scans",0))+1
			owner.base_scenery_end_boundary();base_boundary_open=false;_next("inherited")
		"inherited":
			if owner.received_snapshot_scope_step():_next("finish")
		"finish":
			owner._boundary_received_metadata={}
			scope_open=false;owner.received_snapshot_scope_end(objects,controlled,true)
			active=false;phase="done"
			if not owner.closed and not owner.retiring:owner.process_mode=previous_mode

func advance(deadline_usec: int) -> Dictionary:
	var began:=Time.get_ticks_usec();var count:=0
	while active and Time.get_ticks_usec()<deadline_usec:
		if not is_instance_valid(owner) or owner.closed or owner.retiring:cancel();break
		var before:=Time.get_ticks_usec();var prior:=phase
		_unit();count+=1;units+=1
		var cost:=Time.get_ticks_usec()-before;maximum_unit_us=maxi(maximum_unit_us,cost)
		if Time.get_ticks_usec()>deadline_usec:overruns[prior]=maxi(int(overruns.get(prior,0)),Time.get_ticks_usec()-deadline_usec)
	return {"done":not active,"cancelled":cancelled,"phase":phase,"units":count,"elapsed_us":Time.get_ticks_usec()-began,"maximum_unit_us":maximum_unit_us,"overruns":overruns.duplicate(),"total_us":Time.get_ticks_usec()-began_at}

func cancel() -> void:
	if not active:return
	active=false;cancelled=true;phase="cancelled"
	if is_instance_valid(owner):
		if is_instance_valid(owner.drive_collision) and owner.drive_collision.has_method("cancel_received_full"):owner.drive_collision.cancel_received_full()
		owner._boundary_received_metadata={}
		if base_boundary_open:
			owner.base_scenery_boundary_depth-=1;base_boundary_open=false
			owner.base_scenery_progress_dirty=true
		if scope_open:scope_open=false;owner.received_snapshot_scope_end(objects,controlled,false)
		# A cancelled unpublished owner must be retired, not resumed half-built.
		owner.process_mode=Node.PROCESS_MODE_DISABLED
	objects=[];metadata={};current={};keys=[]
