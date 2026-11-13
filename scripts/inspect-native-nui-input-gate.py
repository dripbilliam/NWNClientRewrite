"""Finite unchanged original input-gate prefix; explicitly captured helper returns.

Proves the fifth dispatch argument, not NUI modal membership or pixel/input order.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backups/research-python'))
import capstone
import pefile
import unicorn
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE, UC_HOOK_MEM_READ
from unicorn.x86_const import *

p = argparse.ArgumentParser()
p.add_argument('--report', required=True)
output = Path(p.parse_args().report).resolve()
if output.exists():
    raise SystemExit('Refusing to overwrite original observations')
raw = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
START, END = 0x1406f15ee, 0x1406f1653
MANAGER, CONTEXT = 0x1412df8b0, 0x1414299a0
PREPARE, QUERY = 0x140a70b10, 0x140a86250
RMNU = 0x524d6e75
body = pe.get_data(START - base, END - START)
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True
instructions = list(cs.disasm(body, START))
assert instructions[-1].address + instructions[-1].size == END
cmp_ = next(i for i in instructions if i.address == 0x1406f160e)
assert cmp_.mnemonic == 'cmp' and cmp_.operands[0].mem.base == capstone.x86.X86_REG_RIP
OVERRIDE = cmp_.address + cmp_.size + cmp_.operands[0].mem.disp
u = Uc(UC_ARCH_X86, UC_MODE_64)
for page in sorted({START & ~4095, MANAGER & ~4095, CONTEXT & ~4095, OVERRIDE & ~4095,
                    PREPARE & ~4095, QUERY & ~4095}):
    u.mem_map(page, 4096)
u.mem_write(START, body)
u.mem_write(PREPARE, b'\xc3')
u.mem_write(QUERY, b'\xc3')
heap, stack, stub = 0x200000000, 0x300000000, 0x400000000
u.mem_map(heap, 0x40000)
u.mem_map(stack, 0x10000)
u.mem_map(stub, 0x1000)
u.mem_write(stub, b'\xc3')
manager, captured, vtable, context, window, modal_list = [heap + n for n in [0, 0x1000, 0x2000, 0x10000, 0x20000, 0x30000]]


def wq(at, value):
    u.mem_write(at, struct.pack('<Q', value))


def wi(at, value):
    u.mem_write(at, struct.pack('<I', value & 0xffffffff))


events = []
reads = []
trace = []
case = {}
finished = False


def returned(value=0):
    sp = u.reg_read(UC_X86_REG_RSP)
    u.reg_write(UC_X86_REG_RAX, value & 0xffffffff)
    u.reg_write(UC_X86_REG_RIP, int.from_bytes(u.mem_read(sp, 8), 'little'))
    u.reg_write(UC_X86_REG_RSP, sp + 8)


def code_hook(_u, address, size, _data):
    global finished
    if address == END:
        finished = True
        u.emu_stop()
    elif address == stub:
        assert u.reg_read(UC_X86_REG_RCX) == captured
        events.append('captured_field58_type_getter')
        returned(case['typeValue'])
    elif address == PREPARE:
        events.append('captured_prepare_a70b10')
        returned()
    elif address == QUERY:
        assert u.reg_read(UC_X86_REG_RCX) == context
        events.append('captured_query_a86250')
        returned(case['queryResult'])
    elif not START <= address < END:
        raise RuntimeError('Uncaptured code boundary ' + hex(address))
    trace.append(hex(address))


def read_hook(_u, _access, address, size, _value, _data):
    if address in [manager + 0x88, manager + 0x90, window + 0x18c]:
        reads.append(address)


u.hook_add(UC_HOOK_CODE, code_hook)
u.hook_add(UC_HOOK_MEM_READ, read_hook)
rows = []
failure = None
try:
    for kind in ['null', 'GObj', 'other', 'Rmnu']:
        for override in [0, 1, -1]:
            for query in [0, 1, -1]:
                for window_state in ['null', 'zero', 'nonzero']:
                    for modal_top in ['other', 'Rmnu']:
                        case = {'managerField58Type': kind, 'typeValue': RMNU if kind == 'Rmnu' else 0x474f626a if kind == 'GObj' else 0x4f746872,
                                'override': override, 'queryResult': query, 'context6730Window': window_state, 'unrelatedModalTop': modal_top}
                        events.clear(); reads.clear(); trace.clear(); finished = False
                        u.mem_write(manager, bytes(0x100)); u.mem_write(context, bytes(0x7000)); u.mem_write(window, bytes(0x200))
                        wq(MANAGER, manager); wq(CONTEXT, context); wi(OVERRIDE, override)
                        wq(manager + 0x58, 0 if kind == 'null' else captured)
                        wq(captured, vtable); wq(vtable + 0x20, stub)
                        wq(manager + 0x88, modal_list); wi(manager + 0x90, 1); wi(modal_list, RMNU if modal_top == 'Rmnu' else 0x4f746872)
                        wq(context + 0x6730, 0 if window_state == 'null' else window); wi(window + 0x18c, int(window_state == 'nonzero'))
                        for reg in [UC_X86_REG_RAX, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R12, UC_X86_REG_R15]:
                            u.reg_write(reg, 0)
                        u.reg_write(UC_X86_REG_RSP, stack + 0xff08)
                        u.emu_start(START, END + 1, count=256)
                        assert finished, 'Finite256-instruction bound exceeded'
                        value = u.reg_read(UC_X86_REG_R15D)
                        queried = kind != 'Rmnu' and override == 0
                        expected = int(queried and (query != 0 or window_state == 'nonzero'))
                        expected_events = ([] if kind == 'null' else ['captured_field58_type_getter']) + (['captured_prepare_a70b10', 'captured_query_a86250'] if queried else [])
                        assert value == expected and events == expected_events, (case, value, events)
                        assert manager + 0x88 not in reads and manager + 0x90 not in reads
                        assert reads.count(window + 0x18c) == int(queried and query == 0 and window_state != 'null')
                        rows.append({'case': dict(case), 'parameter5Value': value, 'events': list(events), 'modalListReads': 0})
except Exception as error:
    failure = {'type': type(error).__name__, 'message': str(error), 'case': dict(case), 'trace': list(trace)}
result = {'success': failure is None, 'checks': len(rows), 'binarySha256': digest,
          'sourceSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'prefix': {'start': hex(START), 'endExclusive': hex(END), 'sha256': hashlib.sha256(body).hexdigest(),
                     'assembly': [f'{i.address:#x}: {i.mnemonic} {i.op_str}' for i in instructions]},
          'overrideAddress': hex(OVERRIDE), 'rows': rows, 'failure': failure,
          'boundary': 'Unchanged6f15ee..6f1653 prefix only; authored original-offset pointer/type/flag memory and explicit virtual/prepare/query stubs; R12D=0. Proves parameter5 and helper/read gating, not complete6f14e0/6ed720, helper implementations, field names, NUI membership, render ordering, native interaction or server/UI acceptance.',
          'runtime': {'unicorn': unicorn.__version__, 'capstone': capstone.__version__}, 'gpu': False, 'servers': 0, 'nativeBuilds': 0}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'success': result['success'], 'checks': len(rows), 'failure': failure, 'report': str(output)}))
raise SystemExit(0 if result['success'] else 1)
