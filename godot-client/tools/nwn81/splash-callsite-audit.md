# NWN-81 original splash sound: bounded native callsite audit

Pinned executable: `C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA-256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. This is a source-only checkpoint, not a proven splash sound identity.

The saved [native intro teardown map](../nwn75/sdl-main-teardown.md) establishes the `CPregameIntro` constructor at `0x140719c70`, created from client startup paths `0x1406d6660` and `0x1406db800`; the global owner is `0x141422cc0`. The [GUI callback map](../nwn75/legacy-gui-attachment-callback-producers.md) identifies intro state update `0x14071a4b0` as a fade-stage writer. The pinned PE `.pdata` gives constructor `0x140719c70..0x140719d9e` and updater `0x14071a4b0..0x14071b08c` (end exclusive). This links startup to visual intro ownership, but it does not link the intro to a sound resource or the precise first audible frame.

The saved [NWN-81 menu audio checkpoint](menu-audio-checkpoint.md) identifies GUI input helper `0x140a60d30`: kind 1 selects `gui_button`, kind 5 `gui_open`, kind 6 `gui_close`, subject to owner/input gates. The original executable exports `CExoSound::PlayOneShotSound` at `0x1401d9d00` and `CExoSoundInternal::PlayOneShotSound` at `0x1401df9e0`. A raw executable-section rel32-displacement scan for these three targets returned 31 total matches in the image, with **zero** fields inside either pinned `CPregameIntro` range. The scan looks for any matching 4-byte displacement, so positive hits elsewhere are only candidates; this absence rules out a direct standard rel32 edge from those two intro bodies to these three exact entries, not indirect sound calls, other wrappers or movie audio. Commands:

```powershell
node tools/nwn75/pe-function-range.cjs 'C:\Users\Niflheim\Desktop\Tools\Local Tools\FullDecomp\NwnRootInstall\bin\win32\nwmain.exe' 0x140719c70 0x14071a4b0
node tools/nwn75/inspect-pe-exports.cjs 'C:\Users\Niflheim\Desktop\Tools\Local Tools\FullDecomp\NwnRootInstall\bin\win32\nwmain.exe' --name-contains=PlayOneShotSound --limit=20
node tools/nwn75/scan-rip-references.cjs 'C:\Users\Niflheim\Desktop\Tools\Local Tools\FullDecomp\NwnRootInstall\bin\win32\nwmain.exe' 0x140a60d30 0x1401d9d00 0x1401df9e0
```

The separate [movie entry](../nwn75/movie-presentation-entry.md) and [movie audio](../nwn75/original-movie-audio-publication.md) maps prove an optional startup/movie owner and Vorbis-to-OpenAL audio publication, but do not prove that the splash uses a movie. `mus_theme_main` is a configured theme name, not evidence of the splash trigger.

**Open edge:** identify the exact splash presentation branch inside the intro/client state machine, follow any intermediate/indirect sound or movie call to a particular resource, and site-back its start condition and first playback time. REA opened the pinned binary, but `analyze_function(0x14071a4b0)` and a single-instruction request did not complete after several minutes and were stopped at tool boundaries. No sound asset has been assigned to the splash from this evidence.
