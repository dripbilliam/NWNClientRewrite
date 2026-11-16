extends SceneTree
const Controller=preload("res://systems/native_data/godot_login_profile_controller.gd")
const KEY="ABCDE-FGHIJ-KLMNO-PQRST-UVWXY-12345-67890"
var replies: Array[Dictionary]=[]
var changes: Array[Dictionary]=[]
var controller
var directory: String

func _initialize()->void:
	directory=ProjectSettings.globalize_path("res://.cache/nwn79/test-login-controller-"+str(Time.get_ticks_usec()))
	controller=Controller.new()
	var lock:={"value":false}
	if not controller.open(directory,"",7,func(message: Dictionary):replies.append(message),func()->bool:return lock.value,func(status: Dictionary):changes.append(status)):
		fail("open: "+controller.error);return
	request("open",1)
	if not check(replies[-1].kind=="login-profiles-view" and replies[-1].profiles.is_empty() and replies[-1].connection==7,"fresh view"):return
	var old_view: int=replies[-1].viewId
	var values:={"label":"Main","playerName":"Druid","cdKey":KEY}
	request("save",2,{"viewId":old_view,"values":values})
	if not check(values.cdKey=="" and changes.size()==1 and replies[-1].kind=="login-profiles-view" and replies[-1].profiles.size()==1,"create profile and clear submitted key"):return
	var profile_id: String=changes[-1].activeProfileId
	if not check(controller.active_player_name()=="Druid" and changes[-1].hasSavedCdKey,"active metadata"):return
	request("delete",3,{"viewId":old_view,"profileId":profile_id})
	if not check(replies[-1].kind=="login-profiles-notice" and changes.size()==1,"stale view rejected"):return
	lock.value=true
	request("delete",4,{"viewId":controller.view_id,"profileId":profile_id})
	if not check(replies[-1].kind=="login-profiles-notice" and changes.size()==1,"connected profile locked"):return
	lock.value=false
	request("delete",5,{"viewId":controller.view_id,"profileId":profile_id})
	if not check(changes.size()==2 and changes[-1].loginProfiles.is_empty(),"delete profile"):return
	request("save",6,{"viewId":controller.view_id,"values":{"label":"Recovered","playerName":"Druid","cdKey":"BAD"}})
	if not check(replies[-1].kind=="login-profiles-notice" and changes.size()==2,"bad key recoverable"):return
	request("save",7,{"viewId":controller.view_id,"values":{"label":"Recovered","playerName":"Druid","cdKey":KEY}})
	if not check(changes.size()==3 and changes[-1].loginProfiles.size()==1,"valid key recovery"):return
	request("close",8)
	request("delete",9,{"viewId":controller.view_id,"profileId":changes[-1].activeProfileId})
	if not check(changes.size()==3,"closed view rejected"):return
	controller.close()
	DirAccess.remove_absolute(directory.path_join("client-settings.json"))
	DirAccess.remove_absolute(directory)
	print("NWN79 Godot login profile controller PASS")
	quit(0)

func request(operation: String,id: int,fields: Dictionary={})->void:
	var message:={"kind":"login-profile-input","connection":7,"operation":operation,"requestId":id,"viewId":controller.view_id}
	message.merge(fields,true)
	controller.handle(message)

func check(ok: bool,stage: String)->bool:
	if not ok:fail(stage)
	return ok

func fail(stage: String)->void:
	printerr("NWN79 Godot login profile controller failed: "+stage)
	if controller!=null:controller.close()
	quit(1)
