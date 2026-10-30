# Native server-row activation — locally tested, partial

Rows now select on mouse-down, matching CGuiListBox::HandleLMouseDown
`0x1401ea090`. A double-click routes to the existing Connect action. Protected
servers use the original PLAYERPASSWORD child; no passwordless login is sent.
Enter and keypad Enter also use Connect after a list click captures internal
keyboard ownership. Key release and repeated-key echoes cannot activate again.

Original CGuiMan::HandleLMouseDown `0x1401f5300` records the double-click flag at
offset0xb0 and clears it when the hit GUI owner changes. Selection callbacks
`0x1408d1b30`, `0x1408d1750` and `0x1408d1a20` gate compatibility and parent
ownership, then route the double-click to `0x1408ce280`. That Connect path checks
the selected row and creates PLAYERPASSWORD for password/DM cases. Static
evidence is `../backups/animations/rea-native-server-activation-v1.json`.

The replacement catalog service acknowledges selection using the initiating
view ID and canonical endpoint. A fast double-click or Enter can queue intent
while that selection is pending. It connects only when the acknowledgment,
selected endpoint, current connection/tab, role availability and policy agree.
The intent is consumed once. Missing/mismatched acknowledgments, refused joins,
changed endpoints, modal ownership, Back and connection replacement retire it.
Selection acknowledgments are absent from unrelated refresh/error views.
Credentials remain transient in the existing native Connect/password flow.

Prepared evidence uses headless actual native input, not screenshots:

- `native-server-activation-headless-v1`:24 mouse/key, acknowledgment-race,
  password, admission/policy, duplicate, Back/modal and connection-scope checks.
- `native-server-activation-keys-v1`:15 list keyboard and scrolling regressions.
- `native-server-activation-details-v1`:28 Details/password/text-fit checks.
- `native-server-activation-entry-v1`:31 Multiplayer/Direct regressions.
- `native-server-activation-pages-v1`:28 Internet/History/Favorites regressions.
- `native-server-activation-service-v1.tap`:59 service/wire tests, including
  canonical acknowledgment scope and the previous original key/filter/sort cases.

On 2026-10-29 the user finished the manual session and authorized replacing it
for local tests. Only its verified replacement process was closed. Fresh native
graphical receipts now cover activation (24 checks), list keyboard input (15),
Details/password/caption fit (31), Multiplayer/Direct (35), and browser pages
(32). Captured Details and Internet-page images were reviewed. Startup passed
all 12 routes, with an unfocused window on secondary screen0 (primary2).

`native-server-activation-local-v1` passed all seven native admission checks and
170 authoritative gameplay/UI checks against the owned original server at
127.0.0.1:5125. It exited normally, released its workers and shut down its owned
test server. The service/wire suite passed59 tests. Together these are385 scoped
checks; `tools/audit-native-server-activation-tested.mjs` verifies their receipts
and current source hashes. Client public-server connections were zero.

The initial graphical keyboard invocation used a nonexistent test-script name.
Its failed receipt is retained as `native-server-activation-keys-graphical-v1`;
the corrected invocation passed as v2. No runtime fix or weakened assertion was
needed. The original server's existing pending-wind particle warning remains;
this step does not accept particles or performance. Full UI/browser parity
remains false; scoped passes cannot accept the whole goal.

Original Enter/default-button dispatch is not fully traced. The captured large
application key router has an explicit retained-evidence projection, including
its limits; it does not prove every pregame Enter/modifier/DM/platform path.
Those comparisons remain open, along with encouraged-button artwork, other
scales, sounds, game-type filtering, PvP/version wording, local NWSync status and
remaining admission dialogs. Legacy selection-triggered extended queries are
also not claimed migrated by this activation step.
