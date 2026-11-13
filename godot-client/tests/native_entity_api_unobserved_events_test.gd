extends SceneTree
const Current=preload("res://systems/client_api/entities.gd")
const Before=preload("res://tests/fixtures/native_entity_events_before.gd")
class CountCurrent extends Current:
	var reference_calls:=0
	func _reference(id: int) -> Variant:
		reference_calls+=1
		return super._reference(id)
class CountBefore extends Before:
	var reference_calls:=0
	func _reference(id: int) -> Variant:
		reference_calls+=1
		return super._reference(id)
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func provider(value: RefCounted) -> RefCounted:
	value._bind_sources(func(_id):return null,Callable())
	return value
func normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary={}
		for key in value:
			if key!="api_instance":result[key]=normalize(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item in value:result.append(normalize(item))
		return result
	return value
func dynamic_sequence(value: RefCounted,rows: Array) -> Array:
	var events: Array=[]
	var second: Callable=func(event):events.append(["second",normalize(event),event.is_read_only(),event.reference.is_read_only()])
	var first_box: Array=[Callable()]
	first_box[0]=func(event):
		events.append(["first",normalize(event),event.is_read_only(),event.reference.is_read_only()])
		check(not value._apply_boundary(1,1,8,1,[],[],false),"Publication still rejects reentrant mutation")
		value.entity_added.disconnect(first_box[0]);value.entity_added.connect(second)
	value.scope_changed.connect(func(event):
		events.append(["scope",normalize(event),event.is_read_only()])
		value.entity_added.connect(first_box[0]))
	check(value._apply_boundary(1,1,8,1,rows,[],true),"Dynamic-subscriber boundary accepted")
	for signal_name in ["scope_changed","entity_added"]:
		for connection in value.get_signal_connection_list(signal_name):value.disconnect(signal_name,connection.callable)
	first_box.clear()
	return events
func run() -> void:
	var rows: Array=[]
	for id in range(1,2001):rows.append({"id":id,"areaId":8,"objectType":9,"nativeLifetime":id+100})
	var before=provider(CountBefore.new());var current=provider(CountCurrent.new())
	var started:=Time.get_ticks_usec();var before_ok: bool=before._apply_boundary(1,1,8,1,rows,[],true);var before_us:=Time.get_ticks_usec()-started
	started=Time.get_ticks_usec();var current_ok: bool=current._apply_boundary(1,1,8,1,rows,[],true);var current_us:=Time.get_ticks_usec()-started
	check(before_ok and current_ok,"Both unobserved full boundaries accepted")
	check(before.reference_calls-current.reference_calls==rows.size(),"Unobserved additions avoid all2000 event reference payloads")
	check(before.diagnostics()==current.diagnostics(),"Unobserved publication preserves registry metrics")
	check(normalize(before.list_references())==normalize(current.list_references()),"Unobserved publication preserves all scoped references and ordering")
	var updates_before: Array=[];var updates_current: Array=[]
	before.entity_updated.connect(func(event):updates_before.append(normalize(event)))
	current.entity_updated.connect(func(event):updates_current.append(normalize(event)))
	check(before._apply_boundary(1,1,8,1,[rows[1],rows[0]],[],false) and current._apply_boundary(1,1,8,1,[rows[1],rows[0]],[],false),"Subscriber attached after an unobserved boundary receives next delta")
	check(updates_before==updates_current and updates_current.size()==2,"Later subscribers receive exact new updates without historic additions")
	var dynamic_before=provider(Before.new());var dynamic_current=provider(Current.new())
	check(dynamic_sequence(dynamic_before,rows.slice(0,3))==dynamic_sequence(dynamic_current,rows.slice(0,3)),"Scope callback connection and per-entity listener replacement preserve exact immutable event order")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"unobserved_full":{"rows":rows.size(),"before_us":before_us,"current_us":current_us,"before_reference_calls":before.reference_calls,"current_reference_calls":current.reference_calls},"scope":"Frozen-before event semantics and one cold unobserved boundary; descriptive timing only, not live-entry speedup."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
