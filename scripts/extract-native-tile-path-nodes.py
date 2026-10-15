"""Read-only emulation of ComputePathNodeInformation, never a game patch.

Only allocator calls are substituted; native graph selection, writes and
rotation instructions execute in Unicorn. The output is engine graph data,
not copied resources. Requires workspace-local Unicorn under backups.
"""
from pathlib import Path
import sys, hashlib, struct, json
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'backups/research-python'))
import pefile
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import *

binary = root.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
data = binary.read_bytes()
expected = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
assert hashlib.sha256(data).hexdigest() == expected
pe = pefile.PE(data=data)
base = pe.OPTIONAL_HEADER.ImageBase
uc = Uc(UC_ARCH_X86, UC_MODE_64)
uc.mem_map(base, (pe.OPTIONAL_HEADER.SizeOfImage + 4095) & ~4095)
uc.mem_write(base, pe.get_memory_mapped_image())
heap, stack, stop = 0x200000000, 0x300000000, 0x400000000
uc.mem_map(heap, 0x100000)
uc.mem_map(stack, 0x10000)
uc.mem_map(stop, 0x1000)
uc.mem_write(stop, b'\xf4')
allocate_at = heap + 0x1000
allocators = {0x140c10324, 0x140c10368}
allowed_functions = {0x1402ca770}  # ComputePathNodeRotation
def hook(uc, address, size, _):
    global allocate_at
    if address == stop:
        uc.emu_stop()
    elif address in allocators:
        length = uc.reg_read(UC_X86_REG_RCX)
        assert length < 0x10000
        pointer = allocate_at
        allocate_at += (max(length, 1) + 15) & ~15
        assert allocate_at < heap + 0x100000
        uc.mem_write(pointer, bytes(max(length, 1)))
        uc.reg_write(UC_X86_REG_RAX, pointer)
        rsp = uc.reg_read(UC_X86_REG_RSP)
        uc.reg_write(UC_X86_REG_RIP, struct.unpack('<Q', uc.mem_read(rsp, 8))[0])
        uc.reg_write(UC_X86_REG_RSP, rsp + 8)
    elif not (0x1402c84c0 <= address < 0x1402ca76c or
              0x1402ca770 <= address < 0x1402ca830):
        raise RuntimeError(f'Unmapped native dependency {address:x}')
uc.hook_add(UC_HOOK_CODE, hook)

def run(kind, rotation):
    global allocate_at
    allocate_at = heap + 0x1000
    uc.mem_write(heap, bytes(0x1000))
    rsp = stack + 0xff08
    uc.mem_write(rsp, bytes(0x80))
    uc.mem_write(rsp, struct.pack('<Q', stop))
    outs = [heap + i*8 for i in range(5)]
    for offset, pointer in zip([0x28, 0x30, 0x38, 0x40], outs[1:]):
        uc.mem_write(rsp+offset, struct.pack('<Q', pointer))
    for reg, value in [(UC_X86_REG_RSP, rsp), (UC_X86_REG_RCX, heap+0x100),
                       (UC_X86_REG_RDX, kind), (UC_X86_REG_R8, rotation), (UC_X86_REG_R9, outs[0])]:
        uc.reg_write(reg, value)
    uc.emu_start(0x1402c84c0, stop, count=100000)
    assert uc.reg_read(UC_X86_REG_RIP) == stop
    count, entrances = [struct.unpack('<i', uc.mem_read(p,4))[0] for p in outs[:2]]
    pointers = [struct.unpack('<Q', uc.mem_read(p,8))[0] for p in outs[2:]]
    def pairs(pointer, n):
        return [list(struct.unpack('<ff',uc.mem_read(pointer+i*8,8))) for i in range(n)]
    return {'centres':pairs(pointers[0], count),'entrances':pairs(pointers[1],entrances),
            'regions':[struct.unpack('<i',uc.mem_read(pointers[2]+i*4,4))[0] for i in range(entrances)]}

graphs = {str(kind):[run(kind,rotation) for rotation in range(4)] for kind in range(1,121)}
output = root / 'backups/animations/native-tile-path-node-observations.json'
output.write_text(json.dumps({'binarySha256':expected,'function':'1402c84c0','allocatorSubstitutions':sorted(hex(a) for a in allocators),
                            'limits':'Read-only emulated leaf owner; not a running-game hearing oracle.','graphs':graphs},indent=2))
print(json.dumps({'output':str(output),'types':len(graphs),'rotations':4}))
