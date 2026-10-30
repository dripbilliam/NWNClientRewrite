extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Plan=preload("res://systems/native_data/players_layout.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
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
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original player-list resources mount read-only")
	var models: Dictionary={}; var hashes: Dictionary={}
	for name in Plan.RESOURCES:
		var raw: PackedByteArray=catalog.get_resource(name,2002); var parser:=Actor.new(); models[name]=parser.parse(raw); hashes[name]=Cache.digest(raw); check(parser.failure.is_empty(),"Original player-list model parses: "+name)
	var raw: PackedByteArray=catalog.get_resource("ingame_pvp",2047); var parser:=Gff.new(); var layout: Dictionary=parser.parse(raw,"GUI ").root; hashes.ingame_pvp=Cache.digest(raw); check(parser.failure.is_empty(),"Original player-list GUI parses")
	var before:=layout.duplicate(true); var plan:=Plan.parse(layout,models); check(str(plan.error).is_empty(),"Original player-list GUI and constructed models produce a native attachment plan")
	if str(plan.error).is_empty():
		check(near(plan.size,Vector2(360,461)) and near(plan.list_origin,Vector2(0,456)),"Original frame is360x461 with its own player-list attachment")
		check(near(plan.view.position,Vector2(1,124.9)) and near(plan.view.size,Vector2(358,330.1)),"The constructed list uses its source top/bottom viewport hooks")
		check(near(plan.row.rect.position,Vector2(4,129.9)) and near(plan.row.rect.size,Vector2(335,29)) and near(plan.row_step,Vector2(0,30.9999)),"Player rows use their original29px art and linked31px spacing")
		check(near(plan.attitude.offset,Vector2(175,156.9)) and near(plan.reaction,Vector2(329,143.9)),"Attitude checkbox and reaction text attach to original row hooks")
		check(near(plan.name_rect.position,Vector2(29.1,135.9)) and near(plan.name_rect.size,Vector2(142.9,18.9999)),"Player-name clipping follows original text0/text1 hooks")
		check(plan.entries.size()==12 and plan.entries.tguilabel.caption.Obj_StrRef==7994 and plan.entries.tguilabel1.caption.Obj_StrRef==7995 and plan.entries.tguilabel2.caption.Obj_StrRef==7996 and plan.entries.tguilabel3.caption.Obj_StrRef==7993,"Source title and three original column captions retain their TLK references")
		for tag in Plan.BUTTONS:
			check(near(plan.entries[tag].rect.size,Vector2(34,34)) and plan.entries[tag].caption.is_empty() and plan.entries[tag].icon==Plan.BUTTONS[tag].icon,"Original icon action uses native34px art without an invented caption: "+tag)
		check(plan.entries.tellbutton.tooltip==0x104db and plan.entries.invitebutton.tooltip==0x42b and plan.entries.leavebutton.tooltip==0x42f,"Recovered original tooltips remain distinct per action")
		check(plan.native_data_only and not plan.full_players_parity and layout==before,"The data plan preserves active input and does not claim a visible functional player window")
		var changed:=layout.duplicate(true)
		for child in changed.Obj_ChildList:
			if str(child.Obj_Tag).to_lower()=="tellbutton": child.Obj_X+=0.25
		var alternate:=Plan.parse(changed,models); check(str(alternate.error).is_empty() and near(alternate.entries.tellbutton.offset,plan.entries.tellbutton.offset+Vector2(25,0)),"Active server GUI placement is used instead of compiled original button coordinates")
		changed=layout.duplicate(true); changed.Obj_ResRef="pnl_custom_players"; var supplied:=models.duplicate(); supplied.pnl_custom_players=models.pnl_ig_pvp; supplied.erase("pnl_ig_pvp"); alternate=Plan.parse(changed,supplied)
		check(str(alternate.error).is_empty() and alternate.main.resource=="pnl_custom_players","An active GUI can supply another frame resource with the required original attachments")
	var missing:=models.duplicate(); missing.erase("ctl_ig_btn_attit"); check(not str(Plan.parse(layout,missing).error).is_empty(),"Missing original attitude artwork cannot silently become a generic button")
	var missing_control:=layout.duplicate(true); missing_control.Obj_ChildList=missing_control.Obj_ChildList.filter(func(child):return str(child.Obj_Tag).to_lower()!="transferbutton"); check(not str(Plan.parse(missing_control,models).error).is_empty(),"A missing source action is reported before exposing a partial player-list plan")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"resourceSha256":hashes,"publicConnections":0,"fullPlayersParity":false,"visiblePlayersFrameAccepted":false,"scope":"Original player-list native data/attachment plan only. Original callbacks are retained separately as evidence; visible native frame, action availability and authoritative party outcomes remain unimplemented."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
