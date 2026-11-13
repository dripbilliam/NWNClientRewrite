# Non-activating secondary-monitor startup

User preference: launches and test closures must not interrupt the foreground
application or capture/reposition the mouse. Prefer a non-primary display.

Normal interactive launches preserve the previously tested complete lighting
and particle configuration through the [gameplay profile](NATIVE-RENDER-LAUNCH-PROFILE.md).
The earlier `-SharedParticles` instruction restored particles alone and left
the corrected world lighting disabled; it is superseded by the grouped profile.
`-RenderProfile legacy` remains an explicit diagnostic rollback. See the
[responsiveness correction](NATIVE-UI-RESPONSIVENESS-REGRESSION.md).

`join-native.ps1` reads Windows monitor membership before starting the engine.
`tools/native-window-screen.ps1` uses EnumDisplayMonitors and the primary flag;
its ordering matches Godot's Windows display adapter. The protocol-only host
passes the selected index through the engine's `--screen` option, before user
arguments, and always hides the helper console. Kernel graphical checks use the
same discovery. No display mode, foreground window or cursor is modified by
this discovery. One-screen setups omit the secondary-screen override.

`project.godot` creates windows with `display/window/size/no_focus=true`.
The native entry rechecks the current topology for direct entry/hot-plug changes,
then centers its initial size on the selected usable screen. Normal interactive
entry retains the no-focus flag until a click in the actual game window;
automated local checks retain it throughout their run. No startup or teardown
code requests foreground activation. The older creator probe's explicit
window-focus request was removed.

Godot documents the [no-focus setting](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-display-window-size-no-focus)
and [primary-screen discovery](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-get-primary-screen).
Its [Windows display source](https://github.com/godotengine/godot/blob/master/platform/windows/display_server_windows.cpp)
uses non-activating ShowWindow for this flag and EnumDisplayMonitors for screen
indices. These upstream references explain the approach; the installed engine's
observations below are the acceptance evidence.

`reports/native-secondary-startup-v3.json` and its `.native.json` show the real
installed engine selecting screen 0 while the primary is screen 2 (three
screens), opening and closing its browser without a server join, retaining the
no-focus flag, reporting no focus and mouse mode 0 (visible). Normal-heap
debugger traps are armed, sources unchanged, exit 0 and no engine error.
Earlier v2 correctly selected the secondary display but reported focus after
the flag was released automatically; that approach was replaced by explicit
click activation. The failed v2 acceptance is retained. Physical click-to-
activate remains available for the user's next interactive session; these
automated checks do not simulate a desktop click or force focus to test it.

Do not use background/minimized observations as clean FPS acceptance. This
startup behavior does not establish renderer, gameplay or mixed-client parity.
