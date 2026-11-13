extends "res://tools/nwn62/drive_collision_indexed_before_reindex.gd"

# Private cost hypothesis: a new tiny static group gets its normal incremental
# tree instead of paying a second bulk tree build after all source publications.
func static_group(key: String)->Dictionary:
	if static_groups.has(key):return static_groups[key]
	var index:=Spatial.new()
	var group:={"index":index,"ticket":index.begin(spatial_ticket.scope),"bounds":{}}
	static_groups[key]=group
	return group
