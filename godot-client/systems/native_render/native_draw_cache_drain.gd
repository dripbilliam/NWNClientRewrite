extends Node
# Process-owned optional-cache retirement driver. It outlives individual worlds.
var tick: Callable
var stopping: Callable
func _process(_delta: float) -> void:
	if tick.is_valid():tick.call()
func _exit_tree() -> void:
	if stopping.is_valid():stopping.call()
	tick=Callable();stopping=Callable()
