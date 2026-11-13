extends "res://tools/nwn62/drive_reindex_component.gd"
const ProfiledScript=preload("res://tools/nwn62/drive_collision_indexed_profiled.gd")

# Diagnostic decomposition of the frozen synchronous path. This repeats its
# statements in original order and checks the final byte signature against
# an ordinary prepared() invocation on the same authored captured shape.
func measured()->Dictionary:
	var setup:=make(ProfiledScript,1918);var collision=setup.collision;var world=setup.world
	collision.tables.doortypes={"orderedRows":[]}
	var t:=Time.get_ticks_usec();collision.invalidate_preview_geometry();var invalidate_us:=Time.get_ticks_usec()-t
	t=Time.get_ticks_usec();collision.begin_source_batch();var begin_us:=Time.get_ticks_usec()-t
	var row_count:=0;var creature_count:=0;var creature_us:=0;var static_us:=0
	t=Time.get_ticks_usec()
	for id in collision.source_rows.keys():
		var row_t:=Time.get_ticks_usec()
		collision.refresh_source(int(id))
		var elapsed:=Time.get_ticks_usec()-row_t
		if collision.creature_ids.has(id):creature_count+=1;creature_us+=elapsed
		else:static_us+=elapsed
		row_count+=1
	var refresh_us:=Time.get_ticks_usec()-t
	t=Time.get_ticks_usec();collision.invalidate_preview_geometry();var end_invalidate_us:=Time.get_ticks_usec()-t
	t=Time.get_ticks_usec();collision.spatial.end_batch(collision.spatial_ticket);var global_end_us:=Time.get_ticks_usec()-t
	var group_count:=0;var group_max_us:=0;var group_sum_us:=0;var group_nonempty:=0
	t=Time.get_ticks_usec()
	for key in collision.static_groups:
		var group: Dictionary=collision.static_groups[key]
		if int(group.index.snapshot().entries)>0:group_nonempty+=1
		var group_t:=Time.get_ticks_usec()
		group.index.end_batch(group.ticket);collision.dirty_groups[key]=true
		var elapsed:=Time.get_ticks_usec()-group_t
		group_sum_us+=elapsed;group_max_us=maxi(group_max_us,elapsed);group_count+=1
	var group_end_us:=Time.get_ticks_usec()-t
	collision.source_batch=false
	t=Time.get_ticks_usec();collision.flush_group_bounds();var bounds_us:=Time.get_ticks_usec()-t
	var spatial=collision.spatial.query(collision.spatial_ticket,Vector3(-20,-20,0),Vector3(100,100,0),1.0)
	var groups: Array=[]
	for key in collision.static_groups.keys():
		var group: Dictionary=collision.static_groups[key]
		groups.append([key,group.index.query(group.ticket,Vector3(-20,-20,0),Vector3(100,100,0),1.0).ids])
	groups.sort_custom(func(a,b):return str(a[0])<str(b[0]))
	var bindings: Array=[]
	for id in collision.source_rows.keys():
		var row: Dictionary=collision.source_rows[id]
		bindings.append([id,row.get("point"),row.get("dimensions"),row.get("published"),row.get("published_order"),row.get("model_key")])
	var result:={"signature":var_to_bytes([spatial.ids,groups,bindings,collision.source_errors,collision.model_users.size()]).hex_encode(),"ready":collision.ready(),"invalidate_us":invalidate_us,"begin_us":begin_us,"row_count":row_count,"creature_count":creature_count,"creature_us":creature_us,"static_us":static_us,"refresh_us":refresh_us,"end_invalidate_us":end_invalidate_us,"global_end_us":global_end_us,"group_count":group_count,"group_nonempty":group_nonempty,"group_end_us":group_end_us,"group_sum_us":group_sum_us,"group_max_us":group_max_us,"bounds_us":bounds_us,"total_us":invalidate_us+begin_us+refresh_us+end_invalidate_us+global_end_us+group_end_us+bounds_us,"profile":collision.profile.duplicate(true)}
	collision.close();world.free();return result

func run()->void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var legs: Array=[]
	for mode in ["control","profile","profile","control"]:
		legs.append(leg(ControlScript,1918,"none") if mode=="control" else measured())
		await process_frame
	for row in legs:check(row.ready and row.signature==legs[0].signature,"profiled synchronous split matches ordinary prepared result")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"legs":[],"scope":"Frozen synchronous source, actual SceneTree, authored 1918-source captured shape. Phase timers have per-row/per-group clock overhead; no original-asset/FPS result."}
	for row in legs:
		var copy: Dictionary=row.duplicate(true);copy.erase("signature");report.legs.append(copy)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
