extends SceneTree
const Spatial=preload("res://systems/native_render/drive_spatial_index.gd")
var failures: Array[String]=[]
func one(count: int,bulk: bool)->Dictionary:
	var index:=Spatial.new()
	var ticket:=index.begin([1,1,91])
	if not ticket.get("ready",false):failures.append("scope "+str(count)+" "+str(bulk))
	if bulk and not index.begin_batch(ticket):failures.append("begin batch "+str(count))
	var begun:=Time.get_ticks_usec()
	for n in count:
		var x:=float(n)*20.0
		var response:=index.upsert_shape(ticket,n,[n+1,1],n+1,"static",Vector3(x-12.2,-12.2,0),Vector3(x+12.2,12.2,0),false,n)
		if not response.get("accepted",false):failures.append("upsert "+str(n)+" "+str(bulk))
	var insert_us:=Time.get_ticks_usec()-begun
	var finish_us:=0
	if bulk:
		begun=Time.get_ticks_usec()
		if not index.end_batch(ticket):failures.append("end batch "+str(count))
		finish_us=Time.get_ticks_usec()-begun
	var response:=index.query(ticket,Vector3.ZERO,Vector3(11,0,0),0.4,-1,false)
	if not response.get("ready",false) or response.ids!=[0,1]:failures.append("query "+str(count)+" "+str(bulk)+" "+str(response.ids))
	if int(index.snapshot().entries)!=count:failures.append("entries "+str(count)+" "+str(bulk))
	return {"groups":count,"bulk":bulk,"insert_us":insert_us,"finish_us":finish_us,"total_us":insert_us+finish_us,"height":index.snapshot().height,"entries":index.snapshot().entries}
func _initialize()->void:call_deferred("run")
func run()->void:
	var rows: Array=[]
	for count in [1024,2550]:
		for bulk in [false,true]:rows.append(one(count,bulk))
	var result:={"success":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Standalone Spatial tree publication only; no model parsing, World sync, FPS, or original-client inference."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
