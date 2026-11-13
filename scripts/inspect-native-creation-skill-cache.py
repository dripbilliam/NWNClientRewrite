"""Read-only candidate writes to CNWCCreatureStats+E0 in its code region.
Linear Capstone candidates are not provider-confirmed instruction boundaries or
field ownership. Confirm interesting instructions and procedures with REA before
deriving native behavior; this scan itself is not a parity oracle.
"""
import importlib.util,json,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from capstone import Cs,CS_ARCH_X86,CS_MODE_64,CS_AC_WRITE
from capstone.x86 import X86_OP_MEM,X86_REG_RSP,X86_REG_RBP,X86_REG_RIP
if __name__=='__main__':
 frontend='--frontend' in sys.argv
 start,end=(0x1408d0000,0x1409d0000)if frontend else(0x1407ea000,0x1407fb000)
 cs=Cs(CS_ARCH_X86,CS_MODE_64);cs.detail=True;cs.skipdata=True;rows=[]
 for ins in cs.disasm(bytes(m.u.mem_read(start,end-start)),start):
  if ins.id==0:continue
  for operand in ins.operands:
   if operand.type==X86_OP_MEM and operand.mem.disp==0xe0 and operand.mem.base not in[X86_REG_RSP,X86_REG_RBP,X86_REG_RIP] and operand.access&CS_AC_WRITE:
    rows.append(dict(address=hex(ins.address),bytes=ins.bytes.hex(),mnemonic=ins.mnemonic,operands=ins.op_str))
 out=m.root/('backups/animations/native-creation-skill-cache-frontend-v1.json'if frontend else'backups/animations/native-creation-skill-cache-candidates-v1.json')
 assert not out.exists(),'Preserve prior research'
 out.write_text(json.dumps(dict(target=m.digest,region=[hex(start),hex(end)],scope=__doc__,candidates=rows),indent=2))
 print(json.dumps(dict(output=str(out),candidates=rows)))
