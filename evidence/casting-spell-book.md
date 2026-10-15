# Casting: live spell ownership and resource consumption

This is the1194 spellbook checkpoint. The resumed1211 action/facing/round/
context continuation is recorded in [Casting actions](casting-actions.md).

Target: NWN:EE89.8193.37-17, original `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The original installation and Ghidra database remain unchanged.

**Casting is not playable yet.** This checkpoint connects native spellbook
imports and queries to canonical creatures, maps resource consumption and cast
request selection, and makes the spell panel observe live pools. Cast requests
have a validated pure coordinator, but are not bound to gameplay while their
lower queue/execution owner is missing. No spell ID is replaced with a locally
invented healing/damage effect or cast duration.

## Implemented owners

`src/spell_book.js` owns ten physical known/memorized pools per class, native
growth/deletion rules, domain validation, minimum ability, bonus/prestige spell
gain, import, readiness/talent/has-spell queries, remaining uses, unreadying,
spell-like readiness and per-day maximum adjustment. Active class/spell/domain
and class-referenced tables provide the rules. Constants for engine metamagic
feat mappings and native class enum exemptions are target-build behavior,
not campaign/NPC exceptions.

`src/spell_book_runtime.js` imports these pools after combat/ability cache
initialization. It retains the constructor-owned pools and the saved source
remains immutable. `TalentRuntime` and the script GetHasSpell, GetSpellUsesLeft
and GetSpellLevelByClass commands now query live state. The last two commands
preserve the original extra preliminary VM result on negative inputs; class
TYPE and class slot INDEX are not treated as interchangeable IDs.

The consumption/maximum adjustment adapter methods are available, but their
timed cast and dirty-frame callers are **not bound yet**. The frame still records
the missing refresh owner. Increasing a maximum does not refill spent uses.
Prepared slots, spontaneous daily counters and duplicate spell-like entries
remain distinct. A positive use count does not guarantee UnReadySpell succeeds
for a particular metamagic mask; the original slot selector is retained.

The UI reads the owned pools and refreshes when their state changes. Its
`spell.cast` action remains a recorded placeholder. The rendered check verifies
an imported wizard's43 known entries and34 memorized entries, not a cast.

## Native evidence and bounded validation

| Owner | Address | Validation |
|---|---|---|
| ReadSpells, AddKnownSpell |14040f3e0,1403ef2e0|Original instructions with captured GFF readers and initial slot refresh|
| GetUses, SetSlot, Resize, ReadyCount |140409160,140415c00,140416610,140405110|Original instructions with captured rule/ability/feat/domain helpers|
| GainWithBonus, HasTalent, HasSilencedSpell, script GetHasSpell |140408120,1403faab0,1404026a0,1405257e0|Original instructions with explicit rule/cache/VM boundaries|
| UnReady, DecrementReady, ability ready/level, AdjustPerDay |140416eb0,14038a590,140416b00,140408aa0,1403f00a0|Original instructions; slot setter executes; rule and accessor helpers captured|
| Cast command; script level/uses commands |140511540,1405306a0,140530b10|Original instructions with captured lower spell queries, registry, VM and AddCastSpellActions|

`scripts/inspect-native-spell-book.py` produces1567 original bounded cases.
`scripts/inspect-native-cast-request.py` produces814 request/query cases;811
are compared against the pure coordinator, and three native stack-pop failures
are retained as observations (VM type/underflow handling is separate).
The17 spell owner/query tests pass, including imported GFF ordering,
metamagic, master spells, multiclass tie resolution, domain scans, raw ready
flags, duplicate abilities, UINT bonus caps, BYTE wrap and signed maximum
delta behavior. These captured helper boundaries do not establish native
end-to-end spell or networking parity.

ReadSpells' usual Ready default0 is verified at complete caller instructions:
personal information140397a34, template1403980b0, and player load1404bb1aa.
The other-player copy call1404bbe14 obtains its default from the source player.
Missing SpellGain cells load255 at14029bb06..14029bb09; the replacement now
matches that loader behavior instead of rejecting Aribeth's normal class data.
Missing NumSpellLevels scratch storage remains a recorded unavailable value.

Full static casting flow is retained in
`backups/animations/casting-action-flow-full-asm.txt`: command140511540,
AddCastSpellActions14037d540, AIActionCastSpell1403ada70 and
SpellCastAndImpact14049c4b0. Ghidra pseudocode truncates the location and action
branches, so it is not used as evidence of complete owners.

## Integration and failures retained

1194 tests and production build pass. The installed import audit uses39
fresh Prelude/BIC sessions;17 caster class slots successfully consume a spell
and expose the decremented count through the live script command without
changing authored data or canonical IDs. It does **not** claim all39 characters
are issue-free: `palemaster.bic` reports102 computed HP versus114 saved HP.
Its spell import/consumption passes, but the aggregate `importReady` gate stays
false and the worker/aggregate exit1 is preserved.

Reports: `backups/casting-spell-import-v2-20261014/summary.json`, per-character
JSONs and `backups/animations/casting-installed-spell-book-v2.txt`.
The first audit stopped at the HP error; the revised audit collects every
character report and still fails at the end. It does not whitelist the error.

Prelude startup import succeeds. Its remaining missing `script1` resource and
seven unsupported startup owners remain in
`backups/casting-spell-book-startup-v2-20261014`.
The ordinary melee regression still passes retaliation, approach, kills and
encounter deactivation, with the six previously recorded warning owners.
Capture: `casting-spell-book-combat-regression-v2.txt`.
The first attempt passed game coordinates to the renderer-coordinate fixture,
placed the player outside the encounter, and failed; its capture is retained.

The rendered wizard spell panel is verified in
`casting-live-wizard-spell-book-ui-v2.txt` and visually inspected in
`casting-live-wizard-spell-book-v2.png`. The first sandboxed Electron launch
failed to load GPU helpers; the owned renderer succeeded outside that sandbox.
The scene's existing unsupported animation-controller warning is retained.
This check does not establish cast animations or gameplay readiness.

## Next owners required

1. AddCastSpellActions native group/action parameters, movement, range/LOS and
   targeting validation. Bind script/object/location and player spell requests.
2. AI action15 casting phases, interruptions/concentration/failure checks,
   resource consumption ordering, counterspells and client cast animation.
3. Native caster/spell context, impact event/projectile ownership and authored
   active SPELLS ImpactScript execution. Fill selected effect/save/resistance
   dependencies without hardcoding spell outcomes.
4. Dirty spell refresh, rest/memorization and UI/quickbar/radial use, then full
   original cast comparisons and continuous campaign acceptance.

Unsupported owners and failed loads stay in the diagnostic journal. Combat,
campaign completion, persistence and original-server/client parity remain open.

Sealed source/research checkpoint:
`backups/live-native-spell-book-1194-20261014.zip`,3736 files,22,759,735 bytes.
Every entry was verified against its manifest length and SHA256. The archive
contains this evidence before the post-seal backup backlink was added.
