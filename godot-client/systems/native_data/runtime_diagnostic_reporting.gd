extends RefCounted
# Direct Godot replacement for diagnostic_reporting.js status, export and retry.
signal changed(status: Dictionary)
var journal: RefCounted
var directory: String=""
var status: Dictionary={}
var unsubscribe: Callable
var panel: VBoxContainer
var status_label: Label
var recent_label: Label
var action_label: Label

func configure(value: RefCounted,settings_directory: String)->void:
	close()
	journal=value
	directory=settings_directory.path_join("runtime-diagnostics")
	unsubscribe=journal.subscribe(Callable(self,"_publish"))
	if not journal.attach(directory.path_join(journal.session+".jsonl")):
		journal.record("diagnostic.storage-unavailable",journal.storage_error,{},"error")

func _publish(value: RefCounted)->void:
	var recent: Array[String]=[]
	var start:=maxi(0,value.records.size()-6)
	for index in range(value.records.size()-1,start-1,-1):
		var row: Dictionary=value.records[index]
		recent.append(str(row.get("code",""))+": "+str(row.get("message","")))
	status={"count":value.records.size(),"pending":value.pending.size(),"location":value.location,"storageError":value.storage_error,"recent":recent}
	if is_instance_valid(status_label):status_label.text="%d recorded · %d pending\n%s%s" % [int(status.count),int(status.pending),str(status.location),"\nSAVE FAILED: "+str(status.storageError)+" · export preserves the session" if not str(status.storageError).is_empty() else ""]
	if is_instance_valid(recent_label):recent_label.text="\n".join(recent)
	changed.emit(status.duplicate(true))

func create_panel()->Control:
	if is_instance_valid(panel):return panel
	panel=VBoxContainer.new();panel.name="Diagnostics"
	status_label=Label.new();status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(status_label)
	recent_label=Label.new();recent_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(recent_label)
	var actions:=HBoxContainer.new();panel.add_child(actions)
	var export_button:=Button.new();export_button.text="Export session";actions.add_child(export_button)
	export_button.pressed.connect(func()->void:
		var result:=export_current();action_label.text=str(result.get("path",result.get("error",""))))
	var history_button:=Button.new();history_button.text="Export history";actions.add_child(history_button)
	history_button.pressed.connect(func()->void:
		var result:=export_history();action_label.text=str(result.get("path",result.get("error",""))))
	var retry_button:=Button.new();retry_button.text="Retry save";actions.add_child(retry_button)
	retry_button.pressed.connect(func()->void:
		if not retry():action_label.text=str(journal.storage_error))
	action_label=Label.new();action_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(action_label)
	if journal!=null:_publish(journal)
	return panel

func export_current(path: String="")->Dictionary:
	if journal==null:return {"error":"Diagnostic journal is unavailable"}
	var destination:=path if not path.is_empty() else directory.path_join("nwn-diagnostics-"+journal.session+".jsonl")
	if not journal.export(destination):return {"error":"Diagnostic journal could not be exported"}
	return {"path":destination}

func export_history(path: String="")->Dictionary:
	if journal==null:return {"error":"Diagnostic journal is unavailable"}
	if not journal.flush(false):return {"error":journal.storage_error}
	var destination:=path if not path.is_empty() else directory.path_join("nwn-saved-diagnostics.jsonl")
	var names:=DirAccess.get_files_at(directory)
	names.sort()
	var output:=PackedStringArray()
	for name in names:
		if not name.ends_with(".jsonl") or name.begins_with("nwn-"):continue
		output.append(FileAccess.get_file_as_string(directory.path_join(name)))
	var file:=FileAccess.open(destination,FileAccess.WRITE)
	if file==null:return {"error":"Diagnostic history could not be exported"}
	file.store_string("".join(output));file.flush()
	var ok:=file.get_error()==OK
	file.close()
	return {"path":destination} if ok else {"error":"Diagnostic history could not be exported"}

func retry()->bool:
	return journal!=null and journal.retry()

func close()->void:
	if unsubscribe.is_valid():unsubscribe.call()
	unsubscribe=Callable()
	journal=null
