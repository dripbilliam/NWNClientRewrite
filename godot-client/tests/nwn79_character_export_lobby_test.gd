extends SceneTree
const Lobby=preload("res://systems/character_lobby.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func run()->void:
	var lobby=Lobby.new();root.add_child(lobby)
	var requests: Array=[];lobby.request.connect(func(message: Dictionary):requests.append(message.duplicate(true)))
	var entries: Array=[{"id":"nibs-1","name":"Nibs","revision":1,"savedAtUnixMs":1000},{"id":"nibs-2","name":"Nibs newer","revision":2,"savedAtUnixMs":2000}]
	var selecting: Dictionary={"phase":"character-selection","connected":true,"localAllowed":false,"canSelect":true,"selected":"server:17:nibs","choices":[{"key":"server:17:nibs","label":"Server Nibs"}],"savedCharacters":entries}
	lobby.apply_state({"connection":7,"state":selecting})
	check(lobby.choices.item_count==1 and lobby.choices.get_item_text(0)=="Server Nibs","Saved exports are not forged into playable server choices")
	check(lobby.saved_button.visible and lobby.saved_button.text=="Saved characters (2)" and lobby.saved_list.item_count==2,"Ordered saved-character list is visible in lobby")
	check(lobby.saved_list.get_item_metadata(0)=="nibs-1" and lobby.saved_list.get_item_metadata(1)=="nibs-2","Vault IDs retain source order")
	lobby.saved_button.pressed.emit()
	check(lobby.saved_popup.visible,"Saved characters button opens the actual lobby list")
	entries[0].name="Mutated after publication"
	check(lobby.saved_list.get_item_text(0)=="Nibs","Lobby saved list owns its published copy")
	check(lobby.export_button.disabled and not lobby.save_on_disconnect.visible,"Selection phase cannot export a character")
	var playing: Dictionary={"phase":"playing","connected":true,"localAllowed":false,"savedCharacters":entries}
	lobby.apply_state({"connection":7,"state":playing})
	check(not lobby.export_button.disabled and lobby.save_on_disconnect.visible,"Playing server-vault character can export without local-vault admission")
	lobby.export_button.pressed.emit()
	check(requests.size()==1 and requests[-1]=={"kind":"lobby-export","connection":7},"Actual Save Character button sends scoped export request")
	playing.exportStatus={"state":"pending","text":"Saving character…"}
	lobby.apply_state({"connection":7,"state":playing})
	check(lobby.export_button.disabled and lobby.export_status_label.visible and lobby.export_status_label.text=="Saving character…","Pending reply disables duplicate save and shows status")
	lobby.export_button.pressed.emit()
	check(requests.size()==1,"Programmatic duplicate press cannot bypass pending gate")
	playing.exportStatus={"state":"saved","text":"Saved Nibs","entry":{"id":"nibs-3","name":"Nibs"}}
	playing.savedCharacters=entries.duplicate(true);playing.savedCharacters.append({"id":"nibs-3","name":"Nibs","revision":3})
	lobby.apply_state({"connection":7,"state":playing})
	check(not lobby.export_button.disabled and lobby.export_status_label.text=="Saved Nibs" and lobby.saved_list.item_count==3 and lobby.saved_list.get_item_metadata(2)=="nibs-3","Saved reply refreshes ordered vault list and re-enables button")
	playing.exportStatus={"state":"failed","text":"Export reply timed out","uncertain":true}
	lobby.apply_state({"connection":7,"state":playing})
	check(lobby.export_button.disabled and lobby.export_status_label.text=="Export reply timed out","Uncertain server reply stays visible and blocks duplicate export")
	playing.exportStatus={"state":"failed","text":"Vault write failed"}
	lobby.apply_state({"connection":7,"state":playing})
	check(not lobby.export_button.disabled and lobby.export_status_label.text=="Vault write failed","Definite failure stays visible and allows explicit retry")
	lobby.disconnect_button.pressed.emit()
	check(requests[-1]=={"kind":"lobby-disconnect","saveCharacter":true,"connection":7},"Save-on-disconnect waits for 3/10 even with server-vault character")
	playing.phase="area-loading";lobby.apply_state({"connection":7,"state":playing})
	check(lobby.export_button.disabled and not lobby.save_on_disconnect.visible,"Area loading has no active-character export button")
	lobby.apply_state({"connection":8,"state":{"phase":"menu","canJoin":true}})
	check(lobby.saved_characters.is_empty() and lobby.saved_list.item_count==0 and not lobby.saved_button.visible and not lobby.export_status_label.visible and not lobby.saved_popup.visible,"Reconnect removes stale export list and result")
	lobby.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual Godot CharacterLobby Save Character button, status, ordered vault list and reconnect reset; no server or Node"}
	print("NWN79_CHARACTER_EXPORT_LOBBY_RESULT ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
