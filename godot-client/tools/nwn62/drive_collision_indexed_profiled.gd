extends "res://tools/nwn62/drive_collision_indexed_before_reindex.gd"

# Timers for source-work attribution only. This class is never staged as client source.
var profile:={"descriptor_us":0,"descriptor_calls":0,"pose_and_binding_us":0,"publish_us":0,"publish_calls":0,"group_lookup_us":0,"group_lookup_calls":0,"group_creates":0,"queue_model_us":0,"queue_model_calls":0,"row_us":0,"row_calls":0,"finish_us":0,"finish_calls":0}
func descriptor(object: Dictionary)->Dictionary:
	var t:=Time.get_ticks_usec();var result:=super.descriptor(object)
	profile.descriptor_us+=Time.get_ticks_usec()-t;profile.descriptor_calls+=1;return result
func publish_binding(binding: Dictionary)->void:
	var t:=Time.get_ticks_usec();super.publish_binding(binding)
	profile.publish_us+=Time.get_ticks_usec()-t;profile.publish_calls+=1
func static_group(key: String)->Dictionary:
	var existed:=static_groups.has(key);var t:=Time.get_ticks_usec();var result:=super.static_group(key)
	profile.group_lookup_us+=Time.get_ticks_usec()-t;profile.group_lookup_calls+=1
	if not existed:profile.group_creates+=1
	return result
func queue_model(spec: Dictionary)->void:
	var t:=Time.get_ticks_usec();super.queue_model(spec)
	profile.queue_model_us+=Time.get_ticks_usec()-t;profile.queue_model_calls+=1
func row(table: String,index: int)->Dictionary:
	var t:=Time.get_ticks_usec();var result:=super.row(table,index)
	profile.row_us+=Time.get_ticks_usec()-t;profile.row_calls+=1;return result
func finish_publication(binding: Dictionary,result: Dictionary)->void:
	var t:=Time.get_ticks_usec();super.finish_publication(binding,result)
	profile.finish_us+=Time.get_ticks_usec()-t;profile.finish_calls+=1
