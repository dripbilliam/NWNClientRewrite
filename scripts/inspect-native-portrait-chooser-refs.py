"""Read-only RIP-relative LEA references to portrait chooser strings.
Only derived addresses/labels are written. This is not a complete xref census.
"""
from pathlib import Path
import sys,json,hashlib,bisect
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
strings=json.loads((root/'backups/animations/rea-portrait-chooser-strings-v1.json').read_text())['structuredContent']['raw_result']
targets={int(row['address'],16):row['value'] for row in strings if int(row['address'],16)<base+0x1000000}
functions=sorted((e.struct.BeginAddress,e.struct.EndAddress) for e in pe.DIRECTORY_ENTRY_EXCEPTION)
begins=[r[0] for r in functions];decoder=Cs(CS_ARCH_X86,CS_MODE_64);rows=[]
for section in pe.sections:
 if not section.Characteristics&0x20000000:continue
 raw=section.get_data();at=-1
 while True:
  at=raw.find(b'\x8d',at+1)
  if at<0:break
  start=at-1
  if start<0 or at+6>len(raw) or not 0x48<=raw[start]<=0x4f or raw[at+1]&0xc7!=5:continue
  address=base+section.VirtualAddress+start
  target=address+7+int.from_bytes(raw[at+2:at+6],'little',signed=True)
  if target not in targets:continue
  instruction=next(decoder.disasm(raw[start:start+7],address),None)
  if not instruction or instruction.mnemonic!='lea' or instruction.size!=7:continue
  index=bisect.bisect_right(begins,address-base)-1
  owner=functions[index] if index>=0 and address-base<functions[index][1] else None
  rows.append(dict(address=hex(address),target=hex(target),label=targets[target],function=hex(base+owner[0]) if owner else None))
output=dict(target=digest,scope=__doc__,references=rows)
(root/'backups/animations/native-portrait-chooser-refs-v1.json').write_text(json.dumps(output,indent=2)+'\n')
print(json.dumps(output))
