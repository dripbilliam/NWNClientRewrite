"""Read-only OpenGL import/constant candidates; not rendering-state proof."""
import hashlib,struct,json,bisect
from pathlib import Path
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
root=Path(__file__).resolve().parents[1];data=(root/'../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
p=pefile.PE(data=data);base=p.OPTIONAL_HEADER.ImageBase;cs=Cs(CS_ARCH_X86,CS_MODE_64)
imports=[dict(name=e.name.decode(),address=hex(e.address))for d in p.DIRECTORY_ENTRY_IMPORT for e in d.imports if e.name and e.name.decode()in ['glCullFace','glFrontFace','glEnable','glDisable']]
strings=[]
for value in [b'glCullFace',b'glFrontFace']:
 start=0
 while (start:=data.find(value,start))>=0:strings.append(dict(name=value.decode(),address=hex(base+p.get_rva_from_offset(start))));start+=len(value)
entries=[e.struct for e in p.DIRECTORY_ENTRY_EXCEPTION];starts=[e.BeginAddress for e in entries];candidates=[];seen=set();calls=[]
for s in p.sections:
 if s.Name.rstrip(b'\0')!=b'.text':continue
 code=s.get_data();offset=0
 for opcode in [b'\xff\x15',b'\xff\x25']:
  at=0
  while (at:=code.find(opcode,at))>=0:
   dest=base+s.VirtualAddress+at+6+struct.unpack_from('<i',code,at+2)[0];rva=s.VirtualAddress+at;at+=2
   entry=next((e for e in imports if int(e['address'],16)==dest and e['name']in ['glCullFace','glFrontFace']),None)
   if not entry:continue
   index=bisect.bisect_right(starts,rva)-1
   if index<0 or rva>=entries[index].EndAddress:continue
   e=entries[index];ins=list(cs.disasm(p.get_data(e.BeginAddress,e.EndAddress-e.BeginAddress),base+e.BeginAddress))
   for i,v in enumerate(ins):
    if v.address==base+rva:calls.append(dict(name=entry['name'],procedure=hex(base+e.BeginAddress),address=hex(v.address),context=[dict(address=hex(x.address),text=x.mnemonic+' '+x.op_str)for x in ins[max(0,i-6):i+4]]))
 while (offset:=code.find(struct.pack('<I',0xb44),offset))>=0:
  rva=s.VirtualAddress+offset;index=bisect.bisect_right(starts,rva)-1;offset+=4
  if index<0 or rva>=entries[index].EndAddress:continue
  e=entries[index]
  if e.BeginAddress in seen:continue
  seen.add(e.BeginAddress);ins=list(cs.disasm(p.get_data(e.BeginAddress,e.EndAddress-e.BeginAddress),base+e.BeginAddress))
  for i,v in enumerate(ins):
   if '0xb44' in v.op_str:candidates.append(dict(procedure=hex(base+e.BeginAddress),address=hex(v.address),context=[dict(address=hex(x.address),text=x.mnemonic+' '+x.op_str)for x in ins[max(0,i-5):i+9]]))
output=root/'backups/animations/native-model-culling-candidates.json';output.write_text(json.dumps(dict(target=digest,scope=__doc__,imports=imports,strings=strings,candidates=candidates,calls=calls),indent=2)+'\n');print(json.dumps(dict(imports=imports,candidates=len(candidates),calls=calls)))
