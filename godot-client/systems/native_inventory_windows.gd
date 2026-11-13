extends Node
# Native13/1 window ownership. Backend metadata is raw protocol/lifetime state;
# this owner decides actual visibility, displayed owner and local GUI mode.
const InventoryOwner=preload("res://systems/native_inventory.gd")
const Policy=preload("res://systems/native_data/inventory_window_owner.gd")
const INVALID:=2130706432
var owner_ui
var alternate
var scope: Array=[]
var metadata: Dictionary={}
var handled: Dictionary={"primary":0,"alternate":0,"rejected":0}
var states: Dictionary={}
var closed:=false
var revision:=0
var detailed_timings:=false
var timing_rows: Array=[]
func record_time(phase: String) -> void:
	if not detailed_timings or timing_rows.size()>=128:return
	timing_rows.append({"phase":phase,"mono_us":Time.get_ticks_usec(),"wall_ms":Time.get_unix_time_from_system()*1000.0,"process_frame":Engine.get_process_frames(),"scope":scope.duplicate(),"owner":alternate.displayed_owner(),"receipt":alternate.window_receipt,"received_owner":metadata.get("alternate",{}).get("rawOwnerId"),"received_receipt":metadata.get("alternate",{}).get("receiptSerial"),"wanted":alternate.ui.wanted,"visible":alternate.ui.is_visible_in_tree(),"frame_ready":ready_view(alternate),"pixels_measured":false})
var stats:={"presentations":0,"closes":0,"rejected_replies":0,"pending":0,"unported_container_closes":0,"errors":[]}
func initial_state() -> Dictionary:return {"active":false,"displayedOwner":INVALID,"containerMode":0,"containerId":INVALID,"containerField":0,"attached":true}
func configure(ui,catalog,cache_path: String,layout: String) -> void:
	owner_ui=ui;states={"primary":initial_state(),"alternate":initial_state()}
	alternate=InventoryOwner.new();add_child(alternate);alternate.configure(ui.controls,catalog,cache_path,ui.text,layout,"alternate");alternate.request.connect(ui.request.emit)
	alternate.ui.request.connect(local_input.bind("alternate"));ui.inventory.ui.request.connect(local_input.bind("primary"))
	set_process(true)
func view(role: String):return alternate if role=="alternate" else owner_ui.inventory
func ready_view(value) -> bool:
	return is_instance_valid(value) and is_instance_valid(value.ui) and value.frame_skin.layout_ready and value.equipment_skin.layout_ready
func synchronize(epoch: int,area: int,controlled: int,raw: Dictionary) -> void:
	if closed:return
	var next:=[epoch,area,controlled]
	if next!=scope:
		scope=next;states={"primary":initial_state(),"alternate":initial_state()};handled={"primary":0,"alternate":0,"rejected":0};alternate.ui.present_received(false);alternate.set_displayed_owner(-1,0,0)
		owner_ui.inventory.display_owner_id=-1
	alternate.generation=epoch;alternate.area_id=area;alternate.controlled_id=controlled
	# Share the already accepted canonical UI map, not another registry walk.
	alternate.objects=owner_ui.inventory.objects;alternate.update_inventory(raw)
	observe(raw.get("windows",{}))
func observe(value: Variant) -> void:
	if closed or not value is Dictionary:return
	var previous_receipt:=int(metadata.get("alternate",{}).get("receiptSerial",0))
	metadata=value.duplicate(true)
	if int(metadata.get("alternate",{}).get("receiptSerial",0))!=previous_receipt:record_time("native-window-message-observed")
	drain()
func local_input(message: Dictionary,role: String) -> void:
	if closed or scope.is_empty() or message.get("kind","") not in ["inventory-open","inventory-close"]:return
	var state: Dictionary=states[role];state.active=message.kind=="inventory-open"
	if state.active:state.displayedOwner=view(role).displayed_owner()
	else:state.containerMode=0;state.containerId=INVALID;state.containerField=0
	states[role]=state;revision+=1
	if role=="alternate":record_time("native-local-open" if state.active else "native-local-close")
func sync_mode(role: String) -> void:
	var value=view(role);var state: Dictionary=states[role]
	state.active=value.ui.wanted
	if not state.active:state.containerMode=0;state.containerId=INVALID;state.containerField=0
	elif ready_view(value):
		var container=value.frame_skin.container_stage
		state.containerMode=1 if is_instance_valid(container) and container.visible else 0
		state.containerId=int(value.ui.state.get("container",{}).get("ownerId",INVALID)) if int(state.containerMode)!=0 else INVALID
	states[role]=state
func drain() -> void:
	if closed or scope.is_empty() or owner_ui.controlled_id<0:return
	var rejected: Variant=metadata.get("rejected")
	if rejected is Dictionary and int(rejected.get("receiptSerial",0))>int(handled.rejected):
		handled.rejected=int(rejected.receiptSerial)
		if int(rejected.get("actorId",-1))==owner_ui.controlled_id and int(rejected.get("areaId",-1))==owner_ui.area_id:
			owner_ui.request.emit({"kind":"inventory-close","inventoryRole":"rejected","ownerId":int(rejected.ownerId),"inventoryReceipt":int(rejected.receiptSerial)});stats.rejected_replies+=1
	for role in ["primary","alternate"]:
		var record: Dictionary=metadata.get(role,{})
		if record.is_empty():continue
		var value=view(role);value.window_serial=int(record.get("serial",0));value.window_receipt=int(record.get("receiptSerial",0))
		if int(record.get("receiptSerial",0))<=int(handled[role]):continue
		if int(record.get("actorId",-1))!=owner_ui.controlled_id or int(record.get("areaId",-1))!=owner_ui.area_id:
			handled[role]=int(record.receiptSerial);continue
		if not ready_view(value):stats.pending+=1;continue
		var requested_owner:=int(record.get("rawOwnerId",INVALID));var selected:=Policy.select(requested_owner,owner_ui.controlled_id,owner_ui.inventory.objects)
		# Canonical protocol admission preceded this presentation frame. Wait for
		# its accepted object upsert instead of inventing a missing-owner reply.
		if not selected.available:stats.pending+=1;continue
		sync_mode(role)
		var result:=Policy.transition(states[role],bool(record.get("receivedOpen",false)),requested_owner,owner_ui.controlled_id)
		if not result.ready:stats.pending+=1;continue
		handled[role]=int(record.receiptSerial)
		if not result.changed:continue
		states[role]=result.state;revision+=1
		for event in result.events:
			match str(event.kind):
				"forceVisible":
					value.ui.present_received(true);stats.presentations+=1
					if role=="alternate":record_time("native-window-visible")
				"refreshOwner":value.set_displayed_owner(int(event.ownerId),int(record.serial),int(record.receiptSerial));value.signature="";value.refresh()
				"deactivate":value.item_context.cancel();value.stack_dialog.cancel();value.gold.cancel();value.ui.present_received(false);stats.closes+=1
				"containerClose":stats.unported_container_closes+=1
				_:pass # Godot children are already attached; independent windows coexist.
func _process(_delta: float) -> void:
	if closed or scope.is_empty():return
	for role in ["primary","alternate"]:sync_mode(role)
	drain()
func blocks_pointer(point: Vector2) -> bool:return not closed and is_instance_valid(alternate) and alternate.blocks_pointer(point)
func receive(message: Dictionary) -> void:
	if closed or scope.is_empty():return
	# A retired alternate command cannot clear a newer owner's pending state.
	if message.get("kind","")=="inventory-command-result":
		if int(message.get("ownerId",-1))!=alternate.displayed_owner() or int(message.get("windowSerial",-1))!=alternate.window_serial:return
	alternate.receive(message)
func owner_snapshot(role: String) -> Dictionary:
	if closed or not states.has(role):return {"ready":false}
	sync_mode(role)
	return states[role].duplicate(true).merged({"ready":ready_view(view(role)),"role":role,"revision":revision,"provenance":"native window and container-stage state; received13/1 owner"},true)
func snapshot() -> Dictionary:
	if detailed_timings:stats.timings=timing_rows.duplicate(true)
	return stats.duplicate(true).merged({"primary":owner_snapshot("primary"),"alternate":owner_snapshot("alternate"),"alternate_inventory":alternate.snapshot() if is_instance_valid(alternate) else {},"full_alternate_item_actions":false,"container_close_sender_bound":false},true)
func close() -> void:
	if closed:return
	closed=true;set_process(false);metadata.clear();scope.clear()
	if is_instance_valid(alternate):alternate.objects={};alternate.close()
func _exit_tree() -> void:close()
