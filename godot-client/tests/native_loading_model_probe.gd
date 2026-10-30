extends SceneTree
const Setup=preload("res://systems/native_data/session_catalog.gd")
const Model=preload("res://systems/native_data/binary_model.gd")
class InspectModel:
	extends Model
	var meshes: Array=[]
	func read_mesh(at: int) -> Dictionary:
		meshes.append({"node":reader.text(at-112+32,32,true),"mode":reader.u8(at+436),"vertices":reader.u16(at+448),"textures":reader.u16(at+450),"faces":reader.u32(at+12),"draws":reader.u32(at+420)})
		return super.read_mesh(at)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var descriptor: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.source)); var mounted:=Setup.prepare(descriptor); var catalog=mounted.catalog; var models: Array=[]
	for name in ["ttu01_v13_01","ttu01_o17_01"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2002); var parser:=InspectModel.new(); var model:=parser.parse(bytes)
		models.append({"name":name,"bytes":bytes.size(),"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes),"catalog_error":catalog.failure,"parser_error":parser.failure,"nodes":model.get("nodes",[]).size(),"meshes":parser.meshes})
	var gff:=preload("res://systems/native_data/gff_document.gd").new(); var gui:=gff.parse(catalog.get_resource("load_screen",2047))
	var gui_summary: Array=[]
	var panel:=preload("res://systems/native_data/actor_model.gd").new(); var panel_data:=panel.parse(catalog.get_resource("pnl_loadscreen",2002)); var panel_summary: Array=[]
	for node in panel_data.get("nodes",[]):
		if node.mesh.is_empty() or node.mesh.vertices.is_empty(): continue
		var uv: Array=[]
		for layer in node.mesh.uv:
			var u: Array=[]; var v: Array=[]
			for index in layer.size()/2: u.append(layer[index*2]); v.append(layer[index*2+1])
			uv.append([u.min(),u.max(),v.min(),v.max()])
		panel_summary.append({"name":node.name,"textures":node.mesh.textures,"uv_bounds":uv,"render":node.mesh.render,"alpha":node.alpha,"position":node.position,"scale":node.scale})
	if not gui.is_empty():
		for record in gui.records.values():
			var selected: Dictionary={}
			for key in record:
				if str(key) in ["Obj_ResRef","Obj_Tag"]: selected[key]=record[key]
			if not selected.is_empty(): gui_summary.append(selected)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":models.all(func(row):return row.bytes>0),"scope":"Read-only local resource/header inspection; not parser acceptance","models":models,"gui":gui_summary,"panel":panel_summary,"network":false},"  ")+"\n"); quit()
