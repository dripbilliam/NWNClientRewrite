# Last-seen character appearance — partial UI parity

User direction, 2026-10-29: save observed appearance/equipment on disconnect and
test a server-vault-only character before rejoining. Implemented natively; the
entire UI goal remains active and unaccepted.

The character-selection BIC is a stats record, not necessarily a full save.
The owned original server omitted `Equip_ItemList` on both selections. The
user's saved Syvgg reply also omitted it. Treat absence as unknown equipment,
not an empty loadout. An explicitly present empty list can describe an
unclothed character. The reported purple color was confirmed by the user to be
the character's actual color; no palette/color decoder changes were made.

`character_appearance_cache.gd` stores a bounded, checksummed native data record
in `user://character-appearance-v1`. It retains body/head/colors/tail/wings and
equipment slots, base-item IDs, model parts and dyes from the admitted controlled
creature. It excludes scripts, effects, item ownership, world IDs and positions.
This is neither a BIC export nor a server request. Atomic replacement preserves
the previous snapshot when the latest observed data is incomplete.

The scope includes a digest of the public account identifier and login name,
the normalized endpoint and exact advertised server-character key. No CD key
or password enters the native cache. Native lobby metadata carries only the
account digest. New login preparation clears that digest before assigning the
new identity. Different accounts, endpoints and characters cannot share previews.

The actual native disconnect/reset and graceful-quit paths save the controlled
appearance before clearing gameplay data. A complete fresh selection reply wins
over the cache. Otherwise the picker renders the cached data under the current
server catalog and labels it **Last seen appearance**. Changed active base-item
model types refuse incompatible cached parts. There is no cached model/GPU data
or JavaScript rendering. Play admission never waits for these visuals. Before
the first observed play session, an incomplete reply shows the portrait and an
equipment-unavailable explanation.

## Verification

`native-vault-appearance-roundtrip-final-v1` uses an isolated original
`nwserver.exe` on `127.0.0.1:5126`, `servervault=1`, `publicserver=0`. It copies the
original installed equipped fighter into an owned server-vault fixture, rather
than exercising the character-creation UI. The server admits it without any
client BIC upload. Its live controlled-object appearance includes armor (slot2,
base16), sword (slot16, base1) and shield (slot32, base56).

The protocol participant disconnects, waits for the server's leave observation,
reconnects and obtains the same advertised server character. Its new preview
still omits equipment. While that real second session remains at character
selection, the native production picker/controller test consumes the received
metadata/bytes and actual observed actor, saves/reopens its native snapshot, and
renders the equipment before a second Play. All slots, base items, model parts
and dyes are compared numerically with the actual received appearance.

This is composed evidence across the real protocol participant and native UI
process, not a claim of a single full-app graphical disconnect/reconnect run.
The real app reset/quit hook is wired and its entry compiles/starts; complete
full-app lifecycle/portal coverage remains to be tested. No automated public or
Arelith gameplay connection was made. The owned server observed both leaves,
stopped, and its temporary preview-byte store was emptied.

| Current source-pinned run | Checks | Scope |
| --- | ---: | --- |
| `native-appearance-cache-storage-final-v1` |18| Cold persistence, replacement, isolation, incomplete data, unequipping, integrity/size, active-rule changes and owned cleanup |
| `native-bic-cache-corpus-final-v1` |629|39 original BICs/102 equipped records, typed extraction and complete cache-to-preview field preservation |
| `native-picker-cache-input-final-v1` |41| Native four-arrow pending/ack navigation, edit ownership, scrolling and800/1280/3440 layouts |
| `native-stage-cache-final-v1` |12| Actual native model, missing-equipment refusal, camera, visibility and retirement |
| `native-picker-cached-fresh-final-v1` |22| Native controller save/reopen, visible label, complete fresh-data replacement, account isolation and portrait crop/input |
| `native-vault-appearance-roundtrip-final-v1-cached-ui` |24| Graphical production picker with actual original-server metadata/bytes/observed equipment, while the reconnected protocol participant remains prejoin |

Total746 scoped native checks. The normal entry also passes
`native-picker-cache-menu-final-v1`; nineteen protocol-coordinator unit cases
pass separately. None of these counts accepts the full UI goal. The final
graphical `.cached.png` was reviewed: armor, sword and shield are visible,
portrait proportions are preserved and the last-seen label is visible.

Earlier failed receipts remain retained: the first Play probe omitted area-ready
acknowledgment; an input fixture unnecessarily acknowledged an already selected
row; portrait fixtures lacked the actually selected character's portrait; the
first corpus comparison wrongly required dictionary insertion order; and the
first wire equipment comparison mixed JSON floats/native integers. Original
server startup/query/authentication failures are retained too. The readiness
probe now treats its local-vault flag as the numeric byte it actually returns.

## Remaining acceptance

First-login server equipment cannot be invented. Other-client/offline changes
can make a snapshot stale; the label stays explicit. A hard process crash does
not run graceful-quit saving. Alias changes and server-cluster transfers do not
yet have full cache identity/lifecycle coverage. Advanced visual transforms,
all model families, every server resource override and the complete chooser
action/state/font/sound/fullscreen/scale audit remain open. The subsequent
[local Delete follow-up](NATIVE-LOCAL-CHARACTER-DELETION.md) adds scoped native
local mutation/confirmation checks; complete Delete/Customize and the wider UI
inventory remain unfinished. The local prejoin cache test does not
accept character creation, full admission UI, general porting or combat parity.
