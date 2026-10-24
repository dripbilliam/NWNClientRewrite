# Merchant protocol and replicated dialogue tokens — 2026-10-19

Target unchanged NWN:EE89.8193.37-17 x64 nwmain, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Existing persistent REA/Ghidra session91238 reused read-only. No executable,
live-process or project changes; no proprietary resource copies.

## Observed failure

Live v165 Olgerd conversation emitted network.text-token-unhandled action9,
sourceRow7: multiplayer lacked the first class Lower STRREF provider. It was
not a bad authored sentence. The generic adapter now reads first class and
level from replicated.stats.classes in server order and resolves active
classes.2da Name/Lower, racialtypes ConverName/ConverNameLower through active
TLK overrides. No NPC/module/class name substitutions. Original-derived
callback140704d40, existing verified class/race rule providers and token parser
are reused. Missing stat/world providers stay diagnosed. This is not complete
coverage of every named-token data owner.

The same unchanged server sent P/7/4 (29bytes) and G/M stock updates when the
user selected Olgerd's shop. Both were unhandled by the previous build.

## Verified original owners

Client dispatcher1407a41a0 routes7 to1407b0de0; G dispatcher1407b3c90 routes
merchant M to1407b4b80. Store open7/4 reads panel BYTE, sell rate SHORT, buy
and black-market rates BYTE, identify price/max buy price/store gold INT,
black-market BOOL, restriction-list selector BOOL, signed count and INT items.
Server writer1404dd920 establishes field meanings. Store OBJECT_ID is absent:
do not assign the speaking NPC's ID or invent a canonical store object.

M/A reads XY BYTE then ordinary canonical item reader79fe30. M/D reads ID;
M/U reads XY+ID (not ordinary repository stack/cost delta); M/P reads page
count and category, both BYTE. No guessed record scanning. Native stock writer
1404eecc0 selects current category/page in the player's server GUI.

Client request writers1407c3c10 (buy7/1: itemID,XY,destinationID),7c3d00
(sell7/2:itemID),7c3b80 (category7/4:BYTE),7c3af0 (page7/5:BYTE),7c3a50
(close7/6:empty),7c3a70 (identify7/7:itemID) are implemented through narrow IPC.
Server14045d4a0 performs actual ownership, affordability, acquisition and gold
changes. It looks up the current store from player GUI88; store ID is not sent.
Server1404e08a0 transaction7/3 writes itemID and gold only: its success argument
is unused. We do not synthesize success. P/7/6 closes via1404d4ed0.

Client store-panel close97cb00 sends close and deactivates merchant, keeping
the existing inventory. Open8418f0 opens the character inventory if necessary.
Our paired merchant/backpack view follows that lifecycle. Canonical stock and
backpack items share registry proxies, while M is a distinct GUI membership.
Changing category/page clears only displayed membership. Store/area/session
generation guards reject stale or foreign-item requests. Merchant Examine is
allowed only for current server stock.

Display pricing follows client assembly1409aac68..9aaca0 and sell label97bc20:
unsigned cost, DOUBLE rate/100, truncation and nonzero-cost minimum1. Sell
maximum uses signed comparison; stolen metadata selects black-market rate.
Server price owners4fa640/4fa760 use their own FLOAT calculations and remain
authoritative; displayed numbers never debit or credit local gold.

## Validation and remaining limits

inspect-native-network-store.py executes complete original request/open/result
writers with actual scalar and OBJECT_ID codecs. Lookup/customer rates and
transport are explicit lower boundaries.80 cases cover both formats, ID
namespaces/sentinels, signed rates, restriction modes and black market flags.
Focused v2:45tests pass including installed inventory replay, container guards,
merchant sender comparison, malformed opening replies, record boundaries,
canonical transitions, stale input and live rule/TLK token updates.

Isolated real Electron DOM fixture passes paired opening, category labels from
installed TLK, purchase/sale selection, merchant drag, Examine and close; it
asserts no local authoritative item/gold mutation. Live server acceptance is
still pending at this source checkpoint. Native store skin/item icon art,
quantity confirmation, alternate associate inventory, full merchant restrictions
presentation and complete campaign playthrough are not claimed complete.

## Live unchanged-server acceptance (v166)

Olgerd opens merchant/backpack via ordinary dialogue after Pavel/Bim scripts
and native door transition.15 initial clothing/armor stock items, then19
scroll/potion items after native category change. Small Shield purchase creates
new canonical2147484314 in controlled backpack while infinite stock2147484004
remains. Sale removes the purchased proxy from backpack. Merchant potion Examine
returns native27/2 with description/properties. Store close leaves inventory
open; default activation of Greater Magic Bag2147484310 then opens native
container C and closes normally. No runtime errors or merchant unhandled
records during these checks. This is an owned single replacement-client live
acceptance, not concurrent original-client merchant acceptance.

Sealed v165 replay independently decodes both earlier failed store openings,
32merchant records including30adds, and no unhandled records. The replicated
first class resolves to wizard using installed classes Lower/TLK. Original
full v165 capture:242552518bytes, SHA256
50ef1e57babac8d70b08ab5ed611f31d98e48ac729ee3a702c69e75e1f2a758e.

Final UI revision additionally retains native pending item state until7/3
acknowledgement (without implying success), and guards async completion after
reset. Isolated DOMv6 covers pending/ack and reset. Its source/build is newer
than livev166; the final reconnect uses the final build. Broader71focused
checks pass (45merchant/inventory/session +26IPC/native-token checks).

Finalv167 acceptance complete: BVO-tF2S buy/sell produces and removes canonical2147484317, both acknowledgements clear pending UI. Left replacement PID4776 playing m0q1b at Olgerd, merchant scroll/potion category2 with19 stock entries. Automation cleared,0runtime errors/token/merchant record failures. Server unchanged. Currentv167 full report stays active/unsealed; bounded readiness proof is sealed separately.
