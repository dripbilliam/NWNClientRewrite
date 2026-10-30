extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Plan=preload("res://systems/native_data/journal_layout.gd")
const Order=preload("res://systems/native_data/journal_order.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func near(a: Vector2,b: Vector2) -> bool: return a.distance_to(b)<0.001
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original journal resources mount read-only")
	var models: Dictionary={}; var layouts: Dictionary={}; var hashes: Dictionary={}
	for name in Plan.RESOURCES:
		var raw: PackedByteArray=catalog.get_resource(name,2002); var parser:=Actor.new(); models[name]=parser.parse(raw); check(parser.failure.is_empty(),"Original journal model parses: "+name); hashes[name]=preload("res://systems/native_data/prepared_cache.gd").digest(raw)
	for name in ["jnl_panel","jnl_page_quest","jnl_page_notes"]:
		var raw: PackedByteArray=catalog.get_resource(name,2047); var parser:=Gff.new(); var doc:=parser.parse(raw,"GUI "); layouts[name]=doc.root; check(parser.failure.is_empty(),"Original journal GUI parses: "+name); hashes[name]=preload("res://systems/native_data/prepared_cache.gd").digest(raw)
	var plan:=Plan.parse(layouts,models); check(str(plan.error).is_empty(),"Original journal resources produce a complete static attachment plan")
	if str(plan.error).is_empty():
		check(near(plan.size,Vector2(360,460)) and near(plan.page_origin,Vector2(0,58)),"Original journal panel and page form a360x460 frame")
		check(plan.tabs.size()==3 and Plan.TAB_REFS==[0xf809,0xf80b,0xf80a] and near(plan.tabs[1].offset,Vector2(119,58)) and near(plan.tabs[2].offset,Vector2(239,58)),"Three original page models chain their own next attachments and tooltip IDs")
		check(near(plan.quest_view.position,Vector2(1,89)) and near(plan.quest_view.size,Vector2(342,370)) and near(plan.quest_tree,Vector2(6,89)),"Quest viewport and linked tree use original hooks")
		check(near(plan.notes_view.position,Vector2(6,63)) and near(plan.notes_view.size,Vector2(333,396)),"Personal notes retain the original bottom-attached edit model and text extent")
		check(plan.sort.keys().size()==3 and plan.sort.has("dateradio") and plan.sort.has("nameradio") and plan.sort.has("priorityradio"),"Quest pages provide original Date/Name/Priority controls")
		var missing:=models.duplicate(); missing.erase("ctl_jnl_questbtn"); check(not str(Plan.parse(layouts,missing).error).is_empty(),"A missing required quest control cannot be silently replaced by generic artwork")
		for height in [0,16,80,1536,2000]:
			var row:=Plan.description(models.ctl_jnl_entrytxt,float(height),Vector2(6,40))
			check(str(row.error).is_empty() and near(row.next,Vector2(6,60+mini(height,1536))) and absf(row.text.size.y-height)<0.01,"Original entry animation caps linkage separately from measured text height%d"%height)
	var oracle_path:=ProjectSettings.globalize_path("res://../backups/animations/native-journal-order-observations-v1.json"); var file:=FileAccess.open(oracle_path,FileAccess.READ); var oracle: Dictionary=JSON.parse_string(file.get_as_text()); file.close()
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==312,"Original journal order oracle identifies the verified executable")
	for row in oracle.rows:
		var before: Array=row.entries.duplicate(true); var actual:=Order.indices(row.entries,int(row.mode),int(row.dayLength)); var expected: Array[int]=[]
		for value in row.indices: expected.append(int(value))
		check(actual==expected and row.entries==before and int(row.dirty)==1,"Original journal index exchanges match mode%d length%d order%s"%[row.mode,row.dayLength,str(row.indices)])
	var output_file:=FileAccess.open(output,FileAccess.WRITE); output_file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(oracle_path),"resourceSha256":hashes,"fullJournalParity":false,"publicConnections":0,"scope":"Original journal attachment plan and312 unchanged native comparator/selection-sort observations only. No live UI, note persistence, authoritative actions or full journal parity acceptance."},"  ")+"\n"); output_file.close(); quit(0 if failures.is_empty() else 1)
