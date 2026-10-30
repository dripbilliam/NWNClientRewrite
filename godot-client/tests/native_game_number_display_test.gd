extends SceneTree
const Numbers=preload("res://systems/native_data/game_numbers.gd")
const Slot=preload("res://systems/spell_slot.gd")
const Sheet=preload("res://systems/server_character_sheet.gd")
const Lobby=preload("res://systems/character_lobby.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Nui=preload("res://systems/native_data/nui_state.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var values: Dictionary=JSON.parse_string('{"hp":18,"maximum":27,"xp":12345,"level":3,"percent":15,"penalty":2,"weight":19,"fraction":4.9,"negative":-4.9}')
	check(typeof(values.hp)==TYPE_FLOAT,"Fixture uses the actual JSON floating-point representation")
	for key in ["hp","maximum","xp","level","percent","penalty"]:
		check(Numbers.text(values[key])==str(int(values[key])),"Whole-number game display: "+key)
	check(Numbers.text(values.fraction)=="4" and Numbers.text(values.negative)=="-4","Fractional game display truncates consistently with existing inventory formatting")
	check(Numbers.tenths(values.weight)=="1" and Numbers.tenths(0)=="0","Network weights convert units before whole-number display")
	check(Numbers.text(null)=="—" and Numbers.text(INF)=="—" and Numbers.text(NAN)=="—","Missing or nonfinite values stay unavailable")
	check(Numbers.text("100.0")=="100" and Numbers.text("1.9")=="1","Numeric rule-table strings also use whole-number display")
	check(Numbers.text("∞")=="∞" and Numbers.text("3/5")=="3/5" and Numbers.text("15%")=="15%","Authored count and stat markers remain intact")
	var sheet:=Sheet.new()
	check(sheet.value(values.fraction)=="4" and sheet.value(null)=="—" and sheet.value("Sword +2")=="Sword +2","Shared character-sheet formatter handles numeric values and existing stat text")
	sheet.free()
	for value in [values.level,values.fraction,"3/5",null]:
		var slot:=Slot.new(); slot.setup("Spell 1.5",value,true); root.add_child(slot)
		check(slot.counter.text==Numbers.text(value,"") and slot.tooltip_text=="Spell 1.5","Actual spell/quickbar control formats count only: "+str(value))
		slot.free()
	var text:=Text.new(); text.overrides={9000:"Custom Class 1.5"}; text.tables={"classes":{"orderedRows":[{"Name":"9000"}]}}
	var actor:={"id":42,"replicated":{"stats":{"classes":[{"id":0,"level":values.level}]},"hitPoints":{"current":values.hp,"maximum":values.maximum}},"inventoryStats":{"combatInformation":{"field6":values.percent,"field7":values.penalty}}}
	var before:=actor.duplicate(true); var rules:=Rules.new(); rules.text=text
	var model:=rules.record(actor,"number-fixture")
	check(model.classes==["Custom Class 1.5 (3)"] and model.details[5].value=="15%" and model.details[6].value=="-2","Active custom class labels survive while class levels, percentages and penalties use integers")
	check(actor==before,"Record formatting does not modify authoritative values")
	var lobby:=Lobby.new(); var preview: String=lobby._preview({"firstName":{"text":"Name 1.5"},"currentHitPoints":values.hp,"hitPoints":values.maximum,"experience":values.xp,"classes":[{"id":0.0,"level":values.level}],"abilities":{"Str":18.0}})
	check(preview.begins_with("Name 1.5 ") and preview.contains("HP: 18 / 27 · XP: 12345") and preview.contains("Class 0 · level 3") and preview.contains("Str: 18"),"Fallback character preview formats JSON game fields without changing the character name")
	lobby.free(); text.close()
	check(Nui.text(1.25,{"number_precision":2})=="1.25" and Nui.text("Version 8193.37")=="Version 8193.37","Server-authored NUI precision and supplied text remain as specified")
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Game-value formatting and actual native count/record controls. Diagnostic precision and server-authored strings/formats are preserved; no gameplay arithmetic or protocol changes."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
