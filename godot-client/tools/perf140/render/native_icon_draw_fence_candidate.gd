extends CompositorEffect
# Private prototype. All fields below are immutable after publication or are
# accessed exclusively on the RenderingServer thread. The receiver is an
# immutable Callable; delivery uses its ObjectID-safe deferred main-thread path.
var completed: Callable
var armed_epoch := 0
var published_epoch := 0

func _init(receiver: Callable = Callable()) -> void:
	completed = receiver
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	enabled = true

# Called only through RenderingServer.call_on_render_thread AFTER the icon
# viewport's property mutations have been queued. Main never reads these fields.
func arm(epoch: int) -> void:
	armed_epoch = epoch

func _render_callback(_callback_type: int, _render_data: RenderData) -> void:
	# This callback belongs to this camera/viewport's actual draw, rather than
	# an unrelated global frame whose deferred notification happened to arrive.
	if armed_epoch <= 0 or published_epoch == armed_epoch:
		return
	published_epoch = armed_epoch
	if completed.is_valid():
		completed.call_deferred(armed_epoch)
