"""Pinned-byte static proof of the temporary original GUI popup bypass.

No target execution or process/network/GPU activity. Reports the measured wrapper
span/switch, its direct caller and the saved primary major-message dispatch.
"""
from pathlib import Path
import argparse, hashlib, json
import pefile, capstone
from capstone.x86_const import X86_OP_MEM, X86_OP_IMM

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--report', required=True)
args = p.parse_args()
report = Path(args.report).resolve()
if report.exists(): raise SystemExit('Refusing to overwrite existing evidence')
image = (root.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(image).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=image)
base = pe.OPTIONAL_HEADER.ImageBase
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True
start, end = 0x1406f9c40, 0x1406f9da3
body = pe.get_data(start - base, end - start)
instructions = list(cs.disasm(body, start))
writes = [i for i in instructions if i.mnemonic == 'mov' and
          i.operands[0].type == X86_OP_MEM and i.operands[0].mem.disp == 0x540 and
          i.operands[1].type == X86_OP_IMM]
assert [i.operands[1].imm for i in writes].count(1) == 1
assert [i.operands[1].imm for i in writes].count(0) == 6
switch = [{'panel': n + 2, 'target': hex(base + int.from_bytes(pe.get_data(0x6f9da4 + n * 4, 4), 'little'))}
          for n in range(7)]
assert [row['target'] for row in switch] == [hex(a) for a in
        [0x1406f9c75, 0x1406f9d93, 0x1406f9cb4, 0x1406f9cf5,
         0x1406f9d1b, 0x1406f9d3d, 0x1406f9d5f]]
callers = []
for section in pe.sections:
    if not section.Characteristics & 0x20000000: continue
    raw, rva = section.get_data(), section.VirtualAddress
    for n in range(len(raw) - 4):
        if raw[n] != 0xe8: continue
        address = base + rva + n
        if address + 5 + int.from_bytes(raw[n + 1:n + 5], 'little', signed=True) == start:
            callers.append(address)
assert callers == [0x1407aa29c]
dispatch_path = root / 'backups/animations/rea-client-major-message-dispatch.json'
dispatch = json.loads(dispatch_path.read_text(encoding='utf-8-sig'))
dispatch = dispatch.get('structuredContent') or json.loads(dispatch['content'][0]['text'])
value = dispatch['raw_result']['value']
pseudocode = value['pseudocode']
assert 'case 0x24:' in pseudocode
fragment = pseudocode.split('case 0x24:', 1)[1].split('break;', 1)[0]
assert 'FUN_1407aa180(param_1,bVar2)' in fragment
receiver_start, receiver_end = 0x1407aa24e, 0x1407aa2ab
receiver = list(cs.disasm(pe.get_data(receiver_start - base, receiver_end - receiver_start), receiver_start))
assembly = lambda rows: [f'{i.address:#x}: {i.mnemonic} {i.op_str}' for i in rows]
result = {'success': True, 'kind': 'native-gui-forced-popup-static-v1', 'target': digest,
          'source': str(Path(__file__).relative_to(root)),
          'sourceSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'wrapper': {'start': hex(start), 'endExclusive': hex(end),
                      'rangeMeaning': 'Measured instruction span through final RET; switch table separately recorded',
                      'sha256': hashlib.sha256(body).hexdigest(), 'assembly': assembly(instructions)},
          'bypassWrites': assembly(writes), 'switch': switch,
          'directCalls': [hex(i) for i in callers],
          'majorDispatch': {'path': str(dispatch_path.relative_to(root)),
                            'sha256': hashlib.sha256(dispatch_path.read_bytes()).hexdigest(),
                            'evidenceId': dispatch['evidence_id'], 'major': 36, 'fragment': fragment},
          'receiver': {'procedure': '0x1407aa180', 'minor': 4,
                       'derivation': 'Minor-1,-1,-1 then compare1 selects original minor4; readINT32 then call6f9c40',
                       'assembly': assembly(receiver)},
          'findings': ['+540 is temporarily set around original forced-open controls and reset on all wrapper return paths',
                       'Panel2/4/5/6/7/8 force paths are distinct from ordinary toggles;3/out-of-range do nothing',
                       'An existing journal/player/book logical owner is not toggled closed by this force wrapper',
                       'The bypass does not erase or enable any disabled target membership'],
          'executedOriginal': False, 'serverOutcome': False, 'productionChanges': []}
report.parent.mkdir(parents=True, exist_ok=True)
report.write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
print(json.dumps({'success': True, 'report': str(report), 'sourceSha256': result['sourceSha256']}))
