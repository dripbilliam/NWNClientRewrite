"""Read-only native camera call sites from the pinned installed PE.
No original game bytes are written to the workspace or modified.
"""
import sys, hashlib, bisect
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from capstone.x86 import X86_OP_MEM,X86_REG_RIP
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
assert hashlib.sha256(data).hexdigest()=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
p=pefile.PE(data=data);base=p.OPTIONAL_HEADER.ImageBase;cs=Cs(CS_ARCH_X86,CS_MODE_64)
if sys.argv[1:2]==['scan-linear']:
 # Include leaf functions without unwind entries. Start at a verified function
 # entry; linear decoding is discovery evidence, not proof of function bounds.
 lo,hi=int(sys.argv[2],16),int(sys.argv[3],16);term=sys.argv[4]
 items=list(cs.disasm(p.get_data(lo-base,hi-lo),lo));shown=set()
 for n,i in enumerate(items):
  if term not in i.op_str:continue
  print(f'Linear candidate {i.address:#x}; verify entry/callers before use')
  for j in range(max(0,n-5),min(len(items),n+6)):
   if j not in shown:print(f'{items[j].address:#x}: {items[j].mnemonic} {items[j].op_str}');shown.add(j)
 sys.exit()
if sys.argv[1:2]==['scan-range']:
 lo,hi=int(sys.argv[2],16),int(sys.argv[3],16);term=sys.argv[4];shown=set()
 for entry in p.DIRECTORY_ENTRY_EXCEPTION:
  e=entry.struct;start,end=base+e.BeginAddress,base+e.EndAddress
  if end<=lo or start>=hi:continue
  items=list(cs.disasm(p.get_data(e.BeginAddress,e.EndAddress-e.BeginAddress),start))
  for n,i in enumerate(items):
   if term not in i.op_str or i.address in shown:continue
   print(f'Unwind fragment {start:#x}..{end:#x}; match {i.address:#x}')
   for j in range(max(0,n-5),min(len(items),n+6)):
    if items[j].address not in shown:print(f'{items[j].address:#x}: {items[j].mnemonic} {items[j].op_str}');shown.add(items[j].address)
 sys.exit()
if sys.argv[1:2]==['scan']:
 a=int(sys.argv[2],16);term=sys.argv[3];e=next(e.struct for e in p.DIRECTORY_ENTRY_EXCEPTION if base+e.struct.BeginAddress<=a<base+e.struct.EndAddress)
 items=list(cs.disasm(p.get_data(e.BeginAddress,e.EndAddress-e.BeginAddress),base+e.BeginAddress));shown=set()
 for n,i in enumerate(items):
  if term in i.op_str:
   for j in range(max(0,n-7),min(len(items),n+8)):
    if j not in shown:print(f'{items[j].address:#x}: {items[j].mnemonic} {items[j].op_str}');shown.add(j)
 sys.exit()
if sys.argv[1:2]==['calls']:
 targets={int(a,16)for a in sys.argv[2:]}
 for section in p.sections:
  if not section.Characteristics&0x20000000:continue
  raw=section.get_data();va=base+section.VirtualAddress;at=raw.find(b'\xe8')
  while at>=0:
   target=va+at+5+int.from_bytes(raw[at+1:at+5],'little',signed=True)
   if target in targets:print(f'{va+at:#x} -> {target:#x}')
   at=raw.find(b'\xe8',at+1)
 sys.exit()
if sys.argv[1:2]==['refs']:
 targets=[int(a,16)for a in sys.argv[2:]];cs.detail=True
 functions=[e.struct for e in p.DIRECTORY_ENTRY_EXCEPTION];starts=[base+e.BeginAddress for e in functions]
 for section in p.sections:
  if not section.Characteristics&0x20000000:continue
  # RIP disp32 may precede an immediate (CMP, MOV). Candidate windows must
  # include that suffix; assuming the displacement ends the instruction misses
  # native state gates/writes. Verify displacement location and decoded operand.
  raw=section.get_data();va=base+section.VirtualAddress
  for at in range(3,len(raw)-4):
   disp=int.from_bytes(raw[at:at+4],'little',signed=True);target=va+at+4+disp
   if not any(t-8<=target<t+32 for t in targets):continue
   for begin in range(max(0,at-11),at):
    for i in cs.disasm(raw[begin:at+12],va+begin,count=1):
     if i.disp_size!=4 or i.address+i.disp_offset!=va+at:continue
     actual=i.address+i.size+i.disp
     if not any(t<=actual<t+32 for t in targets):continue
     if not any(o.type==X86_OP_MEM and o.mem.base==X86_REG_RIP for o in i.operands):continue
     f=functions[bisect.bisect_right(starts,i.address)-1]
     print(f'{i.address:#x}: {i.mnemonic} {i.op_str}; target {actual:#x}; function {base+f.BeginAddress:#x}..{base+f.EndAddress:#x}')
 sys.exit()
for raw in sys.argv[1:]:
 a=int(raw,16)
 e=next((e.struct for e in p.DIRECTORY_ENTRY_EXCEPTION if base+e.struct.BeginAddress<=a<base+e.struct.EndAddress),None)
 lo,hi=(base+e.BeginAddress,base+e.EndAddress) if e else (a,a+768)
 print(f'Function unwind range {lo:#x}..{hi:#x}, around {a:#x}' if e else f'No unwind record; instruction window at {a:#x} (not a function-boundary claim)')
 # PE unwind records may describe only a compiler-split fragment/prologue.
 # Keep decoding the requested observation window; do not equate the unwind
 # fragment's end with the entire logical function.
 code=p.get_data(lo-base,max(hi-lo,a-lo+768))
 for i in cs.disasm(code,lo):
  if a-256<=i.address<a+768:print(f'{i.address:#x}: {i.mnemonic} {i.op_str}')
