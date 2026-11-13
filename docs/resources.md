# Resources, caches and audio

Original resources remain external to the repository. Native catalog/decoding and preparation live in `godot-client/systems/native_data/`; rendering consumers live in `systems/native_render/`. The active normal route does not require whole-area GLB conversion.

## Catalog and formats

Mounted base/install, module/server, HAK, loose, Workshop and admitted NWSync resources must follow the original precedence and active-session identity. Resource existence, provider, archive slot and lifetime are meaningful; a zero-length resource may still exist.

Native readers cover KEY/BIF, ERF/MOD/HAK, GFF/BIC, 2DA/TLK and original models/images. Preserve bounded counts/offsets, physical IDs, raw/default semantics, byte encodings and malformed-input behavior. Do not substitute one server's fixed class/item IDs.

Original resource-manager registration/insertion/lookup evidence is retained at `0x1401947b0`, `0x14018e330`, `0x14018ffb0`. These addresses are research pointers, not proof every consumer is equivalent. Original 2DA token/default/storage behavior still has explicit compatibility limits.

## Preparation and residency

Workers prepare original models, textures, palettes, tables and text. Catalog revisions, file stamps, content hashes, engine/extension identity and source-format variants participate in invalidation. Retire stale work before publishing into a new catalog or area.

Main Menu → Options → Prework exposes preparation/cancel/clear and selected-content scopes. Preparation must not join a server implicitly. Persistent cache validity, failure handling and disk/GPU lifetime require consumer evidence; file presence alone is insufficient.

NWSync has local download/cache/mount/cancel evidence. Public authentication, large content sets and current-route cross-server cases are separate. Keep required-content admission gated and failure/cancel/retry visible.

## Audio

Creation samples, combat voices and direct script sounds have native owners. Later direct-route headless checks must not inherit every bridge-era device acceptance claim.

Remaining music, ambient/placed sounds, footsteps, weapon/death/quick-chat audio, codec/device/preferences and complete mixer voice-stealing/priority behavior are tracked in [NWN-47](https://linear.app/nwnanalog/issue/NWN-47). The corrected audio-survivor retirement does not explain every retained native AV.

Broader precedence, custom-resource and failure-isolation coverage is [NWN-53](https://linear.app/nwnanalog/issue/NWN-53). Exact format and native-function dossiers remain in the [archive](archive.md) and existing JSON receipts.
