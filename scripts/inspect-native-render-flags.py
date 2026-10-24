"""Read-only RIP-relative native render-flag reference scan.

Candidate byte windows are verified by Capstone instruction boundaries within
PE unwind ranges. Leaf code without an unwind entry is not covered. Reports
direct RIP-relative accesses only, not pointer aliases, unresolved indirect
writes, dynamic overrides or runtime values. No game launch.
"""
from pathlib import Path
import bisect, hashlib, json, struct, sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64
from capstone.x86 import X86_OP_MEM, X86_REG_RIP

data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
# FullDynamicLighting is read at1400ccc01 in the saved Scene::Render dossier.
# The other two addresses are independently mapped configured light counts.
targets={0x14140ac58:'g_bFullDynamicLighting',0x14128e588:'LightManager::m_nMaxLights',0x14128e58c:'configured-shadow-light-count'}
entries=sorted((e.struct for e in pe.DIRECTORY_ENTRY_EXCEPTION),key=lambda e:e.BeginAddress)
starts=[e.BeginAddress for e in entries];candidates=set()
for section in pe.sections:
 if section.Name.rstrip(b'\0')!=b'.text':continue
 code=section.get_data();origin=base+section.VirtualAddress
 for offset in range(len(code)-4):
  end=origin+offset+4+struct.unpack_from('<i',code,offset)[0]
  # Memory operands can precede a byte or DWORD immediate.
  if not any(end+trailing in targets for trailing in (0,1,4)):continue
  rva=section.VirtualAddress+offset;index=bisect.bisect_right(starts,rva)-1
  if index>=0 and rva<entries[index].EndAddress:candidates.add(index)
cs=Cs(CS_ARCH_X86,CS_MODE_64);cs.detail=True;references=[]
for index in sorted(candidates):
 entry=entries[index];instructions=list(cs.disasm(pe.get_data(entry.BeginAddress,entry.EndAddress-entry.BeginAddress),base+entry.BeginAddress))
 for i,ins in enumerate(instructions):
  for operand in ins.operands:
   if operand.type!=X86_OP_MEM or operand.mem.base!=X86_REG_RIP:continue
   address=ins.address+ins.size+operand.mem.disp
   if address not in targets:continue
   references.append(dict(symbol=targets[address],target=hex(address),procedureRange=hex(base+entry.BeginAddress),
    callSite=hex(ins.address),operandAccess=operand.access,
    context=[dict(address=hex(x.address),instruction=x.mnemonic+' '+x.op_str)for x in instructions[max(0,i-9):i+10]]))
output=root/'runtime-logs/native-render-parity/render-flag-references.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(dict(build='89.8193.37-17',sha256=digest,scope=__doc__,references=references),indent=2)+'\n')
print(json.dumps(dict(output=str(output),verifiedReferences=len(references),candidateRanges=len(candidates))))
