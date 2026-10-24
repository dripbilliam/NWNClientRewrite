"""Read-only skill input disassembly from the hash-pinned installed PE.
No executable copying, native process attachment, injection or modification.
PE exception records provide function bounds; no semantic names are invented.
"""
import sys, json, hashlib, argparse
from pathlib import Path
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile,capstone
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
decoder=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64)
rows=[]
for address in [0x140805480,0x140702b80,0x1407c0860]:
 entries=[e.struct for e in pe.DIRECTORY_ENTRY_EXCEPTION if base+e.struct.BeginAddress<=address<base+e.struct.EndAddress]
 assert len(entries)==1
 entry=entries[0];start=base+entry.BeginAddress;end=base+entry.EndAddress
 offset=pe.get_offset_from_rva(entry.BeginAddress)
 rows.append(dict(address=hex(address),begin=hex(start),endExclusive=hex(end),instructions=[dict(at=hex(i.address),mnemonic=i.mnemonic,operands=i.op_str) for i in decoder.disasm(data[offset:offset+end-start],start)]))
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--report',default='godot-client/reports/native-skill-static-v2.json')
args=parser.parse_args()
output=(root/args.report).resolve()
assert output.is_relative_to(root/'godot-client/reports'), 'Report must stay in project reports'
assert not output.exists(), 'Existing evidence is preserved; choose a new report name'
with output.open('x',encoding='utf-8') as report: report.write(json.dumps(dict(binarySha256=digest,scope=__doc__,functions=rows),indent=2)+'\n')
for row in rows:
 print(row['begin'],row['endExclusive'])
 for instruction in row['instructions']:print(instruction['at'],instruction['mnemonic'],instruction['operands'])
