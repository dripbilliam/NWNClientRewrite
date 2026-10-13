# NWN: Enhanced Edition Reverse-Engineering Workspace

This workspace tracks a subsystem-by-subsystem investigation of NWN: Enhanced Edition. The long-term objective is a comprehensive behavioral reconstruction, not a claim that Ghidra can automatically recover the original source code. Optimized binaries do not preserve original names, comments, types, or every source-level distinction; conclusions must be validated against code paths and runtime evidence.

## Target and existing analysis

- Target executable: `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`
- Target build: NWN:EE `89.8193.37-17`, x64 PE
- Expected SHA-256: `3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`
- Existing Ghidra project: `../FullDecomp/ghidra-projects/NWN-EE-8193.37-17.gpr`
- Existing Ghidra version and bridge setup: `../FullDecomp/GHIDRA_MCP_SETUP.md`

The executable and Ghidra project are shared research inputs in the original `FullDecomp` workspace. Do not copy or re-import them here. Keep the binary unchanged. Avoid speculative Ghidra renames/types/comments; record evidence in this workspace first.

## Research workflow

1. Record the exact target/build and the evidence source for every finding.
2. Trace from imports/strings to callers, then through callers to subsystem boundaries.
3. Label statements as **Observed**, **Inferred**, or **Open**; include addresses and validation status.
4. Keep renderer, resources, protocol, scripting, and world simulation as separate tracks until their interfaces are demonstrated.
5. Validate hypotheses with independent call paths, runtime behavior, or known reference implementations before treating them as facts.

## Current entry points

- [Initial Windows executable inventory](evidence/binary-inventory.md)
- [First object-render milestone](evidence/first-object-render.md)
- [Research tracker](RESEARCH_TRACKER.md)
- [Initial OpenGL render-path findings](evidence/rendering-pipeline.md)

Ghidra label persistence is checked by [VerifyRendererLabels.java](scripts/VerifyRendererLabels.java). The PartTriMesh RTTI scan is in [InspectPartTriMeshVtable.java](scripts/InspectPartTriMeshVtable.java), and local snapshots under `backups/` are excluded from Git.

## Desktop model viewer

The Electron/Three.js viewer builds and launches with:

```powershell
npm install
npm start
```

Modules now open in **Game UI** view, using installed NWN panel/button assets and fonts. **J** opens the journal; Witch's Wake's eleven subrace entries appear under **Completed Quests**, with their real authored text. **I/C/M/B/O** open inventory, character, map, spellbook and options. **Escape** closes a panel; **Tools** restores the development interface. Choose **Language Data** (`lang/en/data`, or your installed language) for interface text from `dialog.tlk`. Personal notes and assigned quickbar targets persist during the loaded module session. Unsupported actions emit `[UI placeholder]` requests; character creation, combat, conversation, inventory actions, save and networking systems remain unfinished. See [UI evidence and limits](evidence/game-ui.md).

The Tools inspector provides gameplay panel previews and all 104 installed native GUI layouts, including front-end menus, character generation, shops, multiplayer/server panels and settings. With game data loaded, **Game UI** can open the native main menu before a module is selected. Add `--check-ui --full-scene` to the renderer harness for journal/input/panel/navigation checks.

**Tools → Runtime diagnostics** shows the complete session's record count, save status and log path, with export and retry controls. Electron automatically saves ignored JSONL files under `runtime-logs/`; browsers retain sessions in IndexedDB and can export saved history. Unsupported engine calls include script/API/object/PC context, and missing resources, decode errors, scene omissions, incomplete adapters and placeholder interactions are retained. Fallback lookup attempts are distinct from final missing assets. Add `--check-diagnostics` to the renderer harness to compare the complete journal, durable file and downloaded export; `--browser-diagnostics` also checks browser persistence after reload. See [Diagnostic coverage and limits](evidence/runtime-diagnostics.md).

**Load Character** accepts an installed/user-owned `.bic`. Select it before opening a module to load player data before startup scripts. The initial capsule preview can also be upgraded once inside a module; startup is not replayed. A later BIC selection stages the character for the next module. The HUD and character, skill, feat, equipment and spell panels read actual imported state; owned items receive canonical session IDs. Body/head and chest-armor appearance use the creature renderer. Spell/feat use, inventory manipulation, leveling, other item/effect rules and remaining equipment visuals are pending. See [Character/XP evidence and accuracy limits](evidence/player-character.md).

`node scripts/smoke-character.mjs <install> <WitchsWake.mod>` checks the installed BIC corpus and Brogan's real scripted 100 XP reward. The Electron harness accepts `--check-character --check-scripts --full-scene` for character UI/rendering and the door/XP round trip; `--character --interactive --full-scene` opens the installed wizard fixture for inspection.

`node scripts/smoke-plt.mjs <install> <module>` verifies head texture orientation against installed model UVs. Add `--focus-character` to the Electron harness to frame the PC in the full area.

For MOD areas, the viewer opens the module's IFO entry area when available. ASCII NWN WOK walkmeshes are parsed with `surfacemat.2da` walk flags; a capsule preview moves with WASD or the arrow keys, follows walkable triangles, collides with available PWK and active DWK meshes, and keeps the camera centered on the player. **Click a visible door** to select it and queue an approach/use action; **E** or the movement HUD use the selected or nearby door. The actor follows a walkmesh route to an authored DWK use point before changing state. **Escape** or manual movement cancel approach; **F** recenters the player camera. Doors rest until used. Locks and player overlap are checked; door state persists across development area switches until another module is loaded. Doors play authored opening/closing clips when available and retain conservative collision until the resting pose; missing state clips use a translucent collision preview. A first NWScript VM executes shipped door transition scripts, queues AssignCommand/DelayCommand continuations and retains the same player/object IDs across linked area traversal. Unsupported script calls report the script name and instruction offset. Full campaign startup, placeable actions, combat, inventory gameplay, saves and networking remain unfinished.

The module session owns one native-style uint32 object registry, shared by rendering, actions, picking and scripts. It indexes all authored areas and their objects, including owned inventory/equipment items, with persistent IDs and owner references. Native allocation/lookup/deletion and internal/external ID namespaces are implemented; this is a foundation for future multiplayer replication, not a networking client. Witch's Wake's real client-entry script adds its 11 journal entries once, and its door script checks possessed familiars before assigning a jump. See [Native script/object evidence and accuracy boundaries](evidence/script-object-runtime.md).

The shared animation runtime is used by tiles, doors, placeables, creature skeletons and their attachments, and standalone models. Enable **Animation tools** for diagnostic previews (off at module startup). **Animation preview** lists instances and their authored/inherited clips; select a clip, use **Play/Pause**, and **Focus** the selected object. **Isolate selected object** hides surrounding models for an unobstructed preview; uncheck it to restore the area. Available idle/default clips play automatically. Binary and ASCII controllers support position, quaternion orientation, uniform scale, mesh opacity, linear/Bezier curves, loops, and one-shot poses. Supermodels resolve through the module/HAK/game resources; standalone models can use **Game Data** or accompanying supermodel MDLs. Mapped skin geometry follows bone updates; exceptional skin variants remain approximate. Preview playback changes appearance, while gameplay collision follows queued use actions. Preview controls are temporarily disabled during a gameplay door transition. See [Animation evidence and remaining work](evidence/model-animation.md).

**Right-click objects, the player capsule, or scenery** for the shared radial menu. Hold, drag and release to select, or right-click once then click an entry. The hand action opens/closes doors, including explicit Close on linked doors. **Player actions** also opens the self menu when scenery obscures the capsule. Nested menus include native emote pages, spells, abilities and associate commands. Center returns to the parent; Escape cancels. Unfinished systems log `[Radial placeholder]` requests in the console and show HUD feedback. Spell/feat lists await character data; item/associate providers await object loading. See [Radial menu evidence and limits](evidence/radial-menu.md).

The bundled renderer harness accepts `--check-radial --full-scene` to exercise linked-door closing, hold/release, nested menus and placeholders with real pointer input.

See [Gameplay foundation and target evidence](evidence/door-click-gameplay.md) for object picking, action queues and known limits. Run `npm test` for format, movement, animation and gameplay regressions. Exercise installed resources without copying assets into the repository with:

```powershell
node scripts/smoke-module.mjs '..\FullDecomp\NwnRootInstall' "..\FullDecomp\NwnRootInstall\data\mod\Witch's Wake.mod" angmarshouse brogansarm
node scripts/smoke-scripts.mjs '..\FullDecomp\NwnRootInstall' "..\FullDecomp\NwnRootInstall\data\mod\Witch's Wake.mod"
node scripts/smoke-conversations.mjs '..\FullDecomp\NwnRootInstall' "..\FullDecomp\NwnRootInstall\data\mod\Witch's Wake.mod"
node scripts/smoke-startup.mjs '..\FullDecomp\NwnRootInstall' "..\FullDecomp\NwnRootInstall\data\mod\Witch's Wake.mod"
node scripts/smoke-gameplay.mjs '..\FullDecomp\NwnRootInstall' "..\FullDecomp\NwnRootInstall\data\mod\Witch's Wake.mod"
node scripts/smoke-animations.mjs '..\FullDecomp\NwnRootInstall' "..\FullDecomp\NwnRootInstall\data\mod\Witch's Wake.mod"
```

The startup check runs with startup enabled and verifies effects, expiry, native-history XP reduction, exit healing and reward audio while asserting remaining clone/damage blockers; passing does not mean the opening is complete. Optional `--python-reference` requires Python 3.12 with `audioop` and compares every decoded reward sample in memory. See [Startup effects/audio evidence](evidence/startup-effects-audio.md) and [character progression/rules evidence](evidence/character-progression.md).

`node scripts/smoke-progression.mjs <install> <module>` checks installed high-level characters against the shared rules loader, level loss and preauthored history replay. The rules loader follows class table references through module/HAK precedence. Add `--check-progression --full-scene` to the Electron harness for the startup-enabled wizard HUD checkpoint; `--check-character` isolates original BIC import and panels with startup explicitly disabled.

Native-traced base attack/save providers now feed script-visible armor class, nominal melee/offhand/ranged bonuses and final Fortitude/Reflex/Will modifiers. The character panel displays base and final values separately. Canonical equipped items and positive attack/AC/save effects refresh shared stats through XP changes, area entry, deferred removal and expiry. `GetBaseAttackBonus`, `GetAC` and final save queries resolve canonical object IDs; unavailable NPC stats and unsupported item/effect behavior retain diagnostics. `node scripts/smoke-combat.mjs <install> <module>` checks installed BIC snapshots and rollback/replay without changing the assets: AC matches 39/39 and final saves 38/39, with the Weapon Master discrepancy retained. See [modifier evidence and remaining fidelity work](evidence/combat-final-modifiers.md). Opponent-specific modifiers, negative-effect immunity, temporary ability effects, actual equip/unequip, attack resolution and independent native/server comparisons remain open.

The optional `NWN_HAK_PATH` environment variable adds a user HAK directory. The smoke tool reports unavailable object meshes separately from absent tile floors. For the bundled renderer check, build first and run `electron scripts/smoke-viewer.cjs <install> <module> [area] [screenshot.png]` through the local Electron executable. Use `angmarshouse --check-scripts --full-scene` to verify the scripted Angmar/Brogan round trip with retained player/door IDs and journal state. Add `--check-gameplay --full-scene` to verify actual pointer picking and a settled door action; `--interactive --full-scene` opens a normal module with doors resting. It uses a hidden offscreen window and stores its profile under ignored `backups/`; if the host defines `ELECTRON_RUN_AS_NODE`, remove that variable in the testing shell first.

Use **Open Model** to choose an ASCII or supported binary `.mdl` and its matching `.tga` bitmaps together. The viewer handles triangle-list meshes, node transforms, UVs, and local TGA/DDS textures. Area scenes use ARE Sun/Moon ambient and diffuse colors, converted from NWN BGR/sRGB storage. Static MDL point lights use the target's radius-derived constant-attenuation approximation and shadow flags; meshes cast and receive PCF shadows. Visible doors resolve through `genericdoors.2da`/`doortypes.2da`. Particle previews are off by default because static data cannot determine whether runtime emitter effects activate; enable **Preview effects** to inspect a simplified emitter preview. ARE files do not serialize runtime diffuse direction, so a labeled default preview direction is used when diffuse light is present. Environment-mapped reflection shaders are confirmed in NWN:EE but are not yet rendered by the viewer. Separate static/dynamic shadow passes, exact light filtering, particle physics, binary light/emitter payloads, animated-mesh vertex/UV channels, dangly meshes, triangle strips, clip blending, event dispatch, and gameplay actor state selection remain unsupported.

To extract one named resource from the existing installation without unpacking an archive into this repository:

```powershell
py scripts/extract_key_bif_resource.py `
	'C:\path\to\NwnRootInstall\data\nwn_base.key' `
	'C:\path\to\NwnRootInstall' `
	plc_creats.tga `
	"$env:TEMP\plc_creats.tga" `
	--bif data/textures_02.bif
```

For the volumetric rock sample, extract `dag_rockledge1.mdl` and its two referenced maps, then select all three files together in the desktop viewer:

```powershell
$install = (Resolve-Path '..\FullDecomp\NwnRootInstall').Path
$assets = Join-Path $env:TEMP 'nwn-model-test-assets'
$key = Join-Path $install 'data\nwn_base.key'
py scripts/extract_key_bif_resource.py $key $install dag_rockledge1.mdl (Join-Path $assets 'dag_rockledge1.mdl') --bif data/os_models.bif
py scripts/extract_key_bif_resource.py $key $install ttu01_rock02.tga (Join-Path $assets 'ttu01_rock02.tga') --bif data/xp2_tiles.bif
py scripts/extract_key_bif_resource.py $key $install ttu01_moss.tga (Join-Path $assets 'ttu01_moss.tga') --bif data/xp2_tiles.bif
```

Creature clicks and radial **Talk** now run authored DLG/NCS branches; placeable **Use** runs OnUsed. Choose numbered replies by click or keys 1–9. Dialogue captures movement input. See [conversation/trigger evidence](evidence/conversations-triggers.md) for native contracts and remaining gaps. Renderer validation: `brogansarm --check-conversations --full-scene`; add `--interactive` to leave Angmar's conversation open after verifying XP and quest UI. `--character --interactive --full-scene --play` opens an exploration fixture. Both fixtures explicitly disable startup and the initial area-enter script through the Tools checkbox; later area/object scripts still run. Normal loads keep that checkbox enabled. The test bypass does not imply campaign startup works.
