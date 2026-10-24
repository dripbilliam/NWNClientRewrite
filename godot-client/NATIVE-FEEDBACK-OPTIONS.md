# Combat feedback Options

Options → Game now includes the existing client's **Floating combat feedback**
and **Show total damage only** controls. Their native ConfigFile values persist
across Options owners, apply immediately to the shared original formatter and
are resynchronized on each connection. Defaults remain floating enabled and
grouped damage. The original number colors and formatting are preserved.

Disabling floating combat feedback suppresses damage and special attack
overhead text. Combat history remains visible. Server-script floating prompts,
including toolbar assignment instructions, remain visible independently.
No server damage, rolls, hit points or spell state are calculated or changed
by these preferences.

Godot owns both controls and persistent local preferences. The bounded local
bridge message accepts only two Booleans from the current connection and is
available before area admission. The backend acknowledges the applied values.
`GameplayDelivery` supplies the live options to the original `NetworkFeedbackView`;
changing preferences during a pending table lookup affects the later emission.
Protected keys and Workshop settings continue through their existing owners.

## Validation

`reports/native-feedback-options-local-v1.json` passes 20 actual local checks,
plus the existing 16 dialogue/examination checks and one animated/moving area
admission. Its authored GodotFeedback1 server module adds only a chat script
using the installed native API's EffectDamage and floating-text functions.
Three actual fire-damage messages of amount 3 are received from 127.0.0.1:5121:

| Floating | Total only | Native overhead | Damage history |
|---|---|---|---|
| On | Off | 3 and server prompt | Present |
| On | On | 3 and server prompt | Present |
| Off | On | Server prompt only | Present |

Native rendering, the decoded server packets and backend emissions agree.
This live fixture has one damage group; multi-group 3/5 versus total 8 is
verified separately through the actual shared formatter in backend tests.
It does not establish multi-type native-server combat or full combat parity.

The native controls save to an isolated preference file during this run, and
the user's original configuration hash and runtime preference are restored.
Actual WASD through simultaneous Options/inventory and authored middle-mouse
orbit pass. The final native exit is zero, disconnect is observed, pending
inventory icons retire to zero and there are no rejected commands or native/
renderer errors. The Options screenshot was reviewed. Original game processes
and the editor are preserved; no public server is contacted.

`reports/feedback-options-ui-v1.json` passes 10 rendered authored GUI checks:
actual checkbox clicks, independent settings, persistence in a new Options
owner, current acknowledgement, retired-connection rejection, unauthenticated
input suppression and malformed-config defaults. These are synthetic viewport
events rather than physical-device acceptance.

`reports/feedback-options-settings-regression-v3.json` passes all 21 existing
Workshop/CD-key/debug/Main Menu GUI checks. The initial v1 regression retains
a single synthetic Save-click failure. V2 passed with nonsecret geometry/request
tracing; v3 additionally injects pointer motion before the click, as the other
GUI drivers do. The initial cause is not established, and v1 is not promoted.
All associated accepted engine logs are clean.

`reports/feedback-options-node-v4.log` passes 122 backend tests without failures
or skips. New cases cover grouped/total/suppressed damage, suppressed critical
attack text with retained history, unaffected script prompts, changing options
during a pending lookup, typed connection-scoped settings, and rejection of
incomplete live evidence. Existing actions, spellbook, inventory, settings and
saved-shortcut tests are included. The native dependency check also passes.

## Remaining Options work

Scripted camera commands/collision, shadow-budget selection, wireframe,
blood/gore presentation, broader graphics/feedback preferences, sound/music/
voices and interactive debug behavior remain in the full migration. These two
controls do not accept those systems, native bitmap-font/skin parity, actual
preference resynchronization across a second live admission, broader pending
work/failure cases or complete moving-scene 60 FPS performance. Missing particle
providers and unhandled game-message diagnostics remain open.

The owned local server now runs the authored GodotFeedback1 fixture, which
inherits the earlier party/NUI/dialogue/transition commands. The original
GodotParty1 module and installed binaries/assets are unchanged. Reproduce this
check with `./godot-client/join-local.ps1 -FeedbackSmoke -Report unused-name.json`
while that local fixture is active. The migration goal remains active.

The subsequent [camera milestone](NATIVE-CAMERA-MODES.md) ports the native
mode/input/follow core and retains feedback behavior in a 20-check local
regression. Complete camera and Options parity remain open.
