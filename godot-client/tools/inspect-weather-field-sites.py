"""Read-only native client weather-state displacement inventory.
Candidate field uses are locations for further analysis, not semantic proof.
"""
from pathlib import Path
import sys,json,importlib
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator')
from capstone import Cs,CS_ARCH_X86,CS_MODE_64,CS_OP_MEM
from capstone.x86_const import X86_REG_RSP,X86_REG_RBP
decoder=Cs(CS_ARCH_X86,CS_MODE_64);decoder.detail=True;decoder.skipdata=True
rows=[];start,end=0x1407c0000,0x1407f0000
for inst in decoder.disasm(bytes(m.u.mem_read(start,end-start)),start):
 if inst.id==0:continue
 for operand in inst.operands:
  if operand.type==CS_OP_MEM and operand.mem.base not in [X86_REG_RSP,X86_REG_RBP] and operand.mem.disp in [0x2e0,0x2e8,0x2ec,0x2f0,0x2f1,0x2f4]:
   rows.append(dict(address=hex(inst.address),assembly=inst.mnemonic+' '+inst.op_str,offset=hex(operand.mem.disp)))
out=Path(sys.argv[1]);assert not out.exists();out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(sites=len(rows),rows=rows)))
