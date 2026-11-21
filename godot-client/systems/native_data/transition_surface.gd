extends RefCounted
# Original client7b1670 receives world-space vertices, raises Z by0.05;
#86f940 derives the center from these vertices. Never guess from a visual model.
static func prepare(object: Dictionary) -> Dictionary:
	var source: Variant=object.get("replicated",{}).get("vertices")
	if not source is Array or source.size()<3 or source.size()>255: return {}
	var points: Array=source.duplicate()
	if points.size()>3 and points[0]==points[-1]: points.pop_back()
	var polygon:=PackedVector2Array(); var vertices:=PackedVector3Array()
	for point in points:
		if not point is Array or point.size()!=3 or not point.all(func(v):return (v is int or v is float) and is_finite(float(v))): return {}
		polygon.append(Vector2(point[0],point[1])); vertices.append(Vector3(point[0],point[2]+0.05,-point[1]))
	var indices:=Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty(): return {}
	var area:=-1.0; var destination: Array=[]; var faces:=PackedVector3Array(); var bounds:=AABB(vertices[0],Vector3.ZERO)
	for vertex in vertices: bounds=bounds.expand(vertex)
	for offset in range(0,indices.size(),3):
		var a: int=indices[offset]; var b: int=indices[offset+1]; var c: int=indices[offset+2]
		faces.append(vertices[a]); faces.append(vertices[b]); faces.append(vertices[c])
		var size:=absf((polygon[b]-polygon[a]).cross(polygon[c]-polygon[a]))
		if size>area:
			area=size; destination=[(points[a][0]+points[b][0]+points[c][0])/3.0,(points[a][1]+points[b][1]+points[c][1])/3.0,(points[a][2]+points[b][2]+points[c][2])/3.0]
	return {"vertices":vertices,"indices":indices,"faces":faces,"bounds":bounds,"destination":destination} if area>0 else {}
