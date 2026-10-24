# Character creator and lobby lifecycle, 2026-10-20

Cancelling a creator previously left its asynchronous initializer running under
only an active boolean. If another chooser opened before it finished, the old
job could replace the new rules, resolver, selected entry or error state. Its
public selection promise also waited for the pending IO to finish despite the
user already cancelling. Late saves could finish a newer chooser or clear its
saving state; asynchronous recommendations could overwrite intervening edits.
Lobby local-file reads similarly changed selection before checking whether
their connection was still current.

CharacterFrontend now gives each choose/finish invocation a generation. The
selection promise resolves independently of initialization IO, and every
delayed publication checks its owner. Recommendations work on a private draft
snapshot; saves serialize a consistent snapshot and require the draft to remain
unchanged before persistence/selection. Each save releases only its own busy
state. A write already started may still finish in the user's local vault, but
it cannot select or submit into a replacement chooser. Voice errors and portrait
suffix fallback retain their original owner/resolver. Finish captures its own
resolver callback before notifying external capture listeners, so a reentrant
new chooser keeps its own result and focus.

NetworkLobby now checks connection and request generation before and after
local BIC IO/preview. Stale byte buffers are cleared; old preview, vault-list
and font/table-binding failures cannot replace a newer connection's state.
Reset invalidates pending file reads and clears old rule-table references.
Server packet codecs, character rules, resources and canonical world objects
are not altered by these UI lifetime changes.

The actual Chromium lifecycle fixture runs19 cases using installed local
rule/UTI resources, distinct synthetic class labels and explicitly deferred
IO/vault/preview providers. No server connections or disk vault writes:

- Late rule success/rejection; cancellation independent of pending IO.
- Delayed file reads and preselected-entry imports across chooser replacement.
- Cancellation during BIC resource reads and overlapping old/new vault writes.
- Late recommendation/voice failures and portrait suffix fallback.
- Reentrant capture callback preserving the new selection promise.
- User edits during recommendation, BIC serialization and vault persistence.
- Ordinary local Save Character returning to the rendered selector.
- Lobby file reads, rejected previews, latest-selection ordering, vault errors
  and resource-binding errors across connection replacement.

Result creation-experience-lifecycle-v3.json passes all19 with no fixture
console errors. The lobby draw/error callbacks and vault/preview providers
are captured test boundaries; this is not a complete live multiplayer
character-admission or physical-input comparison. v1/v2 retain earlier10/14
case milestones.34 focused creator, voice, cache and resource tests pass;
final buildlifecycle-v2 succeeds with index-BLwIaM2E.js.

Offline creator experience-v16 also passes all15 wizard steps, custom package270
and a fresh level1 wizard BIC. Portrait/skill scroll remains550/400 after edits.
Unavailable feats start hidden, with2 groups and28 submenu choices; the toggle
exposes243 disabled choices. A profile portrait decodes, a voice source decodes
and starts then disposes, and human/half-orc previews each load17 models,
16 parts and26 textures. Zero HTTP attempts or reported console/content errors.
That fixture does not decode every catalog portrait.

The authorized portrait copy was rehashed currently:1463 files/143943134 bytes,
all SHA256 identical, zero missing/different files and no profile writes.
The cached100282-reference/97820-object collection checks in443.9ms with zero
HTTP and zero downloaded bytes; demanded classes/feat hashes still match the
fresh-download observations. Original NWSync databases were not reused.

A new exhaustive selectable-row catalog audit found323 of356 canonical
portraits available. The remaining33 have neither canonical nor unprefixed
images in the downloaded catalog or the supplied/copied portrait folder.
They include the edisum_, egbert_, OrcAfrun_ and OgreOni entries from the user's
screenshot. These are unresolved source-availability gaps, not claimed fixed
by copying unrelated images. An additional local portrait-pack path has been
requested. No network fetch was attempted.

The local movement client48208 remains untouched on server20964 at
127.0.0.1:5121, still running its v21 build for the pending physical-key check.
The new lifecycle build is ready for its next normal reload. A passive sample
after41.4 minutes since launch observes119.1–128.1FPS in the9-tile/20-object
starting room,18 programs and no pending assets/shaders, failed objects or
renderer errors. This is a rolling300-sample window, not complete history,
and it does not establish the earlier dense/modded/fullscreen case.

The goal remains ACTIVE. The current requirement-by-requirement audit is
creation-experience-current-audit-v1.json. It explicitly leaves missing portrait
sources, physical-key/contact feedback and stronger dense-world performance
acceptance open. All live testing stays local; cached resource checks forbid
HTTP. The original installation and server configuration remain unchanged.
