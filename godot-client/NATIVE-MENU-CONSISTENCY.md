# Main-menu presentation consistency

Follow-up: [the shared native UI framework](NATIVE-UI-FRAMEWORK.md) extracts the
general painter from inventory, centralizes window theming and control creation,
and constructs both flexible settings pages from definitions. Receipts below
describe this earlier presentation milestone; new framework receipts are separate.

The current main-menu routes use one original-NWN visual family. The prototype
Multiplayer/Options/Resume/Disconnect/Exit button column is removed. A menu whose
source artwork is still preparing presents status; a live pending connection
retains an explicit Cancel connection action. This does not remove cancellation.

Pregame Main/Options, Multiplayer entry and the in-game menu retain their actual
original GUI/MDL layouts. In-game menu assets start preparing when their native
owner is configured, rather than waiting for the first Escape/menu click. Main,
Options and Multiplayer do not present the text/button layout before its own
artwork and fonts have arrived. Readiness checks only that menu's controls,
not unrelated inventory/actor work on the shared painter. Empty icon captions
do not incorrectly wait for a font binding that was never needed.

The main menu's blank News button was a real text-projection omission:
`PRE_MAIN/RepoNewsButton` stores `AurString_Text="News"`, not a TLK reference.
Entry-menu captions now support this original literal-text case while retaining
active TLK and explicit original runtime-caption precedence. The unsupported
News action remains disabled; no fake repository/news implementation is added.

## Replacement-only Client Options

The flexible client settings window is named **Client Options**. Its five pages
(Graphics, Performance, Interface, Prework, UI preload), actions and preferences
remain present. This is a replacement-only menu derived from NWN's style, not a
claim that the original ConfigWindow has been fully ported.

`native_client_menu_style.gd` supplies a shared black/gold theme, original bitmap
Galahad font at its native height, and original button, checkbox, arrow and close
model pixels. It styles tabs, edits, popups, progress and scroll controls too, so
the window does not mix a native frame with default grey Godot controls. The
normal menu controls and settings use the same source family. The earlier
font-only theme handoff after world admission no longer overwrites this style.
The bottom-right menu control receives this theme as well. Original replicated
menu geometry remains authored; it is not replaced by a newly invented layout.

## Checkbox rendering correction

Visual review exposed unchecked controls displaying an X. Original `CTL_CHK_PRE`
clips turn the mark's face around when unchecked. Private GUI rasterization had
forced double-sided rendering, revealing that back face. It now preserves the
source material's culling in both standard and mixed-axis sampler materials.
World rendering is outside this change. The persistent GUI preparation revision
is `original-gui-sampler-v3-source-culling`, so old double-sided baked artwork is
not reused. Existing sampler/filter/UV behavior is retained and tested.

`backups/animations/rea-native-menu-consistency-v1.json` retains selected original
checkbox/menu initializer facets for pinned `nwmain.exe` SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The native actor inspection records the actual original clip transforms and the
literal News caption. The culling interpretation uses those transforms plus
the observed native checkbox pixels; this is not a full original GPU trace.

## Evidence and limits

Current full-source menu-input receipts:

- `native-menu-consistency-pregame-current-v1`:27 checks, original Main/Options,
  Video/Controls/Client Options return routing, literal News and retired presses.
- `native-menu-consistency-ingame-current-v1`:36 checks, source menu, confirmed
  end-game/export routing, window drag/placement,125% scale, scope retirement
  and menu-specific artwork readiness.
- `native-menu-consistency-multiplayer-final-v1`:35 checks, original entry and
  profile/direct/browser input. These use owned/authored replies, not public logins.

Supporting receipts test unchanged dependencies: styled settings15, settings
behavior38, disconnect14, persistent GUI prework38, original sampler/pixels126,
and actual animated GUI actors23. They predate only the later Browser owner
change which connects/gates its entry-menu artwork-ready signal; the current
Multiplayer and both menu-input runs cover that changed owner. The auditor
requires every other captured source hash to remain current and reports this
specific excluded difference rather than pretending all receipts are identical.

Actual Main, Options, in-game,125% menu and Graphics/Interface screenshots were
reviewed. Checked and unchecked images must differ, and actual native tab,
checkbox persistence and close actions pass. All runs are local UI diagnostics;
there is no public gameplay connection, physical mouse warp or clean FPS claim.

Failed/intermediate runs are retained. The first compile hit a Node signal-name
collision; the first visual-settings probe used an invalid coordinate helper;
the first readiness gate incorrectly counted an empty icon caption. Visual
review found the double-sided checkbox state and missing literal News label.
These runs are not accepted as final evidence.

The complete original ConfigWindow, unfinished campaign/movie/news/storage
actions, all other UI surfaces, full role/resource/scale/original-client behavior
and the entire parity objective remain open. The approved character-picker
redesign remains a separate surface. This milestone resolves the mixed main-menu
presentation; it does not certify the complete native UI or port missing settings.
