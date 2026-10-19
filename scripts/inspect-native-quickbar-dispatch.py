"""Read-only client instruction references to quickbar Tracy source locations.
These are address candidates, not semantic or execution proof.
"""
import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-message-text').m
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from capstone.x86_const import X86_OP_MEM,X86_REG_RIP
cs=Cs(CS_ARCH_X86,CS_MODE_64);cs.detail=True;cs.skipdata=True;rows=[]
for i in cs.disasm(m.pe.get_data(0x1000,0xd50000),0x140001000):
 if not i.id:continue
 for op in i.operands:
  if op.type==X86_OP_MEM and op.mem.base==X86_REG_RIP:
   address=i.address+i.size+op.mem.disp
   if 0x140e41ce0<=address<=0x140e41d70:rows.append(dict(address=hex(i.address),instruction=i.mnemonic+' '+i.op_str,target=hex(address)))
out=m.root/'backups/animations/native-quickbar-dispatch-candidates.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=rows,output=str(out))))
