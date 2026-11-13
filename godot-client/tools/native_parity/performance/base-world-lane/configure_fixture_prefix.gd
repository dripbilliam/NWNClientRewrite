extends Node
const Assets=preload("res://fake_assets.gd")
var pool
var snapshot_objects: Array=[]
var area_id:=-1
var assets
var maximum_asset_workers:=4
var table_requests: Dictionary={}
var initial_static_tables_only:=false
func prepared(_id,_result):pass
