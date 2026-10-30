"""Execute unchanged original confirmation-result and delete-reselection code.
GUI deactivation/destruction, physical file removal/list decrement and preview
selection are captured boundaries. No native game process or user file changes.
"""
import importlib,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
rows=[];calls=[];owner=m.heap;table=m.heap+0x1000;destroy=m.stop+0x100
def integer(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def finish(value=0):
 rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,m.q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,value)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y=u.reg_read(UC_X86_REG_RCX),u.reg_read(UC_X86_REG_RDX);signed=struct.unpack('<i',struct.pack('<I',y&0xffffffff))[0]
 if a==0x1401fc440:calls.append(['deactivate',signed]);finish();return
 if a==destroy:calls.append(['destroy',signed]);finish();return
 if a==0x14070e5b0:calls.append(['delete-helper',integer(owner+0x12f8)]);m.wi(owner+0x1308,integer(owner+0x1308)-1);finish();return
 if a==0x140712440:calls.append(['preview',signed]);finish();return
 if a==0x1401ed160:raise RuntimeError('Unresolved selection helper')
 if a==select_tab:calls.append(['select-tab',signed]);finish();return
 if not any(lo<=a<=hi for lo,hi in [(0x1402015a0,0x1402015df),(0x140201e30,0x140201e7f),(0x140201ef0,0x140201f3f),(0x140710420,0x14071049f)]):raise RuntimeError('Unexpected original dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
# Resolve the original call from its current immutable PE instruction stream.
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
dis=Cs(CS_ARCH_X86,CS_MODE_64);dis.detail=True
body=list(dis.disasm(bytes(u.mem_read(0x140710420,0x80)),0x140710420))
targets=[i.operands[0].imm for i in body if i.mnemonic=='call' and i.operands and i.operands[0].type==2]
select_tab=next(a for a in targets if a not in [0x14070e5b0,0x140712440])
def run(entry,rcx,rdx):
 global calls
 calls=[];u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(owner,table);m.wq(table,destroy)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,rcx);u.reg_write(UC_X86_REG_RDX,rdx)
 return rsp
for name,entry,result in [('ok',0x140201ef0,1),('cancel',0x140201e30,2),('escape',0x1402015a0,2)]:
 run(entry,owner,0);u.emu_start(entry,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;assert calls==[['deactivate',result],['destroy',1]];rows.append(dict(kind='button',button=name,result=result,calls=calls))
for count in [1,2,3,7]:
 for selected in range(count):
  for result in [0,1,2,3]:
   run(0x140710420,owner,result);m.wi(owner+0x12f8,selected);m.wi(owner+0x1308,count);u.emu_start(0x140710420,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
   after=count-(result==1);expected=min(selected,after-1) if result==1 else None
   assert calls==([['delete-helper',selected],['select-tab',expected],['preview',expected]] if result==1 else [])
   rows.append(dict(kind='selection',count=count,selected=selected,result=result,after=after,next=expected,calls=calls))
out=m.root/'backups/animations/native-character-delete-results-v1.json';out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,selectTabAddress=hex(select_tab),cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),binarySha256=m.digest)))
