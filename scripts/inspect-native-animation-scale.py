"""Unmodified FindAnimScale140050ed0 over synthetic model/clip ownership chains.
No resource lookup or arithmetic replacement; includes >16 clip sentinel scans.
"""
import sys,importlib,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
def hook(u,a,n,data):
 if a==m.stop:u.emu_stop();return
 if not 0x140050ed0<=a<0x1400510b0:raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
cases=[]
for factors,owner,count in itertools.product([[1,.66,2],[.66,1,3],[0,2,1],[2,.5,4]],[0,1,2,None],[1,16,17,24]):
 u.mem_write(m.heap,bytes(0x100000));models=[m.heap+i*0x1000 for i in range(3)];clip=m.heap+0xf000
 for i,model in enumerate(models):
  array=model+0x200;m.wq(model+0x98,array);m.wi(model+0xa0,count);m.wf(model+0xcc,factors[i]);m.wq(model+0xa8,models[i+1] if i<2 else 0)
  for j in range(count):m.wq(array+j*8,clip if i==owner and j==0 else clip+0x100+j*8)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,models[0]);u.reg_write(UC_X86_REG_RDX,clip)
 u.emu_start(0x140050ed0,m.stop,count=10000)
 cases.append(dict(factors=factors,owner=owner,clipCount=count,result=m.xmm(UC_X86_REG_XMM0)))
out=m.root/'backups/animations/native-animation-scale-v1.json';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=cases),indent=2)+'\n');print(json.dumps(dict(cases=len(cases))))
