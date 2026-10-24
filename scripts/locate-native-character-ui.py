"""Read-only RIP-relative LEA candidates for verified player-list handler strings.
Candidates require containing-procedure analysis before semantic claims.
"""
import sys,json,hashlib,struct
from pathlib import Path
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile,capstone
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();assert hashlib.sha256(data).hexdigest()=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);targets={0x140e58078:'char-layout',0x140e580a0:'skill-layout',0x140e580e0:'sheet-source',0x140e79010:'char-source',0x140e79910:'feat-source'};rows=[];decoder=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64)
for section in pe.sections:
 if not section.Characteristics&0x20000000:continue
 raw=section.get_data();base=pe.OPTIONAL_HEADER.ImageBase+section.VirtualAddress
 for rex in [b'\x48\x8d',b'\x4c\x8d']:
  offset=0
  while True:
   offset=raw.find(rex,offset)
   if offset<0:break
   if offset+7<=len(raw)and raw[offset+2]&0xc7==5:
    target=base+offset+7+struct.unpack_from('<i',raw,offset+3)[0]
    if target in targets:
     instruction=next(decoder.disasm(raw[offset:offset+7],base+offset),None)
     if instruction and instruction.size==7:rows.append(dict(address=hex(instruction.address),target=hex(target),setting=targets[target],instruction=instruction.mnemonic+' '+instruction.op_str))
   offset+=1

for row in rows:
 address=int(row['address'],16)-pe.OPTIONAL_HEADER.ImageBase
 entry=next((e.struct for e in pe.DIRECTORY_ENTRY_EXCEPTION if e.struct.BeginAddress<=address<e.struct.EndAddress),None)
 row['owner']=hex(pe.OPTIONAL_HEADER.ImageBase+entry.BeginAddress)if entry else None
pointers=[]
for target,label in targets.items():
 offset=0;pattern=struct.pack('<Q',target)
 while True:
  offset=data.find(pattern,offset)
  if offset<0:break
  pointers.append(dict(address=hex(pe.OPTIONAL_HEADER.ImageBase+pe.get_rva_from_offset(offset)),target=hex(target),setting=label));offset+=1
out=root/'backups/animations/native-character-ui-reference-candidates.json';out.write_text(json.dumps(dict(code=rows,pointers=pointers,strings=[dict(name=n,address=hex(pe.OPTIONAL_HEADER.ImageBase+pe.get_rva_from_offset(data.find(n.encode()))))for n in targets.values()if data.find(n.encode())>=0]),indent=2)+'\n');print(json.dumps(dict(code=rows,output=str(out))))
