extends "res://tests/native_creature_voice_world_test.gd"
func frame(serial: int,source: Dictionary,sound: String="testscript") -> Dictionary:
	return {"serial":serial,"events":[{"source":source.duplicate(true),"soundBytes":Array(sound.to_ascii_buffer())}]}
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original:=Catalog.new(); check(original.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original native catalog mounts read-only")
	var catalog:=MemoryCatalog.new(); catalog.source=original; catalog.authored={"testscript:4":tone()}
	var world:=ParryWorld.new(); world.catalog=catalog; root.add_child(world)
	world.combat=preload("res://systems/native_render/combat_presentation.gd").new(); world.add_child(world.combat)
	var actor:=Node3D.new(); world.add_child(actor); actor.position=Vector3(2,1,-3); world.instances[world.controlled_id]=actor
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(2,5,3); camera.make_current()
	var object:={"id":world.controlled_id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":0},"replicated":{"position":[2,3,1]}}
	world.desired[object.id]={"key":"one","object":object}; world.installed[object.id]="one"
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world); var sounds=owner.script_sounds; var audio=owner.world_audio
	var source:={"id":object.id,"objectType":5,"lifetime":1,"replicated":{"position":[9,9,9]}}
	var canonical:=JSON.stringify(object); sounds.receive_raw(frame(1,source))
	check(await wait_for(func():return audio.stats.played==1),"Decoded server script cue reaches actual native worker/WAV/Dummy output")
	var first: Dictionary=audio.voices.values()[0]; var id:=int(first.id)
	check(first.profile.positional and first.profile.priority==8 and first.profile.volume==127 and first.position==[2.0,3.0,1.0],"Existing physical actor supplies original height0, priority8, default-volume127 one-shot origin")
	check(JSON.stringify(object)==canonical,"Sound routing does not mutate canonical gameplay fields")
	await create_timer(0.08).timeout
	check(is_instance_valid(first.player) and first.player.get_playback_position()>0,"Actual Dummy playback clock advances without a physical-device claim")
	actor.position=Vector3(4,1,-3); object.replicated.position=[4,3,1]; audio.advance()
	check(first.position==[2.0,3.0,1.0],"Script one-shot origin remains fixed when its actor moves")
	sounds.receive_raw(frame(1,source)); check(sounds.stats.started==1 and sounds.stats.stale==1,"Duplicate transport serial cannot replay the sound")
	world.desired.erase(object.id); world.instances.erase(object.id); sounds.receive_raw(frame(2,{"id":7,"objectType":16,"lifetime":2,"state":{"position":[2,3,1]}}))
	check(await wait_for(func():return audio.stats.played==2),"Nonrendered sound proxy still plays positionally without a model or interactable registry entry")
	check(audio.voices.has(id),"Already-playing one-shot survives canonical source removal")
	sounds.receive_raw(frame(3,{"id":1,"objectType":3,"lifetime":3}))
	check(await wait_for(func():return audio.stats.played==3),"Existing module proxy uses original nonpositional one-shot branch")
	var last: Dictionary=audio.voices.values()[-1]; check(not last.profile.positional and last.profile.priority==8,"Original 2D branch retains priority8")
	object.nativeLifetime=5; world.desired[object.id]={"key":"new","object":object}; sounds.receive_raw(frame(4,source))
	check(sounds.stats.started==3 and sounds.stats.stale==2,"Reused source ID cannot bind an older canonical lifetime")
	sounds.receive_raw(frame(5,{"id":7,"objectType":16,"lifetime":2,"state":{"position":[2,3,1]}},"")); check(sounds.stats.suppressed==1 and sounds.stats.started==3,"Empty sound reference starts nothing")
	var state: Dictionary=sounds.snapshot(); var audio_state: Dictionary=audio.snapshot()
	owner.close(); sounds.receive_raw(frame(6,source)); check(sounds.manager==null and sounds.stats.started==3 and audio.voices.is_empty(),"Closed area rejects late cues and stops actual one-shot players")
	await settle_retirement(); var deadline:=Time.get_ticks_msec()+2000
	while mixer_survivors(audio)>0 and Time.get_ticks_msec()<deadline: await create_timer(0.02).timeout
	check(mixer_survivors(audio)==0,"Actual stopped native streams/playbacks retire before process exit")
	world.combat.close(); world.instances.clear(); world.desired.clear(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scriptSounds":state,"audio":audio_state,"driver":AudioServer.get_driver_name(),"scope":"Direct native fixed-position sound with authored PCM, real catalog worker/Dummy output, nonrendered and nonpositional proxies, stale ID/serial and mixer retirement. No actual server/device acceptance."},"\t")); file.close(); print("NATIVE_SCRIPT_SOUND_WORLD ",checks," checks"); quit(0 if failures.is_empty() else 1)
