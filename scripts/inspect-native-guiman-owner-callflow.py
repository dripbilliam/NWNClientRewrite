"""Bounded static direct-call extension of exact GuiMan pointer witnesses."""
from pathlib import Path
from collections import deque
import argparse
import hashlib
import json
import time
import capstone
import pefile

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--report', required=True)
output = Path(p.parse_args().report).resolve()
if output.exists():
    raise SystemExit('Refusing to overwrite original observations')
started = time.monotonic()
raw = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
spans = {base+r.struct.BeginAddress: base+r.struct.EndAddress for r in pe.DIRECTORY_ENTRY_EXCEPTION}
index_path = ROOT / 'godot-client/reports/native-ui-dispatch-bridges-v1.json'
index = json.loads(index_path.read_text(encoding='utf-8-sig'))
assert index['success'] and index['binarySha256'] == digest
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True
global_address = 0x1412df8b0
volatile = {'rax', 'rcx', 'rdx', 'r8', 'r9', 'r10', 'r11'}
families = {}
for full, parts in {'rax': ['eax', 'ax', 'al', 'ah'], 'rbx': ['ebx', 'bx', 'bl', 'bh'],
                    'rcx': ['ecx', 'cx', 'cl', 'ch'], 'rdx': ['edx', 'dx', 'dl', 'dh'],
                    'rsi': ['esi', 'si', 'sil'], 'rdi': ['edi', 'di', 'dil'],
                    'rbp': ['ebp', 'bp', 'bpl'], 'rsp': ['esp', 'sp', 'spl']}.items():
    for part in parts:
        families[part] = full
for number in range(8, 16):
    for suffix in ('d', 'w', 'b'):
        families[f'r{number}{suffix}'] = f'r{number}'
queue = deque((int(row['start'], 16), None) for row in index['allVerifiedReferences'])
seen = set()
parameter_paths = {}
witnesses = {}
edges = {}
unowned = set()
bodies = {}
failure = None
try:
    while queue:
        if len(seen) >= 1024 or time.monotonic()-started > 30:
            raise RuntimeError('Finite1024-procedure/30-second bound exceeded')
        start, parameter_origin = queue.popleft()
        mode = (start, parameter_origin is not None)
        if mode in seen:
            continue
        seen.add(mode)
        assert start in spans
        end = spans[start]
        body = pe.get_data(start-base, end-start)
        instructions = list(cs.disasm(body, start))
        bodies[hex(start)] = {'endExclusive': hex(end), 'bodySha256': hashlib.sha256(body).hexdigest(),
                              'completeLinearDecode': bool(instructions) and instructions[-1].address+instructions[-1].size == end}
        joins = {ins.operands[0].imm for ins in instructions if ins.group(capstone.CS_GRP_JUMP)
                 and ins.operands and ins.operands[0].type == capstone.x86.X86_OP_IMM}
        aliases = {} if parameter_origin is None else {'rcx': parameter_origin}
        for ins in instructions:
            if ins.address in joins:
                aliases.clear()
            before = dict(aliases)
            for op in ins.operands:
                if op.type == capstone.x86.X86_OP_MEM and op.mem.index == 0:
                    origin = before.get(ins.reg_name(op.mem.base))
                    if origin is not None and op.mem.disp in (0x58, 0x88, 0x90):
                        row = {'procedure': hex(start), 'address': hex(ins.address),
                               'instruction': f'{ins.mnemonic} {ins.op_str}', 'fieldOffset': hex(op.mem.disp),
                               'bytes': op.size, 'read': bool(op.access & capstone.CS_AC_READ),
                               'write': bool(op.access & capstone.CS_AC_WRITE), 'origin': origin}
                        witnesses.setdefault((ins.address, op.mem.disp), row)
            if ins.group(capstone.CS_GRP_CALL) and ins.operands and ins.operands[0].type == capstone.x86.X86_OP_IMM and 'rcx' in before:
                target = ins.operands[0].imm
                edge = {'caller': hex(start), 'at': hex(ins.address), 'callee': hex(target), 'origin': before['rcx']}
                edges.setdefault(ins.address, edge)
                if target in spans and target not in parameter_paths:
                    origin = {'passedBy': hex(ins.address), 'caller': hex(start), 'parent': before['rcx']}
                    parameter_paths[target] = origin
                    queue.append((target, origin))
                elif target not in spans:
                    unowned.add(target)
            for register in ins.regs_access()[1]:
                name = ins.reg_name(register)
                aliases.pop(families.get(name, name), None)
            operands = ins.operands
            if ins.mnemonic == 'mov' and len(operands) == 2 and operands[0].type == capstone.x86.X86_OP_REG and operands[0].size == 8:
                destination, source = operands
                if source.type == capstone.x86.X86_OP_MEM and source.mem.base == capstone.x86.X86_REG_RIP and source.mem.index == 0 and ins.address+ins.size+source.mem.disp == global_address:
                    aliases[ins.reg_name(destination.reg)] = {'exactGlobalLoad': hex(ins.address)}
                elif source.type == capstone.x86.X86_OP_REG and source.size == 8 and ins.reg_name(source.reg) in before:
                    aliases[ins.reg_name(destination.reg)] = before[ins.reg_name(source.reg)]
            if ins.group(capstone.CS_GRP_CALL):
                for register in volatile:
                    aliases.pop(register, None)
            elif ins.group(capstone.CS_GRP_JUMP) or ins.group(capstone.CS_GRP_RET):
                aliases.clear()
except Exception as error:
    failure = {'type': type(error).__name__, 'message': str(error)}
rows = list(witnesses.values())
result = {'success': failure is None, 'failure': failure, 'binarySha256': digest,
          'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'indexSha256': hashlib.sha256(index_path.read_bytes()).hexdigest(),
          'elapsedSeconds': time.monotonic()-started, 'procedureModes': len(seen),
          'bodies': bodies, 'exactManagerArgumentCalls': list(edges.values()),
          'unownedDirectCallees': [hex(x) for x in sorted(unowned)], 'witnesses': rows,
          'limits': ['Static local argument witnesses only, not executed runtime paths or whole-program alias analysis.',
                     'Only exact global loads/register moves and direct calls passing the exact pointer inRCX are followed. Joins/jumps discard knowledge and calls discard volatile registers; arguments/spills/returns/indirection remain incomplete.',
                     'PE unwind fragments and linear decoding may omit logical-function paths. Absence is not established.',
                     'Offsets are not semantic names and these witnesses do not establish classic/NUI membership or input/render priority.'],
          'servers': 0, 'gpu': False, 'nativeBuilds': 0}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'success': result['success'], 'failure': failure, 'procedureModes': len(seen),
                  'witnesses': len(rows), 'field58Writes': [row for row in rows if row['fieldOffset'] == '0x58' and row['write']],
                  'report': str(output)}))
raise SystemExit(0 if result['success'] else 1)
