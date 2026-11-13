"""Preserve exact original field58 setter/clearer and diagnostic naming."""
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
raw = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
candidate_path = ROOT / 'godot-client/reports/native-guiman-field58-candidates-v1.json'
candidates = json.loads(candidate_path.read_text(encoding='utf-8-sig'))
assert candidates['success'] and candidates['binarySha256'] == digest
procedures = [row for row in candidates['procedures'] if row['start'] in ['0x1401f45b0', '0x1401f4650', '0x1401f6440']]
assert len(procedures) == 3
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True
strings = []
for row in procedures:
    start, end = int(row['start'], 16), int(row['endExclusive'], 16)
    body = pe.get_data(start-base, end-start)
    assert hashlib.sha256(body).hexdigest() == row['bodySha256']
    if start != 0x1401f45b0:
        continue
    for ins in cs.disasm(body, start):
        for operand in ins.operands:
            if operand.type != capstone.x86.X86_OP_MEM or operand.mem.base != capstone.x86.X86_REG_RIP:
                continue
            at = ins.address+ins.size+operand.mem.disp
            data = pe.get_data(at-base, 192).split(b'\0', 1)[0]
            text = data.decode('ascii')
            strings.append({'instruction': hex(ins.address), 'address': hex(at), 'text': text,
                            'bytesSha256': hashlib.sha256(data+b'\0').hexdigest()})
assert any(row['text'] == 'pMouseFocusControl != m_pMouseFocusControl' for row in strings)
assert any(row['text'] == 'CaptureMouse' for row in strings)
assert any(row['text'] == 'libsource\\guiman\\guiman.cpp' for row in strings)
result = {'success': True, 'binarySha256': digest,
          'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'candidateSha256': hashlib.sha256(candidate_path.read_bytes()).hexdigest(),
          'field58DiagnosticName': 'm_pMouseFocusControl', 'setterDiagnosticName': 'CaptureMouse',
          'procedures': procedures, 'exactDiagnosticStrings': strings,
          'staticFacts': ['1f45b0 saves the managerRCX in nonvolatileRBX and incoming controlRDX inRDI, warns if incoming equals current+58, clears+58 before old control virtualC0, ORs+ac with incomingR8D, then assigns+58=incomingRDI.',
                          '1f4650 clears exact matching pointer fields including+58 during its wider owner retirement;1f6440 clears matching nonnull+58 before virtualC0 and resets+ac.',
                          'The earlier6f15ee prefix tests the type of the mouse-capture owner. Calling that pointer the current modal would conflate distinct original owners.'],
          'limits': ['Static exact original code and assertion names, not execution acceptance or a claim that virtualC0 has no nested effects.',
                     'No whole-program NUI/classic modal membership or causality conclusion; modal-array+88/count90 remains a separate authoritative contract.',
                     'No native pointer capture/render adaptation or global53/2 coverage change is introduced.'],
          'servers': 0, 'gpu': False, 'nativeBuilds': 0}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'success': True, 'field58': result['field58DiagnosticName'], 'procedures': len(procedures), 'report': str(output)}))
