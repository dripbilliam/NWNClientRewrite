# Character chooser Server Info and Player List — partial parity

The [owned live roster follow-up](NATIVE-LOBBY-LIVE.md) now verifies addition,
portrait/class presentation and removal with a second real local participant.
It also corrects integer labels under the actual JSON transport. Full original
client/role/scale/audio comparison and the rest of the chooser remain unfinished.

The original chooser's two additional pages now have native owners and real
protocol wiring. PRE_PLAYMOD attaches PMOD_DETAILS800 and CTL_PRE_PLYRLIST at
the original417-pixel page viewport. The existing basic server query is shown
immediately. Opening Server Info makes a cancellable extended query to the
current policy-approved endpoint for the version field. Its result cannot cross
a tab/connection lifetime; completed details are cached for that connection.

Original715400 formats Module Name, Players, Levels, IP Address, PvP Zone,
Server Version and Server status. Its label constants and PvP/status mappings
come from code plus data140e4d5ac, not guessed English labels. Native TLK lookup
still owns their text. The original dialog-font pointer defaults to
`ttf fnt_default 14`; the static large variant is `ttf fnt_default_hr 16`.
The default now binds to the installed native TTF, not a Godot fallback.
Large-dialog preference integration remains open.

Server status comes from received availability messages. Original4df850 emits
1/1 for busy(mode1),1/2 for idle(mode0), and1/3 with resources for running(mode2).
NativeLobby projects those validated message kinds into the page. It never
infers Running from a client phase; an unreported status remains blank.

Player List sends the existing original49/1 start and49/2 stop requests through
NetworkGameSession. Add/update/remove records remain separate from world entities
and vault selection. Only public name/portrait/class fields are forwarded.
Original70dae0 appends CTL_PRE_BTN_PLYR rows, formats full class names and levels,
disables their input and paints both text lines at half intensity. The native
owner follows these rules, using active classes/portraits/TLK, the source16x25
portrait mesh,44-pixel row advance and original scrollbar. Scroll arrows advance
one row; font metrics cannot silently replace that row step.

Leaving the tab, choosing a vault row, hiding the chooser, Play, disconnect and
connection replacement retire the subscription/page ownership. A failed send
releases the protocol flag for retry without an older failed send rolling back
a newer successful request. Metadata failures stay visible. Held tab/footer
presses cannot affect replacement connections or a different selected character;
unrelated received metadata does not swallow a valid click on the same owner.

Original static evidence is retained in
`../backups/animations/rea-native-lobby-pages-v1.json`. It includes page callbacks,
row construction, TLK constants, font pointers, status writer and original roster
start/stop handlers. `reports/native-lobby-pages-catalog-v1.json` adds original
Player List row resource hashes/hooks. These are source observations, not proof
of complete original-client visual parity.

Final checks and limits:

- `native-lobby-pages-input-graphical-v3`:32 native source/input/lifetime checks;
  Server Info and Player List images reviewed at1200x850, secondary/unfocused.
- `native-lobby-pages-startup-v3`:12 full native startup/menu routes, no network.
- `native-lobby-pages-local-v2`:7 native admission plus170 authoritative gameplay/
  UI checks against the owned hidden original server127.0.0.1:5125. No crashes,
  failed actions or leftover workers; the owned server released its port.
- 44 service/packet/session checks, including real NetworkGameSession subscription
  methods, update/removal handling, stop-before-Play, failed-send recovery,
  metadata cancellation/privacy and received server-status mapping.

These265 checks cover different scopes. The local gameplay harness uses its
existing automatic character driver; it does not click these new pages against
a second live original-server player. The linked live follow-up supplies that
roster test; original-client pixel/gesture comparison remains required. No automated
public/Arelith client connection was made. No clean FPS/performance claim is made.

Development failures remain in reports: a helper type-inference error, a test
type-inference error, and an arrow test attempted before its artwork was ready.
The final arrow test waits for actual preparation and requires exactly44 pixels.
Visual review separately caught the wrong fallback dialog font and corrected it
using the original pointer. The existing pending-wind particle warning is
unrelated and has not been accepted as fixed by these UI checks.

Still open: remaining embedded character-record pages/fields, original title
policy, local metadata/pregeneration persistence/Delete/Customize, automatic and
keyboard selection, late custom-TLK/override invalidation, complete role/state/
large-font/scale/audio comparison, background pose/tint differences and the rest
of the entire UI audit. This checkpoint does not complete the chooser or goal.
`tools/audit-native-lobby-pages.mjs` verifies scoped receipts and rollback inputs.
