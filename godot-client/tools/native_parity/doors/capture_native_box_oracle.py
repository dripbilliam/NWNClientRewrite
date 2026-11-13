"""Execute only original BoxIntersect14022b7e0 in a read-only PE emulator.

No original game process, server, renderer, network or game file is changed.
The five-argument leaf body has no captured helper calls. This does not execute
the surrounding Scene/Part hit filters, transforms or gameplay action code.
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
ENTRY, END = 0x14022B7E0, 0x14022BC86


def cases():
    boxes = [([-1., -1., -1.], [1., 1., 1.]),
             ([0., -2., 0.], [0., 2., 3.]),
             ([-.08, -2.02, 0.], [0., .02, 2.97]),
             ([-0., -0., -0.], [0., 0., 0.])]
    points = [[0., 0., 0.], [-0., -0., -0.], [1., 1., 1.],
              [-1., -1., -1.], [-3., 0., 1.], [3., 0., 1.],
              [0., -3., 1.], [0., 3., 1.], [0., 0., -3.],
              [0., 0., 4.], [-3., -3., -3.], [3., 3., 4.],
              [1.e-8, -.0001, 2.9700000286102295]]
    for (low, high), start, end, alias in itertools.product(boxes, points, points, [False, True]):
        yield {"low": low, "high": high, "start": start, "end": end, "alias_end": alias}
    # Finite inputs whose intermediate f32 differences overflow must still be
    # observed; do not silently replace the original expression with a slab.
    for start, end in [([-3.e38, 0., 0.], [3.e38, 0., 0.]),
                       ([3.e38, 3.e38, 3.e38], [-3.e38, -3.e38, -3.e38])]:
        for alias in [False, True]:
            yield {"low": [-1., -1., -1.], "high": [1., 1., 1.], "start": start, "end": end, "alias_end": alias}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--arity",type=int,choices=[4,5],default=5)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[4]
    output = Path(args.output).resolve()
    allowed = (root / "godot-client/.cache/native-presentation-parity/root").resolve()
    if not output.is_relative_to(allowed) or output.exists():
        raise RuntimeError("Fresh root-owned output required")
    entry, end = (ENTRY, END) if args.arity==5 else (0x14022B400,0x14022B7DE)
    filename = "native-door-box-fivearg-v1.json" if args.arity==5 else "native-box-fourarg-v1.json"
    evidence_path = root / "godot-client/tools/native_parity/visibility/evidence" / filename
    evidence_bytes = evidence_path.read_bytes()
    document = json.loads(evidence_bytes)
    row = next(r for r in document["rows"] if r["key"] == "doorBoxIntersect5") if args.arity==5 else document
    if row["subject"]["digest"]["sha256"] != TARGET or int(row["procedure"]["address"], 16) != entry:
        raise RuntimeError("Original box identity differs")
    ranges = [(int(r["start"], 16), int(r["end"], 16) + 1) for r in row["procedure"]["body"]["ranges"]]
    if ranges != [(entry,end)]:
        raise RuntimeError("Original box body coverage differs")
    sys.path.insert(0, str(root / "scripts"))
    m = importlib.import_module("inspect-native-intratile-coordinator")
    if m.digest != TARGET:
        raise RuntimeError("Installed original PE differs")
    from unicorn import UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8,
                                  UC_X86_REG_R9, UC_X86_REG_RSP, UC_X86_REG_RAX,
                                  UC_X86_REG_RIP)
    u = m.u
    u.hook_del(m.hook_handle)
    pointers = [m.heap + n * 0x1000 for n in range(60, 65)]
    start_p, end_p, low_p, high_p, out_p = pointers
    sentinel = struct.pack("<3f", 73.125, -5.5, .25)

    def hook(_u, address, _size, _data):
        if address == m.stop:
            u.emu_stop()
        elif not entry <= address < end:
            raise RuntimeError(f"Unexpected original box dependency {address:x}")

    handle = u.hook_add(UC_HOOK_CODE, hook)
    rows = []
    try:
        for case in cases():
            for ptr, key in zip(pointers, ["start", "end", "low", "high"]):
                u.mem_write(ptr, struct.pack("<3f", *case[key]))
            u.mem_write(out_p, sentinel)
            selected_out = end_p if case["alias_end"] else out_p
            before = bytes(u.mem_read(selected_out, 12))
            sp = m.stack + 0x1FEF8
            u.mem_write(sp, struct.pack("<Q", m.stop))
            u.mem_write(sp + 0x28, struct.pack("<Q", selected_out))
            for register, value in [(UC_X86_REG_RCX, start_p), (UC_X86_REG_RDX, end_p),
                                    (UC_X86_REG_R8, low_p), (UC_X86_REG_R9, high_p),
                                    (UC_X86_REG_RSP, sp)]:
                u.reg_write(register, value)
            u.emu_start(entry, m.stop, count=100000)
            if u.reg_read(UC_X86_REG_RIP) != m.stop:
                raise RuntimeError("Original box did not return")
            face = struct.unpack("<i", struct.pack("<I", u.reg_read(UC_X86_REG_RAX) & 0xFFFFFFFF))[0]
            result = bytes(u.mem_read(selected_out, 12))
            if (face <= 0 or args.arity==4) and result != before:
                raise RuntimeError("Original non-hit unexpectedly wrote output")
            rows.append({"case": case, "face": face, "written": args.arity==5 and face > 0,
                         "output_hex": result.hex(), "input_output_hex": before.hex()})
    finally:
        u.hook_del(handle)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", encoding="utf-8") as stream:
        json.dump({"version": 2, "target": TARGET, "entry": hex(entry),"arity":args.arity,
                   "source_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                   "scope": __doc__, "python": sys.executable,
                   "evidence_sha256": hashlib.sha256(evidence_bytes).hexdigest(),
                   "evidence_id": row["evidence_id"], "cases": rows}, stream, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps({"success": True, "cases": len(rows), "output": str(output)}))


if __name__ == "__main__":
    main()
