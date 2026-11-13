extends SceneTree
# SOURCE ONLY. Isolated parser bytes/text, no engine run approved yet.
# No game assets/server/GPU/native extension are required by this future gate.
const BinaryModel=preload("res://systems/native_data/binary_model.gd")
const AsciiModel=preload("res://systems/native_data/ascii_model.gd")
const Reader=preload("res://systems/native_data/binary_data.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func binary_mesh(bytes: PackedByteArray) -> Dictionary:
	var parser:=BinaryModel.new();parser.reader=Reader.new(bytes);parser.model_size=512;parser.raw_start=524;parser.raw_size=0
	var result: Dictionary=parser.read_mesh(12)
	check(parser.failure.is_empty(),"New metadata does not reject an otherwise admitted empty serialized trimesh")
	return result
func ascii(tilefade_line: String,bounds_lines: String="") -> Dictionary:
	var parser:=AsciiModel.new()
	var source: String="""newmodel DoorMeta
setsupermodel DoorMeta NULL
classification Door
beginmodelgeom DoorMeta
node dummy DoorMeta
 parent NULL
endnode
node trimesh HitPart
 parent DoorMeta
 alpha 0
 render 0
 shadow 0
 %s
 %s
 verts 4
  1 2 3
  2 2 3
  1 3 3
  10 20 30
 faces 1
  0 1 2 1 0 1 2
endnode
endmodelgeom DoorMeta
"""%[tilefade_line,bounds_lines]
	var result: Dictionary=parser.parse(source)
	check(parser.failure.is_empty() and not result.is_empty(),"Metadata-only ASCII field handling preserves original geometry admission")
	return result
func run() -> void:
	var bytes:=PackedByteArray();bytes.resize(524)
	var at:=12
	for pair in [[0x14,-2.0],[0x18,-1.0],[0x1c,3.0],[0x20,4.0],[0x24,5.0],[0x28,6.0],[0x1f8,7.25]]:bytes.encode_float(at+int(pair[0]),float(pair[1]))
	bytes.encode_u32(at+0x6c,2);bytes.encode_u32(at+0x64,1);bytes.encode_u32(at+0x70,1);bytes.encode_u32(at+0x178,0x12345678)
	var mesh:=binary_mesh(bytes)
	check(mesh.native_bounds_available and mesh.native_bounds_valid and mesh.native_bounds_source=="binary_mdl_header","Serialized original bounds have explicit availability/provenance")
	check(mesh.native_bounds=={"min":[-2.0,-1.0,3.0],"max":[4.0,5.0,6.0]} and mesh.native_bounds_offset==32,"Authored bbox reads exact extension14/20 rather than empty-geometry AABB")
	check(not mesh.render and mesh.native_render_raw==2 and mesh.shadow and mesh.transparency_hint,"Existing render/shadow/transparency behavior stays unchanged while raw render bits survive")
	check(mesh.native_tilefade==0x12345678 and mesh.native_tilefade_available and mesh.native_tilefade_source=="binary_mdl_header","Tilefade comes from extension178, separately from transparency hint")
	check(mesh.native_area==7.25 and mesh.vertices.is_empty() and mesh.indices.is_empty(),"Prior native area and geometry fields are preserved")
	bytes.encode_u32(at+0x14,0x80000000)
	var negative_zero:=binary_mesh(bytes);var bits:=PackedByteArray();bits.resize(4);bits.encode_float(0,negative_zero.native_bounds.min[0])
	check(bits.decode_u32(0)==0x80000000,"Authored signed-zero bits survive metadata read")
	bytes.encode_u32(at+0x14,0x7fc00001)
	var nonfinite:=binary_mesh(bytes)
	check(nonfinite.native_bounds_available and not nonfinite.native_bounds_valid and is_nan(nonfinite.native_bounds.min[0]),"Malformed authored box remains received metadata, explicitly invalid for consumers")
	var literal:=ascii("tilefade 1");var ascii_mesh: Dictionary=literal.nodes[1].mesh
	check(ascii_mesh.native_bounds=={"min":[0.0,0.0,0.0],"max":[10.0,20.0,30.0]} and ascii_mesh.native_bounds_available and ascii_mesh.native_bounds_source=="ascii_processverts","Native ASCII bounds include initial origin and ALL source vertices, including unused ones")
	check(ascii_mesh.native_tilefade==1 and ascii_mesh.native_tilefade_source=="ascii_decimal_prefix","Exact ASCII tilefade integer is retained")
	check(literal.nodes[1].alpha==0 and not ascii_mesh.render and ascii_mesh.vertices.size()==9 and ascii_mesh.collision_indices.size()==3,"Invisible original Parts retain vertices/indices and alpha without a new drawing policy")
	var missing:=ascii("");check(missing.nodes[1].mesh.native_tilefade==0 and missing.nodes[1].mesh.native_tilefade_source=="ascii_constructor_default","Absent ASCII tilefade follows the proven native constructor0")
	var prefix:=ascii("tilefade 1suffix");check(prefix.nodes[1].mesh.native_tilefade==1,"Native scanf percent-d consumes a valid decimal prefix")
	var boolean:=ascii("tilefade TrUe");check(boolean.nodes[1].mesh.native_tilefade==1 and boolean.nodes[1].mesh.native_tilefade_source=="ascii_boolean_token","Native failed integer parse recognizes case-insensitiveTRUE")
	var retained:=ascii("tilefade 1\ntilefade unknown");check(retained.nodes[1].mesh.native_tilefade==1,"Unknown later token retains previous field rather than resetting constructor default")
	var unresolved:=ascii("tilefade 999999999999999999999");check(unresolved.nodes[1].mesh.native_tilefade==null and not unresolved.nodes[1].mesh.native_tilefade_available,"Unproven scanf overflow stays explicitly unavailable")
	var signed:=ascii("tilefade -1");check(signed.nodes[1].mesh.native_tilefade==4294967295,"Signed32 literal preserves the written DWORD bits")
	var seeded:=ascii("tilefade 0","bmin -4 -5 -6\nbmax 40 50 60");check(seeded.nodes[1].mesh.native_bounds=={"min":[-4.0,-5.0,-6.0],"max":[40.0,50.0,60.0]},"Explicit ASCII bounds seed native ProcessVerts reduction")
	var unavailable:=ascii("tilefade 0","bmin unproven 0 0");check(not unavailable.nodes[1].mesh.native_bounds_available,"Unsupported seed parse is unavailable without rejecting existing geometry")
	print("NATIVE_PARITY_DOOR_PARSER_METADATA ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
