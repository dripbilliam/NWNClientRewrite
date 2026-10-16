# NWScript ActionUseFeat

Target NWN:EE89.8193.37-17 x64, original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project remain unchanged. Full verified instructions
14050ee70..14050f190 supersede the misleading truncated decompiler output.

`script_use_feat.js` ports ExecuteCommandActionUseFeat287. Required arguments
are feat INT and target OBJECT. If the count exceeds2, the native command pops
both subfeat INT and engine location2. A three-argument call fails its mandatory
fourth pop; the local typed VM records an engine failure rather than silently
defaulting the missing argument. Type mismatches also retain engine context.

Auxiliary input is passed directly for compiled feat5 and the native form
bitset304/305/335..342. Otherwise successful active spell lookup replaces it
with the arithmetic upper16 FeatID; missing spell metadata preserves the raw
auxiliary. Full raw INT feat comparisons occur before WORD narrowing at UseFeat.
This is original compiled behavior, not a spell-specific effect implementation.

The command resolves canonical script-self, casts it to a creature, checks its
area and resolves the target. Existing-target dispatch copies the ACTOR's native
XYZ through its AsObject cast, with zero point if that cast fails. Missing target
and a valid location area dispatch OBJECT_INVALID plus the copied location;
otherwise the original target ID and null point reach UseFeat in the actor area.
There is no added PC/dead/commandability gate or extra generic action queue.
UseFeat's lower result is ignored; the successful VM command status is0 and its
script return type is void. The shared FeatRuntime/cast/effect owners are reused.

`inspect-native-script-use-feat.py` executes738 original command cases including
typed-pop failures, compiled exceptions, high/signed IDs, target/location cases,
self/area/cast failures and ignored UseFeat results. Typed pops, registry, casts,
areas, spell lookup, UseFeat and location cleanup are captured lower boundaries.
Cleanup through1405538c0/1405534a0 is observed on all exits; JavaScript location
value lifetime remains owned by the typed VM/GC. This does not claim native VM
allocation identity or complete lower gameplay/effect implementation.

Installed unchanged druid/barbarian characters pass through the actual client
NwScriptVm and installed API287 signature, using an owned instruction fixture:
two-argument Wild Shape305, four-argument selected Brown Bear305/1008 and
four-argument Rage293/spell307 normalization. Their authored installed scripts
execute, conjure/release phases run, own feat uses decrease once, queues drain,
canonical player/root/stats/equipment remain, class/innate pools stay unchanged,
and errors are zero (`installed-script-use-feat-v1.json`). This is an isolated
startup/AI-off fixture, not an authored quest or campaign playthrough. Existing
impact/effect presentation warnings remain visible.

All1591 tests pass (`script-use-feat-full-tests-v2.txt`) and the production build
passes with the existing chunk-size warning (`script-use-feat-build-v2.txt`).
Three focused tests additionally check full dispatch traces, typed2/4 argument
VM consumption/void result, and malformed arguments with engine context.
Active dependency audit v31 now has94 unbound names (previously95), with22
missing authored NCS unchanged. Static binding presence does not establish full
branch implementation. Spell/effect completion, combat and continuous campaign
acceptance remain open; goal ACTIVE.
