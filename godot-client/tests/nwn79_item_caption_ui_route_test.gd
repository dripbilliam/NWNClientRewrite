extends SceneTree
# Actual inventory controls receiving a retained item after server 24/5 apply.
# The packet/session mutation is covered by nwn79_native_item_caption_session_test.
const Inventory=preload("res://systems/server_inventory.gd")
const Tooltip=preload("res://systems/native_data/item_tooltip.gd")
const PlateState=preload("res://systems/native_data/nameplate_state.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func view(serial: int,rows: Array) -> Dictionary:
	return {"kind":"inventory-view","viewId":serial,"title":"Caption route","items":rows,"layout":[{"slot":2,"x":0,"y":0,"w":40,"h":80,"label":"Chest"}],"page":0,"summary":{"gold":0,"capacity":100,"weight":1},"armorClass":10,"container":{},"store":{}}
func row(item: Dictionary,text) -> Dictionary:
	return {"entryId":101,"itemId":101,"channel":"I","slot":2,"x":0,"y":0,"width":1,"height":1,"stack":1,"name":text.raw(item.name,42),"tooltip":Tooltip.project(item,text,42),"pending":false}
func run() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var text:=Text.new()
	var host:=Control.new(); root.add_child(host); host.size=Vector2(1280,800)
	var ui:=Inventory.new(); host.add_child(ui); ui.setup(""); ui.open()
	var object:={"id":101,"objectType":6,"item":{"name":{"text":"Steel Blade"},"field2b8":0,"field2c0":""}}
	ui.receive(view(1,[row(object.item,text)])); await process_frame; await process_frame
	check(ui.buttons.has(101) and ui.buttons[101].current(),"Original retained item has an active inventory control")
	var control=ui.buttons[101]; var identity: int=control.get_instance_id()
	var prior_signature: int=PlateState.signature(object,42,text.revision)
	for mode in [1,2,3,0]:
		# Server 24/5 changes this canonical item in place; layout and object ID stay put.
		object.item.field2b8=mode; object.item.field2c0="Marked" if mode!=0 else ""
		var projected: Dictionary=Tooltip.project(object.item,text,42)
		var nameplate: Dictionary=PlateState.project(object,42,text)
		ui.receive(view(mode+2,[row(object.item,text)])); await process_frame; await process_frame
		check(ui.buttons.has(101) and ui.buttons[101].get_instance_id()==identity and control.current(),"Caption mode %d retains actual hover/input control"%mode)
		check(control.row.tooltip==projected and control.row.tooltip.text==projected.text,"Caption mode %d reaches the actual inventory tooltip row"%mode)
		check(nameplate.available and nameplate.override_mode==mode and not nameplate.caption.text.is_empty(),"Caption mode %d reaches the world item nameplate projection"%mode)
		check(prior_signature!=PlateState.signature(object,42,text.revision),"Caption mode %d invalidates retained world label cache"%mode)
		prior_signature=PlateState.signature(object,42,text.revision)
	ui.receive(view(7,[])); await process_frame; await process_frame
	check(not ui.buttons.has(101) and not control.row.has("entryId") and control.native_tooltip_content().get("identity",[])[0]==-1,"Item removal replaces the item tooltip with the generic empty-slot tooltip")
	ui.receive(view(8,[row(object.item,text)])); await process_frame; await process_frame
	check(ui.buttons.has(101) and ui.buttons[101].current(),"A new area may present its own received item")
	ui.reset(); await process_frame; await process_frame
	check(ui.buttons.is_empty(),"Area/reconnect reset releases item caption controls")
	ui.queue_free(); host.queue_free(); text.close(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual retained inventory control/tooltip row and item-nameplate projection after canonical 24/5 mutation; original packet/session oracle and live pixels are separate."},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
