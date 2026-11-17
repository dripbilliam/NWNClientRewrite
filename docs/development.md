# Development and validation

## Setup and launch

The client development route is Windows/PowerShell with pinned Godot and the native helper build prerequisites installed by the setup script. Godot identity is pinned in `godot-client/runtime-lock.json`. A user-owned NWN:EE installation, required content and credentials are external inputs.

From the repository root:

```powershell
.\godot-client\tools\setup.ps1
.\godot-client\join-native.ps1
```

The normal client opens Main Menu without joining a server. `join-native.ps1` forwards ordinary gameplay to the Godot-only `join-godot.ps1`; an explicit owned local server can be selected with `join-godot.ps1 -ServerHost 127.0.0.1 -Port 5121`. These source-workspace commands assume an installed NWN:EE content tree and are not a standalone release package.

The root npm package, lockfile and `npm start` route have been retired. The supported launch does not install or start Node or Electron. Historical JavaScript implementation files remain read-only references during NWN-79 migration.

## Checks

| Change | Appropriate validation |
| --- | --- |
| Godot protocol/data | `join-godot.ps1 -CheckOnly`, relevant focused Godot tests, then an isolated owned-server matrix for network behavior |
| Native data or controls | Feature-specific copied-source/headless harness |
| Rendering or presentation | Actual graphical fixture with matching source/runtime/settings and visual review |
| Multiplayer behavior | Unchanged owned original server, real controls, received results and independent exports where applicable |
| Interoperability | Original and replacement clients together on the same owned server |
| Wiki/docs | `npm test --prefix wiki`, build, then check |

Use fresh run names. Inspect each harness before running it: a filename containing “test” does not imply socket-free or GPU-free execution. Source, engine, extension and settings pins must match the actual run. Do not patch old pins to make changed sources pass.

Keep cold/warm loading, input periods, quiet periods, profiling and menu caps separate. Headless timings, fixture counts and screenshots alone do not establish playable performance.

## Workspace constraints

Preserve existing dirty/staged work, accepted artifacts, failed receipts, unrelated processes and saved profiles. Do not rebuild shared native outputs during a retained session or replace a running client automatically.

Automated server tests use owned localhost fixtures. Public-server login, chat and gameplay remain user-controlled unless explicitly authorized for the particular task. Preserve foreground focus and pointer; graphical fixtures should launch unfocused on a discovered secondary monitor when available. Do not run competing GPU workloads during the user's game or manual comparison.

The original executable and analysis databases are read-only inputs. Do not patch or inject into the game.

## Historical tools

The [documentation archive](archive.md) preserves the exact original paths and bytes. Older seal/checkpoint scripts may intentionally require those original Markdown inputs. Restore the needed notes into an isolated historical source tree when reproducing a checkpoint; do not recreate hundreds of live notes or rewrite a receipt's historical hashes.

Operational test-input notes remain beside their harnesses. Their presence is a reproducibility exception, not a pattern for new documentation.
