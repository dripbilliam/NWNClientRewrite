"""Finite static original-server key-auth log caller audit; no runtime keys."""
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
    raise SystemExit('Refusing to overwrite original observations')
started = time.monotonic()
raw = (ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwserver.exe').read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert digest == '98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6'
pe = pefile.PE(data=raw)
base = pe.OPTIONAL_HEADER.ImageBase
needle = b'Rejected key auth for player'
at = raw.find(needle)
assert at >= 0 and raw.find(needle, at+1) < 0
format_bytes = raw[at:at+256].split(b'\0', 1)[0]
address = base+pe.get_rva_from_offset(at)
text = next(section for section in pe.sections if section.Name.rstrip(b'\0') == b'.text')
code, origin = text.get_data(), base+text.VirtualAddress
spans = sorted((base+row.struct.BeginAddress, base+row.struct.EndAddress) for row in pe.DIRECTORY_ENTRY_EXCEPTION)
starts = [start for start, _ in spans]
candidates = set()
unowned = []
for modrm in (5, 13, 21, 29, 37, 45, 53, 61):
    offset = code.find(bytes([modrm]))
    checked = 0
    while offset >= 0:
        if offset+5 <= len(code) and origin+offset+5+struct.unpack_from('<i', code, offset+1)[0] == address:
            where = origin+offset
            index = bisect.bisect_right(starts, where)-1
            if index >= 0 and where < spans[index][1]:
                candidates.add(spans[index])
            else:
                unowned.append(hex(where))
        offset = code.find(bytes([modrm]), offset+1)
        checked += 1
        if checked % 4096 == 0 and time.monotonic()-started > 30:
            raise SystemExit('Finite30-second static audit bound exceeded')
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True
rows = []
for start, end in sorted(candidates):
    body = pe.get_data(start-base, end-start)
    instructions = list(cs.disasm(body, start))
    references = []
    for index, ins in enumerate(instructions):
        if any(operand.type == capstone.x86.X86_OP_MEM and operand.mem.base == capstone.x86.X86_REG_RIP
               and ins.address+ins.size+operand.mem.disp == address for operand in ins.operands):
            references.append({'at': hex(ins.address), 'neighborhood': [f'{i.address:#x}: {i.mnemonic} {i.op_str}' for i in instructions[max(0,index-35):index+24]]})
    if references:
        rows.append({'start': hex(start), 'endExclusive': hex(end), 'bodySha256': hashlib.sha256(body).hexdigest(),
                     'references': references, 'assembly': [f'{i.address:#x}: {i.mnemonic} {i.op_str}' for i in instructions],
                     'calls': [{'at': hex(i.address), 'target': hex(i.operands[0].imm)} for i in instructions if i.mnemonic == 'call' and i.operands and i.operands[0].type == capstone.x86.X86_OP_IMM],
                     'completeLinearDecode': bool(instructions) and instructions[-1].address+instructions[-1].size == end})
result = {'success': bool(rows), 'binarySha256': digest,
          'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'staticFormat': {'address': hex(address), 'text': format_bytes.decode('ascii'), 'sha256': hashlib.sha256(format_bytes+b'\0').hexdigest()},
          'procedures': rows, 'unownedCandidates': unowned, 'elapsedSeconds': time.monotonic()-started,
          'scope': 'Static exact original-server log-format references/unwind bodies. Format placeholders contain no runtime credential values. Authentication result2 semantic meaning remains unknown until its actual producer/case contract is proven; this is not an auth bypass or readiness fix.',
          'serversStarted': 0, 'gpu': False, 'nativeBuilds': 0}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'success': result['success'], 'procedures': [{'start': row['start'], 'references': [ref['at'] for ref in row['references']]} for row in rows], 'elapsedSeconds': result['elapsedSeconds'], 'report': str(output)}))
raise SystemExit(0 if rows else 1)
