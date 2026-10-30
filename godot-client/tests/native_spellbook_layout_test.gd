extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Plan=preload("res://systems/native_data/spellbook_layout.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original spellbook model corpus mounts read-only")
	var source: Dictionary={}
	for name in Plan.RESOURCES:
		var parser:=Actor.new(); var model:=parser.parse(catalog.get_resource(name,2002)); check(parser.failure.is_empty(),"Original "+name+" decodes"); source[name]=model
	var layout:=Plan.parse(source)
	check(layout.error.is_empty(),"Original programmatic spellbook and memorization attachments form a data plan")
	if layout.error.is_empty():
		var models: Dictionary=layout.models
		check(layout.main_size.distance_to(Vector2(360,471))<0.001 and layout.memory_size.distance_to(Vector2(360,471))<0.001,"Both original windows retain360x471 source extents")
		check(layout.class_tabs.size()==8 and layout.level_tabs.size()==10,"Original eight class and ten level tab slots are represented")
		check(layout.class_tabs[0].offset.distance_to(Vector2(6,59))<0.001 and layout.class_tabs[7].offset.distance_to(Vector2(237,59))<0.001,"Class tab links use33px original hook increments")
		check(layout.level_tabs[0].offset.distance_to(Vector2(6,102))<0.001 and layout.level_tabs[9].offset.distance_to(Vector2(303,102))<0.001,"Level tabs follow page64px attachment and original links")
		check(layout.known_view.position.distance_to(Vector2(2,109))<0.001 and layout.known_view.size.distance_to(Vector2(348,360))<0.001,"Known viewport uses the original page-relative view hooks")
		check(layout.memory_view.position.distance_to(Vector2(1,20))<0.001 and layout.memory_view.size.distance_to(Vector2(358,450))<0.001,"Memorization has its separate original viewport")
		var known:=Plan.known_rows(models,2); check(known.rows[0].offset==Vector2(0,40) and known.rows[1].offset==Vector2(0,73) and known.next_origin==Vector2(0,106),"Known spell rows follow root40px and leaf33px links")
		check(known.rows[0].caption.position.distance_to(Vector2(74,41))<0.001 and known.rows[0].caption.size.distance_to(Vector2(223,31))<0.001,"Leaf text uses original text0/text1 box instead of whole row mesh bounds")
		check(known.rows[0].icon==Vector2(50,56) and known.rows[0].arrow.offset==Vector2(297,73) and known.rows[0].help.offset==Vector2(266,72),"Leaf icon, prepare arrow and help attachment positions remain distinct")
		for count in [0,1,8,9,10,17,18,19,27]:
			var grid:=Plan.memory_slots(models,count); check(grid.error.is_empty() and grid.slots.size()==count and grid.row_count==int(ceil(float(count)/9)),"Original prepared slot count%d forms nine-column linked rows"%count)
		var grid:=Plan.memory_slots(models,19)
		for pair in [[0,33,40],[8,298,40],[9,33,73],[17,298,73],[18,33,106]]:
			check(grid.slots[pair[0]].offset==Vector2(pair[1],pair[2]),"Prepared slot%d follows original FIRST34px/NEXT33px positions"%pair[0])
		check(grid.slots[0].rect.size==Vector2(34,33) and grid.slots[1].rect.size==Vector2(33,33) and grid.slots[0].icon==Vector2(50,56),"Prepared slot mesh widths and icon hook keep their original asymmetric first cell")
		check(Plan.LEVEL_ICONS[7]==Plan.LEVEL_ICONS[8] and Plan.LEVEL_ICONS[8]==Plan.LEVEL_ICONS[9] and Plan.LEVEL_REFS[0]==68674 and Plan.LEVEL_REFS[9]==68683,"Original shared level7/8/9 icon and localized level references are retained")
		check(not Plan.parse({}).error.is_empty() and not Plan.memory_slots(models,-1).error.is_empty(),"Missing resources and invalid counts fail explicitly")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"uiImplemented":false,"fullSpellbookParity":false,"scope":"Original model-backed spellbook/memorization layout data plan only. Current generic UI remains; no native input/actions/pixel parity claimed."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
