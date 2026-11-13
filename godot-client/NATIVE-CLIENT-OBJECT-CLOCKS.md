# Conditional lazy client object clocks

`native_data/client_object_clocks.gd` is a new, unintegrated RefCounted component.
It has no provider, Node, process loop, world-row store, or runtime admission hook.
Its relevant bindings contain only references, explicit registration,
two recent stamp phases and one frame's detached sample. Frame completion does
not iterate or copy bindings. No native binding/list capacity is invented.
Optional caller resource bounds return explicit unavailable rather than hiding
an overflow; they are not native limits. Selector data is detached once at
ingress and internally retained without per-frame list recopies at completion.

The source basis is [the lifecycle audit](NATIVE-REMOTE-CLIENT-CLOCK-LIFECYCLE.md),
especially the conditional lazy equivalence section. Creature7fbd10 uses selected
time at its AI phase, T0's current day length for597a20 subtraction, and only the
millisecond remainder for+58. It refreshes its previous pair during each eligible
AI update even without pending widgets. Birth7fb140 instead stamps base T0;
807680 reset writes the two previous-stamp DWORDs. Registration7675d0 occurs
before AI without a mesh gate. These facts do not certify the current protocol
adapter's birth, physical destruction, or AI traversal history.

`configure([connection,generation,areaId],resourceLimits={})` starts an explicitly
scoped component. Optional `maxBindings` and `maxSelectorIds` are nonnegative
integer caller policies; absent/null means no invented resource ceiling.
Every reference contains that exact `scope`, UInt32 `id`, explicitly present
`nativeLifetime` and `knownLifetime` (positive safe integer or explicit null),
and a caller-certified opaque
`physicalToken` (positive safe integer or printable ASCII string). Lifetime
numbers or token equality alone never create registration/construction facts.
Null display lifetimes require an opaque string physical token and the same
trusted construction/registration admission; absent fields never mean null.
This represents an internal physical-clock ref before raw/UI disclosure, not a
fake positive raw token. Optional positive `lifecycleEpoch` is retained exactly
and must match across transfers. Later display refs do not silently alias it;
Services resolves its private clock ref only after Root verifies the actual row.

`bind(ref,fact)` requires `registeredBeforeAi:true` and
`registration:{frame,phase,order}`. Phase is `before-ai` or `after-ai`, order is a
positive safe integer. An optional explicit `stamp` has those same position
fields, `kind:'birth'`, and a supplied base-T0 `pair:{day,time}`. A binding may be
created on first enqueue with historical registration facts; preceding completed
AI history takes precedence over an older birth stamp. Unknown birth can be
omitted when a certified preceding AI pass supplies the baseline.

`begin_frame(frame,data)` accepts increasing safe integer frame sequence and
**post-receive** `world`, `timer1`, `timer2` DWORD pairs, positive UInt32
`dayLength`, immutable `selector:{flags,exclusions:{known:true,ids:Array|null}}`,
and explicit `eligibility:{module:bool,area:bool,completePass:bool}`. Every frame
also requires caller-certified `clockStreamKnown:true`. The complete
pass fact must certify that the registered relevant creature was visited; native
manager early termination cannot be inferred away. Selector precedence matches
6d7fe0: bit2 takes precedence over bit1, null list admits every ID, and INVALID
`0x7f000000` selects base T0. These are complete-input contracts, not claims of
partial-provider support.

After `begin_frame`, replay staged native reset facts in actual order through
`reset_stamp(ref,pair,{frame,phase,order,nativeReset:true})`. Before-AI reset is
accepted only while that frame is open; after-AI reset only after completion.
Native reset callbacks received earlier must be staged, not relabeled with the
time of a later coalesced raw publication. Multiple resets in a phase retain the
latest ordered pair. The last pre-AI phase survives a same-frame after-AI reset,
so a lazy first query still reports the earlier AI elapsed field.

`complete_frame()` records only the three pairs and selector of a complete,
eligible AI phase. `sample(ref,frame)` is valid **after completion** of that exact
current frame. It uses the previous eligible phase's selected pair when this
object was already registered, or a later explicit birth/reset pair. It never
measures from enqueue time or the previous query. Repeated queries return a
detached identical result. `elapsedMilliseconds` is the native subtraction
remainder; `elapsedDays` is separate and is not folded into it. No GUI delta is
accepted by this owner.

Module/area-ineligible frames do not advance AI stamps and yield unavailable
elapsed output. Sequence gaps, malformed complete inputs and partial AI passes
create an explicit history barrier. A later complete phase restores the next
frame's baseline; a correctly phased current birth/reset can provide an earlier
known baseline. This only repairs the sampler's conceptual previous-stamp
history: it never repairs missing native pause/rate/selector history or promotes
global clock certainty. All later accepted inputs must independently carry the
external complete-clock certification. Valid backwards subtraction is unavailable because native597a20
leaves scratch unwritten. No zero, clamp, rebase, or seeded scratch is invented.

`retire(ref)` removes a binding without asserting physical destruction. Explicit
`rebind_scope(next,transfers,{continuousHistory:true})` requires same connection,
each transfer's `samePhysical:true`, unchanged ID and exact physical token. It
replaces references, preserves only explicitly transferred histories, and rejects
old scoped callbacks. Reconnect requires a new `configure`, never a transfer.
Ambiguous D+A or replicationRemoved cannot be converted into a fresh birth by
this component. `state_view` and `binding_view` return detached diagnostics;
private helpers/backing dictionaries are not mutation APIs. `close` releases all
thin records and snapshots.

The dedicated test separates90 retained original caller/subtraction observations
from authored eager-reference timelines. The eager reference updates every
registered object on each complete eligible phase, while the candidate samples
only selected consumers. Timelines include changing selectors/membership,
explicit reset callbacks, rate changes, AI gaps, first late enqueue, constructor
and reset phase ordering, unknown/backwards results, trusted scope transfer,
reconnect/removal/reuse, and mutation isolation. They do not prove a current
network, timer provider, physical lifecycle, native manager traversal, GUI, or
ScriptFloating integration.

Authoring command (not yet executed):

`node godot-client/tools/test-native-client-object-clocks.mjs native-client-object-clocks-v1`

The isolated copied headless runner has a65s owned-child deadline,2MiB output
bound, exact engine/corpus/source/copy/fixture/six-native-output guards, and no
server, key, profile, GPU, original process or native build work.
