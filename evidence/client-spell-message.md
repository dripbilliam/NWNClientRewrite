# Native spell notifications (CC8) — 2026-10-16

Progress toward the full spellcasting/combat/campaign goal. Spell start/release
notifications now use the native template/token decision tree and installed
talk-table text. All spell selection remains active-data based. This does not
complete the spell ecosystem, combat, campaign or native network transport.

Read-only target: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game/Ghidra project unchanged. Previous verified checkpoint:
`backups/cast-visual-controller-1852-20261016-v1.zip`,9579 files,114591328 bytes.
Current checkpoint target: `backups/client-spell-message-1857-20261016-v1.zip`.

## Original evidence

The server writer is SendServerToPlayerCCMessage1404cf090, case8. It creates a
9-byte-estimate message for the supplied PLAYER_ID, writes the source OBJECTID,
spell DWORD and two BOOLs (identified/cast-start). Then it writes a has-item BOOL.
For an item, the **original** identified INT must equal1 to select the item name;
otherwise the next field is the base-item BYTE. Identified names have a BOOL
followed by localized text or the item's override string. The item ID itself is
not transmitted to the client. Missing item lookup logs the native warning but
does not invent a name field. Payload/send gates execute in the native oracle;
the live local projection ports field selection, not full packet transport.

BOOL encoding retains the low bit, independently of the writer's exact INT==1
test. Base-item narrowing is BYTE. Server/client OBJECTID conversion reuses the
already checked native owner and preserves OBJECT_INVALID. Canonical registry
objects/IDs are never converted or inserted into client storage by this feature.

Client major12h dispatches to140770c80. Its verified jump table14077a5ac maps
minor8 (index7) to1407760c1. The complete case ends at1407766bd and branches to
the common dispatcher tail14077a4cd. Original branch instructions are retained
in `client-cc-receiver-dispatch-v1.txt`; table, text constants and color bytes
have separate captures. Whole-function Ghidra decompilation failed with
`Response buffer size exceeded`; the failed request is retained in
`rea-client-combat-message-dispatch.json`. It was not retried unchanged, and no
whole-dispatcher decompilation or execution claim is made. Bounded disassembly
and execution of the verified case provide the acceptance evidence instead.

The receiver reads source/spell/three BOOLs before its first overflow guard. It
reads the optional item name/base type, then checks overflow again before any
spell lookup or log output. GetSpell wrapper14076b750 calls the signed-ID native
array lookup. With a valid spell:

- Nonzero AltMessage uses that StrRef template after setting custom token0 to
  the source name. This branch does not install new token1/2 values.
- Otherwise the verb StrRef is8127 for cast-start without an item,1501 for
  release without an item,63264 for item use.
- Identified ordinary spells use spell.Name. Identified item casts use the
  transmitted name. Unknown ordinary spells use StrRef1502. Unknown item names
  set token0 to the active base-item name and parse63265 first.
- The source name then replaces token0, the verb becomes token1, the selected
  name token2, and template10482 is parsed. Failed source-name lookup uses8349.
- Player source names use bytes60/99/153/255/255/62; other sources use
  60/99/204/153/204/62, when the player object exists. The final message uses
  60/99/204/119/255/62 and closes with `</c>`.

Invalid spell lookup still reaches the native display lower with empty text.
The display call uses color128, two zero arguments and an empty resource.
The implementation preserves this even though the current UI omits empty rows.

## Integration

`client_spell_message.js` owns the native receiver decision tree plus a typed
local field projection of the writer. These are decoded scalar fields, not a
raw encoded NWN message. The existing native packet stream/framing and network
transport remain separate work. Malformed typed fields set read overflow and
produce a durable failure; they do not silently become valid notifications.

`ClientSpellPresentation` queues startup notifications until the new session's
UI is attached. It snapshots transmitted item-name fields **at receipt**, before
a consumed item can be removed. Client text lookup happens at presentation time.
Recipient/session filtering precedes output. Reserved custom tokens0..2 update
only the existing client token state, with the checked native SetCustomToken
owner and parser. They never broadcast back or mutate server custom tokens.
Active Name/AltMessage/baseitems rules and installed TLK supply the actual text.
No spell-specific message database or English gameplay phrase was added.

The GameUi log retains repeated native notifications. Previously its generic
duplicate filter collapsed adjacent equal potion-use lines. Native spell output
now requests explicit repeated rows; existing generic message callers keep their
previous default. HTML-like content remains textContent, never interpreted HTML.

The native color strings and raw messages are retained in snapshots; current
display strips color controls into plain text and records
`spell.client-richtext-adapter-incomplete`. Native rich widget colors/layout,
full localized fetch/widget context and transport/replication are not claimed.
The former broad `spell.client-message-unimplemented` warning is removed only
for this connected CC8 path. Missing items, malformed reads and presentation
errors have their own durable diagnostics. Runtime item-rename engine support
and complete name replication remain part of the broader engine-call work;
imported localized names and the lower override-string branch are covered here.

Voice research this turn identified client creature constructor1407fb140,
stats constructors1407ea230/1407ea7a0 and appearance constructor140973840.
Stats50 participates in native racial modifier lookup and defaults to6; it is
race storage, not an SSF sound-set ID. AppearanceD0 defaults to255 and its lower
body/voice selection needs further provenance. No guessed chant selection was
enabled. The previous casting field/voice diagnostics remain active.

## Validation and practical limits

- `native-client-spell-message-observations.json`:1536 original branch cases.
  Variations cover both flags, item presence, localized/override input, invalid
  spell, alternate template, name/player availability/identity and both overflow
  exits. Scalar readers, spell/name/base-item/TLK services, string/parser/GUI
  lowers are captured. Outer dispatcher/profiling, actual raw bit streams, TLK
  parsing internals and GPU widget output are not executed by this oracle.
- `native-server-spell-message-observations.json`:1280 whole writer cases with
  native dispatch, comparisons and send gates. Varied noncanonical identified/
  casting INTs, missing/valid items, override presence, BYTE narrowing, payload
  and send failure. Getters/scalar encoding/strings/transport are captured lower
  services. Tests compare exact emitted field sequences and item warning/lookup
  branches, not synthetic packet bytes.
- Five new tests: both native captures plus queue ownership across item
  destruction, recipient filtering, malformed item failure, ordinary identified/
  unidentified template output, client tokens and markup stripping.
- **1857 tests pass**, final build passes. Final item UI verifies three separate
  visible log rows through consumption (not merely three queued events).
- Installed projectile UI selects untouched wizard Daze37 via active metadata:
  native start/release templates show actual player/spell names; conjure01,
  fade, authored donefade, cleanup, projectile travel/impact/delete still pass.
  `live-client-spell-message-ui.json` retains both flag variants, raw/control text,
  plain text and diagnostics. Screenshot inspected: both notification rows and
  authored purple hand/white projectile are visible in the existing dark scene.
- Final installed item UI uses the unchanged preset's Cure Critical Wounds
  potion31 three times through item wheel/F2, exhausts the stack, removes its
  shortcut and retains three correctly named native notices. No new failures;
  previously absent plc_w02.pwk stays recorded separately.
- The projectile and final standard UI processes printed GPU command-buffer
  errors **after** their PASS/exit paths; renderer assertions/errors were clean.
  The final item UI completed normally. This is not a claim of complete
  GPU/driver stability.
- Existing spellbook/radial/F2/cancel/counterspell regression passed on the final
  build. All UI sessions are startup/entry fixtures, not campaign completion.

Next: native cast-field/voice provenance and the remaining projectile/model/scene
owners, engine/effect gaps, combat and then campaign play/fix/resume. Full goal
remains active.
