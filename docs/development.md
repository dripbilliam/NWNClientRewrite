# Development and validation

## Setup and launch

The development route is Windows/PowerShell with compatible Node.js/npm, MSVC x64 and Windows SDK tools. Godot identity is pinned in `godot-client/runtime-lock.json`. A user-owned NWN:EE installation, required content and credentials are external inputs.

From the repository root:

```powershell
npm install
.\godot-client\tools\setup.ps1
.\godot-client\join-native.ps1
```

The normal client opens Main Menu without joining a server. For the existing owned-local development profile, use `.\godot-client\join-local.ps1`. Its install/profile assumptions are workspace-specific; this is not a standalone release package.

`npm start` builds/opens the preserved Electron reference client. It is not the primary frontend.

## Checks

| Change | Appropriate validation |
| --- | --- |
| JavaScript/protocol | Relevant existing Node tests; `npm test` is the broad regression suite |
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
