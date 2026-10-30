extends "res://tests/native_particle_schedule_test.gd"
const Vertices=preload("res://systems/native_render/particle_vertices.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
func emitter(count: int,mode: int=0) -> Dictionary:
	var list: Array=[]
	for index in count:
		list.append({"position10":[M.f(index*0.01),2.0,3.0],"trail64":[M.f(index*0.01-0.03),1.98,2.99],"quaternion34":[0.5,-0.5,0.5,0.5],"direction4c":[0.0,0.0,1.0],"rotation1c":M.f(index*0.01),"age":M.f(index*0.0005),"field48":0.0,"frame44":0,"stopped70":0})
	return {"renderMode1a8":mode,"active188":{"records":list},"lifeExp":1.0,"source50":{"opacity108":0.8,"instance":null},"instance100":null,"flags":0,"position1e0":[1.0,2.0,3.0],"quaternion1d0":[0.5,0.5,0.5,0.5],"ageMode1cc":1,"xGrid":2,"yGrid":4,"elevationThreshold":5.0,"colorStart":[0.8,0.4,0.1],"colorEnd":[0.1,0.5,0.9],"alphaStart":0.9,"alphaEnd":0.1,"sizeStart":2.0,"sizeEnd":0.5,"sizeStartY":0.0,"sizeEndY":0.0,"fps":10.0,"frameStart":0.0,"frameEnd":7.0,"blendMode68":0,"twoSided":false}
func providers() -> Dictionary:
	return {"sourceFactor":func(_source):return 0.75,"cameraQuaternion":func():return [0.5,0.5,0.5,0.5],"lightColor":func(_position):return [0.5,1.5,2.0]}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(Kernel.available(),"Pinned compiled native extension is available")
	var p:=providers()
	for mode in 7:
		var a:=emitter(256,mode); var b:=a.duplicate(true); a.flags=8; b.flags=8
		var gd:=Vertices.build(a,p); var native:=Kernel.build(b,p)
		check(not native.has("error") and gd.buffer==native.get("buffer"),"All compiled bytes match GD original arithmetic mode "+str(mode))
		check(a.active188.records==b.active188.records,"Compiled atlas state matches original arithmetic mode "+str(mode))
		check(gd.count==native.get("count") and gd.softInverse==native.get("softInverse"),"Compiled draw metadata matches mode "+str(mode))
		var prepared:=emitter(3,mode); var prepared_gd:=prepared.duplicate(true)
		Vertices.advance_atlas(prepared); Vertices.advance_atlas(prepared_gd)
		check(Kernel.build(prepared,p,true).get("buffer")==Vertices.build(prepared_gd,p,true).get("buffer"),"Prepared-atlas path mode "+str(mode))
	var bad:=emitter(1); bad.xGrid=-1; check(Kernel.build(bad,p).has("error"),"Negative atlas dimensions reject safely")
	bad=emitter(1); bad.renderMode1a8=9; check(Kernel.build(bad,p).has("error"),"Unknown mode rejects safely")
	bad=emitter(1); bad.active188.records[0].erase("position10"); check(Kernel.build(bad,p).has("error"),"Missing particle field rejects safely")
	bad=emitter(1); bad.active188.records[0].position10=[1,2]; check(Kernel.build(bad,p).has("error"),"Short particle vector rejects safely")
	bad=emitter(1); bad.active188.records[0].rotation1c=INF; check(Kernel.build(bad,p).has("error"),"Unmapped nonfinite trig rejects safely")
	bad=emitter(1); bad.xGrid=INF; check(Kernel.build(bad,p).has("error"),"Nonfinite integer field rejects safely")
	check(Kernel.build(emitter(0),p).is_empty(),"Empty surface remains empty")
	var samples: Dictionary={}
	# CPU-only scoped arithmetic timing; this is not a world/FPS acceptance test.
	for kind in ["gd","compiled"]:
		var e:=emitter(1024); var times: Array=[]
		for iteration in 15:
			var began:=Time.get_ticks_usec(); var out:=Vertices.build(e,p,true) if kind=="gd" else Kernel.build(e,p,true)
			check(int(out.get("count",0))==6144,"Timing loop preserves full allocation "+kind+" "+str(iteration))
			if iteration>=3: times.append((Time.get_ticks_usec()-began)/1000.0)
		var sorted:=times.duplicate(); sorted.sort(); samples[kind]={"mean_ms":times.reduce(func(a,b):return a+b,0.0)/times.size(),"median_ms":sorted[sorted.size()/2],"samples":times.size(),"particles":1024}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"timings":samples,"native_only":true,"network_connections":0,"scope":"Compiled kernel vs original-matching GD across seven modes, atlas state and explicit invalid inputs. CPU microtimings only; no world/GPU/performance acceptance."},"\t")); file.close()
	print("NATIVE_PARTICLE_KERNEL ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
