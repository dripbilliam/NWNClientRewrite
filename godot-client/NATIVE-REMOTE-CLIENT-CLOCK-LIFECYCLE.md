# Native remote client clock lifecycle

This read-only static audit closes several lifecycle facts left open by [the earlier ScriptFloating clock audit](NATIVE-SCRIPT-FLOATING-CLOCK-AUDIT.md). The target is the original `nwmain.exe`, SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. [The source report](reports/native-remote-client-clock-lifecycle-v1.json) retains exact function identities, complete selected pseudocode/assembly and coverage. REA used an ephemeral headless Ghidra analysis process; the game was not executed or attached, original bytes were not written, and no engine test, server, game connection, key/profile access or native build ran.

The current Root change admits decoded `module-pause-state`3/9 and SceneCapture records, but does not activate a remote clock owner. That decoder work supersedes the older audit's statement that3/9 is unsupported. It does not itself initialize timers or establish frame history. This audit edits no production or test source.

## Construction and counter origin

`CAppManager::CAppManager`03d280 creates the client wrapper6aadf0, which allocates internal client6c9df0. Its constructor writes BYTE flags`+4c8=0`, allocates a16-byte shared list at`+4d0` with null element buffer/count0/capacity0, and initializes timer pointers`+50/+58/+60` to null. The **list object is present-empty**, not a null list; those states have different selection semantics.

`SDL_main`046340 invokes service wrapper6acd40→6e3c80 once on the startup path. Services allocate three distinct0x38-byte CWorldTimers in order T0`+50`, T1`+58`, T2`+60`. They are process-service owners, not constructed by each area or calendar message.

Timer constructor596aa0 writes:

| Field | Proven initial value |
| --- | --- |
| mode DWORD`+0` | 0 |
| counter QWORD`+8`, previous QWORD`+10` | The same single microsecond sample |
| paused DWORD`+18` | 0 |
| minutesPerHour BYTE`+2c` | 5 |
| dayLength DWORD`+30` | 7,200,000ms |
| secondsPerDay DWORD`+34` | 7,200 |
| dayOffset DWORD`+24` | `0x6df4c-floor((sample/1000)/7200000)` modulo DWORD |
| timeOffset DWORD`+28` | `10496000-((sample/1000)%7200000)` modulo DWORD |

The constructor does **not** initialize fixed-rate DWORD`+4` or paused day/time`+1c/+20`; mode0/paused0 avoid reading those fields initially. At that stored sample, GetWorldTime normalizes the fixed constructor pair day`0x6df4c`, time10,496,000ms to day450381/time3,296,000ms. Each timer takes its own constructor sample.

The actual source chain is16dd30(arg0)→16e0f0. Threaded mode returns the internal cached microsecond QWORD`+20`; otherwise16e110 takes the direct Real branch. There is **no process-relative subtraction** in this chain. Selecting the exact runtime frequency/cache mode remains a host timer-provider boundary, not a server field.

CExoTimersInternal constructor16dd60 latches the exact raw BOOL result of QueryPerformanceFrequency at its`+0`; only value1 selects QPC. It saves signed LARGE_INTEGER frequency F at`+8`. Its conversion has two branches and must not be replaced with `(Q*1000000)/F`:

| Latched condition | Stored conversion | Real16e110 operation |
| --- | --- | --- |
| QPF result exactly1 and unsigned F<200,000,000 | branch DWORD`+4=1`; double`+18=double(signedF)/1000000.0` | Convert signed QPC Q to double, divide by stored double, then `CVTTSD2SI` to signed64; returned QWORD preserves those bits. |
| QPF result exactly1 and unsigned F>=200,000,000 | branch DWORD`+4=0`; QWORD`+10=trunc(signedF/1000000)` | Treat QPC bits as uint64 and use unsigned64 `DIV` by that stored integer divisor. |
| QPF result other than1 | No QPC conversion is read | GetTickCount returns a **DWORD**, zero-extend it, then multiply in64 bits by1000. Its DWORD wrap is not GetTickCount64. |

The constructor initializes cached microseconds`+20` with that same chosen conversion before launching its thread. The exact Real assembly is16e132 `CVTSI2SD`,16e139 `DIVSD`,16e13e `CVTTSD2SI` for double;16e149..150 zero-high unsigned division for integer;16e160 zero-extension and16e162 multiplication for fallback. QPF and branch are not re-queried on every sample. Malformed frequency/overflow cases are not certified by assuming a valid modern Windows result.

Shipped data at14128f0c8 sets `g_bUseThreadedTimers=1`. The real timer loop is16e1f0 (16e1e0 is a thunk reached by the launch-pad vtable). It updates cached DWORD ticks`+28`, microseconds`+20` and time64`+30`, then sleeps for `g_nThreadedTimerResolution*1000` nanoseconds. Shipped resolution at14128f0cc is100, hence100µs. `perfstats`311db0 saves the flag/resolution, forces1 and10µs when enabled, and restores saved values when disabled; callback57ba70 writes the flag from a BYTE. The shipped default is therefore not a measurement of a live flag or an assertion that external/indirect writes are impossible.

A new direct Win32 Real provider could be an explicit branch candidate, with latched QPF result/frequency/conversion and exact integer/double operation order. It must not claim equality to the native default threaded-cache sampling phase. It should identify its selected branch rather than silently substituting Godot's process-relative ticks or a high-precision multiply/divide formula.

Constructor offsets cancel a common counter origin while day length is unchanged. This is not a universal permission to start at zero. If constructor and later counter are both shifted by one old day length L, the old offset day drops by1. After a rate change to day length L', the resulting absolute time shifts by `L-L'`. Therefore arbitrary rebasing is not generally invariant across module-rate changes or mixed timers. A remote adapter needs a clearly admitted microsecond source/calibration or an explicit narrower equivalence claim.

## Module, area and cleanup boundaries

The actual module3/1 path7a4d30→7cd2c0 reads the module minutes-per-hour BYTE and calls597850 on **T0 only**, through base-clock getter6ac330. SetMinutesPerHour coerces0 to1 and writes seconds/day=`rate*1440`, milliseconds/day=`rate*1440000`; it does not recompute offsets, snapshot or reset timers. The complete inspected module body does not call ResetTimer or an absolute SetWorldTime method. It does not synchronize T1/T2 rates. The nearby7c2c20→7c25c0 is the3/2 acknowledgement sender, not another timer initialization.

Module3/3 handler7a58e0 writes the module's calendar year/month/day/hour fields and visual phase/transition through7cfbb0. It does not call a CWorldTimer method. The complete area receiver76d910 uses T0's snapshot difference to seed its loading fade, then host microsecond samples for that fade loop; no clock reallocation/reset/SetWorldTime call appears in that body. These observations concern the inspected native bodies, not a proof that every indirect/external mutation is impossible.

Cleanup6e6020 performs this order before destroying/recreating module and object-registry owners:

1. `SetPauseState(mask2,value0,incomingNULL)`.
2. `SetPauseState(mask1,value0,incomingNULL)`.
3. `ClearOldExclusions`6d6770 again.

It retains the three clock pointers. An already-clear state can return early in either setter, so cleanup is not three unconditional timer resets. It is called through6acdc0, including module dispatcher case8, and by disconnect6e2da0 after DisconnectFromSession when the module owner exists. Its full inspected body does not reseed constructor epoch or allocate CWorldTimers. A new connection-scoped projection is an adaptation unless it preserves or safely establishes this process-level lifecycle; received calendar alone cannot do that.

## Native frame order and units

Complete client frame6db800 establishes this sequence:

1. If flags bit2 is clear: snapshot T0 only if bit1 is also clear, then snapshot T1 if bit2 is still clear. Always snapshot T2.
2. ProcessReceivedFrames and UpdateStatusLoop. Received3/9 transitions and their per-ID reset callbacks therefore occur **after** those initial snapshots.
3. When module and area owners exist, perform the client pre-AI update6e6220 and ClientAIList manager767d50.
4. Read T2 snapshot difference and call GUI UpdateAndRender1f70e0. A newly activated floaty receives this same GUI tick.

SetSnapshotTime597880 first copies counter to previous; mode0 then samples the microsecond source, other modes add the signed integer quotient`1000000/fixedRate`. GetSnapshotTimeDifference597050 returns modular unsigned64 subtraction with no narrowing. At the GUI caller,6dc252 calls the getter;6dc257 moves **EAX** to XMM1,6dc25b performs signed DWORD-to-f32 conversion,6dc25e divides by f32 1e6, and6dc26a calls GUI. Global DeltaT earlier uses the same caller conversion from T0, not T2. Other callers can use different widths; do not narrow the getter globally.

## Creature birth, resets and AI stamps

Creature constructor7fb140 calls base getter6ac330→T0.GetWorldTime and writes previous DWORD day`+50` and millisecond-within-day`+54` (instructions7fb450..7fb478). Birth does **not** use selected clock6ab840. Base CNWCObject constructor761760 initializes floaty cooldown`+98=0`, but supplies no proven initialized elapsed DWORD`+58`.

Accepted A/type5 reader77f870 calls that constructor only when the native typed lookup is absent. After assigning the actual ID/area and successful AddExternalObject, it immediately calls ClientAIList.AddObject7675d0, before later appearance/equipment work. AddObject deduplicates actual IDs and appends them without a mesh-readiness condition. A generic proxy, newly stamped lifetime, coalesced raw row or D+A is not this native birth boundary.

Manager767d50 rotates its live ID list and calls virtualE8 AIUpdate for its initial count. An unavailable initial lookup/cast ends the pass; this is not a promise to update every arbitrary known proxy. For a visited creature,7fbd10 samples its **selected** clock, subtracts previous`+50/+54` using T0's day length, writes only the millisecond remainder to`+58`, and later samples the selected clock again to refresh`+50/+54` before FIFO766e20. Missing model emits a warning but does not skip those clock/FIFO operations.

Creature reset virtual10 at807680 writes only previous day/time. Pause transitions reset old-list objects using new flags/timers before clearing the old list; incoming list objects receive scene callback150 before selected-time reset. Exact callbacks belong to the native current object, not a future reused numeric ID. Base reset2964d0 is a no-op. D tombstones and current hard-remove rendering do not prove the original delayed destruction occurred.

## Conditional lazy-query equivalence

A per-known-object scan is not mathematically required merely to reproduce the elapsed field for objects that matter to ScriptFloating. A bounded lazy design is derivable **only if** its adapter knows the actual eligible AI phases and exact object birth/reset/retirement boundaries:

- Retain the three full snapshots and selector/list state of the preceding completed eligible AI phase. Retain the old rate/offset state, rather than converting a past counter through a newly changed rate.
- At first relevant query, use the actual T0 constructor birth stamp if it is newer than the preceding AI phase; otherwise use the preceding selected-clock pair. Any later exact transition reset overrides that previous pair, including multiple ordered resets within one incoming message/frame.
- Subtract from the selected current pair with T0's current day length, then preserve the native defined/undefined result. Advance the conceptual previous pair at each eligible AI phase; do not measure the whole interval since first enqueue or last queue query.
- Keep GUI T2 snapshot-difference consumption separate. Do not assume a known raw object was in ClientAIList or that AI ran during loading/subframes. True native destruction/reconstruction is separate from known-lifetime retirement.

This is a conditional algorithmic observation, **not** proof of a current runtime optimization. It does not authorize starting stamps at first enqueue, resetting them on raw disclosure tokens, reconstructing them from final snapshots, or treating missing phase/birth history as zero. Host/SessionWorld ordering and the actual runtime owner remain separate integration work.

## Backwards subtraction and retained limits

SubtractWorldTimes597a20 returns`0xfffffffe` without writing either output when both input times are within T0 day length and the current pair precedes the previous pair. Creature7fbd10 does not check that status before copying stack scratch`local_b4` into elapsed`+58`. Its scratch is not initialized along that path. The earlier bounded original executions demonstrated seed-dependent outputs; this audit did not rerun them. No deterministic zero, clamp or rebase is native parity for that branch.

The report separates fresh complete static queries, exhausted frame/area source views, and the prior pinned creature/FIFO/GetWorldTime/subtraction dossier. Large full REA responses exceeded the transport budget for frame/area; retained source paging completed without rerunning or cancelling analysis. High-pcode omissions remain explicit; source/assembly observations do not claim exhaustive external/indirect mutation coverage. Runtime timing, threading/cache selection, complete connection adaptation and original received special-clock acceptance remain unproved. No pixel requirement or renderer substitution is used to reach these conclusions.
