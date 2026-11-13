extends SceneTree
# Root schedules this graphical fixture. It never connects to a server and
# uses only the sealed original GUI corpus. A Safe run records references;
# later runs compare every actual raster/bound against that exact reference.
const Icons = preload("res://systems/native_item_icons.gd")
const Recorded = preload("res://systems/native_data/recorded_catalog.gd")
const Cache = preload("res://systems/native_data/prepared_cache.gd")
const CASES = [["pb_but_inv", "up"], ["pnl_chat_prompt", ""], ["pb_but_map", "down"], ["but_chat_bar360", ""], ["pb_but_inv", "hilite"], ["but_chat_bar720", ""], ["edit_chat_left", ""], ["pb_but_map", "hilite"], ["edit_chat_main", ""], ["edit_chat_right", ""], ["ctl_btn_chatmode", "up"], ["pb_but_inv", "down"]]
var checks := 0
var failures: Array[String] = []
var report_path := ""
var reference_path := ""
var rows: Array = []

class CancelIcons extends Icons:
	var cancellations := 0
	var fence_weak: WeakRef
	func draw_icon(job: Dictionary) -> void:
		super.draw_icon(job)
		if not pending_draw.is_empty():
			cancellations += 1
			if render_fence != null:
				fence_weak = weakref(render_fence)
			close()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func production_region(name: String) -> Rect2:
	# Exact NativeChatHud/NativeChatBackdrop callers: pnl_chat itself supplies
	# layout hooks and is not rasterized; prompt/panes have bounded crops.
	if name == "pnl_chat_prompt":
		return Rect2(0, -20, 2040, 23)
	if name in ["edit_chat_left", "edit_chat_right", "edit_chat_main"]:
		return Rect2(0, -10, 720 if name == "edit_chat_main" else 360, 2048)
	return Rect2()

func wait_texture(owner, key: String, completions: Dictionary) -> Texture2D:
	var deadline := Time.get_ticks_msec() + 30000
	while not owner.textures.has(key) and not completions.has(key) and Time.get_ticks_msec() < deadline:
		await process_frame
	return owner.textures.get(key)

func run() -> void:
	var corpus := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
		elif argument.begins_with("--catalog="):
			corpus = argument.trim_prefix("--catalog=")
		elif argument.begins_with("--reference="):
			reference_path = argument.trim_prefix("--reference=")
	if report_path.is_empty() or corpus.is_empty() or FileAccess.file_exists(report_path) or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var catalog := Recorded.new()
	check(catalog.mount(corpus), "Sealed original GUI corpus opens: " + catalog.failure)
	var corpus_sha := FileAccess.get_sha256(corpus.path_join("manifest.json"))
	check(corpus_sha == "1ef50ed518173a2f172f42a935252c0c3500319c2393286a5773f2de3b28e035", "Exact recorded original GUI corpus is used")
	var reference: Dictionary = {}
	if not reference_path.is_empty():
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(reference_path))
		check(saved is Dictionary and bool(saved.get("success", false)) and str(saved.get("catalog_sha256", "")) == corpus_sha, "Successful same-corpus reference is available")
		if saved is Dictionary:
			for row in saved.get("rasters", []):
				reference[str(row.id)] = row
	var held_nodes: Array = []
	for reuse in [false, true]:
		var owner := Icons.new()
		root.add_child(owner)
		owner.reuse_models_enabled = reuse
		owner.maximum_cached_models = 4
		owner.configure(catalog, "") # Deliberately no persistent finished-pixel path.
		var completions: Dictionary = {}
		owner.completed.connect(func(key: String, _texture: Texture2D, error: String): completions[key] = error)
		var requests: Array = []
		# Burst requests allow worker completions and heterogeneous viewport sizes
		# to interleave naturally. Comparisons are keyed by resource/state.
		for pair in CASES:
			check(catalog.has_resource(str(pair[0]), 2002), "Original GUI resource exists: " + str(pair[0]))
			requests.append({"name": pair[0], "clip": pair[1], "key": owner.request_model(str(pair[0]), str(pair[1]), {}, 0, "", [], production_region(str(pair[0])))})
		for request in requests:
			var id := ("reuse" if reuse else "transient") + ":" + str(request.name) + ":" + str(request.clip)
			if str(request.key).is_empty():
				check(false, "Original GUI request refused " + id)
				continue
			var texture := await wait_texture(owner, str(request.key), completions)
			check(texture != null, "Actual GUI raster completes " + id + ": " + str(completions.get(str(request.key), "pending at deadline")))
			if texture == null:
				continue
			var image := texture.get_image()
			check(image != null and not image.is_empty(), "Actual nonempty GPU readback " + id)
			if image == null or image.is_empty():
				continue
			image.convert(Image.FORMAT_RGBA8)
			var row := {"id": id, "width": image.get_width(), "height": image.get_height(), "rgba_sha256": Cache.digest(image.get_data()), "bounds": JSON.stringify(owner.image_bounds[str(request.key)])}
			rows.append(row)
			if not reference_path.is_empty():
				check(reference.has(id), "Reference has requested original state " + id)
				if reference.has(id):
					check(row.width == reference[id].width and row.height == reference[id].height and row.rgba_sha256 == reference[id].rgba_sha256 and row.bounds == reference[id].bounds, "Byte-exact original raster and bounds match reference " + id)
			var image_path := report_path.trim_suffix(".json") + ".%02d-" % rows.size() + str(request.name) + "-" + (str(request.clip) if not str(request.clip).is_empty() else "default") + ".png"
			check(image.save_png(image_path) == OK, "Independent raster artifact saved " + id)
		check(int(owner.stats.get("prework_hits", 0)) == 0, "No persistent finished pixels can mask this run")
		for model in owner.cached_models.values():
			held_nodes.append(weakref(model))
		owner.close()
		check(owner.cached_models.is_empty() and owner.assets.running.is_empty(), "Close drains active owner and cached GUI actors")
		owner.queue_free()
		await process_frame
		await process_frame
	check(held_nodes.all(func(value): return value.get_ref() == null), "All retained GUI actors retire")
	for iteration in 3:
		var cancelled := CancelIcons.new()
		root.add_child(cancelled)
		cancelled.configure(catalog, "")
		cancelled.request_model("pb_but_inv", "up")
		var deadline := Time.get_ticks_msec() + 30000
		while not cancelled.closed and Time.get_ticks_msec() < deadline and cancelled.stats.errors.is_empty():
			await process_frame
		check(cancelled.closed and cancelled.cancellations == 1 and cancelled.pending_draw.is_empty(), "Cancel after viewport/arm submission retires request " + str(iteration))
		check(cancelled.request_model("pb_but_map", "up").is_empty(), "Closed owner refuses another request")
		var weak_fence := cancelled.fence_weak
		cancelled.close()
		cancelled.queue_free()
		await process_frame
		await process_frame
		var drain_deadline := Time.get_ticks_msec() + 2000
		while weak_fence != null and weak_fence.get_ref() != null and Time.get_ticks_msec() < drain_deadline:
			await process_frame
		check(weak_fence == null or weak_fence.get_ref() == null, "Cancelled camera fence retires after queued renderer use")
	check(rows.size() == CASES.size() * 2, "Every requested original raster is represented")
	var output := {"success": failures.is_empty(), "checks": checks, "failures": failures, "catalog_sha256": corpus_sha, "rasters": rows, "reference": reference_path, "thread_model": ProjectSettings.get_setting("rendering/driver/threads/thread_model"), "main_on_render_thread": RenderingServer.is_on_render_thread(), "engine": Engine.get_version_info(), "server_connections": 0, "graphical": true, "scope": "Original GUI raster byte/bounds comparisons with unique in-memory-only caches, mixed viewport dimensions, model reuse and close/cancel lifecycle. No world FPS acceptance."}
	output.rendering_method = RenderingServer.get_current_rendering_method()
	output.rendering_driver = RenderingServer.get_current_rendering_driver_name()
	var writer := FileAccess.open(report_path, FileAccess.WRITE)
	writer.store_string(JSON.stringify(output, "\t"))
	writer.close()
	quit(0 if failures.is_empty() else 1)
