extends "res://tests/native_particle_schedule_test.gd"
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
func bits(value: float) -> String: return "%08x"%PackedFloat32Array([value]).to_byte_array().decode_u32(0)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:="res://../backups/animations/native-camera-polygon-observations.json"; var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data.target==BINARY_SHA and data.rows.size()==1876,"Original polyhit identity/count")
	var index:=0
	for row in data.rows:
		var c: Dictionary=row.case; var vertices: Array=c.vertices.map(func(v):return M.values(v)); var result: Variant=Polygon.hit(vertices,M.values(c.normal),M.f(c.constant),M.values(c.start),M.values(c.end))
		check((result!=null)==bool(row.result) and (result==null or result.map(bits)==row.bits),"Original polyhit exact case "+str(index))
		if index>=1620:
			var plane:=Polygon.plane(vertices); check(plane.normal.map(bits)==M.values(c.normal).map(bits) and bits(plane.constant)==bits(c.constant),"Original normal/plane exact case "+str(index))
		index+=1
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(path),"scope":"Original 1876 stored polygon crossings and 256 original normal/plane calculations, exact float bits; does not establish BSP membership or transform parity"},"\t")); file.close()
	print("NATIVE_POLYGON_HIT ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
