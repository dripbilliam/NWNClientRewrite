# DenseSync server stress scripts

The fixture packs `stress_entry.ncs` and `stress_heartbeat.ncs` as type 2010.
The two ARE records name those resources in their `OnEnter` and `OnHeartbeat`
fields. The editable sources are [stress_entry.nss](../stress_entry.nss) and
[stress_heartbeat.nss](../stress_heartbeat.nss).

Each area supplies up to 24 `<area>_mech_<index>` placeables with authored
`on`, `off`, `off2on`, and `on2off` clips. Doors use
`<area>_door_0` through `<area>_door_11`. The matching non-player
`<area>_door_actor_<index>` must be within 1.6 m of its door to perform the
queued open and close actions. The scripts restore the door state on entry
and begin door pulses after the player moves horizontally by at least 0.75 m.
The first four banks request the opposite authored states and the next four
restore them. The server checks the first bank after three seconds and logs
requested, queued, opened, closed, and pending counts.

The bytecode was compiled against the installed `ovr/nwscript.nss`
(SHA-256 `c14098d0181f921618622f379ff5cb682b8656d5293f218392531eef7a8478ad`).
The private build used the compiler API from neverwinter.nim revision
`0972fc1ffa73d1a038b9abb00dc40d5a07e28dbe` and MSVC 14.50.35717
in C++14 mode. It linked `compilerapi.cpp` and the six native C++
units listed in `neverwinter/nwscript/compiler.nim`. The small driver
initializes language `nwscript` with debug output disabled and writes
only type 2010. Pass the installed language file, the source script, and
a fresh output path.

```text
compile-fixture-script.exe <installed ovr/nwscript.nss> <area script.nss> <new output.ncs>
```

Two independent compilations produced identical bytes. Each NCS has the
`NCS V1.0` signature, the size opcode, and a declared size equal to its
file size.

| Resource | Bytes | SHA-256 |
| --- | ---: | --- |
| `stress_entry.ncs` | 230 | `f6c9bb785e5c47de8939ead44691ea73a90e1053a3634e453f42dafac9249e58` |
| `stress_heartbeat.ncs` | 4,420 | `acc86366021df9c2732848ffced18ec1f691f5eceb0b40a147b17afd7d4c4b26` |
