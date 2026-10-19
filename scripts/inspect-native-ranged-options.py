"""Read-only instruction windows for the native ranged receiver configuration.
Instruction text is static evidence; it is not an executed setting oracle.
"""
import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-message-text').m
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from capstone.x86_const import X86_OP_MEM,X86_REG_RIP
cs=Cs(CS_ARCH_X86,CS_MODE_64);cs.detail=True;cs.skipdata=True
rows=[]
for start,size in [(0x1406b98e0,0x260),(0x1409840e0,0x100)]:
 rows.append(dict(start=hex(start),instructions=[dict(address=hex(i.address),text=i.mnemonic+' '+i.op_str)for i in cs.disasm(m.pe.get_data(start-m.base,size),start)]))
instructions=list(cs.disasm(m.pe.get_data(0x6bc680,0x2200),0x1406bc680));candidates=[]
for index,i in enumerate(instructions):
 if i.id and any(o.type==X86_OP_MEM and o.mem.disp==0x40 for o in i.operands):candidates.append([dict(address=hex(e.address),text=e.mnemonic+' '+e.op_str)for e in instructions[max(0,index-6):index+7]])
instructions=list(cs.disasm(m.pe.get_data(0x6ae3b0,0xcdd6),0x1406ae3b0));callbacks=[]
for index,i in enumerate(instructions):
 if i.id and any(o.type==X86_OP_MEM and o.mem.base==X86_REG_RIP and i.address+i.size+o.mem.disp==0x140e2c6c8 for o in i.operands):
  window=[]
  for e in instructions[max(0,index-15):index+20]:
   entry=dict(address=hex(e.address),text=e.mnemonic+' '+e.op_str)
   for o in e.operands if e.id else []:
    if o.type==X86_OP_MEM and o.mem.base==X86_REG_RIP:
     address=e.address+e.size+o.mem.disp
     if 0x140d80000<=address<0x140e80000:entry['data']=m.pe.get_data(address-m.base,100).split(b'\0')[0].decode('ascii',errors='replace')
   window.append(entry)
  callbacks.append(window)
definition=[]
for address in range(0x140e2c690,0x140e2c718,8):
 value=int.from_bytes(m.pe.get_data(address-m.base,8),'little');entry=dict(address=hex(address),value=hex(value))
 if 0x140d80000<=value<0x140e80000:entry['text']=m.pe.get_data(value-m.base,150).split(b'\0',1)[0].decode('ascii',errors='replace')
 definition.append(entry)
getModel=hex(int.from_bytes(m.pe.get_data(0xe474e8+0x140,8),'little'))
readyModel=hex(int.from_bytes(m.pe.get_data(0xe6e978+0x10,8),'little'))
out=m.root/'backups/animations/native-ranged-option-instructions.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows,candidates=candidates,callbacks=callbacks,definition=definition,creatureGetModel=getModel,readyModel=readyModel),indent=2)+'\n');print(json.dumps(dict(getModel=getModel,readyModel=readyModel,output=str(out))))
