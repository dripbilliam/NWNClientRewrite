extends "res://tests/native_scalar_rounding_test.gd"
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	check(not args.has("--scalar-representation=value") and not args.has("--scalar-representation=packed") and OS.get_environment("NWN_SCALAR_REPRESENTATION").is_empty(),"Normal scalar selection is tested without launch/environment overrides")
	super.run()
