"""Read-only RIP-relative references to derived appearance research strings.
No original image or asset bytes are written; output is addresses and labels.
"""
import sys,json,struct,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
r=json.loads((root/'backups/animations/rea-arelith-robe-names-v1.json').read_text())
strings=r['structuredContent']['normalized_result'];targets={int(s['address'],16):s['value'] for s in strings}
rows=[]
for entry in pe.DIRECTORY_ENTRY_EXCEPTION:
 begin,end=entry.struct.BeginAddress,entry.struct.EndAddress
 if not 0x970000<=begin<0x980000:continue
 for ins in Cs(CS_ARCH_X86,CS_MODE_64).disasm(pe.get_data(begin,end-begin),base+begin):
  if '[rip ' not in ins.op_str:continue
  displacement=ins.op_str.split('[rip ',1)[1].split(']',1)[0]
  target=ins.address+ins.size+int(displacement.replace(' ',''),16)
  if target in targets:rows.append(dict(function=hex(base+begin),address=hex(ins.address),label=targets[target]))
out=root/'backups/animations/arelith-appearance-string-refs-v1.json'
out.write_text(json.dumps(dict(target=digest,references=rows),indent=2)+'\n')
print(json.dumps(rows))
