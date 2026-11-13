extends SceneTree
# CPU-only comparison against midpoint values saved by the unchanged original
# shader oracle. This does not measure graphical performance.
const Post=preload("res://systems/native_render/native_postprocess.gd")

func _initialize() -> void:
	call_deferred("run")

func authored_frame(count: int,ambient: Vector3,diffuse: Vector3,direction: Vector3,fog: Vector3,start: float,end: float,projection: Projection) -> PackedFloat32Array:
	var frame:=Post.empty_frame()
	Post.row(frame,0,Vector4(ambient.x,ambient.y,ambient.z,count))
	Post.row(frame,1,Vector4(diffuse.x,diffuse.y,diffuse.z,0))
	Post.row(frame,2,Vector4(direction.x,direction.y,direction.z,0))
	Post.row(frame,3,Vector4(fog.x,fog.y,fog.z,start))
	frame[16]=end
	for n in 4:Post.row(frame,5+n,projection[n])
	for n in count:
		Post.row(frame,9+n*2,Vector4(float(n%5)-2.0,float(n%3)-1.0,2.0+float(n%7) if n%7==3 else -2.0-float(n%7),1))
		Post.row(frame,10+n*2,Vector4(.01+float(n%4)*.03,.02+float(n%6)*.02,.03+float(n%7)*.01,-64.0 if n%3==0 else 64.0))
	frame[17]=.4;frame[18]=.35;frame[19]=.7
	return frame

func run() -> void:
	var oracle:="";var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="):oracle=arg.substr(9)
		if arg.begins_with("--report="):report=arg.substr(9)
	if oracle.is_empty() or report.is_empty():quit(2);return
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	var frames: Array=[authored_frame(0,Vector3(.001,.002,.025),Vector3(.11,.01,.01),Vector3(.43,.49,.76),Vector3(.06,.008,.008),10,45,Projection.create_perspective(55,1,.01,100)),authored_frame(8,Vector3(.02,.03,.01),Vector3(.1,.07,.02),Vector3(.3,.4,-.8660254),Vector3(.08,.12,.2),-3,12,Projection.create_perspective(75,1.4,.01,100)),authored_frame(128,Vector3(.001,.002,.003),Vector3(.01,.02,.03),Vector3(0,0,-1),Vector3(.005,.01,.02),2,10,Projection.IDENTITY)]
	var rows: Array=[];var max_delta:=0.0;var failures: Array=[]
	for mask in [0,4,8,12,16,20,24,28]:
		for frame: PackedFloat32Array in frames:
			var expected: Array=saved.samples.filter(func(sample):return int(sample.mask)==mask and int(sample.lights)==int(frame[3]))
			if expected.size()!=8:failures.append("Missing original samples for "+str([mask,int(frame[3])]))
			var actual:=Post.midpoint_tone_cpu(frame,mask)
			if actual.size()!=4:failures.append("Malformed tone for "+str([mask,int(frame[3])]))
			for sample in expected:
				var delta:=absf(float(sample.midpoint)-actual[0]);max_delta=maxf(max_delta,delta)
				if delta>.0001:failures.append(str([mask,int(frame[3]),delta]))
			rows.append({"mask":mask,"lights":int(frame[3]),"cpu":actual[0],"oracle":expected[0].midpoint if not expected.is_empty() else null})
	var value:={"success":failures.is_empty(),"max_delta":max_delta,"cases":rows.size(),"observations":saved.samples.size(),"failures":failures,"rows":rows,"scope":"CPU-only comparison to saved original GPU midpoint oracle; no current GPU or FPS test"}
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(value,"  "));file.close()
	quit(0 if value.success else 1)
