extends SceneTree
const Fields=preload("res://systems/native_render/native_creature_visibility_fields.gd")
const Hooks=preload("res://systems/native_render/native_scene_shadow_hooks.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
var checks:=0
var failures: Array=[]
var report:=""
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func birth(id: int,physical: String,certified: bool=true,ownership: String="new") -> Dictionary:
	return {"version":2,"objectId":id,"objectType":5,"operation":"create","ownership":ownership,"physicalToken":physical,"lifecycleEpoch":3,"constructionCertified":certified,"aiRegistrationCertified":certified,"constructionHistoryComplete":certified}
func row(id: int,physical: String,native_lifetime: int=1) -> Dictionary:
	return {"id":id,"objectType":5,"nativeLifetime":native_lifetime,"nativeClockOwner":{"version":1,"source":"native-client-clock-owner-v1","epoch":3,"connection":7,"physicalCurrent":true,"physicalToken":physical}}
func event(serial: int,id: Variant,token: Variant,permission: bool,value: bool) -> Dictionary:
	return {"kind":"raw-creature-visibility-permission","connection":7,"serial":serial,"actorId":id,"lifetime":token,"permission":permission,"field114":value,"recipientOwner":null if id==null else {"version":1,"source":"native-client-clock-owner-v1","epoch":3,"connection":7,"physicalCurrent":true,"physicalToken":"physical1" if id==1 else "physical2"}}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var facts:={"current":true};var fields:=Fields.new()
	check(fields.configure(7,func(connection):return connection==7 and facts.current).available,"Scoped local visibility owner configures")
	var source:=row(1,"physical1");var token:=Lifetime.token(source)
	check(not fields.bind(source).available and not fields.fields(1,token).available,"First snapshot/model presence cannot invent constructor zero fields")
	check(not fields.accepted_lifecycle(birth(1,"physical1",false)).available,"Incomplete native construction history is explicit unavailable")
	check(fields.accepted_lifecycle(birth(1,"physical1")).constructed and fields.bind(source).available,"Only certified native lifecycle birth seeds local110/114")
	check(fields.fields(1,token).creature110==0 and fields.fields(1,token).creature114==0,"Native CNWCCreatureStats constructor really initializes both fields zero")
	fields.controlled_changed(1,token)
	check(not fields.fields(1,token).available,"Certified constructor does not invent current controlled DM permission")
	check(not fields.initialize_connection_permission({"source":"native_dm_permission_31_22","permission":0,"field114":0,"parameter":0}).available,"Sticky server permission record cannot masquerade as connection16 initialization")
	check(fields.initialize_connection_permission({"source":"native_connection_start_16","permission":0,"field114":null,"parameter":null}).available,"Exact native connection16 initialization certifies ordinary permission once")
	check(fields.receive_connection_permission(false).available and fields.ai(1,token,{}).available,"Ordinary connection false branch requires no guessed DM getter or GUI owner")
	check(fields.receive(event(1,1,token,false,true)).available and fields.fields(1,token).creature114==1,"Fresh received secondBOOL writes only current physical creature114")
	check(not fields.receive(event(1,1,token,false,false)).available and fields.fields(1,token).creature114==1,"Duplicate serial cannot reapply sticky snapshot fields")
	check(not fields.receive(event(2,2,[],false,false)).available and fields.snapshot().serial==1,"Malformed recipient reference cannot consume valid next serial")
	check(fields.receive(event(2,1,token,true,false)).available and not fields.fields(1,token).available,"Positive DM controlled owner needs its exact AI branch before fields publication")
	check(not fields.ai(1,token,{}).available,"Missing original getter is not substituted with zero")
	check(fields.ai(1,token,{"controlled_getter6ac1b0":1}).available and fields.fields(1,token).creature110==0,"Nonzero original getter skips GUI/110 write exactly")
	fields.receive(event(3,1,token,true,false))
	check(not fields.ai(1,token,{"controlled_getter6ac1b0":0}).available,"Positive branch requires explicit GUI presence")
	var applied:=fields.ai(1,token,{"controlled_getter6ac1b0":0,"gui_present":true,"gui674":1})
	check(applied.available and applied.changed and applied.statusA8==3 and applied.request_target and fields.fields(1,token).creature110==1 and fields.fields(1,token).creature114==1,"Actual DM branch writes110, optionalGUI114 and requests native target setter")
	check(fields.ai(1,token,{}).available and fields.stats.ai_writes==1,"Already-nonzero110 native branch does not repeat or require unused fields")
	var remote:=row(2,"physical2");var remote_token:=Lifetime.token(remote)
	fields.accepted_lifecycle(birth(2,"physical2"));fields.bind(remote)
	check(fields.fields(2,remote_token).creature110==0 and fields.fields(2,remote_token).creature114==0,"Current controlled permission never projects onto every remote NPC")
	fields.receive(event(4,1,token,false,true))
	check(fields.fields(1,token).creature110==0 and fields.fields(1,token).creature114==1,"Received permissionfalse clears110 and still applies secondBOOL114")
	check(fields.initialize_connection_permission({"source":"native_connection_start_16","permission":0,"field114":null,"parameter":null}).available and fields.fields(1,token).creature114==1,"Reobserved connection initializer cannot overwrite a later received114 write")
	var copied:=fields.fields(1,token);copied.creature114=99
	check(fields.fields(1,token).creature114==1,"Detached field results cannot mutate local native cache")
	check(fields.accepted_lifecycle(birth(1,"physical1",false,"retained")).available,"Actual retained physical owner survives area-transfer constructor callback")
	var changed:=row(1,"physical1",2);var changed_token:=Lifetime.token(changed)
	check(fields.bind(changed).available and fields.fields(1,changed_token).creature114==1 and not fields.fields(1,token).available,"New disclosure reference retains physical fields but invalidates old lifetime queries")
	fields.controlled_changed(1,changed_token)
	check(fields.receive(event(5,1,token,false,false)).recipient_available and fields.fields(1,changed_token).creature114==0,"Delayed prior-area reference writes only its exact retained physical recipient")
	fields.accepted_lifecycle(birth(1,"physical-reused"));var reused:=row(1,"physical-reused",3);var reused_token:=Lifetime.token(reused)
	check(fields.bind(reused).available and fields.fields(1,reused_token).creature114==0 and not fields.bind(changed).available,"Same-ID fresh physical construction starts real constructor state and rejects previous physical owner")
	fields.controlled_changed(null)
	check(fields.receive(event(6,null,null,true,true)).available and fields.fields(1,reused_token).creature114==0,"Permission with no controlled creature stores global permission without a fabricated target")
	check(fields.receive(event(7,1,changed_token,false,true)).recipient_available==false and fields.fields(1,reused_token).creature114==0 and fields.snapshot().permission==false,"Old physical recipient after same-ID reuse cannot mutate successor, while global permission still updates")
	var unknown:=birth(1,"physical-reused",false);unknown.operation="remove"
	check(not fields.accepted_lifecycle(unknown).available and not fields.fields(1,reused_token).available,"Retirement/ambiguous native owner never leaves previous physical fields queryable")
	facts.current=false;check(not fields.bind(remote).available,"Connection fence rejects retained cache access")
	fields.close();check(not fields.fields(2,remote_token).available,"Closed owner cannot resurrect fields")
	for detail in [0,1,2]:
		for controlled in [false,true]:
			for reveal in [false,true]:
				var selected:=Hooks.plan({"kind":"native_reveal_hooks","setter":"target765920","revealed":reveal,"render_owner_present":true,"native_field108":0},detail,controlled)
				var dynamic: bool=reveal and (detail==2 or detail==1 and controlled)
				var blob: bool=not dynamic if reveal else detail==0
				check(selected.available and selected.commands[0]=={"kind":"native_shadow","enabled":dynamic} and selected.commands[1].attached==blob and selected.store_revealF4==reveal,"Exact native detail/control/reveal branch "+str([detail,controlled,reveal]))
	var command:={"kind":"native_reveal_hooks","setter":"immediate765c80","revealed":true,"render_owner_present":false,"native_field108":0}
	check(Hooks.plan(command,2,true).store_revealF4==null,"Positive immediate absent wrapper does not manufacture native F4 assignment")
	command.revealed=false;check(Hooks.plan(command,0,true).store_revealF4==false,"Negative immediate absent wrapper still clears native F4")
	command.revealed=true;command.render_owner_present=true;command.native_field108=1
	check(Hooks.plan(command,2,true).commands.is_empty() and Hooks.plan(command,2,true).store_revealF4==null,"Positive immediate blocked108 executes no render hooks")
	check(not Hooks.plan(command,"player",true).available,"Renderer shadow detail cannot be inferred from account/client role")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Exact certified physical-constructor/DM local cache, mutation/lifetime isolation and native shadow-detail hook planning. Authored ordered inputs; no live client, GPU, shadowblob implementation or native fade timing acceptance."}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_VISIBILITY_LOWERS ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
