"""Save bounded immutable activation, supersession and retirement witnesses.

This is static instruction evidence, not game execution or complete coverage of
computed calls. Previously accepted132/480 CPU results remain separate.
"""
from pathlib import Path
import argparse, hashlib, json, struct
import capstone, pefile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--report', required=True)
out = Path(parser.parse_args().report).resolve()
if out.exists():
    raise SystemExit('Refusing to overwrite original evidence')
raw = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True
spans = {r.struct.BeginAddress: r.struct.EndAddress for r in pe.DIRECTORY_ENTRY_EXCEPTION}

def witness(rva, end=None):
    # PE unwind fragments can split a logical procedure. Never call the first
    # fragment a complete Ghidra function body.
    limit = end if end is not None else spans[rva]
    data = pe.get_data(rva, limit-rva)
    ins = list(cs.disasm(data, base+rva))
    assert sum(i.size for i in ins) == len(data)
    strings = []
    calls = []
    for i in ins:
        if i.mnemonic in ['call', 'jmp'] and i.operands and i.operands[0].type == capstone.x86.X86_OP_IMM:
            calls.append({'at': hex(i.address), 'target': hex(i.operands[0].imm), 'instruction': i.mnemonic})
        for operand in i.operands:
            if operand.type != capstone.x86.X86_OP_MEM or operand.mem.base != capstone.x86.X86_REG_RIP:
                continue
            address = i.address+i.size+operand.mem.disp
            try:
                value = pe.get_data(address-base, 256).split(b'\0', 1)[0]
            except pefile.PEFormatError:
                continue
            if len(value) >= 5 and all(32 <= v < 127 for v in value):
                strings.append({'at': hex(i.address), 'address': hex(address), 'text': value.decode('ascii')})
    return {'start': hex(base+rva), 'endExclusive': hex(base+limit), 'sha256': hashlib.sha256(data).hexdigest(),
            'boundary': 'Explicit selected contiguous byte range' if end is not None else 'Exact PE unwind fragment; not necessarily complete logical function',
            'assembly': [f'{i.address:#x}: {i.mnemonic} {i.op_str}' for i in ins], 'directCalls': calls, 'strings': strings}

ranges = {
    'modalInsert': (0x1f66f0, 0x1f6794),
    'modalRemove': (0x1f7080, 0x1f70da),
    'reorderAfterRemoval': (0x1fc8c0, 0x1fc93e),
    'radialPriorTopAndGuard': (0x1f9320, 0x1f9348),
    'radialSubmenuCallbackScope': (0x1f8960, 0x1f89fa),
    'ordinaryGuiCallbackScope': (0x1e5830, 0x1e5871),
    'genericPanelDeactivate': (0x1fc470, 0x1fc660),
    'modalPanelDeactivate': (0x1fc440, 0x1fc462),
    'radialDeactivate': (0x1f8a00, 0x1f8b12),
    'examinePriorTop': (0x76ba70, 0x76ba80),
    'mainOptionsOpen': (0x6f86c0, None),
    'loadingOpen': (0x6e37f0, None),
    'goldOpen': (0x856190, None),
    'barterGoldOpen': (0x97da30, None),
    'itemSplitOpen': (0x9a8660, None),
    'mapNoteOpen': (0x891530, None),
    'examineGenericOpen': (0x799ea0, None),
    'examineObjectOpen': (0x79a1e0, None),
    'macroLabelOpen': (0x861780, None),
    'macroCommandOpen': (0x861680, None),
    'okCancelActivate': (0x2007e0, None),
}
rows = {name: witness(*value) for name, value in ranges.items()}
assert any(s['text'] == 'm_PositionInActivePanelList != NULL' for s in rows['genericPanelDeactivate']['strings'])
split = rows['itemSplitOpen']['assembly']
assert any('call 0x1409aa2f0' in s for s in split)
assert any('call 0x1401fbe40' in s for s in split)
# Decode LEA at the exact amount callback assignment; this connects the OPEN
# witness to the previously known9a6aa0 completion without relying on artwork.
lea = next(i for i in cs.disasm(pe.get_data(0x9a86cb, 7), base+0x9a86cb))
assert lea.mnemonic == 'lea' and lea.address+lea.size+lea.operands[1].mem.disp == base+0x9a6aa0
report = {'success': True, 'binarySha256': digest, 'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'witnesses': rows, 'fieldA0': {'meaning': 'm_PositionInActivePanelList', 'assertionAt': '0x1401fc5a0', 'modelOffset': '0x10'},
          'callbackOwner': {'address': '0x14140cdb8', 'meaning': 'CGuiObject::s_pCurrentEventObject', 'evidence': 'saved/set/restored by actual callback instruction ranges; named saved decompiler witnesses corroborate'},
          'itemSplit': {'constructor': '0x1409aa2f0', 'activate': '0x1401fbe40', 'amountCallback': '0x1409a6aa0', 'callbackLeaAt': '0x1409a86cb'},
          'limits': ['Static exact bytes and calls only; no live game or window execution', 'PE unwind fragment is not necessarily a complete logical function', 'No Nui::Window membership or input/render precedence inferred', 'Final radial deactivation body not executed here; original132 CPU dispatch and480 close decisions are separate'],
          'processes': 0, 'servers': 0, 'gpu': False, 'nativeBuilds': 0}
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'success': True, 'witnesses': len(rows), 'itemSplitCallback': report['itemSplit']['amountCallback'], 'report': str(out)}))
