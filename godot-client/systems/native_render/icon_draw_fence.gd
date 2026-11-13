extends CompositorEffect
# V3 adds a bound Resource keep-alive to the queued arm call. The receiver is
# immutable; epoch fields belong exclusively to the RenderingServer thread.
var completed: Callable
var armed_epoch := 0
var published_epoch := 0

func _init(receiver: Callable = Callable()) -> void:
	completed = receiver
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	enabled = true

# _keep_alive is deliberately bound as a Variant Resource argument by the
# producer, retaining this target until the RenderingServer invokes the call.
func arm(epoch: int, _keep_alive: CompositorEffect = null) -> void:
	armed_epoch = epoch

func _render_callback(_callback_type: int, _render_data: RenderData) -> void:
	if armed_epoch <= 0 or published_epoch == armed_epoch:
		return
	published_epoch = armed_epoch
	if completed.is_valid():
		completed.call_deferred(armed_epoch)
