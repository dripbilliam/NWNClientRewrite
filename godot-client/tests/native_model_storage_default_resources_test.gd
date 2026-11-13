extends "res://tests/native_model_storage_resources_test.gd"
func resource_evidence(a: Dictionary,b: Dictionary) -> Dictionary:
	var row:=super.resource_evidence(a,b)
	var args:=OS.get_cmdline_user_args()
	var no_override:=not args.has("--model-storage=native") and not args.has("--model-storage=views") and OS.get_environment("NWN_MODEL_STORAGE").is_empty()
	check(no_override and b.animation.pose.configured_native_storage() and b.animation.pose.native_context!=null,"Unmodified Windows selection actually uses native persistent Part storage")
	row.default_selection=no_override;return row
