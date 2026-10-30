extends RefCounted
# Original GUI coordinates are hundredths of model units, with screen Y down.
# Limit a private UI viewport without resizing model vertices or changing UVs.
static func valid(region: Rect2) -> bool:
	return region==Rect2() or region.position.is_finite() and region.size.is_finite() and region.size.x>0 and region.size.y>0 and region.size.x<=4096 and region.size.y<=4096
static func bounds(source: AABB,region: Rect2) -> AABB:
	if region==Rect2(): return source
	return AABB(Vector3(region.position.x*0.01,source.position.y,region.position.y*0.01),Vector3(region.size.x*0.01,source.size.y,region.size.y*0.01))
