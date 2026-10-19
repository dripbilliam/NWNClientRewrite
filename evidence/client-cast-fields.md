# Client cast fields and Silent sound suppression — 2026-10-16

Progress toward the full spellcasting/combat/campaign goal. Live cast visuals now
consume the native spell/item/sound-suppression fields through a local scalar
projection, including Silent metamagic and Automatic Silent feats. No spell ID
or spell-name exception was added. Chant race/gender and complete update packet
replication remain unfinished; the broader spell ecosystem is not complete.

Read-only target: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game/Ghidra project unchanged. Previous verified checkpoint:
`backups/client-spell-message-1857-20261016-v1.zip`,9620 files,116554154 bytes.
Current checkpoint target: `backups/client-cast-fields-1860-20261016-v1.zip`.

## Native owners and field provenance

Server creature-update writer1404eb590 has the cast fragment1404ebfec..4ec1b0:
animation SHORT15..20 or61 selects the fields. It writes spell DWORD218, caster
item OBJECTID818 and a BOOL. Ordinary casts clear818; item casts store their item
there. This is distinct from the actual spell target214.

The BOOL starts with bit16 from metamagic BYTE22d. If spell lookup succeeds, the
writer queries GetSpellLevel using the stored class index22c through native
GetClass1403fa4a0. Level255 tries the master spell with a **fresh** class lookup;
if that also fails, it uses the original spell's Innate BYTE6f. It does not add
the metamagic slot cost or use domain level. Even an explicit Silent bit still
executes these lookup/feat branches; no early return skips their dependencies.

It then checks feat860,861,862 in physical order and compares level strictly
below the corresponding active ruleset cap (defaults4/7/10). First success sets
the flag and skips later checks. The full keys are
EPIC_AUTOMATIC_LESSER_SILENT_LEVEL_CAP, EPIC_AUTOMATIC_SILENT_LEVEL_CAP and
EPIC_AUTOMATIC_GREATER_SILENT_LEVEL_CAP. The compiler's literals start with PIC
because the seed already hashes E; using PIC as the ruleset key would be wrong.
The oracle checks that seed/length and full-key hash identity.

Client incoming creature update140781e80 has the matching fragment
140782e68..782ed3. It reads all three fields and then checks overflow, including
when the source object is missing. It updates client spell-ID36c, item-ID370 and
sound-suppression374 **only after** a successful guard and for a present source.
Overflow leaves all old cells untouched. Animation uses SHORT-width comparison;
the later looping250..253/261 animation IDs do not consume this fragment.

The existing native cast driver8018d0 uses374 to skip both the chant and authored
ConjSoundVFX at conjure start. It still creates/plays the conjure visual models.
The driver clears374 in release animation states; this ordering is preserved.

Static field scans, bounded parent disassembly and lower-method REA dossiers are
retained. Full781e80 analysis completed but exceeded the stdio response budget;
it was **not a decompilation failure**. The complete79947 UTF16 code units were
retrieved from retained evidence
ev_1d2f95080bdd074bf96e8335317b63a3c9e68b7e69a5c3b1ae5a9af294a89dc6 in two pages,
offset0/65536, with final exhausted=true/next_offset=null. The original complete
MCP response itself was not delivered; these pages preserve full pseudocode.
Do not confuse this with the previous770c80 decompiler response-buffer failure.

Additional appearance research did not establish the missing chant Gender
provenance. Dossiers historically named client-appearance-field-reader973160 and
client-creature-set-appearance-info766960 actually describe **visual-transform
map** read/copy owners, not the creature Gender field. The renderer controller's
old soundSet property has been renamed race: stats50 is race, not an SSF ID.
The local unbound race sentinel remains-1, so chant selection stays diagnosed
rather than guessing from an unrelated field.

## Implementation and remaining limits

`client_cast_fields.js` ports the sound calculation, local typed field projection
and client read/apply fragment. Active ruleset, spell/class rows and existing
canonical feat providers supply lower data. Main passes the projection to the
client presentation. The presentation stores independent client fields and no
longer defaults sound suppression to0. Failed projections/read guards remain
durable controller failures; canonical IDs/state are not mutated.

This runs from a local-authority actor snapshot. Complete native update dirty
flags, ordering, bit-stream encoding, replication and scheduling are not claimed.
`visual.cast-client-fields-adapter-incomplete` now identifies those remaining
boundaries and the unbound chant race/gender fields. Existing async model/cache,
scene and browser audio limitations remain diagnosed separately. Sound events
are retained in the cast snapshot for actual owner-path validation; absence of
a sound event is not a claim of audio hardware silence or complete audio parity.

## Validation

- `native-client-cast-field-observations.json`: **7299 original-code cases**.
  6915 server cases vary raw metamagic, all Automatic Silent feat combinations,
  original/master levels, missing master, class index0/255, Innate and normal/
  custom/negative caps, plus missing spell lookup. The native GetClass body
  executes unchanged. 384 client cases vary animation narrowing, missing source,
  overflow, flag, spell and item IDs. Remaining spell-level/feat/rule/hash/scalar
  reader/writer helpers are captured lower boundaries. These are verified parent
  fragments, not execution of the entire update packet/dispatcher.
- Three new tests compare exact provider ordering/outputs, all incoming field
  mutations/guards, and local conversion without authoritative cell changes.
  The earlier3644 cast controller observations still pass after the semantic
  field rename. **1860 full tests pass**, final build passes.
- Hidden Silent UI fixture changes only an owned in-memory wizard BIC: choose an
  actually known/ready installed projectile spell that allows Silent, put it in
  its active-data legal metamagic slot, and include standard Silent feat33. No
  installed BIC, spell table, script, binary or asset is written. The test chooses
  Daze37 at runtime, observes client374=1 during animation15, no conjure sound
  event, and actual conjure01/fade/donefade/cleanup plus vpr_los travel/impact and
  deletion. Native CC8 text and resource consumption remain active. Capture:
  `live-silent-cast-ui.json`/PNG. This proves the sound request path, not audible
  device output or rendered Automatic Silent feat selection.
- Ordinary untouched wizard Daze37, metamagic0, requests actual authored
  sco_mehanmind01 while its models/projectile and CC8 text complete normally.
  Renderer errors and cast-controller/model failures are empty in both probes.
- First normal UI attempt timed out because the test clicked a tutorial NPC
  before asynchronous spell targeting was armed, entering conversation. The
  harness now waits for the actual pending-spell target ID before clicking the
  world. The subsequent normal run passed. This was a test interaction race;
  no conversation, NPC, module or gameplay exception was added.
- Final standard spellbook/radial/F2/cancel/counterspell regression passes. Its
  process printed the previously observed GPU command-buffer error after PASS;
  functional renderer assertions were clean. No claim of full GPU stability.
- All UI probes remain startup/entry fixtures, not campaign acceptance.

Next: finish native appearance/race/Gender input provenance for chants, remaining
dummy/linked/scene-hit/child/impact projectile owners and audio, then outstanding
effects/engine calls, combat and campaign play/fix/resume. Full goal stays active.
