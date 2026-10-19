# Multiplayer spellbook and memorization menus

Target: installed NWN:EE89.8193.37-17, nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binary and Ghidra project are unchanged. REA uses the existing
read-only ephemeral session. This continues `spell-preparation.md`.

## Observed original behavior

- Prepare writer1407c3870 sends6/16: BYTE class, DWORD spell, BYTE physical
  slot, domain base level, metamagic. Clear1407c3960 sends6/17: BYTE
  class/level/slot. New isolated original-code oracle executes both complete
  writers plus the real CNWMessage scalar codec:234 cases, every transmitted
  bit matches the replacement. Known A5 padding is excluded from comparisons.
- Constructor14088c9c8..d589 binds actual spellbook controls/artwork, including
  CTL_SB_BTN_SPTAB, IR_CANTRIPS, CTL_SPL_BTN_AROW, CTL_CG_BTN_HELP and CTL_BTN_X.
  Arrow callback binding at14088d53e resolves14088e650. The callback forwards
  the selected known spell, current effective level, domain and metamagic to
 14088ff10 with ready0. Full14088ff10..140890046 scans physical widget slots
  in ascending order for spellID-1; it never treats a used record as empty.
  It calls9c2630(send1), then9c25f0(ready0). Full slots return0; disabled
  level with an empty widget returns1 without inserting.
- Examine binding14088d566 resolves14088e6c0, which constructs9c3680 for
  the selected spell and activates the native modal panel.
- Memorization refresh140890330 reads each level's physical slot count,
  spell ID, domain, metamagic and ready state, then updates widget tint via
 9c25f0. Class switch140890790 updates class byte17d0 and refreshes slots.
- Known enumeration remains the previously verified14088ddb0 iterator:
  restricted classes enumerate knowledge; unrestricted divine classes scan
  active spells/rules and append domain spells. No spell-specific/module
  lists are introduced. Metamagic costs use active ruleset values.

REA dossiers `rea-spellbook-*.json` retain exact procedure ranges, assembly,
pseudocode and provenance. Discovery candidate88d8e0 actually resolves the
88d720 destructor,890619/890730 resolve890560 refresh, and890863 resolves
890830 explicit widget update. Those names are candidates, not evidence of
first-empty selection; final authority is88e650 ->88ff10 above.

## Implementation

`network_spellbook_view.js` replaces the flat cast-on-click list with class
icons, level selectors, localized known-spell rows, selection/Examine and a
prepared-only arrow. Prepared classes open a second scrollable window with
collapsible levels and exact replicated physical slots. Ready icons are
normal, used/unready icons dim, empty slots have no spell icon. Spontaneous
classes show transmitted per-level charges and no preparation window.

Known and prepared icons drag to the existing typed quickbar owner. Domain
base level, class and owned metamagic survive. Prepared-slot copies/exchanges
reuse the verified9c21d0 policy, including its unusual source-domain behavior
for displaced records. Right-click/double-click clearing sends6/17.

Selection/trees/scroll positions and pending markers are presentation state.
Neither renderer nor main-process transport changes canonical spellbooks,
slot counts, ready bits, daily uses or effects. Consecutive arrows reserve
different empty slots while waiting for authority. Pending markers retire on
changed replicated records, or after5 seconds with an explicit unconfirmed
diagnostic. Timeout never grants/restores a spell. Session token, controlled
actor reference/ID, area and current source/destination reject stale input.
Typed IPC validates the active controlled session; the original server owns
spell preparation admission and rest. Opening inventory closes these panels.

Native installed fonts, spell/class/level textures and close/help/arrow models
are loaded read-only. This is a web projection of native behavior, not a
pixel-identical port of native GUI heap/event codes. Class-level admission
buttons, full metamagic tree layout and GUI audio remain presentation gaps.
Singleplayer's existing Prepare UI and canonical preparation implementation
are preserved; this new menu replaces the multiplayer panel.

## Verification

-234 native writer cases match. Existing5573 clear/input/drop/iterator native
  comparisons remain passing. Final focused suite46 tests passes, including
  packet invalid-input rejection, current controlled-session admission,
  canonical nonmutation, stale drags and existing casting/wheel/innate paths.
- Hidden Electron fixture uses captured v80 world, installed icons/fonts/TLK,
  actual DOM selection, Examine, class/level switching, quickbar drag, arrows,
  exchanges, clear and collapse. Explicit isolated server-state variants cover
  wizard ready/used/empty, spontaneous per-level7 charges and divine books
  without known IDs. Domain and owned unprepared metamagic drags preserve
  native shortcut fields. No spells are cast by selecting a known row.
  Strict final UIv7 passes; prepared/spontaneous v3 PNGs visually inspected.
  UIv5 failed because fixture domains0/1 lack first-level spells; corrected
  to select installed domains with Level_1. UIv6 failed its30ms assumption
  for async choice lookup; v7 waits for the actual assignment. Earlier UIv1/2
  direct GUI-shell invocations produced no test evidence; v3+ use explicit
  hidden Start-Process and wait for terminal exit. First spontaneous PNGv1
  was captured before paint; v2/v3 wait for the rendered frame.
- Live production DOM v87 joined unchanged local Prelude nwserver20964.
  Right-click cantrip slot0 sent700611, server removed Daze37 into null;
  selecting Acid Splash424 and clicking arrow sent700610, server filled
  that same physical slot with ready0. Count remained4 throughout, all other
  slots retained. Received changes are after request timestamps. Examination
  displays installed localized description. No runtime errors, preparation
  diagnostics or sampling failures. Both PNGs visually inspected. Normal
  close saved the full report; compact acceptance JSON retains requests,
  actions and all three canonical states. No concurrent original-client,
  live divine/spontaneous/metamagic, rest or pixel-parity claim follows.
- Final build passes with the existing bundle-size warning. Layout uses the
  viewport's available height, leaving the hotbar accessible.

Rest HUD wiring remains separate: new preparations must be readied by the
server's actual rest lifecycle. No instant-ready workaround is present.
The broader multiplayer objective remains unfinished.

Post-seal spellbook: multiplayer-spellbook-menus-20261018-v1.zip verified
14198 files /350814290 bytes, checkpoint writer68434 terminal exit0 consumed.
Scope audit network-spellbook-scope-audit-v1.txt:14199 entries incl manifest,
33required /0missing /0forbidden /0duplicates;13928 inherited unchanged text,
73changed/new scanned,0credential candidates. Audit script and this post-seal
note are outside that archive. Final replacement v88 PID47784 OPEN on unchanged
vanilla server20964, buildv4, spellbook open; automatic inputs finished after
4sec. Runtimeerrors0/sampleFailure null, readiness JSON frozen; ready PNG
inspected and lies outside current archive. Full report local-network-spellbook-
v88.json writes ONLY on normal close. Exclude live-v88 JSON, control-v88 JSON
and network-spellbook-interactive-v88 stdout/stderr while open. Original Steam
client is open independently; no concurrent-server claim. Computer Use target
was replacement window5903110, but returned screenshot showed fullscreen
original game covering it, so no further UI inputs; own renderer saved PNG
confirms correct spellbook and unobstructed hotbar. Do not reconnect solely
for minor polish. Rest HUD/native full layout/audio remain later work.
