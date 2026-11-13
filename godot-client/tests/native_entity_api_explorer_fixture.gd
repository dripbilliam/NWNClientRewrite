extends SceneTree
# An owned loopback-only browser test fixture. File controls are test-only;
# production HTTP retains exactly its read-only GET routes.
const API=preload("res://systems/client_api/client_api.gd")
var objects: Dictionary={}
var motion: Dictionary={}
var fixture_directory:=""
var sequence:=0
var generation:=1
var area_id:=7
var api: Node
var binding: RefCounted
func _initialize() -> void: call_deferred("run")
func write_json(name: String,data: Dictionary) -> void:
	var file:=FileAccess.open(fixture_directory.path_join(name),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(data,"  ")+"\n"); file.close()
func object(id: int,life: int=1) -> Dictionary:
	var name: Dictionary={"firstName":{"text":"Scout"},"lastName":{"text":"<img src=x onerror=globalThis.__entityXss=1>"}} if id==1 and life==1 else {"firstName":{"text":"Replacement" if id==1 else "Fixture "+str(id)},"lastName":{"strRef":999}}
	return {"id":id,"nativeLifetime":life,"objectType":5 if id<=40 else 9,"areaId":area_id,"replicated":{"name":name,"position":[1,2,3],"stats":{"armorClass":null}},"appearance":{"parts":[{"id":3}]},"clientAbilityCache":{"base":null,"bonuses":[0,0,0,0,0,0],"dex":0}}
func commit(rows: Array,removed: Array=[],full: bool=false) -> void:
	if full: objects.clear()
	for id in removed: objects.erase(int(id)); motion.erase(int(id))
	for row in rows: objects[int(row.id)]=row
	binding.commit(1,generation,area_id,{"bridgeMode":"full" if full else "delta","objects":rows,"removedObjectIds":removed,"controlledId":1})
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-directory="): fixture_directory=argument.trim_prefix("--fixture-directory=")
	if fixture_directory.is_empty(): quit(2); return
	api=API.install(root)
	binding=api.bind_native(func(id):return objects.get(id),func(id):return motion.get(id))
	var rows: Array=[]
	for id in range(1,61): rows.append(object(id))
	commit(rows,[],true)
	motion[1]={"lifetime":1,"position":Vector3(9,8,7),"render":Vector3(8,8,7),"orientation":Vector3(1,0,0),"active":true}
	var status: Dictionary=api.rest_status()
	write_json("ready.json",{"listening":status.listening,"port":status.get("port"),"discovery_path":status.get("discovery_path"),"explorer_url":"http://127.0.0.1:"+str(status.get("port",0))+"/explorer/"})
	var deadline:=Time.get_ticks_msec()+90000
	while not FileAccess.file_exists(fixture_directory.path_join("stop.json")) and Time.get_ticks_msec()<deadline:
		var control_path:=fixture_directory.path_join("control-"+str(sequence+1)+".json")
		if FileAccess.file_exists(control_path):
			var raw:=FileAccess.open(control_path,FileAccess.READ)
			var command: Variant=JSON.parse_string(raw.get_as_text()) if raw!=null and raw.get_length()<4096 else null
			if raw!=null: raw.close()
			if command is Dictionary and int(command.get("serial",0))>sequence:
				sequence=int(command.serial)
				match str(command.get("action","")):
					"remove": commit([],[1])
					"reuse": commit([object(1,2)]); motion[1]={"lifetime":2,"position":Vector3(12,8,7),"render":Vector3(11,8,7)}
					"transition":
						generation+=1; area_id=8; var changed: Array=[]
						for id in range(1,6): changed.append(object(id,2))
						commit(changed,[],true)
				write_json("ack.json",{"serial":sequence,"scope":api.entities.get_scope()})
		await process_frame
	var stopped:=FileAccess.file_exists(fixture_directory.path_join("stop.json"))
	var server: Node=api.get_node_or_null("EntityRest")
	var diagnostics: Dictionary=server.diagnostics() if server!=null else {}
	api.stop_rest()
	var cleaned: bool=not FileAccess.file_exists(str(status.get("discovery_path","")))
	write_json("fixture-report.json",{"success":stopped and cleaned,"checks":2,"stopped":stopped,"discovery_removed":cleaned,"server_diagnostics":diagnostics,"gameServerConnections":0,"publicConnections":0,"scope":"Owned Godot HTTP fixture with authored entity owners for external browser validation; no running game-client process or renderer integration"})
	api.free(); await process_frame; quit(0 if stopped and cleaned else 1)
