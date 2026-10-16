# Damage-buff admission, presentation and removal

Target: NWN:EE89.8193.37-17 x64, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original installation and Ghidra database remained read-only.

## Original evidence

Full captured application owners:

| Native effect | Application owner | Child icon |
|---|---|---|
| Damage increase13 | 14042a290..42a376 | 31 |
| Damage decrease14 | 140429ce0..429e07 | 32 |
| Damage immunity increase16 | 14042a080..42a28c | 33 or111–119 |
| Damage immunity decrease17 | 140429e10..42a07c | 34 or120–128 |
| Damage reduction12 | 14042a380..42a41d | 3 |
| Damage resistance2 | 14042a420..42a4bd | 1 |
| Damage shield61 | 14042a4c0..42a585 | 49 |

Damage decrease requires a creature and category21 immunity check; there is no
extra positive-cost or plot gate. Damage increase also retains on noncreatures.
Both mark creature combat information dirty. The native loading/dead gate has
duration3/4 exceptions; normal application does not get a blanket dead veto.

Reduction/resistance have no amount, dead or creature gate. If the parent's
exposure field20 is nonzero, the original broadcasts floaty2233/2234 before
child application. Production reuses mapped BroadcastFloatyEffect439ae0 and its
canonical recipient routing. This does not establish final HUD floating-text art.

Immunity rejects negative amounts and, for decreases, plot and creature
category22 immunity. Zero is admitted. Its live pool scan sums only **exactly
equal flag sets**, wraps in INT32, and calls SetDamageImmunity before applying
the icon. Exact single flags8..2048 select elemental icons; other flag sets use
the generic icon. Native SetDamageImmunity49ae80's complete leaf CFG clamps the
INT to-100..100 and writes only the lowest flagged signed BYTE; flags0 writes
nothing. That original setter executes in the oracle.

Removal owners4362e0/436540 mark creature combat information dirty.
436320/436430 scan the live pool **before erase** and respectively add/subtract
the removed contribution. Production now follows that callback order rather
than recomputing after erase from a mixture of offline item projections and
live effects. Shared effect-group removal still owns children and creator IDs.

The complete CGameEffect copy constructor423570..423768 executes in the final
oracle. All icon children inherit the parent's uint64 identity/context/timing,
but have cleared payload and private exposure. Flag1 only preserves icon
visibility. These paths use `copyConstruct` explicitly.

## Implementation and verification

`damage_buff_effect.js` supplies shared damage/mitigation/immunity admission
and removal; `effect_runtime.js` wires the native callbacks and existing
floaty/icon/cache owners. The old presentation warnings for types2/12/13/14/16/17
were removed only after those paths were implemented. `damage_shield.js` now
uses the actual copy-constructor boundary too.

Final `inspect-native-damage-buffs.py` v2 records8,188 original-code executions,
including all seven application and four removal owners, constructor and cache
setter. Creature/dead/immunity, icon application, floaty delivery, heap and
string/vector initialization are explicit lower boundaries. Native allocation
failure and complete downstream damage/GUI/protocol parity are not claimed.
Initial v1 covered the first six owners; it is superseded by v2's shield coverage.

Installed probe v2 invokes unchanged Endure Elements50, Stoneskin172,
Divine Favor414 and Elemental Shield47 impact scripts under the active Prelude
resolver. It checks expected parent/icon types, shared IDs, cleared child
payloads, native floaty tokens, cache snapshots and group removal. Endure
Elements emits five2234 messages; Stoneskin emits2233. General AI/startup/entry
are isolated; all load failures and unrelated warnings remain recorded.

Probe v1 correctly caught a real preexisting Elemental Shield icon49 payload
copy error. Full native shield-owner capture confirmed constructor flag1; the
runtime adapter was corrected, and v2 passes without weakening the assertion.
Other historical effect handlers still using full-copy adapters need an audit;
these fixes do not claim those paths are already accurate.

The installed learn→prepare→rest→cast/cancel probe v3 passes with the new
Endure Elements icons. The rendered `--rest` regression also passes, with no
new errors and the known missing plc_w02 PWK kept separately. Existing native
comparison evidence and UI snapshots remain available. Native icon state is
implemented; HUD buff-art display is a separate remaining task.

Full regression:1,651 tests pass (`damage-buff-full-tests-v3.txt`); build v2
passes with the existing chunk-size warning. Older direct API tests now await
the nested effect application and account for real icon children, including
the death-script snapshot before effect purge. No stat/HP expectations were
relaxed. Spell dependency presence remains86 unbound API names/22 missing NCS
from auditv36. The entire spell/combat/campaign goal remains active.
