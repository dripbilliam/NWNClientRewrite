extends SceneTree
const Store=preload("res://systems/native_data/client_settings_store.gd")
const KEY="ABCDE-FGHIJ-KLMNO-PQRST-UVWXY-12345-67890"
const ALT="ZZZZZ-YYYYY-XXXXX-WWWWW-VVVVV-UUUUU-TTTTT"

func _initialize()->void:
	var directory:=ProjectSettings.globalize_path("res://.cache/nwn79/test-settings-"+str(Time.get_ticks_usec()))
	var first=Store.new()
	if not first.open(directory):fail("open",first.error);return
	if not first.update({"cdKey":KEY}):fail("save",first.error);return
	if first.status().hasSavedCdKey!=true:fail("status","missing key");return
	if not first.update({"disabledMods":["local","123","local","123"]}) or first.status().disabledMods!=["local","123"]:fail("mod selection","duplicate IDs were not collapsed in first-seen order");return
	if not first.save_profile({"label":"Main","playerName":"Druid","cdKey":KEY}):fail("profile save",first.error);return
	var main_id: String=first.status().activeProfileId
	if not first.save_profile({"label":"Alt","playerName":"Wizard","cdKey":ALT}):fail("alternate save",first.error);return
	var alt_id: String=first.status().activeProfileId
	if not first.select_profile(main_id):fail("profile select",first.error);return
	first.close()
	var second=Store.new()
	if not second.open(directory):fail("reopen",second.error);return
	if second.cd_key().get("cdKey","")!=KEY:fail("unlock","key mismatch");return
	if second.status().loginProfiles.size()!=2:fail("reopen","profiles missing");return
	var stale=Store.new()
	if not stale.open(directory):fail("concurrent open",stale.error);return
	if not second.select_profile(alt_id) or second.cd_key().get("cdKey","")!=ALT:fail("alternate select",second.error);return
	var latest:=FileAccess.get_file_as_string(directory.path_join("client-settings.json"))
	if stale.update({"modsDirectory":""}) or FileAccess.get_file_as_string(directory.path_join("client-settings.json"))!=latest:fail("concurrent write","stale owner replaced newer settings");return
	stale.close()
	if not second.delete_profile(alt_id):fail("profile delete",second.error);return
	if second.status().activeProfileId!=null or second.cd_key().get("cdKey","")!=KEY:fail("profile fallback","legacy key mismatch");return
	if not second.update({"removeCdKey":true}):fail("remove",second.error);return
	if second.status().hasSavedCdKey:fail("remove","key still set");return
	second.state.protectedCdKey=Marshalls.raw_to_base64("NWN1corrupt".to_utf8_buffer())
	if not second.cd_key().has("error"):fail("corrupt","unlock unexpectedly succeeded");return
	if not second.update({"cdKey":KEY}) or second.cd_key().get("cdKey","")!=KEY:fail("recovery",second.error);return
	second.close()
	DirAccess.remove_absolute(directory.path_join("client-settings.json"))
	DirAccess.remove_absolute(directory)
	print("NWN79 Godot settings roundtrip PASS")
	quit(0)

func fail(stage: String,detail: String)->void:
	printerr("NWN79 Godot settings "+stage+" failed: "+detail)
	quit(1)
