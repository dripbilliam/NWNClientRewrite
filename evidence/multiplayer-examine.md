# Multiplayer Examine — 2026-10-18

2026-10-21 follow-up: native RGB color controls, correct examined-object token context, multiline descriptions, disclosed portrait and status-first layout are now handled. See [Network rich text](network-rich-text.md) for the observed failure, implementation and current verification limits.

User redirected effort from further movement polish to core gameplay parity.
Examine now routes through the object/inventory radial menu to the vanilla
server. It does not run local lore checks, invent identification, calculate
properties, or substitute a local creature biography for hidden server data.
Self Character Sheet also opens the existing character panel.

## Native evidence

Installed NWN:EE 89.8193.37-17. nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a;
nwserver SHA256
98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6.
Read-only REA analysis; no original executable/project modifications.
Addresses below are original image VAs. Dossiers: rea-examine-*.json.

Client1407bfa80 sends major6/minor5 and one OBJECT_ID. Its GUI-cache gate
precedes sending. Bounded sender discovery initially hit padding; skipdata
located call1407bfbc7. Nearby 7bfe30 and7bff40 send other actions and are
not evidence for Examine. inspect-native-examine-request.py executes the
complete writer plus real scalar/OBJECT_ID codec with cache lookup absent:
14 cases, seven IDs in each of formats0/1. Seven format1 packets agree with
the replacement over every used bit; native uninitialized padding is masked.

Server1404531b0 case5 validates the stream, controlled creature and canonical
target. Dispatch: creature5 ->1404d7b60; item6 ->UseLoreOnItem then1404d8220;
trigger7 ->UseSkill(2,0x66); placeable9 ->1404d8850; door10 ->1404d80d0.
Trap result writer is1404d89a0. Lore/appraisal remain server-owned.

Client14079d350 routes major27 replies: item2 ->14079a1e0,
creature3 ->140799450, placeable4 ->14079a620, trap5 ->14079a960,
door6 ->140799ea0. Decoder preserves custom/localized description wrappers,
optional/disclosed fields, invalid-item close and trap success gates.
Creature effect counts/IDs widen from BYTE to WORD at8193.37-2.

Creature GUI1408978f0 uses damagelevels.STRING_REF and reaction TLKs
Neutral0x1918/Friendly0x1919/Hostile0x1917. Effect labels use
effecticons.StrRef. No locally computed CR or effects are inserted.

Item GUI140899040 obtains base item from the existing item+0x40. The first
reply INT is charges (server item+0x388), followed by tenth-pound weight.
Charges appear only if positive and identified. Value is server-gated.
Initial UI mislabeled that INT as baseItem; live v93 showed the bag as
Short Sword. v94 corrects the mapping and reads canonical baseItem instead.
That failed screenshot is retained explicitly as superseded evidence.
Item GUI1408965e0 builds properties from itempropdef.GameStrRef, subtype
Name and optional CostTableResRef/Param1ResRef overrides, iprp_costtable.Name
and iprp_paramtable.TableResRef. These are installed resource lookups.
Trap labels use traps.TrapName; assessment0..4 uses TLK0xcf98-index.

## Implementation and validation

Typed preload/IPC/session request checks current actor, area and generation,
canonical target/type/removal, and owned inventory/equipped item identity.
Sending has no optimistic identification or gameplay mutation. Only an item
reply updates the existing item's disclosed identified/canUse fields.
Response UI has Close/Escape, input isolation and async generation guards;
session/area changes close it. Resource failures are recorded in diagnostics.

network-examine-focused-v5.txt:59 tests pass, including native request oracle,
malformed packets, hidden creature fields, wide effects, identified and
unidentified items, trap success, stale ownership and equipped items, HUD,
movement/facing/correction and combat presentation regressions. The retained
v2 focused run passed61 with a different selection; do not add their counts.
Buildv3 passes (existing bundle-size warning). Installed DOM UIv5 passes
Examine biography/condition/property labels, canonical container type,
identified-only charges, invalid-item close, all eight HUD buttons and
multiclass/prepared/spontaneous/domain/metamagic hotbar regression paths.
UIv3/v4 failed due to an invalid fixture slot; v5 uses a valid native slot.

Live v93:four actual6/5 requests and27/3,6,4,2 replies for self, door,
placeable and inventory item. First three use typed request delegates;
inventory uses the production DOM context menu and actual wheel Examine.
All four PNGs inspected. Empty starting-door/bed descriptions were actually
empty replies; no replacement descriptions are invented.
Live v94:production Inventory -> item context menu -> Examine -> Close.
One6/5 request; actual Greater Magic Bag reply charges0/weight10/property
32,0,4,255,0. Correct Container label and reduced-content-weight -80%
visible in inspected network-examine-item-v94.png. No sampler failure;
83 runtime records, zero errors. Both captures normally closed before
their full reports were read. network-examine-acceptance-v1.json summarizes.

The reconnect briefly looked stalled during initial replication. Inspection
confirmed 0xffffffff is a valid external object ID, distinct from native
OBJECT_INVALID0x7f000000; no ID-filter workaround was added.
v95 is left open without automated actions. Its full report only exists
after normal close; readiness is frozen separately. Original client and
nwserver were left untouched.

## Remaining scope

Native panel artwork/portrait layout and relative CR category presentation
(native1407f0e50) are not fully ported; UI currently shows disclosed numeric
CR. Trap packets have synthetic coverage, no live trap test this section.
No native GUI-cache replication, full campaign, or new concurrent original
client acceptance claim. These checks establish this interaction, not overall
multiplayer/combat completion. Further movement polish is deferred.
