"""Unchanged GuiMan Render-scope dispatch order with explicit draw/helper stubs."""
from pathlib import Path
import argparse, hashlib, json, struct, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backups/research-python'))
import capstone, pefile, unicorn
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import *
p = argparse.ArgumentParser(); p.add_argument('--report', required=True)
output = Path(p.parse_args().report).resolve()
if output.exists(): raise SystemExit('Refusing to overwrite original observations')
raw = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=raw); base = pe.OPTIONAL_HEADER.ImageBase
START, END, CONTEXT = 0x1401f75c0, 0x1401f76ee, 0x1414299a0
RECT, BEGIN, FINISH, WINDOWS, BACKEND = 0x140a89370, 0x140a75c60, 0x140a81d10, 0x1406c39e0, 0x140a71760
body = pe.get_data(START-base, END-START)
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64); cs.detail = True
instructions = list(cs.disasm(body, START)); assert instructions[-1].address+instructions[-1].size == END
pages = {START & ~4095, CONTEXT & ~4095, *[n & ~4095 for n in [RECT, BEGIN, FINISH, WINDOWS, BACKEND]]}
profile_fields = []
for i in instructions:
    for op in i.operands:
        if op.type == capstone.x86.X86_OP_MEM and op.mem.base == capstone.x86.X86_REG_RIP:
            address = i.address+i.size+op.mem.disp; pages.add(address & ~4095)
            if i.mnemonic == 'cmp': profile_fields.append((address, op.size))
u = Uc(UC_ARCH_X86, UC_MODE_64)
for page in sorted(pages):
    u.mem_map(page, 4096)
    try: u.mem_write(page, pe.get_data(page-base, 4096))
    except pefile.PEFormatError: pass
u.mem_write(START, body)
for helper in [RECT, BEGIN, FINISH, WINDOWS, BACKEND]: u.mem_write(helper, b'\xc3')
heap, stack, stub = 0x200000000, 0x300000000, 0x400000000
u.mem_map(heap, 0x10000); u.mem_map(stack, 0x10000); u.mem_map(stub, 4096); u.mem_write(stub, b'\xc3')
manager, array, context = heap, heap+0x1000, heap+0x8000
def wq(at, value): u.mem_write(at, struct.pack('<Q', value))
def wi(at, value): u.mem_write(at, struct.pack('<I', value & 0xffffffff))
def q(at): return int.from_bytes(u.mem_read(at, 8), 'little')
def returned(value=0):
    sp = u.reg_read(UC_X86_REG_RSP); u.reg_write(UC_X86_REG_RAX, value)
    u.reg_write(UC_X86_REG_RIP, q(sp)); u.reg_write(UC_X86_REG_RSP, sp+8)
events = []; trace = []; receivers = {}; done = False
def hook(_u, address, size, _data):
    global done
    if address == END: done = True; u.emu_stop(); return
    if address == stub:
        receiver = u.reg_read(UC_X86_REG_RCX); assert receiver in receivers
        events.append({'kind': 'collection_virtual10', 'id': receivers[receiver]}); returned()
    elif address == RECT:
        sp = u.reg_read(UC_X86_REG_RSP)
        assert u.reg_read(UC_X86_REG_RDX) == 0 and u.reg_read(UC_X86_REG_R8) == 0 and u.reg_read(UC_X86_REG_R9) == 10
        assert int.from_bytes(u.mem_read(sp+0x28, 4), 'little') == 10
        out = u.reg_read(UC_X86_REG_RCX); u.mem_write(out, struct.pack('<ffff', 0, 0, 10, 10))
        events.append({'kind': 'captured_rect_helper'}); returned(out)
    elif address == BEGIN:
        assert u.reg_read(UC_X86_REG_RCX) == context and u.reg_read(UC_X86_REG_R9) == 0x4100
        assert pe.get_data(u.reg_read(UC_X86_REG_RDX)-base, 80).split(b'\0', 1)[0] == b'nuklear_bug_workaround_placeholder'
        events.append({'kind': 'captured_placeholder_begin'}); returned(1)
    elif address == FINISH:
        assert u.reg_read(UC_X86_REG_RCX) == context
        events.append({'kind': 'captured_placeholder_end'}); returned()
    elif address == WINDOWS: events.append({'kind': 'captured_call_6c39e0'}); returned()
    elif address == BACKEND:
        assert u.reg_read(UC_X86_REG_XMM0) == u.reg_read(UC_X86_REG_XMM6)
        events.append({'kind': 'captured_call_a71760'}); returned()
    elif not START <= address < END: raise RuntimeError('Uncaptured helper '+hex(address))
    trace.append(hex(address))
u.hook_add(UC_HOOK_CODE, hook)
rows = []; failure = None; case = {}
try:
    for order in [[], [11], [11, 22], [22, 11], [31, 11, 22]]:
        for delta in [0.0, 0.016, 0.25]:
            case = {'collectionOrder': list(order), 'delta': delta}; events.clear(); trace.clear(); receivers.clear(); done = False
            u.mem_write(manager, bytes(0x100)); wi(manager+0x20, len(order)); wq(manager+0x18, array); wq(CONTEXT, context)
            for address, size in profile_fields: u.mem_write(address, bytes(size))
            for index, identity in enumerate(order):
                row, receiver, table = heap+0x2000+index*0x100, heap+0x3000+index*0x100, heap+0x4000+index*0x100
                wq(array+index*8, row); wq(row+8, receiver); wq(receiver, table); wq(table+0x10, stub); receivers[receiver] = identity
            for reg in [UC_X86_REG_RAX, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_RSI, UC_X86_REG_RDI, UC_X86_REG_R12, UC_X86_REG_R14]: u.reg_write(reg, 0)
            u.reg_write(UC_X86_REG_RBX, manager); u.reg_write(UC_X86_REG_RBP, stack+0x8000); u.reg_write(UC_X86_REG_RSP, stack+0x7008)
            u.reg_write(UC_X86_REG_XMM6, int.from_bytes(struct.pack('<f', delta), 'little'))
            u.emu_start(START, END+1, count=2048); assert done, 'Finite2048-instruction bound exceeded'
            expected = [{'kind': 'collection_virtual10', 'id': identity} for identity in order] + [{'kind': k} for k in ['captured_rect_helper', 'captured_placeholder_begin', 'captured_placeholder_end', 'captured_call_6c39e0', 'captured_call_a71760']]
            assert events == expected, (case, events)
            rows.append({'case': dict(case), 'events': list(events)})
except Exception as error: failure = {'type': type(error).__name__, 'message': str(error), 'case': dict(case), 'trace': list(trace)}
result = {'success': failure is None, 'checks': len(rows), 'binarySha256': digest,
          'sourceSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'rows': rows, 'failure': failure,
          'prefix': {'start': hex(START), 'endExclusive': hex(END), 'sha256': hashlib.sha256(body).hexdigest(), 'assembly': [f'{i.address:#x}: {i.mnemonic} {i.op_str}' for i in instructions]},
          'boundary': 'Only unchanged GuiMan UpdateAndRender Render-scope prefix; authored collection+18/count20/entry+8/vtable+10 and delta, profiling disabled, explicit collection/rect/placeholder/NUI helpers captured. Proves dispatch order only, not nested helper/GPU effects, exact collection types/formation, all render passes, classic/NUI membership, pixel or input priority.',
          'runtime': {'unicorn': unicorn.__version__, 'capstone': capstone.__version__}, 'servers': 0, 'gpu': False, 'nativeBuilds': 0}
output.parent.mkdir(parents=True, exist_ok=True); output.write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({'success': result['success'], 'checks': len(rows), 'failure': failure, 'report': str(output)}))
raise SystemExit(0 if result['success'] else 1)
