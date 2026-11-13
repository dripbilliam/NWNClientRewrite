extends SceneTree
# Read-only installed TTF + current FontFile measurements. Dumped font bytes
# remain local diagnostic inputs; this does not render pixels or connect.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const FontData=preload("res://systems/native_data/font_data.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func signed16(value: int) -> int:return value-65536 if value&32768 else value
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new()
	if not catalog.mount_install(args.install):push_error(catalog.failure);quit(2);return
	var input_directory:=str(args.report).get_base_dir().path_join(str(args.report).get_file().get_basename()+"-inputs")
	DirAccess.make_dir_recursive_absolute(input_directory)
	var resources: Array=[]
	for name in ["fnt_default","fnt_default_hr"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2074)
		if bytes.is_empty():failures.append({"name":name,"error":catalog.failure});continue
		var parser:=FontData.new();var parsed:=parser.parse(bytes)
		if not parser.failure.is_empty():failures.append({"name":name,"error":parser.failure});continue
		var tables: Dictionary=parsed.tables
		if not tables.has_all(["head","hhea","hmtx","cmap"]):failures.append({"name":name,"error":"Required TTF metrics tables unavailable"});continue
		var head: Dictionary=tables.head;var hhea: Dictionary=tables.hhea
		if int(head.length)<54 or int(hhea.length)<36:failures.append({"name":name,"error":"Short TTF metric table"});continue
		var header:={"units_per_em":FontData.u16(bytes,int(head.offset)+18),"ascent":signed16(FontData.u16(bytes,int(hhea.offset)+4)),"descent":signed16(FontData.u16(bytes,int(hhea.offset)+6)),"line_gap":signed16(FontData.u16(bytes,int(hhea.offset)+8)),"horizontal_metrics":FontData.u16(bytes,int(hhea.offset)+34)}
		var font:=FontFile.new();font.data=bytes;font.allow_system_fallback=false;font.generate_mipmaps=false;font.multichannel_signed_distance_field=false
		var sizes: Array=[]
		for height in [14,16,18]:
			var glyphs: Array=[]
			for byte in 256:
				var code: int=Binary.CP1252_HIGH[byte-128] if byte>=128 and byte<160 else byte
				var glyph:=font.get_glyph_index(height,code,0)
				var string_width: Variant=null if code==0 else font.get_string_size(String.chr(code),HORIZONTAL_ALIGNMENT_LEFT,-1,height).x
				glyphs.append({"byte":byte,"codepoint":code,"glyph":glyph,"advance":font.get_glyph_advance(0,height,glyph).x,"single_string_width":string_width})
			var strings: Array=[]
			for value in ["Nibs","Uninjured","Skrul'nak the Barfly","ABCDEFGHIJKLMNOPQRSTUVWXYZ","WWWWiiii 1234"]:
				strings.append({"text":value,"size":font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,height)})
			sizes.append({"requested_height":height,"godot_height":font.get_height(height),"godot_ascent":font.get_ascent(height),"godot_descent":font.get_descent(height),"glyphs":glyphs,"strings":strings})
		var path:=input_directory.path_join(name+".ttf")
		if FileAccess.file_exists(path):failures.append({"name":name,"error":"Preserve previous dumped font input"});continue
		var output:=FileAccess.open(path,FileAccess.WRITE);output.store_buffer(bytes);output.close()
		resources.append({"name":name,"path":path,"sha256":FileAccess.get_sha256(path),"bytes":bytes.size(),"header":header,"godot_hinting":font.hinting,"godot_subpixel":font.subpixel_positioning,"sizes":sizes})
	var report:={"success":failures.is_empty(),"failures":failures,"resources":resources,"headless":true,"gpu":false,"gameServerConnections":0,"scope":"Installed font bytes and actual current Godot FontFile metrics only. Native original glyph metrics/atlas pixels are not established by this diagnostic."}
	var output:=FileAccess.open(args.report,FileAccess.WRITE);output.store_string(JSON.stringify(report,"  ")+"\n");output.close()
	print("NATIVE_TTF_METRICS ",resources.size()," resources; ",failures.size()," errors");quit(0 if failures.is_empty() else 1)
