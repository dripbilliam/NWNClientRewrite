extends SceneTree

const Icons = preload("res://systems/native_item_icons.gd")
const Fence = preload("res://systems/native_render/icon_draw_fence.gd")
var checks := 0
var failures: Array[String] = []

class IconHarness extends Icons:
	var accepted: Array[int] = []
	func frame_rendered() -> void:
		accepted.append(int(pending_draw.get("completed_epoch", -1)))
		pending_draw = {}

class Receiver extends RefCounted:
	var epochs: Array[int] = []
	func complete(epoch: int) -> void:
		epochs.append(epoch)

class RetiredReceiver extends Node:
	func complete(_epoch: int) -> void:
		push_error("Retired icon receiver must never be invoked")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func resource_alive(value: WeakRef) -> bool:
	# Keep a temporary strong get_ref() result out of run()'s suspended stack.
	return value.get_ref() != null

func enqueue_retained_arm() -> WeakRef:
	# A non-suspending producer mirrors draw_icon's lifetime. Do not retain the
	# compiler's Resource/Callable expression temporaries across run()'s await.
	var held := Fence.new()
	var held_weak: WeakRef = weakref(held)
	var arm := Callable(held, "arm").bind(23, held)
	held = null
	check(resource_alive(held_weak), "Bound Resource argument retains queued arm target")
	arm.call_deferred()
	arm = Callable()
	check(resource_alive(held_weak), "Deferred queue owns keep-alive after producer releases callable")
	return held_weak

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var owner := IconHarness.new()
	root.add_child(owner)
	owner.pending_draw = {"render_epoch": 7, "completed_epoch": 0, "model": null}
	owner.icon_viewport_drawn(6)
	check(owner.accepted.is_empty() and int(owner.pending_draw.completed_epoch) == 0, "Older camera completion cannot consume a new icon")
	owner.icon_viewport_drawn(7)
	check(owner.accepted == [7] and owner.pending_draw.is_empty(), "Matching actual camera completion enters readback once")
	owner.icon_viewport_drawn(7)
	check(owner.accepted == [7], "Duplicate completion after readback is harmless")
	owner.pending_draw = {"render_epoch": 8, "completed_epoch": 0, "model": null}
	owner.icon_viewport_drawn(7)
	check(owner.accepted == [7] and int(owner.pending_draw.render_epoch) == 8, "Replaced request ignores prior callback")
	owner.close()
	owner.icon_viewport_drawn(8)
	check(owner.closed and owner.accepted == [7] and owner.pending_draw.is_empty(), "Closed owner retires request before deferred completion")
	owner.free()

	var actual := Icons.new()
	root.add_child(actual)
	actual.render_fence = Fence.new()
	actual.pending_draw = {"render_epoch": 9, "completed_epoch": 8, "model": null}
	actual.frame_rendered()
	check(int(actual.pending_draw.render_epoch) == 9, "Actual readback gate rejects an unrelated global postdraw without touching viewport")
	actual.close()
	actual.free()

	var receiver := Receiver.new()
	var fence := Fence.new(Callable(receiver, "complete"))
	fence._render_callback(0, null)
	await process_frame
	check(receiver.epochs.is_empty(), "An unarmed viewport draw publishes nothing")
	fence.arm(17)
	fence._render_callback(0, null)
	fence._render_callback(0, null)
	check(receiver.epochs.is_empty(), "Render callback never executes the receiver synchronously")
	await process_frame
	check(receiver.epochs == [17], "Only one deferred main completion is published per actual armed epoch")
	fence.arm(18)
	fence._render_callback(0, null)
	await process_frame
	check(receiver.epochs == [17, 18], "Next armed camera draw publishes its own epoch")
	fence = null
	var retired := RetiredReceiver.new()
	var late := Fence.new(Callable(retired, "complete"))
	late.arm(1)
	retired.free()
	late._render_callback(0, null)
	await process_frame
	check(late.published_epoch == 1, "Invalid receiver retires without invoking freed Node")
	late = null
	var queued := RetiredReceiver.new()
	var pending := Fence.new(Callable(queued, "complete"))
	pending.arm(2)
	pending._render_callback(0, null)
	queued.free()
	await process_frame
	check(pending.published_epoch == 2, "A receiver retired after enqueue is skipped by deferred ObjectID delivery")
	pending = null
	var held_weak := enqueue_retained_arm()
	await process_frame
	await process_frame
	check(not resource_alive(held_weak), "Queued arm releases Resource after deferred invocation/drain without owner/camera")
	var report := {"success": failures.is_empty(), "checks": checks, "failures": failures, "graphical": false, "server_connections": 0, "scope": "Sequential lifetime/job admission/deferred callback checks only. No GPU completion or image parity acceptance."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify(report))
			file.close()
	print("NATIVE_ICON_FENCE_LIFETIME " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
