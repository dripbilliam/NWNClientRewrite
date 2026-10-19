# Talk-table ownership investigation (implementation pending)

Historical investigation, superseded by [implementation evidence](native-talk-table.md).
The original oracle corrected the invalid0xffffffff return below: it is1, not0.

Target remains NWN:EE89.8193.37-17 x64, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
REA captures and independent original disassembly are recorded. No new
GetStringByStrRef binding or talk-table implementation is claimed here.

The wrapper `140530e20..530f64` sets shared CTlkTable BYTE+28 to requested
gender0/1 (other inputs become0), then calls FetchInternal `140198c60..1994b7`
with parseflag0. Explicit output string length is copied before push. This means
ordinary file strings returned by this NWScript getter are not token-expanded.
However, an entry from the global override map does call ParseStr even with0;
that distinct owner must not be lost in a generic UI cache lookup.

FetchInternal selects base male/female pointers+8/+10, custom+18/+20, custom
bit0x01000000 and24-bit custom index. Missing custom table produces native
BadStrRef(ref) text; missing base table follows warning/empty behavior. The
invalid0xffffffff reference clears text/sound and returns1. Several female
range/seek/read failures reset shared gender to0 and recurse; other failures
have separate behavior. File/cache/override and short-read handling require
complete control-flow tests before implementing this owner.

OpenFile primary `1401995b0..19999a` aliases the female pointer to the male
pointer when the female file cannot open. An opened female file with an invalid
header follows different cleanup; blindly falling back on every female error
would hide a load failure. The public OpenFile wrapper is1401999a0. Current
GameText UI data is separate from ModuleSession and lacks this shared mutable
owner, female file handling, override/cache semantics and full STR_RES sound
metadata. It is insufficient evidence for a native getter implementation.

References: `rea-script-get-strref-owner.json`, `rea-tlk-fetch-internal-owner.json`,
`rea-tlk-open-file-primary.json`, `rea-tlk-open-file-secondary.json`, and
`tlk-fetch-open-native-bodies-v1.txt` under backups/animations. No assets copied.
