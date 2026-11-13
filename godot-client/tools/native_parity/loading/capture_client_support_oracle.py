"""Deferred original-instruction client support-Z controller oracle.

Executes unmodified nwmain FUN_1407ff030 only. GetTile, Scene::HitCheck results,
an empty CHitInfo construction and null frees are captured lower boundaries.
This does not execute native scene/BSP/polygon membership, transport or gameplay.
No live process is opened or modified. Nothing executes merely by importing this
source: the original read-only PE/emulator framework is imported inside main.
"""
from pathlib import Path
import argparse
import hashlib
import importlib
import itertools
import json
import struct
import sys

TARGET = "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
ENTRY = 0x1407FF030
CONSTRUCTOR = 0x1400C0C40
GET_TILE = 0x1407DB200
FREE = 0x140C4F024


def f32(value):
    return struct.unpack("<f", struct.pack("<f", value))[0]


def authored_cases():
    cases = []
    points = [[3.0, 4.0, 37.0], [-0.0, -0.0, 11.0],
              [0.0007, 4.0009, -3.0], [10.0, 10.0, 0.0],
              [31.999998092651367, 0.00000001, 90.0]]
    for point, previous, first_hit, normal_output in itertools.product(
            points, [0.0, -0.0, 11.0, 16777217.0], range(7), [False, True]):
        # first_hit6 means a complete miss. Lower answers deliberately own the
        # hit coordinates; the original controller must take only their Z.
        replies = [None] * 6
        if first_hit < 6:
            replies[first_hit] = {"position": [97.0, -83.0, 11.125],
                                  "normal": [-0.0, 0.6000000238418579, 0.800000011920929]}
        cases.append({"point": point, "previous": previous,
                      "area": True, "scene": True, "normal_output": normal_output,
                      "tiles": [True, True, True], "rays": replies})
    for area, scene, tiles in [(False, True, [True] * 3),
                               (True, False, [True] * 3),
                               (True, True, [False, True, True]),
                               (True, True, [True, False, False]),
                               (True, True, [True, False, True]),
                               (True, True, [True, True, False])]:
        for normal_output in [False, True]:
            cases.append({"point": [0.0007, 4.0009, 50.0], "previous": 11.0,
                          "area": area, "scene": scene, "normal_output": normal_output,
                          "tiles": tiles, "rays": [None] * 6})
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--evidence")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[4]
    output = Path(args.output).resolve()
    allowed = root / "godot-client/.cache/native-140fps/loading-agent"
    if not output.is_relative_to(allowed.resolve()) or output.exists():
        raise RuntimeError("Fresh loading-agent output path required; existing evidence preserved")
    evidence_path = Path(args.evidence).resolve() if args.evidence else root / "godot-client/tools/native_parity/visibility/evidence/native-presentation-procedures-v2.json"
    evidence_bytes = evidence_path.read_bytes()
    evidence = json.loads(evidence_bytes)
    row = next(r for r in evidence["rows"] if r["key"] == "clientSupportZ")
    if row["subject"]["digest"]["sha256"] != TARGET or int(row["procedure"]["address"], 16) != ENTRY:
        raise RuntimeError("Original controller evidence identity differs")
    ranges = [(int(r["start"], 16), int(r["end"], 16) + 1)
              for r in row["procedure"]["body"]["ranges"]]
    if ranges != [(ENTRY, 0x1407FF5C7)]:
        raise RuntimeError("Original controller body range differs")
    sys.path.insert(0, str(root / "scripts"))
    # Existing framework authenticates and maps the installed read-only PE;
    # importing it does not execute its __main__ coordinator fixture.
    m = importlib.import_module("inspect-native-intratile-coordinator")
    if m.digest != TARGET:
        raise RuntimeError("Original PE digest differs")
    from unicorn import UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_RCX, UC_X86_REG_RDX,
                                   UC_X86_REG_R8, UC_X86_REG_R9,
                                   UC_X86_REG_RSP, UC_X86_REG_RIP,
                                   UC_X86_REG_RAX, UC_X86_REG_XMM3)
    u = m.u
    u.hook_del(m.hook_handle)
    actor, area, scene, vtable, point, normal = [m.heap + n * 0x1000 for n in range(40, 46)]
    hit_stub = m.stop + 0x358
    current = {}
    events = []
    tile_queries = []
    ray_queries = []
    constructor_calls = []

    def put(address, value):
        u.mem_write(address, struct.pack("<3f", *value))

    def vec(address):
        return list(struct.unpack("<3f", bytes(u.mem_read(address, 12))))

    def hook(_u, address, _length, _data):
        if address == m.stop:
            u.emu_stop()
            return
        x, y, z, w = [u.reg_read(r) for r in
                      [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9]]
        rsp = u.reg_read(UC_X86_REG_RSP)
        if address == CONSTRUCTOR:
            if y != 0 or z != 0xFFFFFFFFBFFFFFFF or w != 0:
                raise RuntimeError("CHitInfo lower construction arguments differ")
            constructor_calls.append({"first": y, "mask": hex(z), "third": w})
            # Explicit captured empty lower owner: no retained Part/dynamic
            # lists or allocation, hence only null frees may follow. The
            # original controller still writes mode1 itself after construction.
            u.mem_write(x, bytes(0x80))
            m.finish(x)
            return
        if address == GET_TILE:
            index = len(tile_queries)
            if x != area or index >= len(current["tiles"]):
                raise RuntimeError("Unexpected GetTile lower call")
            tile_queries.append(vec(y))
            events.append({"kind": "tile", "point": vec(y)})
            m.finish(1 if current["tiles"][index] else 0)
            return
        if address == hit_stub:
            index = len(ray_queries)
            if x != scene or index >= len(current["rays"]):
                raise RuntimeError("Unexpected static Scene lower call")
            hit_info = m.q(rsp + 0x28)
            if m.si(hit_info) != 1:
                raise RuntimeError("Original support controller did not select Scene mode1")
            answer = current["rays"][index]
            query = {"start": vec(y), "end": vec(z), "mode": m.si(hit_info),
                     "hit": answer is not None}
            ray_queries.append(query)
            events.append({"kind": "ray", **query})
            if answer is not None:
                put(w, answer["position"])
                # Verified support assembly: CHitInfo baseRSP+70, normal at
                # RBP-34 (RSP+cc) => the exact +5c numeric normal lower field.
                put(hit_info + 0x5C, answer["normal"])
            m.finish(1 if answer is not None else 0)
            return
        if address == FREE:
            if x != 0:
                raise RuntimeError("Unexpected nonempty captured CHitInfo ownership")
            m.finish()
            return
        if not any(low <= address < high for low, high in ranges):
            raise RuntimeError(f"Unmapped original support lower dependency {address:x}")

    handle = u.hook_add(UC_HOOK_CODE, hook)
    rows = []
    try:
        for current_case in authored_cases():
            current.clear()
            current.update(current_case)
            events.clear()
            tile_queries.clear()
            ray_queries.clear()
            constructor_calls.clear()
            u.mem_write(m.heap, bytes(0x100000))
            u.mem_write(m.stack, bytes([0xA5]) * 0x20000)
            m.wq(area + 0x248, scene if current["scene"] else 0)
            m.wq(scene, vtable)
            m.wq(vtable + 0x58, hit_stub)
            put(point, current["point"])
            u.mem_write(normal, bytes([0xA5]) * 12)
            rsp = m.stack + 0x1FE08
            m.wq(rsp, m.stop)
            m.wq(rsp + 0x28, normal if current["normal_output"] else 0)
            u.reg_write(UC_X86_REG_RSP, rsp)
            for register, value in zip([UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9],
                                       [actor, area if current["area"] else 0, point, 0]):
                u.reg_write(register, value)
            # Windows x64 argument4 is the original float in XMM3.
            u.reg_write(UC_X86_REG_XMM3, int.from_bytes(struct.pack("<f", current["previous"]), "little"))
            u.emu_start(ENTRY, m.stop, count=100000)
            if u.reg_read(UC_X86_REG_RIP) != m.stop:
                raise RuntimeError("Original controller did not return")
            rows.append({"case": dict(current), "events": list(events),
                         "tile_queries": list(tile_queries), "ray_queries": list(ray_queries),
                         "constructor": list(constructor_calls), "position": vec(point),
                         "position_hex": bytes(u.mem_read(point, 12)).hex(),
                         "normal": vec(normal) if current["normal_output"] else None,
                         "normal_hex": bytes(u.mem_read(normal, 12)).hex() if current["normal_output"] else None})
    finally:
        u.hook_del(handle)
    output.parent.mkdir(parents=True, exist_ok=True)
    document = {"version": 1, "target": TARGET, "entry": hex(ENTRY), "scope": __doc__,
                "python": {"executable": sys.executable, "version": sys.version},
                "evidence": {"file": str(evidence_path), "sha256": hashlib.sha256(evidence_bytes).hexdigest(),
                             "evidence_id": row["evidence_id"]},
                "constructor": "Captured empty CHitInfo, mode write still original; only null free lower",
                "scene": "Authored ordered GetTile/HitCheck lower answers; no native BSP membership claim",
                "cases": rows}
    # Exclusive creation; an existing successful or failed receipt is never overwritten.
    with output.open("x", encoding="utf-8") as stream:
        json.dump(document, stream, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps({"success": True, "cases": len(rows), "output": str(output),
                      "scope": "Original support controller instructions only; captured lower scene answers"}))


if __name__ == "__main__":
    main()
