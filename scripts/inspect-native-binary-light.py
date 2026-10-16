"""Unchanged complete binary light reader14007a790 including base reader
14007b6c0. Heap/memcpy and node type queries are captured lower boundaries;
no game asset bytes retained. Flare arrays empty, matching fx_light_clr.
This verifies scalar payload and serialized controller relocation, not GPU
lighting equations, lens flares or animation sampling.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
node,disk,model=m.heap,m.heap+0x2000,m.heap+0x4000
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x140c10368,0x140c10324]:
  p=m.heap+0x10000+allocation*0x1000;allocation+=1;m.finish(p)
 elif a==0x140c4f038:
  p=m.heap+0x10000+allocation*0x1000;allocation+=1
  if x:u.mem_write(p,bytes(u.mem_read(x,min(y,0x1000))))
  m.finish(p)
 elif a in [0x140c10370,0x140c4f024]:m.finish()
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a in [0x14008c2e0,0x14008c360]:m.finish(0)
 elif a==0x14008c300:m.finish(x)
 elif not(0x14007a790<=a<0x14007abd4 or 0x14007b6c0<=a<0x14007b9e1):raise RuntimeError(f'Unexpected native dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global allocation
 allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wf(disk+0x70,case['flareRadius'])
 for i,v in enumerate(case['flags']):m.wi(disk+0xb0+i*4,v)
 controls=[8,20,36,72,75,76,88,96,100,128,140]
 m.wi(disk+0x54,0x100);m.wi(disk+0x58,len(controls))
 for i,v in enumerate(controls):m.wi(model+0x100+i*12,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wq(rsp+0x28,model);m.wq(rsp+0x30,0)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[m.heap+0x9000,node,disk,m.heap+0x8000]):u.reg_write(reg,v)
 u.reg_write(UC_X86_REG_RSP,rsp);u.emu_start(0x14007a790,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=case,flareRadius=m.rf(node+0xa0),flags=[m.si(node+0xf8+i*4)for i in range(7)],controllers=[m.si(m.q(node+0x78)+i*12)for i in range(len(controls))])
rows=[run(dict(flareRadius=r,flags=list(flags)))for r,flags in itertools.product([0,.75,12.5],[(3,0,1,1,1,0,1),(5,1,0,0,0,0,0),(0,0,0,1,1,0,1),(255,0,1,0,0,0,0)])]
out=m.root/'backups/animations/native-binary-light-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
