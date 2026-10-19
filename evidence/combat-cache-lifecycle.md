# Combat-information ownership and polymorph snapshot — 2026-10-17

Read-only original NWN:EE89.8193.37-17 x64 nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original installation and Ghidra project remain unchanged. The prior goal turn
made verified progress (character-sheet/HP code, tests, UI and sealed backup).
This continues the same active spell/combat/campaign goal with single-player
first. No campaign, spell or form-specific outcome exceptions were added.

## Original owners and implementation

`src/combat_information.js` now follows the distinct native lifecycle owners:

- Copy constructor1402a2120..1402a22ae copies selected scalar fields, both weapon
  IDs, both strings and flag bytes68/69. It initializes empty node lists and
  **does not copy attack/damage nodes**. Natural-damage scalar16..18 and padding
  are unwritten. An explicit initialized-byte mask distinguishes those bytes
  from defined zero state; ordinary rebuilds mark16..18 after writing them.
- Assignment1402a2cd0..1402a2f89 is a self no-op. Otherwise it copies the same
  selected scalars/weapon IDs and clones each six-byte node, rebuilding lists
  with16/doubling capacity. It **retains destination strings and flag bytes**.
  The native owner frees old pointer arrays without destroying their old nodes;
  JS retains externally held old node references rather than marking them freed.
- Destructor1402a2930..1402a2a35 removes nodes from the front, releases strings
  and arrays and clears counts/capacities. JS marks each released node disposed
  and invalidates owned arrays/text without replacing canonical game objects.
- Equality1402a2fd0..1402a3177 compares selected fields and node pointer identity.
  Inequality1402a31c0..1402a33a1 compares selected fields and node byte values
  through Node::operator!=1402a33b0. They are **not logical complements**.
  Both ignore strings, flags, capacity, natural-damage16..18 and padding.
  The port preserves that observed distinction instead of correcting the game.

`PolymorphRuntime` now executes the saved-owner replacement represented by
Polymorph14039a02b..14039a081: destroy previous a48, copy-construct a new a48
from the current d70. The same canonical creature, root, stats and equipment
stay in use. The old labelled combat-projection snapshot and its diagnostic
were removed because the real owner is available. UnPolymorph does not consume
or release a48; subsequent transformation replaces it, as observed in the
separately compared full coordinator. No forced d70 refresh is inserted before
snapshot copying. Other unsupported behavior continues to produce diagnostics.

## Independent comparisons

`inspect-native-combat-cache-lifecycle.py` executes845 original-code cases:
12copy,15assignment,13destructor,397equality,396inequality and12bounded actual
Polymorph snapshot blocks. It includes empty/large lists, self-assignment,
shared/distinct node pointers, every scalar-byte difference, strings with
embedded NUL, flags, weapon IDs, every node byte and null nodes only in branches
where native permits them. Heap allocation/free/realloc/memmove and native
CExoString initialization are captured lower boundaries. Untouched destination
padding is recorded but never treated as defined constructor state. Native
node inequality and the full lifecycle owner instructions execute unchanged.
No allocation-failure, arbitrary aliasing/dangling pointer or full heap parity
claim is made. JS lifetime tests omit native allocator addresses themselves.

Five new tests compare those observations, including ordered node release,
source immutability, independent node ownership, retained destination state and
the actual PolymorphRuntime provider. Focused16tests PASS. Full-suitev1
**1923/1923 PASS**. Buildv1 PASS (existing bundle-size warning).

## Installed and UI checks

Installed five-form probev2 PASS with real active tables, canonical equipment,
effect application, cancellation/deferred removal, transform/restore, saved
cache field/ID/string/flag checks and next-transform disposal. It confirms the
snapshot remains intact after restoration. Initial all-form probev1 stopped at
an obsolete assertion that rejected *all* remaining type67 effects; active
item re-equipping now legitimately creates independent effects of that type.
The assertion now checks the transformation's own linked ID group. Failure
report is retained; no engine effect was removed to satisfy that assertion.

The all-form observational sweep completes all102 rows with valid appearance,
including every snapshot/restoration/canonical-identity assertion. It still
**exits1**, retaining missing authored item resources `x1_it_frostghide` and
`x2_mech_hide`, plus presentation/item-visual omissions. They were already
present in the previous sweep. No aliases/assets were manufactured. HP changes
are recorded, not asserted equal for all forms; their full sequence is unchanged
from the historical sweep. Installed form26/40 full/injured HP checks separately
match the128-case native HP pipeline (form-defensesv2:4HP/2turn checks PASS).
This does not prove every form/HP branch independently or clean asset coverage.

Electron polymorph-hotbar UIv1 PASS terminal0: real F2 parent spell130 cast,
prepared-slot use, installed child spell script, live form/model/animation
replacement, canonical object565 and radial cancellation/restoration. Console
errors and casting-phase failures are empty; all startup/import diagnostics
are retained. The UI uses an owned in-memory prepared-spell/entry fixture with
startup disabled. This is not campaign or complete presentation acceptance.

## Remaining scope

Character-sheet full stats writer/comparison delivery, save/GFF combat cache
load/store, creature/client teardown and every lower combat-stat provider are
not complete. The ported assignment/comparison owners are available for that
next integration; no networking or full character-sheet replication claim is
made. Spell audit still has unbound engine names and missing impact scripts;
combat and continuous campaign play remain unfinished. Goal stays ACTIVE.
Verified checkpoint: `backups/combat-cache-lifecycle-1923-20261017-v1.zip`,
10289files/135621966bytes. Every archived length/SHA256 verified;
session62867 terminal exit0 consumed. This verification note and precise
equality/inequality end-address correction were added after sealing. The
oracle guards allow a few padding bytes after those bodies, but execution
returns through the original RET and never executes the padding.
