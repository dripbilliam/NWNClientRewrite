extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("before") or not args.has("after") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var before:=Image.load_from_file(args.before); var after:=Image.load_from_file(args.after)
	if before==null or after==null or before.get_size()!=after.get_size(): quit(1); return
	var sum_error:=Vector3.ZERO; var above:=0; var maximum:=0.0
	for y in before.get_height():
		for x in before.get_width():
			var a:=before.get_pixel(x,y); var b:=after.get_pixel(x,y)
			var error:=Vector3(absf(a.r-b.r),absf(a.g-b.g),absf(a.b-b.b))*255
			sum_error+=error; maximum=maxf(maximum,maxf(error.x,maxf(error.y,error.z)))
			if maxf(error.x,maxf(error.y,error.z))>2.01: above+=1
	var count:=before.get_width()*before.get_height(); var mean:=sum_error/count
	var passed:=float(above)/count<0.005
	var report: Dictionary={"passed":passed,"scope":"Fixed-camera original terrain: native instances versus native spatial batching; not full-world fidelity acceptance","pixels_above_2":above,"total_pixels":count,"mean_absolute_channel_error":[mean.x,mean.y,mean.z],"maximum_channel_error":maximum,"before_sha256":FileAccess.get_sha256(args.before),"after_sha256":FileAccess.get_sha256(args.after),"sourceSha256":FileAccess.get_sha256("res://tests/native_terrain_image_compare.gd")}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if passed else 1)
