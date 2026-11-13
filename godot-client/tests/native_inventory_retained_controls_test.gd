extends SceneTree
# Actual controls and view lifetimes; authored views here are not server proof.
const Inventory=preload("res://systems/server_inventory.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func frames() -> void:
	await process_frame; await process_frame
func row(id: int,channel: String,x: int=0) -> Dictionary:
	return {"entryId":id,"itemId":id,"channel":channel,"slot":2 if channel=="I" else 0,"x":x,"y":0,"width":1,"height":1,"stack":1,"name":"Item "+str(id),"tooltip":Rich.parse("Initial "+str(id)),"price":5,"pending":false}
func view(serial: int,items: Array,store: Dictionary={}) -> Dictionary:
	return {"kind":"inventory-view","viewId":serial,"title":"Native retained controls","items":items,"layout":[{"slot":2,"x":0,"y":0,"w":40,"h":80,"label":"Chest"}],"page":0,"summary":{"gold":100,"capacity":100,"weight":1},"armorClass":15,"container":{},"store":store}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var parent:=Control.new(); root.add_child(parent); parent.size=Vector2(1280,800)
	var ui:=Inventory.new(); parent.add_child(ui); ui.setup(""); ui.open()
	var own:=row(101,"I"); var pack:=row(102,"R")
	ui.receive(view(1,[own,pack])); await frames()
	var first=ui.buttons[101]; var second=ui.buttons[102]; var identity: int=first.get_instance_id(); var packed_identity: int=second.get_instance_id()
	check(first.current() and second.current(),"Initial native item controls own the admitted view")
	own.tooltip=Rich.parse("<c"+String.chr(1)+String.chr(255)+String.chr(1)+">Changed</c>"); own.stack=3; own.pending=true
	ui.receive(view(2,[own,pack])); await frames()
	check(ui.buttons[101].get_instance_id()==identity and ui.buttons[102].get_instance_id()==packed_identity,"Caption/stack/pending updates retain actual equipment and repository controls")
	check(first.current() and first.bound_view==2 and first.row.tooltip==own.tooltip and first.count.text=="3" and first.disabled,"Retained item receives current rich text, count, pending state and input view ownership")
	for serial in range(3,23):
		var update:=view(serial,[own,pack]); update.summary.gold=serial; update.armorClass=serial; ui.receive(update)
	await frames()
	check(first.get_instance_id()==identity and first.current() and ui.ac.text=="AC: 22","Unrelated header/summary updates cannot retire a hovered item control")
	var retired: WeakRef=weakref(second); pack.x=1; ui.receive(view(23,[own,pack])); await frames()
	check(retired.get_ref()==null and ui.buttons[102].position.x==ui.repository.cell_size and ui.buttons[101].get_instance_id()==identity,"Real item-layout changes retire only the changed geometry and retain the equipped control")
	var added:=row(103,"R",4); ui.receive(view(230,[own,pack,added])); await frames()
	check(ui.buttons[101].get_instance_id()==identity and ui.buttons[102].current() and ui.buttons.has(103),"Newly received backpack items cannot retire an equipped hover control")
	var added_owner: WeakRef=weakref(ui.buttons[103]); ui.receive(view(231,[own,pack])); await frames()
	check(added_owner.get_ref()==null and ui.buttons[101].get_instance_id()==identity,"Backpack item removal retains unrelated equipment and releases only the removed control")
	# Use independent received rows here; a server update does not mutate the
	# already published row's occupant in place.
	var carried_own: Dictionary=own.duplicate(true); carried_own.channel="R"; carried_own.slot=0; carried_own.x=5
	var replacement:=row(104,"I"); ui.receive(view(232,[carried_own,pack,replacement])); await frames()
	check(ui.buttons[104].get_instance_id()==identity and ui.buttons[101].get_parent()==ui.repository and ui.buttons[104].row.itemId==104,"Equipment occupancy changes reuse the original slot while the old item receives distinct carried ownership")
	var temporary_owner: WeakRef=weakref(ui.buttons[101]); ui.receive(view(233,[own,pack])); await frames()
	check(temporary_owner.get_ref()==null and ui.buttons[101].get_instance_id()==identity and not ui.buttons.has(104),"Reequipping restores the same slot and retires obsolete carried and previous-occupant references")
	var store:={"open":true,"generation":1,"panel":0,"page":0,"pageCount":2,"labels":["A","B","C","D","E"],"gold":1000,"navigationPending":false}
	var stock:=row(201,"M"); own.pending=false; ui.receive(view(24,[own,pack,stock],store)); await frames()
	var merchant=ui.buttons[201]; var merchant_identity: int=merchant.get_instance_id()
	check(merchant.current() and merchant.get_parent()==ui.store_panel.repository,"Original merchant presentation owns the stock control")
	stock.tooltip=Rich.parse("Merchant update"); stock.price=7; stock.stack=4; store.gold=900; ui.receive(view(25,[own,pack,stock],store)); await frames()
	check(ui.buttons[201].get_instance_id()==merchant_identity and merchant.current() and merchant.row.tooltip==stock.tooltip and merchant.count.text=="4","Merchant metadata/price updates preserve the live hover owner and update its current content")
	var extra:=row(202,"M",1); ui.receive(view(26,[own,pack,stock,extra],store)); await frames()
	check(ui.buttons[201].get_instance_id()==merchant_identity and merchant.current() and ui.buttons.has(202),"Incrementally received merchant stock does not retire the existing hovered item")
	var old_extra: WeakRef=weakref(ui.buttons[202]); extra.x=3; ui.receive(view(27,[own,pack,stock,extra],store)); await frames()
	check(old_extra.get_ref()==null and ui.buttons[202].position.x==3*ui.store_panel.repository.cell_size and ui.buttons[201].get_instance_id()==merchant_identity,"Changed stock geometry retires only that item's control")
	old_extra=weakref(ui.buttons[202]); ui.receive(view(28,[own,pack,stock],store)); await frames()
	check(old_extra.get_ref()==null and not ui.buttons.has(202) and ui.buttons[201].get_instance_id()==merchant_identity,"Removed stock releases its control without retiring surviving stock")
	var page_retired: WeakRef=weakref(merchant); store.page=1; stock.y=10; ui.receive(view(29,[own,pack,stock],store)); await frames()
	merchant=ui.buttons[201]
	check(page_retired.get_ref()==null and merchant.current() and merchant.row.y==10,"Changing merchant pages retires the previous page's input ownership")
	var old_stock: WeakRef=weakref(merchant); stock.channel="R"; stock.x=2; stock.y=0; ui.receive(view(30,[own,pack,stock],{})); await frames()
	check(old_stock.get_ref()==null and ui.buttons[201].get_parent()==ui.repository and ui.buttons[201].current(),"Merchant-to-player ownership change retires stock geometry without deleting its new carried control")
	var carried=ui.buttons[201]; ui.close_inventory(); await frames()
	check(not carried.current(),"Closing the window invalidates retained controls before they can send item input")
	var ending: WeakRef=weakref(carried); ui.reset(); await frames()
	check(ending.get_ref()==null and ui.buttons.is_empty(),"Full inventory retirement releases retained controls and their input owners")
	ui.queue_free(); parent.queue_free(); await frames()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual native inventory/store control identity, metadata/state refresh and retirement; authored views, no server or pixel claim."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
