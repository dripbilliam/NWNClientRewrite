# Gameplay menu input ownership

The user requests that all in-game menus permit WASD, and clicks outside menus
continue to move the character. This is an explicit input-policy requirement;
it is not a new claim about every original NWN menu's modal behavior.

Multiplayer drive readiness no longer checks inventory, character/spellbook/
options/level-up panels, conversation, examine, radial or focused NUI buttons.
World clicks no longer reject those menu visibility flags. Actual canvas hit
testing owns world clicks; menu controls retain their own pointer targets.
World clicks focus the canvas so a previously edited field releases input.
Right-click world menus also work alongside other panels. The transparent gap
between the two spellbook windows passes pointer input through.

Shared text-entry detection distinguishes editable fields/selects from buttons,
checkboxes and sliders. NUI's capture getter only captures text entry. Keyboard
focus/frame checks stop movement while typing, and neither W nor Shift release
can be swallowed by the legacy GameUi capture handler. Local gameplay panels
likewise stop claiming world movement: opening a panel preserves held keys and
the local movement/action queue runs while a conversation panel is displayed.
Unavailable/loading worlds, character-selection lifecycle and actual scripted
cutscene locks remain separate. No movement packet, collision calculation or
server authority was changed.

The radial retains its browser top-layer priority. Its viewport-sized container
does not intercept outside clicks; only the circular menu area/buttons do.
An outside left press closes it and the original event reaches the canvas,
without synthesizing a second click. Inside clicks/gaps never click the world.
WASD/QE/Shift pass through; Escape, numbered entries and arrow navigation retain
radial behavior. Dragging quickbar actions temporarily releases the radial hit
area as before. Conversation reply shortcuts ignore text-entry targets.

Validation:108 focused network/keyboard/radial/NUI/frontend/IPC tests pass.
The actual Chromium fixture instantiates production GameUi, NetworkNuiView,
RadialMenu and NetworkKeyboardInput. It checks a held W across menu opening,
focused buttons/checkboxes, NUI text and chat capture, key release, Shift release,
outside-world hit tests, menu hit isolation, resumed movement after a world
click, top-layer priority and unchanged synthetic actor state. Calls are captured
locally; there are no joins/uploads. The installed-resource NUI fixture also
passes with the existing72 populated toolbar slots and bitmap overhead prompt.

The first extended fixture attempt lacked its Three import map. A second attempt
did not advance the synthetic frame after focus in a hidden/offscreen window;
the final fixture exercises both the focus and production frame guard. Those
fixture failures are retained, not counted as acceptance. See
creation-experience-menu-movement-proof-v1.json and the run/test/build logs.

Final follow-up: focused sliders, radio/tab controls and ordinary buttons keep
arrow-key events for their UI behavior while WASD continues to drive. The input
fixture checks slider W/release plus delivered ArrowRight without a movement
request. The acceptance report now has17 checks.108 focused tests and the final
build pass. The first complete snapshotv48 remains an intermediate checkpoint;
the small arrow-ownership follow-up is sealed in its successorv49. The final
replacement opened at Main Menu with index-zJ6YIfau.js, controlv9, after closing
only the earlier replacement build. No automated server join/chat was sent.
