# Native token parsing and client dialogue integration

Target: NWN:EE89.8193.37-17 x64, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project remain read-only. REA session65686 remains
warm; native captures use original instructions with explicit lower boundaries.

`CResGFFFieldIDHash::Initialize14018d200..18d2ba` builds the runtime CRC table
at14140c510. Hash `14018d1a0..18d1f2` starts at0, does not complement the result,
and stops at NUL or the requested byte count. The initial read-only image has no
initialized table data there; the oracle executes the original initializer,
rather than treating zero BSS as the table. This is distinct from ruleset FNV.

`ParseStr140199e20..19a420` now parses bytes using original case-sensitive
lookup, double-`<<` escaping, CUSTOM decimal IDs with DWORD overflow and special
0xffffffff rejection, nonrecursive replacements, unknown-token placeholders,
and the shared suppression flag. Named records use unsigned CRC binary search,
then stored length and exact byte comparison; collisions retain native lookup
behavior. Native OpenFile imports physical StringTokens columns0..6, hashes only
the first16 bytes of each stored name and keeps stable unsigned-hash order.
Runtime imports the active resolver table, including on language reload, while
preserving separate custom-token and override state. Malformed/missing numeric
table fields are diagnosed as unsupported import; full native C2DA failure and
OpenFile constructor/resource resolution are not established by this increment.

The original parser can read beyond an unterminated token's C-string buffer.
Those real unknown bytes are not reproducible. The oracle retains12 authored
zero-padded malformed observations separately; the replacement diagnoses this
case and leaves UI text unchanged. It does not claim identical undefined reads.
Stored text after embedded NUL remains intact when parsing makes no changes;
parsed output follows native C-string trailing-text behavior.

The game-derived callback was located through RTTI: CNWTlkTable descriptor
1412c2300, vtable140e2e218, first slot140704d40. This callback has no useful
exported class name. `gameTalkTokenValue` follows its selector/fallback, direct
name fields, signed-WORD alignment thresholds, gender restoration, calendar,
suppression and color-byte branches. **An original-code comparison corrected a
misleading REA switch label:** action16 is the12-hour clock conversion from
client field16c; action17 is the month value from164. The failing comparison is
retained. Product behavior follows original execution, not that decompiler label.

Client name/class/race providers consume current canonical character/rule data.
Lowercase class text comes from active classes.2da `Lower`, established by native
LoadClassInfo1402a4e80..4ea4; it is not guessed as Name+1 or a lowercase operation.
Race text uses Name/ConverName/ConverNameLower. These native text getters force
male lookup, then the parent callback restores its saved gender. Alignment refs
are the two original engine reference grids, verified separately against the
complete client leaf1407ef2f0..7ef43b. No spell, actor or campaign exception was
added. The local clock projection reads the shared native-tested WorldTimer and
canonical module dawn/dusk fields; it is not a decoded remote client snapshot.
Complete live client stat/name-override imports remain a separate gate.

Dialogue lines, replies and one-liners now use this pipeline instead of the old
case-insensitive four-name regex and stripped marker list. Target gender selects
localized text; custom values come from the recipient's client table, preserving
server/client state separation. Ordinary GetStringByStrRef still uses parse0;
global override strings now parse custom values using server token state. Named
server values needing unmapped context remain explicitly unavailable. Shared
sync/async TLK drivers use the same original-tested fetch steps. The memory-backed
script getter now completes seek/read synchronously, preventing client rendering
from interleaving between those steps. Existing604 fetch/getter cases cover both
drivers without counting them as new original observations.

Limits remain visible. Player-name lookup has no established transport/context
mapping and yields a diagnosed UI placeholder. No game OBJECT_ID is substituted
for that client/player context. The current widget uses an explicit plain-text
context (B8=1, BC=0): native rich colors and widget visibility controls remain
diagnosed. Non-Western script presentation, complete network/client receiver
routing, TLK speech voice/lip/overhead and all original caller contexts remain
open. Unknown names use the native `<UNRECOGNIZED TOKEN>`; known unsupported
providers use `<UNIMPLEMENTED TOKEN>` with diagnostics. This is not a claim that
every presentation branch or all spell-related text is finished.

Verification:

- `inspect-native-talk-token-parser.py`: **580 complete parser observations**,
  comprising568 semantic comparisons and12 separate known-padding malformed
  observations; **261 original initialized-hash cases**. Original string
  initialization and concatenation execute; heap/memcpy/free/strncmp and authored
  named virtual callbacks are captured lowers, not the actual game resolver.
- `inspect-native-game-talk-token.py`: **1,928 complete game callback cases**
  and **162 original alignment-reference leaf cases**. Context/object/stats,
  resource/name/race/class/alignment/clock/player getters, string assignment,
  formatting, allocation and logging are explicit lower boundaries. These tests
  do not independently prove every imported client field or resource getter.
- Installed Prelude probe, finalv2: active57-row StringTokens, race/class/TLK
  data; nine dialogue-text comparisons; actual parsed NCS token replacement and
  server override parsing; unchanged canonical allocation. Only output lengths/
  hashes are exported, not proprietary installed text.
- Rendered authored control fixture: actual NCS284 setter, local scalar body,
  parser and GameUi.renderConversation show first/replaced custom values in both
  line and reply button. Screenshot was visually inspected. This is not an
  original campaign conversation or complete interaction/GUI resource test.
- **1,794 full tests PASS; buildv3 PASS.** Full built-client spellbook, radial
  self-cast, slot use, hotbar F2 targeting, animations, cancellation and Counterspell
  regression PASS/exit0. A Chromium GPU teardown warning after assertions is
  retained in `talk-token-casting-ui-v1.txt`; no error-free GPU/mixer claim.
- Auditv44 remains **70 unbound commands /22 missing resources**. Binding counts
  do not measure newly supported parser branches or full spell readiness.

Next work includes the remaining spell dependencies and original client speech/
text consumers. Export search found server chat owners, not the stripped native
client receiver; that receiver and its actor/token/audio context still need
tracing. Spellcasting, combat and campaign completion remain unproven.
