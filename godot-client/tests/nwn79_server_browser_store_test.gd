extends SceneTree
const Store=preload("res://systems/native_data/godot_server_browser_store.gd")

func _initialize()->void:
	var directory:=ProjectSettings.globalize_path("res://.cache/nwn79/test-browser-store-"+str(Time.get_ticks_usec()))
	var file:=directory.path_join("native-server-browser.json")
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:fail("fixture directory");return
	var old:={"version":1,"history":[{"host":"Arelith.example","port":5121,"serverName":"Arelith","moduleName":"ARE","playerCount":34},{"host":"bad:url","port":5121}],"favorites":[{"host":"127.0.0.1","port":5121,"serverName":"Local"}],"browserFilters":{"hideEmpty":true,"hideFull":false,"module":"ARE"},"profileDefault":"Druid","last":{"host":"Arelith.example","port":5121,"name":"Druid"}}
	var writer:=FileAccess.open(file,FileAccess.WRITE);writer.store_string(JSON.stringify(old));writer.close()
	var first=Store.new()
	if not first.open(file):fail("legacy read: "+first.error);return
	if first.rows("History").size()!=1 or first.rows("Favorites").size()!=1 or first.state.browserFilters.module!="ARE":fail("legacy normalization");return
	if not first.favorite({"host":"arelith.example","port":5121,"serverName":"Arelith"},true):fail("favorite save: "+first.error);return
	if not first.remember({"host":"127.0.0.1","port":5121,"serverName":"Private Prelude"},"Tester"):fail("recent save: "+first.error);return
	if not first.profile("Tester"):fail("profile save: "+first.error);return
	var second=Store.new()
	if not second.open(file):fail("reopen: "+second.error);return
	if second.rows("History").size()!=2 or second.rows("Favorites").size()!=2 or second.state.profileDefault!="Tester" or second.state.last.name!="Tester":fail("persisted rows");return
	if not second.favorite({"host":"arelith.example","port":5121},false) or second.rows("Favorites").size()!=1:fail("favorite removal");return
	DirAccess.remove_absolute(file)
	DirAccess.remove_absolute(directory)
	print("NWN79 Godot server browser store PASS")
	quit(0)

func fail(stage: String)->void:
	printerr("NWN79 Godot server browser store failed: "+stage)
	quit(1)
