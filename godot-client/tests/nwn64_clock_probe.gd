extends SceneTree
func _initialize() -> void:
	var script: GDScript=load("res://systems/model_rigs.gd");var clock: Node=script.new();var callable:=Callable(clock,"playback_state").bind(7,0)
	print("NWN64_CLOCK_PROBE ",JSON.stringify({"method":str(callable.get_method()),"unbound":callable.get_unbound_arguments_count(),"bound":callable.get_bound_arguments(),"object":str(callable.get_object()),"script_class":script.get_class(),"script_path":script.resource_path,"script_script_type":typeof(script.get_script()),"base_type":typeof(script.get_base_script()),"base":str(script.get_base_script()),"source":script.source_code}))
	clock.free();quit()
