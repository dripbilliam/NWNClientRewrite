"""Exact auth result producer/translation and rejection writer bodies."""
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
raw = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwserver.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6'
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
spans = {base+entry.struct.BeginAddress: base+entry.struct.EndAddress for entry in pe.DIRECTORY_ENTRY_EXCEPTION}
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True
rows = []
for start in [0x14001a990, 0x14001a920, 0x1400c2d20]:
    has_unwind = start in spans
    end = spans[start] if has_unwind else start+128
    body = pe.get_data(start-base, end-start)
    instructions = list(cs.disasm(body, start))
    if not has_unwind:
        padding = next((index for index, ins in enumerate(instructions) if ins.mnemonic == 'int3'), len(instructions))
        instructions = instructions[:padding]
        assert instructions
        end = instructions[-1].address+instructions[-1].size
        body = pe.get_data(start-base, end-start)
    strings = []
    for ins in instructions:
        for op in ins.operands:
            if op.type == capstone.x86.X86_OP_MEM and op.mem.base == capstone.x86.X86_REG_RIP:
                at = ins.address+ins.size+op.mem.disp
                try:
                    data = pe.get_data(at-base, 192).split(b'\0', 1)[0]
                    if len(data) >= 4 and all(32 <= byte <= 126 for byte in data):
                        strings.append({'at': hex(ins.address), 'address': hex(at), 'text': data.decode('ascii')})
                except pefile.PEFormatError:
                    pass
    rows.append({'start': hex(start), 'endExclusive': hex(end), 'bodySha256': hashlib.sha256(body).hexdigest(),
                 'boundary': 'exact_PE_unwind' if has_unwind else 'bounded128byte_leaf_segment_before_first_INT3_not_asserted_whole_function',
                 'assembly': [f'{ins.address:#x}: {ins.mnemonic} {ins.op_str}' for ins in instructions],
                 'staticStrings': strings,
                 'completeLinearDecode': bool(instructions) and instructions[-1].address+instructions[-1].size == end})
result = {'success': True, 'binarySha256': digest,
          'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'procedures': rows,
          'scope': 'Static exact three methods reached by4f17f0 key-auth rejection. No runtime credentials, auth bypass, delay, key change, or semantic result-code label is inferred.',
          'serversStarted': 0, 'nativeBuilds': 0, 'gpu': False}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'success': True, 'procedures': [{'start': row['start'], 'instructions': len(row['assembly']), 'strings': row['staticStrings']} for row in rows], 'report': str(output)}))
