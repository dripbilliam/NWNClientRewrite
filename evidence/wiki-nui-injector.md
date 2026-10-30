# Wiki reader in the original NWN:EE client

Implemented 2026-10-27 for the user's request to display the supplied wiki export
while their unmodified Steam client is connected to Arelith. The original
executable on disk is never patched. Frida installs temporary in-memory hooks;
this is an instrumentation experiment, not a server-deployed feature.

## Scope and operation

- Target: Windows x64 NWN:EE 89.8193.37-17, executable SHA-256
  `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
- The host verifies the selected process's executable path, entire file hash,
  architecture, and in-memory function prologues before installing hooks.
- `scripts/wiki_nui_data.py` converts `wikiexport2.xml` into 66 articles and
  681 text sections. Race-template parameters and included Half-Giant text are
  retained. Sections are split at a presentation budget of 6,000 characters;
  this is not an assertion about an engine limit.
- The injected agent feeds ordinary inline-create (55/1), group-replacement
  (55/5), and destroy (55/2) packets through the original client NUI receiver.
  It uses a separate read-message structure, on the real receive thread after
  a genuine message returns. Original inbound packets and reader state are
  unchanged.
- The local window token is `0x6e770001`, ID `localwikireader`. All of its named
  UI events are intercepted before queue insertion and delivered to the local
  Python reader. An additional send-boundary filter removes any remaining
  records for that token while preserving other records in a mixed NUI batch.
  A genuine server create using the reserved token disables local ownership.
- No commands or fabricated UI events are sent to Arelith. The agent creates no
  network connections. Article data comes entirely from the supplied XML.

The UI provides a scrollable article index, Previous/Next section buttons,
section contents, Back history, and navigation to related exported articles.
No game hotkeys are registered. Closing the reader leaves the injector
available to reopen it through the local control command below.

## Run

Requires Python 3.12 and `frida`. The current machine already supplies both.

From the workspace root, inspect the data without accessing a game process:

```powershell
py -3.12 scripts/wiki_nui_injector.py --inspect
```

Attach to a selected, already connected client:

```powershell
py -3.12 scripts/wiki_nui_injector.py --pid <client-pid>
```

The default verified executable location is the Steam installation under
`C:/Program Files (x86)/Steam/steamapps/common/Neverwinter Nights/bin/win32`.
Use `--exe` for another installation of the exact same build.

Use Ctrl+C for graceful shutdown. For a background instance, request shutdown
through its local control file:

```powershell
Set-Content runtime-logs/wiki-nui-injector/control.json '{"action":"stop"}'
```

Supported control actions are `show` (optional `article` and zero-based
`section`), `hide`, `click` (a local widget identifier), and `stop`. Controls
never evaluate code or issue game/server commands. Paths can be changed with
`--report` and `--control`.

Reopen the window after closing it:

```powershell
Set-Content runtime-logs/wiki-nui-injector/control.json '{"action":"show"}'
```

## Validation

`node --test test/wiki-nui-injector.test.mjs test/network-nui.test.js` passed
15 tests. New checks cover real export conversion, nested links in race
templates, Half-Giant inclusion, section bounds, Python-generated packet
decoding with the existing native codec in format modes 0/1/2, mixed-batch
event/bind filtering, legacy/indexed binds, and malformed output rejection.
Set `NWN_WIKI_PYTHON` to choose a Python executable for these tests.

Observed live on the user's connected stock Steam client:

- A 6,581-byte standard create packet returned success from the original NUI
  receiver, with zero overflow and underflow.
- The original JsonWindow renderer ran for the local token and emitted its
  normal open event. Real mouse-scroll events were received and handled locally.
- A 1,235-byte group-replacement packet displaying Forest Gnome's Details
  section also returned success with zero overflow and underflow.
- Subsequent physical article and Next-button clicks were captured locally;
  their group replacements returned native success with zero overflow and
  underflow, including navigation through Bugbear's sections.
- A bounded first pass destroyed its local window and detached successfully;
  the original game process remained responsive.
- A subsequent persistent instance supported live user interaction: 16 packets
  were accepted and 81 local UI events were observed, with zero native receiver
  errors. The user closed the wiki window; the client process subsequently
  exited and ended the Frida script. The cause of that process exit was not
  established by the available evidence. A narrow check found no recent NWN
  crash-report files or matching Windows application-error events.
  Machine-local logs and current counters are in
  `runtime-logs/wiki-nui-injector/status.json` and `status.jsonl`.

These observations establish original receiver and render-path execution.
They do not establish visual perfection or independently verify every article
and every navigation button. Native open/render hooks are not screenshots.

## Limits

- The supplied export is a snapshot, not the live website. Search and full
  MediaWiki formatting are not implemented. Explicit tables become text rows;
  the recurring Race template becomes labelled text fields. Unknown templates
  are shown as placeholders retaining their parameters.
- Illustration files are absent. The UI shows references/captions and skin
  palette indices instead of downloading or installing image assets.
- Initial create is 6,581 bytes; the largest converted section replacement is
  6,474 bytes. These are uncompressed native NUI packet sizes for this reader,
  not on-the-wire encrypted transport measurements.
- Work is drained after genuine receive callbacks, so an idle connection can
  delay local navigation. This scheduling limitation belongs to the injector,
  not to stock NUI itself.
- The outbound bind filter currently expects indexed bindings from an
  8193.35-or-newer server. The codec tests also cover older bind framing, but
  automatic server-build detection is not implemented in the live agent.
- A server implementation could send these layouts through ordinary NWScript
  NUI calls and would not require client instrumentation. Deploying such a
  feature to Arelith requires its server/module maintainers.
