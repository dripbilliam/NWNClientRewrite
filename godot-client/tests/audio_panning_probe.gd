extends SceneTree
# Engine isolation: authored waveform and raw Godot nodes, no client adapter.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var scene := Node3D.new();root.add_child(scene)
	var camera := Camera3D.new();scene.add_child(camera);camera.make_current()
	var listener := AudioListener3D.new();scene.add_child(listener);listener.make_current()
	var source := AudioStreamPlayer3D.new();scene.add_child(source)
	var wave := AudioStreamWAV.new();wave.format = AudioStreamWAV.FORMAT_16_BITS;wave.mix_rate = 8000;wave.stereo = false;wave.loop_mode = AudioStreamWAV.LOOP_FORWARD;wave.loop_end = 8000
	var bytes := PackedByteArray();bytes.resize(16000)
	for i in 8000:bytes.encode_s16(i*2,int(sin(float(i)*TAU*220/8000)*4095))
	wave.data = bytes
	source.stream = wave;source.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED;source.max_distance = 0;source.attenuation_filter_cutoff_hz = 20500;source.attenuation_filter_db = 0;source.volume_linear = 0.5
	var capture := AudioEffectCapture.new();capture.buffer_length = 1.0
	var index := AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,capture)
	source.play()
	var rows: Array = []
	for position in [Vector3.ZERO,Vector3(5,0,0),Vector3(-5,0,0)]:
		source.global_position = position
		await create_timer(0.25).timeout;capture.clear_buffer();await create_timer(0.15).timeout
		var count := capture.get_frames_available();var energy := Vector2.ZERO
		for sample in capture.get_buffer(count):energy += Vector2(sample.x*sample.x,sample.y*sample.y)
		energy /= maxf(1,count)
		rows.append({"position":[position.x,position.y,position.z],"energy":[energy.x,energy.y],"frames":count})
	source.stop();source.stream = null;scene.queue_free();await process_frame;await process_frame
	AudioServer.remove_bus_effect(0,index)
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"driver":AudioServer.get_driver_name(),"speakerMode":AudioServer.get_speaker_mode(),"rows":rows,"scope":"Raw Godot node/mixer isolation; no native client adapter or external assets"},"\t"));file.close();print(JSON.stringify(rows));quit()
