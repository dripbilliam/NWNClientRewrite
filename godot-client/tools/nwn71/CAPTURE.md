The original fixture-a remains the CPU parser/sentinel baseline. The fresh
fixture-bridge-c adds an explicit existing diagnostic DLL only for polling
engine Tracy connection state. It creates an empty NwnParticlePresentation
owner and calls dispatch65000; it admits no emitters or particle scene work.
No accepted/shared extension list or binary is changed.

The coordinator prepares a fresh bridge view with:

```
node tools/nwn71/prepare-fixture-view.cjs --label=<fresh> --trace-bridge
```

After the private diagnostic engine rebuild, the coordinator runs:

```
node tools/nwn71/run-first-use-capture.cjs --label=cpu-a --engine=<privateEXE> --engine-sha=<hash> --view=.cache/nwn71/fixture-bridge-c
```

The fixture waits up to30seconds for the real engine bridge to report bound and
connected, then submits the controlled group. The CPU-only command measures no
FPS. The root must grant a graphical quiet window before adding `--gpu` to
exercise first-use ShaderRD. The runner discovers the current secondary screen
in Godot enumeration order and passes `--screen`; position is optional. GPU
admission verifies the native window stayed on that actual nonprimary screen
with its unfocusable flag set.
There is no client/server login in either mode.

The runner starts the official Tracy0.13 capture CLI before the engine, records
at most10seconds after connection, caps capture memory at2%of physical RAM, and
bounds both owned child processes to45seconds. It uses a new isolated APPDATA
and LOCALAPPDATA, fresh report/trace files, exact engine/fixture input hashes,
and checks exit codes, engine errors, fixture checks and actual connection.

The capture CLI's connected text is buffered when redirected, so it is never
treated as a readiness signal. The actual bridge poll is the start gate.

After a successful capture, use export-labeled-groups.cjs as in README.md.
Check the sentinel's exact reported group ID against its captured description
before accepting any shader producer attribution. A labeled wait still needs
a representative area recording and normal-engine improvement before NWN-71
can be resolved.
