"""Execute unchanged CGuiLabel::LoadGffData's native bounds flag branch.
The model is already attached. GFF FLOAT reads, the existing string-data getter
and text import are explicit captured boundaries. No renderer/process/server.
"""
from pathlib import Path
import hashlib
import importlib.util
import itertools
import json
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backups/research-python"))
spec = importlib.util.spec_from_file_location("original_image", ROOT / "scripts/inspect-native-intratile-coordinator.py")
image = importlib.util.module_from_spec(spec)
spec.loader.exec_module(image)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RSP, UC_X86_REG_RIP, UC_X86_REG_XMM0

machine = image.u
machine.hook_del(image.hook_handle)
label, string, table, data, resource, tag = [image.heap + value for value in [0x20000, 0x21000, 0x22000, 0x23000, 0x24000, 0x25000]]
stub = image.stop + 0x200
image.wq(table + 0xb8, stub)
image.wq(string, table)
calls, dimensions = [], []


def ascii_at(address):
    result = bytearray()
    while machine.mem_read(address + len(result), 1) != b"\0":
        assert len(result) < 128
        result.extend(machine.mem_read(address + len(result), 1))
    return result.decode("ascii")


def hook(_machine, address, _size, _context):
    if address == image.stop:
        machine.emu_stop()
        return
    x, y, z, w = [machine.reg_read(reg) for reg in [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9]]
    if address == 0x1401a1650:
        field = ascii_at(z)
        assert x == resource and y == tag + 0x18 and field in ["Obj_Label_Width", "Obj_Label_Height"]
        value = dimensions[0 if field.endswith("Width") else 1]
        calls.append({"kind": "GFF-FLOAT", "field": field, "value": value})
        image.wi(w, 1)
        machine.reg_write(UC_X86_REG_XMM0, int.from_bytes(struct.pack("<f", value), "little"))
        image.finish()
    elif address == stub:
        assert x == string
        image.finish(data)
    elif address == 0x1401fe680:
        assert x == label + 0x80 and y == resource and z == tag
        calls.append({"kind": "text-import-boundary", "bounds": [image.rf(data + 0xc), image.rf(data + 0x10)]})
        image.finish()
    elif not 0x1401fe260 <= address <= 0x1401fe418:
        raise AssertionError("Uncaptured original dependency " + hex(address))


machine.hook_add(UC_HOOK_CODE, hook)


def run(flags, initial, supplied):
    global calls, dimensions
    calls, dimensions = [], supplied
    image.wi(label + 8, flags)
    image.wq(label + 0x10, 1)
    image.wq(label + 0x90, string)
    image.wf(data + 0xc, initial[0])
    image.wf(data + 0x10, initial[1])
    stack = image.stack + 0x1fe08
    machine.mem_write(stack - 0x200, bytes(0x300))
    image.wq(stack, image.stop)
    machine.reg_write(UC_X86_REG_RSP, stack)
    for register, value in zip([UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8], [label, resource, tag]):
        machine.reg_write(register, value)
    machine.emu_start(0x1401fe260, image.stop, count=5000)
    assert machine.reg_read(UC_X86_REG_RIP) == image.stop
    bounds = [image.rf(data + 0xc), image.rf(data + 0x10)]
    expected = supplied if flags & 4 else initial
    assert all(struct.pack("<f", actual) == struct.pack("<f", wanted) for actual, wanted in zip(bounds, expected))
    assert [call["field"] for call in calls if call["kind"] == "GFF-FLOAT"] == (["Obj_Label_Width", "Obj_Label_Height"] if flags & 4 else [])
    assert calls[-1]["kind"] == "text-import-boundary"
    return {"flags": flags, "initial": initial, "supplied": supplied, "bounds": bounds, "calls": calls}


if __name__ == "__main__":
    output = ROOT / "godot-client/reports/native-label-bounds-original-v1.json"
    assert not output.exists(), "Preserve previous evidence"
    rows = [run(flags, initial, supplied) for flags, initial, supplied in itertools.product(
        [0, 1, 2, 3, 4, 5, 8, 12, 0x80000000, 0xffffffff],
        [[0, 0], [7, 9]], [[.83, .17], [7.4, .3]])]
    result = {"binarySha256": image.digest, "scriptSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "scope": __doc__, "cases": len(rows), "rows": rows,
              "limits": ["Text import/model attachment/string getter are captured boundaries; no original raster or full GUI equivalence.",
                         "Zero initial native bounds are authored here; constructor and original source owner flags are separate static evidence."]}
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(output), "cases": len(rows), "success": True}))
