"""Record unclassified field58 accesses inside exact manager-argument callees."""
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
source = ROOT / 'godot-client/reports/native-guiman-owner-callflow-v1.json'
calls = json.loads(source.read_text(encoding='utf-8-sig'))
raw = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert calls['success'] and digest == calls['binarySha256'] == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
spans = {base+r.struct.BeginAddress: base+r.struct.EndAddress for r in pe.DIRECTORY_ENTRY_EXCEPTION}
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True
rows = []
for callee in sorted({edge['callee'] for edge in calls['exactManagerArgumentCalls']}):
    start = int(callee, 16)
    if start not in spans:
        continue
    end = spans[start]
    body = pe.get_data(start-base, end-start)
    instructions = list(cs.disasm(body, start))
    found = []
    for ins in instructions:
        for operand in ins.operands:
            if operand.type == capstone.x86.X86_OP_MEM and operand.mem.disp == 0x58:
                found.append({'address': hex(ins.address), 'instruction': f'{ins.mnemonic} {ins.op_str}',
                              'read': bool(operand.access & capstone.CS_AC_READ),
                              'write': bool(operand.access & capstone.CS_AC_WRITE),
                              'baseRegister': ins.reg_name(operand.mem.base), 'bytes': operand.size})
    if found:
        rows.append({'start': callee, 'endExclusive': hex(end), 'bodySha256': hashlib.sha256(body).hexdigest(),
                     'exactArgumentCallers': [edge for edge in calls['exactManagerArgumentCalls'] if edge['callee'] == callee],
                     'unclassifiedField58Accesses': found,
                     'assembly': [f'{ins.address:#x}: {ins.mnemonic} {ins.op_str}' for ins in instructions],
                     'completeLinearDecode': bool(instructions) and instructions[-1].address+instructions[-1].size == end})
result = {'success': True, 'binarySha256': digest,
          'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'callflowSha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'procedures': rows,
          'scope': 'Static candidates only: field58 operand bases are not proven GuiMan aliases. Stack/member/unrelated operands may be present. Exact argument callers and full unwind bodies support manual producer review, not modal/NUI classification or absence proof.',
          'servers': 0, 'gpu': False, 'nativeBuilds': 0}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'success': True, 'candidates': [{'start': row['start'], 'accesses': row['unclassifiedField58Accesses']} for row in rows], 'report': str(output)}))
