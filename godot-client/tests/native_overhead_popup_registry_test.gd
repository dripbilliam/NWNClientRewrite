extends SceneTree
const Registry=preload("res://systems/native_overhead_popup_registry.gd")
var checks:=0
var failures: Array=[]
var context:={"connection":3,"generation":7,"areaId":91}
var rows: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func read_row(id: int) -> Dictionary:return rows.get(id,{})
func run() -> void:
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var overlay:=Control.new();root.add_child(overlay)
	var owner:=Registry.new();root.add_child(owner);owner.automatic=false;owner.configure(func():return context,read_row)
	var a:=Control.new();overlay.add_child(a);a.size=Vector2(100,34);a.position=Vector2(200,200)
	var b:=Control.new();overlay.add_child(b);b.size=Vector2(100,34);b.position=Vector2(200,200)
	rows[42]={"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13}
	rows[43]={"id":43,"objectType":5,"areaId":91,"nativeLifetime":9,"clientKnownLifetime":14}
	check(owner.register(42,rows[42]) and owner.register(43,rows[43]),"Exact popup lifetimes register independently")
	owner.offer(42,rows[42],a);owner.offer(43,rows[43],b);owner.frame_layout()
	check(a.position==Vector2(200,200) and b.position!=a.position,"Later popup moves against earlier native construction ordinal")
	check(owner.slots[42].ordinal<owner.slots[43].ordinal,"Registry preserves construction order")
	var first_ordinal: int=owner.slots[42].ordinal
	a.hide();owner.frame_layout();a.show();a.position=Vector2(200,200);b.position=Vector2(200,200)
	owner.offer(43,rows[43],b);owner.offer(42,rows[42],a);owner.frame_layout()
	check(owner.slots[42].ordinal==first_ordinal and a.position==Vector2(200,200) and b.position!=a.position,"Deactivate/reactivate and reverse offer order do not change construction order")
	var speech:=Control.new();overlay.add_child(speech);speech.position=Vector2(200,200);speech.size=Vector2(100,34)
	owner.offer(42,rows[42],speech);owner.frame_layout()
	check(owner.slots.size()==2 and owner.offers[42].view.get_ref()==speech,"Speech and hover share the one exact object popup slot")
	var before: int=owner.slots[42].ordinal;rows[42].clientKnownLifetime=15;owner.observe([42])
	check(not owner.slots.has(42),"Redisclosure retires previous known lifetime and weak offer")
	owner.register(42,rows[42]);check(owner.slots[42].ordinal>before and owner.slots[42].ordinal>owner.slots[43].ordinal,"Reused ID receives a fresh construction ordinal")
	owner.observe([], [42]);check(not owner.slots.has(42),"Removal retires popup slot at received state boundary")
	context.generation=8;owner.observe()
	check(owner.slots.is_empty() and owner.offers.is_empty(),"Transition resets registry without retaining old entity IDs")
	owner.register(43,rows[43]);context.connection=4;owner.frame_layout()
	check(owner.slots.is_empty(),"Reconnect invalidates old popup construction registry")
	context.connection=3;context.generation=7
	var negative:=Control.new();overlay.add_child(negative);negative.position=Vector2(-9,-19);negative.size=Vector2(100,34)
	owner.offer(43,rows[43],negative);owner.frame_layout()
	check(negative.position==Vector2(-9,-19),"Overlap never re-rounds a single negative offscreen popup or clamps it")
	negative.free();owner.frame_layout()
	check(owner.offers.is_empty() and not owner.is_processing(),"Expired/freed views leave no per-frame idle processing")
	check(owner.slots.size()==1,"View expiration retains native logical popup ordinal until source ends")
	owner.close();owner.free();overlay.free()
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Shared speech/nameplate construction registry, GUI-Y reflection and lifecycle with actual passive Controls; isolated CPU/headless, no pixel or live-server acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
