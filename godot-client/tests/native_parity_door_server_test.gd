extends SceneTree
# Minimal native presentation receiver for actual loopback-authoritative door
# state. No fabricated state changes, server outcomes or window/GPU rendering.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Door=preload("res://systems/native_render/door_instance.gd")
const Names=preload("res://systems/native_data/object_animation.gd")
const Frames=preload("res://systems/bridge_frames.gd")
const Conversation=preload("res://systems/server_conversation.gd")
const TalkText=preload("res://systems/native_data/talk_text.gd")
var peer:=StreamPeerTCP.new()
var frames:=Frames.new()
var catalog:=Catalog.new()
var service
var pool:=Pool.new()
var ticket: Dictionary={}
var report:=""
var checks:=0
var failures: Array=[]
var tables: Dictionary={}
var jobs: Dictionary={}
var selected: Dictionary={}
var door
var model_requested:=false
var hello:=false
var finished:=false
var version:=-1
var acknowledged:=-1
var observations: Array=[]
var events: Array=[]
var text:=TalkText.new()
var conversation
var talking:=-1
var dialog_choices:=0
var feedback: Array=[]

func _initialize() -> void:call_deferred("start")
func check(value: bool,context: String) -> void:
	checks+=1
	if not value:failures.append(context)
func send(value: Dictionary) -> void:
	if peer.get_status()==StreamPeerTCP.STATUS_CONNECTED:peer.put_data((JSON.stringify(value)+"\n").to_utf8_buffer())
func fail(reason: String) -> void:
	if finished:return
	check(false,reason);send({"kind":"failed","reason":reason});finish()
func finish() -> void:
	if finished:return
	finished=true
	if is_instance_valid(door):door.retire()
	if is_instance_valid(service):service.close()
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify({"success":failures.is_empty() and observations.size()>=3,"checks":checks,"failures":failures,"observations":observations,"events":events,"feedback":feedback,"dialog_choices":dialog_choices,"public_connections":0,"scope":"Real loopback server door replication consumed by current native DoorInstance and original installed tables/models; actual ServerConversation choice dispatch, no visual/server-emulation/FPS claim"},"  "));file.close()
	send({"kind":"finished","success":failures.is_empty() and observations.size()>=3});peer.disconnect_from_host()
	quit(0 if failures.is_empty() and observations.size()>=3 else 1)

func start() -> void:
	var ticket_path:="";var install:="";var cache_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticket="):ticket_path=arg.substr(9)
		elif arg.begins_with("--report="):report=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
		elif arg.begins_with("--cache="):cache_path=arg.substr(8)
	if report.is_empty() or ticket_path.is_empty() or FileAccess.file_exists(report):quit(2);return
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(ticket_path))
	if not value is Dictionary or value.get("host")!="127.0.0.1" or not value.get("token") is String:quit(3);return
	ticket=value
	check(catalog.mount_install(install),"actual original catalog mounts read-only")
	if not failures.is_empty():fail("Original catalog failed");return
	pool.unshaded=true
	check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"original TLK opens read-only for real dialogue choices")
	conversation=Conversation.new();root.add_child(conversation);conversation.setup(ProjectSettings.globalize_path("user://door-dialog-layout.cfg"))
	conversation.request.connect(func(message):send({"kind":"reply","entryId":message.entryId,"replyId":message.replyId,"abort":message.abort}))
	service=Assets.new();root.add_child(service);service.maximum_workers=1;service.cache_directory=cache_path;service.configure(catalog);service.completed.connect(completed)
	for name in ["genericdoors","doortypes"]:jobs[service.request(name,2017,"2da")]=name
	peer.connect_to_host("127.0.0.1",int(ticket.port))

func completed(id: int,result: Dictionary) -> void:
	if finished:return
	var kind: String=jobs.get(id,"");jobs.erase(id)
	if not str(result.get("error","missing")).is_empty():fail("Actual source preparation failed: "+str(result.get("error")));return
	if kind in ["genericdoors","doortypes"]:tables[kind]=result.value;prepare();return
	if kind!="model":fail("Unmatched asset result");return
	door=Door.new();root.add_child(door)
	var good: bool=door.install_door(result,pool,int(selected.id),selected.replicated)
	check(good,"current production DoorInstance installs actual server-selected model")
	if not good:fail(door.failure);return
	var snapshot: Dictionary=door.native_door_pick_snapshot()
	check(snapshot.regions>0 and snapshot.missing.is_empty(),"server-selected model has actual physical doorway regions")
	if not failures.is_empty():fail("Actual doorway Part regions incomplete");return
	send({"kind":"door-installed","id":int(selected.id),"model":result.resource_name,"regions":snapshot.regions})

func prepare() -> void:
	if model_requested or selected.is_empty() or tables.size()!=2:return
	var state: Dictionary=selected.replicated
	var type: int=int(state.get("doorType",0));var table: Dictionary=tables["genericdoors" if type==0 else "doortypes"]
	var index: int=int(state.get("genericType",-1)) if type==0 else type
	if index<0 or index>=table.orderedRows.size():fail("Server door appearance row unavailable");return
	var row: Dictionary=table.orderedRows[index];var model:=str(row.get("ModelName",row.get("Model",""))).to_lower()
	if model.is_empty() or model=="****":fail("Actual door table model unavailable");return
	model_requested=true;jobs[service.request(model,2002,"actor-model",{"relevant_tracks":true})]="model"

func receive(message: Dictionary) -> void:
	if message.get("kind")=="finish":finish();return
	if message.get("kind")=="talk-target":talking=int(message.targetId);return
	if message.get("kind")=="ui":present_ui(message.message);return
	if message.get("kind")!="door" or not message.get("object") is Dictionary:return
	var next: Dictionary=message.object
	if int(next.get("objectType",-1))!=10 or not next.get("replicated") is Dictionary:fail("Malformed server door projection");return
	if not selected.is_empty() and int(selected.id)!=int(next.id):fail("Authoritative target lifetime changed");return
	if int(message.get("version",-1))<=version:fail("Stale authoritative door projection");return
	selected=next.duplicate(true);version=int(message.version)
	if is_instance_valid(door):
		door.observe_door(selected.replicated)
		events.append({"version":version,"server_state":Names.door_state(selected.replicated),"clip":door.rigs.entities[int(selected.id)].models[0].clip,"pending_rest":door.pending_rest})
	else:prepare()

func present_ui(message: Dictionary) -> void:
	var kind:=str(message.get("kind",""))
	if kind=="dialog-close":
		conversation.reset()
		if talking>=0:send({"kind":"conversation-done","targetId":talking});talking=-1
	elif kind in ["dialog-entry","dialog-selected"]:
		var row:=message.duplicate(true);row.rich={"text":text.raw(message.get("text",{}))};conversation.present(row)
	elif kind=="dialog-replies":
		var replies: Array=[];var offered: Array=message.replies
		for index in offered.size():replies.append({"id":offered[index].id,"rich":{"text":text.raw(offered[index].text)},"available":index<int(message.get("firstCount",offered.size()))})
		if offered.is_empty():replies.append({"id":4294967295,"rich":{"text":"End"},"available":true})
		conversation.present({"kind":"dialog-replies","entryId":message.entryId,"end":message.end,"localEnd":offered.is_empty(),"replies":replies})
		call_deferred("choose_dialog")
	elif kind in ["server-speech","combat-feedback"]:
		if feedback.size()<64:feedback.append({"kind":kind,"text":text.raw(message.get("text",{})),"raw":message.duplicate(true)})

func choose_dialog() -> void:
	if not is_instance_valid(conversation) or not conversation.opened or conversation.pending:return
	dialog_choices+=1
	if dialog_choices>24:fail("Bounded original tutorial dialogue exceeded24 choices");return
	var selected_reply:=-1
	for phrase in ["not interested in a tutorial","not need tutorial","goodbye","time for me to go","not really interested in chatting"]:
		for index in conversation.rows.size():
			if conversation.reply_available[index] and str(conversation.rows[index].rich.text).to_lower().contains(phrase):selected_reply=index;break
		if selected_reply>=0:break
	if selected_reply<0:
		for index in conversation.rows.size():
			if conversation.reply_available[index]:selected_reply=index;break
	if selected_reply<0:fail("Server supplied no available tutorial reply");return
	conversation.choose(conversation.reply_ids[selected_reply])
	if not conversation.opened and talking>=0:send({"kind":"conversation-done","targetId":talking});talking=-1

func _process(_delta: float) -> bool:
	if finished or ticket.is_empty():return false
	peer.poll()
	if peer.get_status()==StreamPeerTCP.STATUS_CONNECTED:
		if not hello:hello=true;send({"kind":"hello","token":ticket.token})
		if peer.get_available_bytes()>0:
			var packet:=peer.get_data(peer.get_available_bytes())
			if packet[0]!=OK:fail("Private loopback receive failed");return false
			for message in frames.feed(packet[1]):receive(message)
			if not frames.failure.is_empty():fail(frames.failure);return false
	if is_instance_valid(door) and version>acknowledged and door.pending_rest<0:
		var state:=Names.door_state(selected.replicated)
		if state not in [0,1,2]:fail("Unsupported authoritative door state");return false
		var clip: String=door.rigs.entities[int(selected.id)].models[0].clip
		var expected: String=Names.name(10,{0:22,1:50,2:51}[state])
		check(door.received_state==state and clip==expected,"real authoritative state reaches matching native rest clip")
		var row:={"kind":"door-rest","id":int(selected.id),"version":version,"state":state,"clip":clip,"expected":expected}
		observations.append(row.duplicate());acknowledged=version;send(row)
	return false
