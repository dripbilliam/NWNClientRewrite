extends RefCounted
# Worker-only data transformation. Inputs are immutable prepared draw arrays and
# affine transforms; no Node, Resource, RID, rendering or world lookup is used.
const MAX_VERTICES:=50000
const MAX_INDICES:=150000
const MAX_SOURCES:=128
static func channel_layout(arrays: Array) -> String:
	if arrays.size()!=Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or arrays[Mesh.ARRAY_VERTEX].is_empty():return ""
	var count: int=arrays[Mesh.ARRAY_VERTEX].size()
	if not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or arrays[Mesh.ARRAY_NORMAL].size()!=count or not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array or arrays[Mesh.ARRAY_TEX_UV].size()!=count or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array or arrays[Mesh.ARRAY_INDEX].is_empty() or arrays[Mesh.ARRAY_INDEX].size()%3!=0:return ""
	for index in [Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
		if arrays[index]!=null and not arrays[index].is_empty():return ""
	var colors: Variant=arrays[Mesh.ARRAY_COLOR]
	if colors!=null and (not colors is PackedColorArray or colors.size()!=count):return ""
	return "positions-normal-uv-color-index" if colors!=null else "positions-normal-uv-index"

static func bake(job: Dictionary) -> Dictionary:
	var began:=Time.get_ticks_usec()
	var failure:="";var rows: Variant=job.get("rows")
	if not rows is Array or rows.size()<2 or rows.size()>MAX_SOURCES:return {"error":"Merge source count is outside bounded range","epoch":job.get("epoch"),"revision":job.get("revision")}
	var vertices:=0;var indices:=0;var layout:=""
	for row in rows:
		if not row is Dictionary or not row.get("arrays") is Array or not row.get("pose") is Transform3D or not row.pose.is_finite() or row.pose.basis.determinant()<=0.000001:failure="Merge source data unavailable";break
		var current:=channel_layout(row.arrays)
		if current.is_empty() or not layout.is_empty() and layout!=current:failure="Incompatible merge draw channels";break
		layout=current;vertices+=row.arrays[Mesh.ARRAY_VERTEX].size();indices+=row.arrays[Mesh.ARRAY_INDEX].size()
		if vertices>MAX_VERTICES or indices>MAX_INDICES:failure="Merge job exceeds bounded stream size";break
	if not failure.is_empty():return {"error":failure,"epoch":job.get("epoch"),"revision":job.get("revision")}
	var positions:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array();var colors:=PackedColorArray();var faces:=PackedInt32Array()
	positions.resize(vertices);normals.resize(vertices);uv.resize(vertices);faces.resize(indices)
	var has_colors:=layout=="positions-normal-uv-color-index"
	if has_colors:colors.resize(vertices)
	var vertex_at:=0;var index_at:=0;var bounds:=AABB();var ranges: Array=[]
	for row in rows:
		var source: Array=row.arrays;var count: int=source[Mesh.ARRAY_VERTEX].size();var pose: Transform3D=row.pose;var normal_basis:=pose.basis.inverse().transposed()
		for index in count:
			var point: Vector3=pose*source[Mesh.ARRAY_VERTEX][index]
			var normal: Vector3=normal_basis*source[Mesh.ARRAY_NORMAL][index]
			if not point.is_finite() or not normal.is_finite():return {"error":"Nonfinite merged draw stream","epoch":job.get("epoch"),"revision":job.get("revision")}
			positions[vertex_at+index]=point;normals[vertex_at+index]=normal.normalized();uv[vertex_at+index]=source[Mesh.ARRAY_TEX_UV][index]
			if has_colors:colors[vertex_at+index]=source[Mesh.ARRAY_COLOR][index]
			bounds=bounds.expand(point) if vertex_at+index>0 else AABB(point,Vector3.ZERO)
		for index in source[Mesh.ARRAY_INDEX].size():
			var face: int=source[Mesh.ARRAY_INDEX][index]
			if face<0 or face>=count:return {"error":"Merge triangle index exceeds source vertices","epoch":job.get("epoch"),"revision":job.get("revision")}
			faces[index_at+index]=vertex_at+face
		ranges.append({"source_id":row.get("source_id"),"first_vertex":vertex_at,"vertices":count,"first_index":index_at,"indices":source[Mesh.ARRAY_INDEX].size()})
		vertex_at+=count;index_at+=source[Mesh.ARRAY_INDEX].size()
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=faces
	if has_colors:arrays[Mesh.ARRAY_COLOR]=colors
	return {"error":"","arrays":arrays,"bounds":bounds,"ranges":ranges,"vertices":vertices,"indices":indices,"epoch":job.get("epoch"),"revision":job.get("revision"),"worker_us":Time.get_ticks_usec()-began,"thread":OS.get_thread_caller_id()}
