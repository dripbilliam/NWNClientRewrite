"""Bounded offline original level-up private cache instruction evidence.
Addresses are retained original caller/callee entries. The class BAB leaf
has no unwind record: its window ends at the next retained entry2997d0.
No procedure-completeness claim is inferred for arbitrary shared tails.
"""
from pathlib import Path
import sys,json,hashlib
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;image=pe.get_memory_mapped_image();md=Cs(CS_ARCH_X86,CS_MODE_64)
rows=[]
for begin,end in [(0x1402997b0,0x1402997d0)]+[(base+entry.struct.BeginAddress,base+entry.struct.EndAddress)for entry in pe.DIRECTORY_ENTRY_EXCEPTION if entry.struct.BeginAddress<=0x7f7d38<entry.struct.EndAddress]:
    instructions=[dict(address=hex(i.address),bytes=i.bytes.hex(),mnemonic=i.mnemonic,operands=i.op_str)for i in md.disasm(image[begin-base:end-base],begin)]
    rows.append(dict(start=hex(begin),endExclusive=hex(end),instructions=instructions))
out=root/'godot-client/reports/native-level-up-private-cache-source-v2.json';assert not out.exists(),'Preserve source evidence'
out.write_text(json.dumps(dict(binarySha256=digest,scope=__doc__,windows=rows),indent=2)+'\n')
for row in rows:
    print(row['start'],row['endExclusive'])
    for i in row['instructions']:print(i['address'],i['mnemonic'],i['operands'])
