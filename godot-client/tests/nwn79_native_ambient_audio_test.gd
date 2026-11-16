extends SceneTree
const Owner=preload("res://systems/native_data/native_ambient_audio_owner.gd")
class FakeCatalog:
	extends RefCounted
	var available: Dictionary={"daytrack:4":true,"nighttrack:4":true,"battle:4":true,"end_battle:4":true,"daywind:4":true,"nightwind:4":true,"day:4":true}
	func has_resource(name: String,type: int)->bool:return available.has(name.to_lower()+":"+str(type))
class FakeAssets:
	extends Node
	signal completed(id: int,result: Dictionary)
	var serial:=0
	var failure: String=""
	var requests: Array[Dictionary]=[]
	func request(name: String,type: int,decoder: String)->int:
		serial+=1;requests.append({"id":serial,"name":name,"type":type,"decoder":decoder});return serial
	func deliver(id: int,result: Dictionary)->void:completed.emit(id,result)
	func latest(name: String)->int:
		for index in range(requests.size()-1,-1,-1):
			if str(requests[index].name).to_lower()==name.to_lower():return int(requests[index].id)
		return -1
var fixture: Dictionary={}
var checks:=0
func _initialize()->void:call_deferred("run")
func check(value: bool,description: String)->bool:
	checks+=1
	if not value:printerr("NWN79 ambient audio owner failed: "+description);quit(1)
	return value
func pcm()->PackedByteArray:
	var bytes:=PackedByteArray();bytes.resize(1600)
	for index in 800:bytes.encode_s16(index*2,roundi(sin(float(index)*TAU*220.0/8000.0)*4000.0))
	return bytes
func result()->Dictionary:
	var data:=pcm()
	return {"bytes":data,"value":{"codec":"pcm16","channels":1,"sampleRate":8000,"frames":800,"pcm":data},"error":""}
func run()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_ambient_audio_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1:check(false,"Fixture unavailable");return
	fixture=parsed
	var catalog:=FakeCatalog.new();var assets:=FakeAssets.new();root.add_child(assets)
	var owner:=Owner.new();root.add_child(owner);owner.configure(catalog,"",assets)
	if not check(owner.attach(fixture.area),"Area attaches"):return
	if not check(owner.snapshot().loading and assets.requests.size()==2,"Two Godot table requests queue before playback"):return
	var update: Dictionary={"kind":"ambient-command","operation":3,"day":true,"value":4}
	if not check(owner.receive(update) and owner.snapshot().pending==1,"Command queues during table IO"):return
	assets.deliver(assets.latest("ambientmusic"),{"value":fixture.music,"error":""})
	if not check(owner.snapshot().loading and owner.snapshot().pending==1,"First table preserves queued command"):return
	assets.deliver(assets.latest("ambientsound"),{"value":fixture.ambient,"error":""})
	if not check(owner.snapshot().active and owner.snapshot().pending==0 and owner.snapshot().fields["10"]==4,"Queued update applies after initial area state"):return
	if not check(owner.snapshot().channels.music.name=="day.wav" and owner.snapshot().channels.music.status=="failed","Extension is literal resref and does not silently strip to found asset"):return
	if not check(owner.snapshot().channels.ambient.name=="daywind" and assets.latest("daywind")>0,"Ambient track resolves case-insensitively via catalog WAV type"):return
	var ambient_job:=assets.latest("daywind");assets.deliver(ambient_job,result())
	if not check(owner.snapshot().channels.ambient.status=="playing" and owner.ambient.stream!=null,"Godot stream is created and started from decoded catalog bytes"):return
	if not check(Owner.track(fixture.music,1,true)=={"resource":"battle","stingers":["end_battle","",""]},"Original table Resource/Stinger columns map without invented fallback"):return
	if not check(Owner.track(fixture.music,999,true).resource=="","Missing track remains empty"):return
	owner.receive({"kind":"ambient-command","operation":3,"day":true,"value":2})
	if not check(owner.snapshot().channels.music.name=="daytrack" and assets.latest("daytrack")>0,"Music update requests exact found resource"):return
	var music_job:=assets.latest("daytrack");assets.deliver(music_job,result())
	if not check(owner.snapshot().channels.music.status=="playing" and owner.music.stream!=null,"Decoded music stream starts"):return
	var daywind_count:=assets.requests.filter(func(row):return row.name=="daywind").size()
	owner.receive({"kind":"ambient-command","operation":8,"day":true,"value":77})
	if not check(owner.snapshot().fields["2c"]==77 and is_equal_approx(owner.ambient.volume_linear,77.0/127.0) and assets.requests.filter(func(row):return row.name=="daywind").size()==daywind_count,"Volume command updates gain without reloading audio"):return
	owner.day_night(2)
	if not check(owner.snapshot().channels.music.name=="nighttrack" and owner.snapshot().channels.ambient.name=="nightwind","Night transition selects night resources"):return
	var old_job:=assets.latest("nighttrack")
	owner.detach()
	assets.deliver(old_job,result())
	if not check(not owner.snapshot().active and owner.snapshot().channels.is_empty() and owner.music.stream==null and owner.ambient.stream==null,"Area departure retires streams and stale completion"):return
	if not check(owner.attach(fixture.area),"New area generation attaches"):return
	if not check(owner.snapshot().active and owner.snapshot().generation>1,"Cached tables are reused on next area generation"):return
	owner.receive({"kind":"ambient-command","operation":2,"value":1400})
	if not check(owner.delay_ms==1400 and owner.snapshot().fields["c"]==5000,"Delay command changes timer without rewriting packed area field"):return
	owner.receive({"kind":"ambient-command","operation":4,"play":true})
	if not check(owner.snapshot().fields["18"]==1 and owner.snapshot().channels.music.name=="battle","Battle command selects battle track"):return
	assets.deliver(assets.latest("battle"),result())
	owner.receive({"kind":"ambient-command","operation":4,"play":false})
	if not check(owner.snapshot().fields["18"]==0 and owner.snapshot().channels.stinger.name=="end_battle" and assets.latest("end_battle")>0,"Battle end starts 2DA stinger through Godot asset service"):return
	assets.deliver(assets.latest("end_battle"),result())
	if not check(owner.stinger.stream!=null,"Stinger decodes and starts in Godot"):return
	owner.receive({"kind":"ambient-command","operation":1,"play":false})
	owner.receive({"kind":"ambient-command","operation":6,"play":false})
	if not check(owner.snapshot().channels.music.name=="" and owner.snapshot().channels.ambient.name=="","Music and ambient stop commands retire both streams"):return
	owner.receive({"kind":"ambient-command","operation":7,"day":true,"value":2})
	if not check(owner.snapshot().fields["24"]==2,"Ambient track command retains area-state slot"):return
	if not check(not owner.receive({"kind":"ambient-command","operation":9,"value":1}),"Unsupported ambient operation rejected"):return
	owner.close()
	if not check(not owner.receive({"kind":"ambient-command","operation":1,"play":true}) and not owner.snapshot().active,"Closed owner rejects commands"):return
	owner.free();assets.free()
	print("NWN79 Godot ambient audio owner PASS: checks=",checks," queued_order=true resource_case_extension=true lifecycle=true")
	quit(0)
