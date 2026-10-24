"""Read-only native area fog-amount use-site inventory; no original execution."""
import sys,json,hashlib
from pathlib import Path
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64,CS_OP_MEM
source=Path(sys.argv[1]);out=Path(sys.argv[2]);data=source.read_bytes()
target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
assert hashlib.sha256(data).hexdigest()==target
assert not out.exists()
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;image=pe.get_memory_mapped_image()
md=Cs(CS_ARCH_X86,CS_MODE_64);md.detail=True
instructions=list(md.disasm(image[0x7d0000:0x7f0000],base+0x7d0000))
rows=[]
for i,ins in enumerate(instructions):
 if any(op.type==CS_OP_MEM and op.mem.disp==0x310 for op in ins.operands):
  owner=next((row.struct.BeginAddress+base for row in pe.DIRECTORY_ENTRY_EXCEPTION if row.struct.BeginAddress<=ins.address-base<row.struct.EndAddress),None)
  rows.append({'address':hex(ins.address),'unwindOwner':hex(owner) if owner else None,'instruction':ins.mnemonic+' '+ins.op_str,'context':[hex(v.address)+': '+v.mnemonic+' '+v.op_str for v in instructions[max(0,i-3):i+4]]})
result={'target':target,'range':['0x1407d0000','0x1407f0000'],'displacement':'0x310','scope':'Candidate use sites only; register base/semantic meaning requires per-function validation','rows':rows}
out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
