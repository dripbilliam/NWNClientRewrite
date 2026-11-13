"""Bounded static search for exact classic GuiMan/Nuklear shared procedures.

No import into an analysis database, target execution, or modal classification.
RIP candidates are admitted only after decoding the exact PE unwind body.
"""
from pathlib import Path
import argparse
import bisect
import hashlib
import json
import struct
import time
import capstone
import pefile

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--report', required=True)
output = Path(p.parse_args().report).resolve()
if output.exists():
    raise SystemExit('Refusing to overwrite evidence')
started = time.monotonic()
deadline = started + 30
raw = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
text = next(s for s in pe.sections if s.Name.rstrip(b'\0') == b'.text')
code = text.get_data()
origin = base + text.VirtualAddress
spans = sorted((base + r.struct.BeginAddress, base + r.struct.EndAddress) for r in pe.DIRECTORY_ENTRY_EXCEPTION)
starts = [a for a, _ in spans]
globals_ = {0x1412df8b0: 'classic_gui_manager', 0x1414299a0: 'nuklear_context'}
candidates = {}
unowned = []
for modrm in [5, 13, 21, 29, 37, 45, 53, 61]:
    at = code.find(bytes([modrm]))
    count = 0
    while at >= 0:
        if at + 5 <= len(code):
            address = origin + at
            target = address + 5 + struct.unpack_from('<i', code, at + 1)[0]
            if target in globals_:
                index = bisect.bisect_right(starts, address) - 1
                if index >= 0 and address < spans[index][1]:
                    candidates.setdefault(spans[index], set()).add(target)
                else:
                    unowned.append({'modrmAddress': hex(address), 'target': hex(target)})
        at = code.find(bytes([modrm]), at + 1)
        count += 1
        if count % 4096 == 0 and time.monotonic() > deadline:
            raise SystemExit('Finite static scan exceeded its30-second budget; no conclusion published')
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True
rows = []
references = []
for (start, end), targets in sorted(candidates.items()):
    body = pe.get_data(start - base, end - start)
    instructions = list(cs.disasm(body, start))
    found = []
    calls = []
    for i in instructions:
        for op in i.operands:
            if op.type == capstone.x86.X86_OP_MEM and op.mem.base == capstone.x86.X86_REG_RIP:
                target = i.address + i.size + op.mem.disp
                if target in globals_:
                    found.append({'at': hex(i.address), 'target': hex(target), 'owner': globals_[target],
                                  'instruction': i.mnemonic + ' ' + i.op_str})
        if i.mnemonic in ['call', 'jmp'] and i.operands and i.operands[0].type == capstone.x86.X86_OP_IMM:
            calls.append({'at': hex(i.address), 'target': hex(i.operands[0].imm), 'kind': i.mnemonic})
    if found:
        references.append({'start': hex(start), 'endExclusive': hex(end), 'references': found})
    if len({r['target'] for r in found}) == 2:
        rows.append({'start': hex(start), 'endExclusive': hex(end), 'bodySha256': hashlib.sha256(body).hexdigest(),
                     'references': found, 'calls': calls,
                     'assembly': [f'{i.address:#x}: {i.mnemonic} {i.op_str}' for i in instructions],
                     'completeLinearDecode': bool(instructions) and instructions[-1].address + instructions[-1].size == end,
                     'boundary': 'Exact PE unwind range, not asserted complete logical function/cold fragments'})
    if time.monotonic() > deadline:
        raise SystemExit('Finite static decode exceeded its30-second budget; no conclusion published')
result = {'success': True, 'binarySha256': digest, 'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'globals': {hex(a): n for a, n in globals_.items()}, 'sharedProcedures': rows, 'allVerifiedReferences': references,
          'unownedCandidates': unowned, 'elapsedSeconds': time.monotonic() - started,
          'limits': ['Static RIP-relative direct-global references only; unknown indirect/dataflow remains',
                     'Shared reference does not establish render/input order or original modal membership',
                     'No absence proof from an empty shared set', 'No target execution, server, GPU or native build'],
          'servers': 0, 'gpu': False, 'nativeBuilds': 0}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'success': True, 'sharedProcedures': len(rows), 'referenceProcedures': len(references),
                  'elapsedSeconds': result['elapsedSeconds'], 'report': str(output)}))
