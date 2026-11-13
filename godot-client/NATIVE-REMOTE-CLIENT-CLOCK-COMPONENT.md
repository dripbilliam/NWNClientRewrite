# Native remote-client clock components

These standalone CPU components are authored and unrun. They activate no remote clock and change no Gameplay, World, Host, renderer, decoder or received state. A new instance remains unknown until an explicit owner publishes state. There are no Nodes, actor registries, SceneTree callbacks or per-frame world scans.

## Timer contract

The new world_timer.gd models CWorldTimer arithmetic. initialize(integer_microseconds_callable) is a **known native constructor** operation, not evidence that a connection/area owns a new timer. The provider returns a nonnegative Godot integer. Construction samples it once into both counters, uses mode0/paused0/rate5/7200000ms/7200sec and sets offsets for native day0x6df4c/raw time10496000. Fixed-rate and paused day/time remain null/unknown because the constructor does not initialize them.

Counters use exact unsigned DWORD {hi,lo} limbs. Unsigned64 /1000 is exact before day/ms arithmetic; that quotient fits signed64. restore_state accepts an explicit full field view, including oracleu64 values outside the signed provider range, without inventing provenance. reset_from copies every defined/unknown timer field while retaining the destination provider.

The native lower counter is absolute QPC-derived microseconds (or absolute GetTickCount()*1000), optionally a threaded cached sample. Constructor offsets cancel an arbitrary origin only while day length is unchanged. Native SetMinutesPerHour changes the base day length without recomputing offsets, so an arbitrary process-relative zero is NOT generally equivalent after that change. This component preserves supplied counters/offsets; it does not approve Godot ticks or any other substitute as the live native counter source.

Public methods are initialize, snapshot, synchronize_previous, snapshot_difference, set_time, set_minutes_per_hour, time, pause, unpause, calendar, time_parts, set_calendar, state_view, restore_state, reset_from and close. Results carry ready; missing providers/state/divisors do not fabricate time. The difference getter preserves modularu64. Only frame_seconds_from_difference narrows its low DWORD to signed32, converts to FLOAT and divides by1000000.

Pure add_world_times/compare_world_times/subtract_world_times preserve DWORD wrap, one carry/borrow and invalid-time chronology bypass. Valid backwards subtraction returns status−2 and outputsDefined:false, without day/time keys. Native unwritten caller scratch is never a result. seconds_to_world_delta preserves repeated FLOAT subtraction and native cast behavior. A nonadvancing or explicitly bounded conversion is unavailable, not approximated by modulo. Calendar helpers do not initialize a module/session.

## Pause-selector contract

The new client_pause_state.gd holds only small flag/list state, supplied timer handles and callbacks. configure uses explicit known fields. Exclusions are {known:false} (unknown), {known:true,ids:null} (native null), or {known:true,ids:[...]} (present, including empty). Unknown is never null. GUI absence uses an explicit {known:true,value:null} wrapper. No flags/profile/control/timer field is guessed.

active_timer preserves INVALID→T0 bypass, bit2 priority, then bit1, and native-null membership1 versus empty membership0. apply preserves raw (flags&mask)==uint32(value) early return. Only signed value1 is ON; later GUI set/clear uses nonzero. Repeated mask2/value1 still executes. Noop consumes no incoming list and does not require later callback/GUI fields.

A non-noop requires the complete known callback table before mutation: pause, unpause, snapshot, syncPrevious, reset, time, object, asObject, scene, sceneVirtual, resetObjectTimes, pauseText, audio, disposeIncoming, guiActive, guiBlocked, guiSetFlags and guiClearFlags. Null object/scene results are explicit missing pointers, not unknown providers. Lower callbacks are trusted accepted providers, not fabricated real-world/GUI/audio services.

Complete6e1fc0 ordering is retained. Old exclusions clear AFTER timer changes, selecting POST-change clocks with OLD membership. Live count is reread after callbacks; duplicate casts/scene lookups remain. Incoming IDs append uniquely but duplicate IDs still invoke every original callback. Scene150 precedes incoming reset; old reset precedes scene158. owned_incoming detaches received arrays before transfer, and the owned DTO is disposed only on the consumed branch. Known null list is valid for selectors but unavailable for clear/transition, where native6d6770 dereferences it.

receive_message models scalar read/capacity/overflow/apply/GUI ownership, not a network decoder. It preserves BYTE(2,1)/BOOL/WORD and ID order,16/doubling growth, overflow-before-apply and explicit unconsumed ownership rather than intentionally leaking memory. write_creature_stamp is only pure807680 day/time writing, not birth or actor authority. close releases component references; it is not native module cleanup6e6020.

snapshot_before_receive is only the proven conditional three-clock prefix: T0 iff flags&3==0, T1 iff flags&2==0, T2 always, in that order. It never dispatches packets, updates objects, advances GUI or assumes a runtime frame owner. Six explicit flag cases check that callback order separately from the original pause corpus.

## Source and lifecycle limits

References are [world_timer.js](../src/world_timer.js), [client_pause.js](../src/client_pause.js) and [retained original evidence](../evidence/client-pause-clocks.md), used only as original-backed algorithm references.

Native boundaries: ctor596aa0, Add596b40, Compare596e50, Subtract597a20, GetWorldTime597180, Snapshot597880, SetTime5978d0/597970, Reset5977e0, Difference597050, state6e1fc0, clear6d6770, selector6d7fe0 and receiver7a5680. Fresh difference evidence ev_af2dab73590b9a25a98c96aa659b0554e41b751b3e1f4487a12c496d82673291 confirms fullu64; frame6db800 performs narrowing.

Independent lifecycle audit finds process-service timers, not per-connection/area constructors. Client ctor has flags0/present-empty list but null timers until services construct three independent clocks. Module3/1 changes T0 rate only;3/3 and area calendar do not synchronize all clocks. Creature birth stamps BASE T0, not its later selected clock. Frame snapshot prefix is T0 when flags&3==0, T1 when flags&2==0, T2 always, BEFORE received frames. Object manager and GUI follow packet transitions. These facts are not production hooks here; lifecycle admission/cleanup remain a separate integration.

## Proposed guarded tests

The fixture exporter checks SHA pins for759 retained original pause cases,90 creature subtraction cases and55 FLOAT-seconds cases. Pause timer/GUI/audio/object/scalar callbacks are controlled boundaries, **not real lower-owner execution**. Backwards cases retain native seeded unwritten outputs; the Godot test requires outputsDefined:false.

Separate authored cases compare actual Godot arithmetic/fields with the existing JS reference: fullu64 epochs/wrap, absolute integer milliseconds, signed fixed rate, pause/unpause, reset provider retention, calendar, null/empty/unknown, raw noop, duplicate callbacks, live old-list count and close. This is not new original full-frame or remote-world acceptance.

Proposed command (not yet run):

    node godot-client/tools/test-native-remote-client-clock-component.mjs native-remote-client-clock-component-v1

The runner isolates the static copy, caps headless engine65s/output2MiB, retains rejected unique labels and checks source/copy/fixture/engine/six native-output hashes. No server, profiles/keys, native build, public connection, GPU, visible UI or user-process action. No acceptance is claimed before terminal proof.

