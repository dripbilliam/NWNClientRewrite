func guarded_observer_cases()->void:
	for enhanced in [false,true]:
		for descendant in [false,true]:
			var value:=pair(enhanced)
			var histories:=[[],[]]
			var lamps:=[value.a,value.b]
			for index in 2:
				var lamp=lamps[index]
				lamp.configure({"color":[.4,.3,.2],"radius":8,"multiplier":1,"shadow":1})
			attach(value)
			for index in 2:
				var lamp=lamps[index]
				var observer: Node3D=lamp
				if descendant:
					observer=Node3D.new();lamp.add_child(observer)
				observer.visibility_changed.connect(func(): histories[index].append(state(lamp)))
			check(not value.b._can_publish_final(value.b.native_properties),"Opaque visibility observer/descendant selects original body")
			both(value,"apply_native_admission",[false,.5]);same(value,"observed admission "+str(enhanced)+"/"+str(descendant))
			both(value,"publish_native_light",[Color(.1,.4,.7),9,7,.3,.8]);same(value,"observed animation")
			both(value,"apply_native_admission",[true,.8]);same(value,"observed readmission")
			check(histories[0]==histories[1] and not histories[0].is_empty(),"Every synchronous observed intermediate facade matches original")
			# Freeing while still connected intentionally exercises exit behavior.
			close(value)
	var reentrant:=pair(true)
	both(reentrant,"configure",[{"color":[.4,.3,.2],"radius":8,"multiplier":1,"shadow":1}]);attach(reentrant)
	var entered:=[false,false];var observations:=[[],[]];var lamps:=[reentrant.a,reentrant.b]
	for index in 2:
		var lamp=lamps[index]
		lamp.visibility_changed.connect(func():
			observations[index].append(state(lamp))
			if not entered[index]:
				entered[index]=true
				lamp.configure({"color":[.8,.2,.1],"radius":13,"multiplier":.7,"shadow":1})
		)
	both(reentrant,"apply_native_admission",[false,.25]);same(reentrant,"synchronous nested configure")
	check(entered[0] and entered[1] and observations[0]==observations[1],"Reentrant visibility callbacks and their partial states match")
	close(reentrant)
func guarded_subclass_case()->void:
	var owner:=FocusOwner.new();root.add_child(owner);owner.set_meta("native_focus_light_owner",weakref(owner))
	var value:={"owner":owner,"a":load("res://baseline/subclass.gd").new(),"b":load("res://candidate/subclass.gd").new()}
	for lamp in [value.a,value.b]:lamp.set_meta("native_enhanced_light",true)
	both(value,"configure",[{"color":[.5,.3,.1],"radius":5,"multiplier":1,"shadow":1}]);attach(value)
	for lamp in [value.a,value.b]:lamp.shadow_enabled=true
	both(value,"publish_native_light",[Color(.7,.2,.3),5,3,0,1]);same(value,"subclass animated override")
	both(value,"apply_native_admission",[false,.25]);same(value,"subclass admission override")
	check(value.a.configure_calls==4 and value.b.configure_calls==4,"Public virtual configure override receives initial/tree/animation/admission calls")
	check(value.a.override_trace==value.b.override_trace,"Subclass configure observes original published inputs and result")
	close(value)
func guarded_domain_cases()->void:
	var value:=pair(false)
	var finite:={"color":[.2,.3,.4],"radius":5.0,"multiplier":1.0,"shadow":1,"ambientonly":0}
	check(value.b._can_publish_final(finite),"Direct callback-free finite facade selects full final-publication path")
	for invalid in [null,"white",[],[1],[1,2],["1",2,3],[NAN,2,3],[INF,2,3],[1000001,2,3]]:
		var props:=finite.duplicate(true);props.color=invalid
		check(not value.b._can_publish_final(props),"Malformed/extreme color retains original body "+str(invalid))
	for field in ["radius","multiplier","shadow","ambientonly"]:
		for invalid in [null,"1",true,NAN,INF,-INF,1000001.0]:
			var props:=finite.duplicate(true);props[field]=invalid
			check(not value.b._can_publish_final(props),"Malformed/extreme scalar retains original body "+field+"/"+str(invalid))
	for props in [{"color":[-0.0,0.0,-0.0],"radius":0.0,"multiplier":-0.0},{"color":[0.0,-0.0,0.0],"radius":0.001,"multiplier":0.0},{"color":[.2,.3,.4],"radius":0.01,"multiplier":1.0}]:
		both(value,"configure",[props]);same(value,"signed zero / float32 support boundary")
		check(var_to_bytes(value.a.light_color)==var_to_bytes(value.b.light_color),"Exact color bit representation preserved")
		check(var_to_bytes(value.a.light_energy)==var_to_bytes(value.b.light_energy),"Exact energy bit representation preserved")
		check(var_to_bytes(value.a.omni_attenuation)==var_to_bytes(value.b.omni_attenuation),"Exact attenuation bit representation preserved")
	close(value)
