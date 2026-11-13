"""Conservative local register witnesses for GuiMan field access producers.

This is a finite static subset audit, not whole-program alias analysis. Register
knowledge is discarded at control-flow joins and volatile calls. A witness only
follows an exact global load and register moves in one straight-line segment.
"""
from pathlib import Path
import argparse
import hashlib
import json
import capstone
import pefile

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--report', required=True)
output = Path(p.parse_args().report).resolve()
if output.exists():
    raise SystemExit('Refusing to overwrite original observations')
binary = ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
raw = binary.read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
index_path = ROOT / 'godot-client/reports/native-ui-dispatch-bridges-v1.json'
index = json.loads(index_path.read_text(encoding='utf-8-sig'))
assert index['binarySha256'] == digest and index['success']
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
manager = 0x1412df8b0
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True
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
rows = []
for procedure in index['allVerifiedReferences']:
    start, end = int(procedure['start'], 16), int(procedure['endExclusive'], 16)
    body = pe.get_data(start-base, end-start)
    instructions = list(cs.disasm(body, start))
    joins = set()
    for ins in instructions:
        if ins.group(capstone.CS_GRP_JUMP) and ins.operands and ins.operands[0].type == capstone.x86.X86_OP_IMM:
            joins.add(ins.operands[0].imm)
    aliases = {}
    for ins in instructions:
        if ins.address in joins:
            aliases.clear()
        operands = ins.operands
        before = dict(aliases)
        for op in operands:
            if op.type != capstone.x86.X86_OP_MEM:
                continue
            mem = op.mem
            alias = before.get(ins.reg_name(mem.base))
            if alias is not None and mem.index == 0 and mem.disp in (0x58, 0x88, 0x90):
                rows.append({'procedure': procedure['start'], 'address': hex(ins.address),
                             'instruction': f'{ins.mnemonic} {ins.op_str}',
                             'fieldOffset': hex(mem.disp), 'bytes': op.size,
                             'read': bool(op.access & capstone.CS_AC_READ),
                             'write': bool(op.access & capstone.CS_AC_WRITE),
                             'exactManagerLoad': hex(alias),
                             'bodySha256': hashlib.sha256(body).hexdigest()})
        for register in ins.regs_access()[1]:
            name = ins.reg_name(register)
            aliases.pop(families.get(name, name), None)
        if ins.mnemonic == 'mov' and len(operands) == 2 and operands[0].type == capstone.x86.X86_OP_REG and operands[0].size == 8:
            destination, source = operands
            if source.type == capstone.x86.X86_OP_MEM and source.mem.base == capstone.x86.X86_REG_RIP and source.mem.index == 0 and ins.address+ins.size+source.mem.disp == manager:
                aliases[ins.reg_name(destination.reg)] = ins.address
            elif source.type == capstone.x86.X86_OP_REG and source.size == 8 and ins.reg_name(source.reg) in before:
                aliases[ins.reg_name(destination.reg)] = before[ins.reg_name(source.reg)]
        if ins.group(capstone.CS_GRP_CALL):
            for register in volatile:
                aliases.pop(register, None)
        elif ins.group(capstone.CS_GRP_JUMP) or ins.group(capstone.CS_GRP_RET):
            aliases.clear()
result = {'success': True, 'binarySha256': digest,
          'sourceSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'indexSha256': hashlib.sha256(index_path.read_bytes()).hexdigest(),
          'proceduresExamined': len(index['allVerifiedReferences']), 'witnesses': rows,
          'limits': ['Only previously indexed direct-global-reference procedures are examined.',
                     'Exact global loads and 64-bit register moves are followed only within conservative straight-line segments; joins/jumps discard knowledge and calls discard volatile registers.',
                     'Unwind body linear decoding may be incomplete; indirect aliases, parameters, spills, nested helpers and other binaries are not covered.',
                     'Field access witnesses do not establish semantic names, classic modal membership, NUI membership, runtime consistency, render or input ordering.'],
          'servers': 0, 'gpu': False, 'nativeBuilds': 0}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'success': True, 'procedures': result['proceduresExamined'],
                  'witnesses': len(rows), 'field58Writes': [r for r in rows if r['fieldOffset'] == '0x58' and r['write']],
                  'report': str(output)}))
